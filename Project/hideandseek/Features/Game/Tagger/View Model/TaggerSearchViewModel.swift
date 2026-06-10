//
//  TaggerSearchViewModel.swift
//  hideandseek
//
//  Created by 캄초 on 6/8/26.
//

import Foundation
import SwiftUI
import Observation

enum HintDisplayResult: Hashable, Identifiable {
    case success
    case failure

    var id: Self {
        self
    }
}

@Observable
@MainActor
final class TaggerSearchViewModel {
    let gameModel: GameModel
    private let mcSession: MultipeerGameSession
    private let niManager: NearbyInteractionManager

    var isHintActive: Bool = false
    var latestObservedDistance: Float?
    var latestObservedDirection: DirectionVector?
    var latestObservedAt: Date?
    var localTaggerConfirmationSentAt: Date?
    var didReceiveLocalReading: Bool = false
    var isHiderWithinWarningRadius: Bool = false

    private var hintDisplayTask: Task<Void, Never>?
    private var proximityConfirmationTask: Task<Void, Never>?
    private var proximityStalenessTask: Task<Void, Never>?
    private var trackingTargetID: PlayerID?
    private var localEnteredWarningRadiusAt: Date?
    private var isProximityTrackingActive = false

    private let warningRadiusMeters: Float = 5
    private let requiredProximityDuration: TimeInterval = 5
    private let readingStaleDuration: TimeInterval = 2

    init(gameModel: GameModel, mcSession: MultipeerGameSession, niManager: NearbyInteractionManager) {
        self.gameModel = gameModel
        self.mcSession = mcSession
        self.niManager = niManager

        debugLog("init completed")
    }

    var hintCountRemaining: Int {
        gameModel.sharedState.hintCountRemaining
    }

    var canUseHint: Bool {
        gameModel.sharedState.canUseHint(by: gameModel.localPlayerID)
    }

    var nearestHiderDistance: Float? {
        currentObservedDistance
    }

    var nearestHiderDirection: DirectionVector? {
        if isHintActive, let hintedDirection = gameModel.sharedState.lastHint?.direction {
            return hintedDirection
        }

        return currentObservedDirection
    }

    var isRecording: Bool {
        isIslandExpanded
    }

    var isIslandExpanded: Bool {
        guard gameModel.sharedState.phase == .playing, gameModel.isLocalTagger else { return false }
        return isHiderWithinWarningRadius && localTaggerConfirmationSentAt != nil
    }

    var isCameraRevealed: Bool {
        true
    }

    private var currentObservedDistance: Float? {
        didReceiveLocalReading ? latestObservedDistance : nearestHiderProximity?.lastDistance
    }

    private var currentObservedDirection: DirectionVector? {
        didReceiveLocalReading ? latestObservedDirection : nearestHiderProximity?.lastDirection
    }

    var nearestHiderProximity: ProximityState? {
        gameModel.sharedState.proximityByHiderID.values
            .filter { $0.lastDistance != nil }
            .min { lhs, rhs in
                (lhs.lastDistance ?? .greatestFiniteMagnitude) < (rhs.lastDistance ?? .greatestFiniteMagnitude)
            }
    }

    var activeHiderIDs: [PlayerID] {
        gameModel.participants.compactMap { participant in
            guard participant.id != gameModel.localPlayerID,
                  participant.role != .tagger,
                  participant.status != .captured else {
                return nil
            }
            return participant.id
        }
    }

    private func setupNearbyInteractionCallbacks() {
        self.niManager.onReadingUpdated = { [weak self] (reading: NearbyInteractionReading) in
            guard let self else { return }

            let convertedDirection: DirectionVector? = {
                if let simdDir = reading.direction {
                    return DirectionVector(simdDir)
                }
                return nil
            }()

            Task { @MainActor in
                self.debugLog(
                    "NI reading received distance=\(self.format(distance: reading.distance)) " +
                    "timestamp=\(self.format(date: reading.timestamp)) " +
                    "canTrack=\(self.canTrackLocalProximity) activeHiders=\(self.activeHiderIDSummary)"
                )

                guard self.canTrackLocalProximity else {
                    self.debugLog(
                        "NI reading ignored: cannot track local proximity " +
                        "phase=\(self.gameModel.sharedState.phase) isLocalTagger=\(self.gameModel.isLocalTagger)"
                    )
                    self.resetProximityTracking(reason: "cannot track local proximity")
                    return
                }

                guard let hiderID = self.observedHiderID() else {
                    self.debugLog("NI reading ignored: no active hider to track")
                    self.resetProximityTracking(reason: "no active hider")
                    return
                }

                self.debugLog("tracking hider=\(self.shortID(hiderID))")

                self.recordLocalProximity(
                    distance: reading.distance,
                    direction: convertedDirection,
                    observedAt: reading.timestamp
                )

                let events = await self.gameModel.send(.observeProximity(
                    hiderID: hiderID,
                    distance: reading.distance,
                    direction: convertedDirection,
                    observedAt: reading.timestamp
                ))
                self.debugLog("observeProximity sent events=\(events.count) hider=\(self.shortID(hiderID))")
            }
        }
    }

    func tapHintButton() async -> HintDisplayResult? {
        guard canUseHint else { return nil }

        let candidates: [HintCandidate] = gameModel.participants
            .filter { $0.role == .hider && $0.status != .captured }
            .compactMap { participant in
                let proximity = gameModel.sharedState.proximityByHiderID[participant.id]
                let distance = currentDistance(for: participant.id, proximity: proximity)
                guard let distance, distance <= 5 else {
                    return nil
                }

                return HintCandidate(
                    hiderID: participant.id,
                    direction: currentDirection(for: participant.id, proximity: proximity),
                    distance: distance
                )
            }

        let events = await gameModel.send(.useHint(candidates: candidates))
        guard let resolution = hintResolution(from: events) else {
            return .failure
        }

        hintDisplayTask?.cancel()
        let result: HintDisplayResult = resolution.selectedHiderID == nil ? .failure : .success
        isHintActive = result == .success

        guard result == .success else {
            hintDisplayTask = nil
            return result
        }

        hintDisplayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 7 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.isHintActive = false
                self?.hintDisplayTask = nil
            }
        }

        return result
    }

    func cancelHintDisplay() {
        hintDisplayTask?.cancel()
        hintDisplayTask = nil
        isHintActive = false
    }

    func activateProximityTracking(reason: String = "manual") {
        guard gameModel.isLocalTagger else {
            debugLog("activateProximityTracking skipped reason=\(reason) isLocalTagger=false")
            return
        }

        setupNearbyInteractionCallbacks()
        isProximityTrackingActive = true
        let didResume = niManager.resumeSessionIfPossible()
        debugLog(
            "activateProximityTracking reason=\(reason) didResumeNI=\(didResume) " +
            "state={\(debugStateSummary)}"
        )
    }

    func deactivateProximityTracking(reason: String = "manual") {
        guard isProximityTrackingActive else {
            debugLog("deactivateProximityTracking skipped reason=\(reason) already inactive")
            return
        }

        niManager.onReadingUpdated = nil
        isProximityTrackingActive = false
        debugLog("deactivateProximityTracking reason=\(reason)")
    }

    func resetProximityTracking(reason: String = "manual") {
        debugLog("resetProximityTracking start reason=\(reason) state={\(debugStateSummary)}")
        proximityConfirmationTask?.cancel()
        proximityConfirmationTask = nil
        proximityStalenessTask?.cancel()
        proximityStalenessTask = nil
        localEnteredWarningRadiusAt = nil
        localTaggerConfirmationSentAt = nil
        trackingTargetID = nil
        latestObservedDistance = nil
        latestObservedDirection = nil
        latestObservedAt = nil
        didReceiveLocalReading = false
        isHiderWithinWarningRadius = false
        debugLog("resetProximityTracking end state={\(debugStateSummary)}")
    }

    private func recordLocalProximity(distance: Float?, direction: DirectionVector?, observedAt: Date) {
        didReceiveLocalReading = true
        latestObservedDistance = distance
        latestObservedDirection = direction
        latestObservedAt = observedAt
        scheduleProximityStalenessReset(for: observedAt)

        debugLog(
            "recordLocalProximity distance=\(format(distance: distance)) " +
            "observedAt=\(format(date: observedAt)) beforeDecision={\(debugStateSummary)}"
        )

        guard let distance else {
            debugLog("recordLocalProximity distance=nil -> compact")
            isHiderWithinWarningRadius = false
            clearLocalProximityConfirmation(reason: "distance nil")
            return
        }

        let isWithinWarningRadius = distance <= warningRadiusMeters
        isHiderWithinWarningRadius = isWithinWarningRadius
        debugLog(
            "recordLocalProximity threshold distance=\(format(distance: distance)) " +
            "within5m=\(isWithinWarningRadius)"
        )

        if isWithinWarningRadius {
            if localEnteredWarningRadiusAt == nil {
                localEnteredWarningRadiusAt = observedAt
                debugLog("entered warning radius at=\(format(date: observedAt)); scheduling 5s confirmation")
                scheduleLocalProximityConfirmation()
            }

            if let enteredAt = localEnteredWarningRadiusAt,
               observedAt.timeIntervalSince(enteredAt) >= requiredProximityDuration,
               localTaggerConfirmationSentAt == nil
            {
                debugLog(
                    "recordLocalProximity confirms by reading elapsed=" +
                    "\(format(seconds: observedAt.timeIntervalSince(enteredAt)))"
                )
                expandDynamicIsland(observedAt: observedAt)
            } else if let enteredAt = localEnteredWarningRadiusAt {
                debugLog(
                    "recordLocalProximity still waiting elapsed=" +
                    "\(format(seconds: observedAt.timeIntervalSince(enteredAt))) " +
                    "confirmedAt=\(format(date: localTaggerConfirmationSentAt))"
                )
            }
        } else {
            debugLog("left warning radius -> compact")
            clearLocalProximityConfirmation(reason: "distance greater than warning radius")
        }
    }

    private func scheduleLocalProximityConfirmation() {
        proximityConfirmationTask?.cancel()
        let enteredAt = localEnteredWarningRadiusAt ?? Date()
        let delay = max(0, requiredProximityDuration - Date().timeIntervalSince(enteredAt))

        debugLog(
            "scheduleLocalProximityConfirmation enteredAt=\(format(date: enteredAt)) " +
            "delay=\(format(seconds: delay))"
        )

        proximityConfirmationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else {
                    #if DEBUG
                    print("[TaggerSearchViewModel] confirmation task aborted: self nil")
                    #endif
                    return
                }

                let now = Date()
                let latestAge = self.latestObservedAt.map { now.timeIntervalSince($0) }
                self.debugLog(
                    "confirmation task woke enteredAt=\(self.format(date: enteredAt)) " +
                    "state={\(self.debugStateSummary)} latestAge=\(self.format(seconds: latestAge))"
                )

                guard self.canTrackLocalProximity else {
                    self.debugLog("confirmation blocked: canTrackLocalProximity=false")
                    return
                }

                guard self.isHiderWithinWarningRadius else {
                    self.debugLog("confirmation blocked: isHiderWithinWarningRadius=false")
                    return
                }

                guard self.localEnteredWarningRadiusAt == enteredAt else {
                    self.debugLog(
                        "confirmation blocked: enteredAt mismatch expected=\(self.format(date: enteredAt)) " +
                        "actual=\(self.format(date: self.localEnteredWarningRadiusAt))"
                    )
                    return
                }

                guard let latestObservedAt = self.latestObservedAt else {
                    self.debugLog("confirmation blocked: latestObservedAt=nil")
                    return
                }

                guard let distance = self.latestObservedDistance else {
                    self.debugLog("confirmation blocked: latestObservedDistance=nil")
                    return
                }

                guard distance <= self.warningRadiusMeters else {
                    self.debugLog(
                        "confirmation blocked: distance=\(self.format(distance: distance)) " +
                        "threshold=\(self.format(distance: self.warningRadiusMeters))"
                    )
                    return
                }

                guard now.timeIntervalSince(latestObservedAt) <= self.readingStaleDuration else {
                    self.debugLog(
                        "confirmation blocked: latest reading stale age=" +
                        "\(self.format(seconds: now.timeIntervalSince(latestObservedAt))) " +
                        "limit=\(self.format(seconds: self.readingStaleDuration))"
                    )
                    return
                }

                self.expandDynamicIsland(observedAt: Date())
                self.proximityConfirmationTask = nil
            }
        }
    }

    private func scheduleProximityStalenessReset(for observedAt: Date) {
        proximityStalenessTask?.cancel()
        let staleDuration = readingStaleDuration

        debugLog(
            "schedule staleness reset observedAt=\(format(date: observedAt)) " +
            "delay=\(format(seconds: staleDuration))"
        )

        proximityStalenessTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(staleDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else {
                    #if DEBUG
                    print("[TaggerSearchViewModel] staleness task aborted: self nil")
                    #endif
                    return
                }

                self.debugLog(
                    "staleness task woke observedAt=\(self.format(date: observedAt)) " +
                    "latestObservedAt=\(self.format(date: self.latestObservedAt))"
                )

                guard self.latestObservedAt == observedAt else {
                    self.debugLog("staleness ignored: a newer reading arrived")
                    return
                }

                self.debugLog("staleness reset fires -> compact")
                self.latestObservedDistance = nil
                self.latestObservedDirection = nil
                self.latestObservedAt = nil
                self.isHiderWithinWarningRadius = false
                self.clearLocalProximityConfirmation(reason: "latest reading stale")
            }
        }
    }

    private func expandDynamicIsland(observedAt: Date) {
        debugLog("expandDynamicIsland before observedAt=\(format(date: observedAt)) state={\(debugStateSummary)}")
        localTaggerConfirmationSentAt = observedAt
        debugLog("expandDynamicIsland after isIslandExpanded=\(isIslandExpanded) state={\(debugStateSummary)}")
        logProximityState("expanded")
    }

    private func clearLocalProximityConfirmation(reason: String = "unspecified") {
        debugLog("clearLocalProximityConfirmation reason=\(reason) before={\(debugStateSummary)}")
        proximityConfirmationTask?.cancel()
        proximityConfirmationTask = nil
        localEnteredWarningRadiusAt = nil
        localTaggerConfirmationSentAt = nil
        debugLog("clearLocalProximityConfirmation after={\(debugStateSummary)}")
        logProximityState("compact")
    }

    private var canTrackLocalProximity: Bool {
        gameModel.sharedState.phase == .playing && gameModel.isLocalTagger
    }

    private func logProximityState(_ state: String) {
        debugLog("dynamicIsland=\(state) state={\(debugStateSummary)}")
    }

    private var debugStateSummary: String {
        [
            "phase=\(gameModel.sharedState.phase)",
            "isLocalTagger=\(gameModel.isLocalTagger)",
            "distance=\(format(distance: latestObservedDistance))",
            "within5m=\(isHiderWithinWarningRadius)",
            "enteredAt=\(format(date: localEnteredWarningRadiusAt))",
            "latestAt=\(format(date: latestObservedAt))",
            "confirmedAt=\(format(date: localTaggerConfirmationSentAt))",
            "isIslandExpanded=\(isIslandExpanded)",
            "isRecording=\(isRecording)"
        ].joined(separator: " ")
    }

    private var activeHiderIDSummary: String {
        let ids = activeHiderIDs.map(shortID)
        return ids.isEmpty ? "[]" : "[\(ids.joined(separator: ","))]"
    }

    private func debugLog(_ message: String, function: String = #function) {
        #if DEBUG
        print("[TaggerSearchViewModel] \(function) \(message)")
        #endif
    }

    private func format(distance: Float?) -> String {
        guard let distance else { return "nil" }
        return String(format: "%.2fm", distance)
    }

    private func format(seconds: TimeInterval?) -> String {
        guard let seconds else { return "nil" }
        return String(format: "%.2fs", seconds)
    }

    private func format(date: Date?) -> String {
        guard let date else { return "nil" }
        return String(format: "%.3f", date.timeIntervalSince1970)
    }

    private func shortID(_ playerID: PlayerID) -> String {
        String(playerID.rawValue.uuidString.prefix(8))
    }

    private func currentDistance(for hiderID: PlayerID, proximity: ProximityState?) -> Float? {
        if hiderID == trackingTargetID, didReceiveLocalReading {
            return latestObservedDistance
        }

        return proximity?.lastDistance
    }

    private func currentDirection(for hiderID: PlayerID, proximity: ProximityState?) -> DirectionVector? {
        if hiderID == trackingTargetID, didReceiveLocalReading {
            return latestObservedDirection
        }

        return proximity?.lastDirection
    }

    private func hintResolution(from events: [GameEventEnvelope]) -> HintResolution? {
        events.compactMap { envelope in
            if case let .hintConsumed(resolution) = envelope.event {
                return resolution
            }

            return nil
        }
        .first
    }

    private func observedHiderID() -> PlayerID? {
        if let trackingTargetID, activeHiderIDs.contains(trackingTargetID) {
            return trackingTargetID
        }

        trackingTargetID = activeHiderIDs.first
        return trackingTargetID
    }
}
