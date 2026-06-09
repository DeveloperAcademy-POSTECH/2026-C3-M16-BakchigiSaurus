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
    var isHiderWithinRecordingRange: Bool = false

    private var hintDisplayTask: Task<Void, Never>?
    private var proximityConfirmationTask: Task<Void, Never>?
    private var proximityStalenessTask: Task<Void, Never>?
    private var trackingTargetID: PlayerID?
    private var localEnteredWarningRadiusAt: Date?

    private let warningRadiusMeters: Float = 5
    private let requiredProximityDuration: TimeInterval = 5
    private let readingStaleDuration: TimeInterval = 2

    init(gameModel: GameModel, mcSession: MultipeerGameSession, niManager: NearbyInteractionManager) {
        self.gameModel = gameModel
        self.mcSession = mcSession
        self.niManager = niManager

        setupNearbyInteractionCallbacks()
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
        isHiderWithinRecordingRange
    }

    var isIslandExpanded: Bool {
        guard let localTaggerConfirmationSentAt else { return false }
        return isHiderWithinRecordingRange && isConfirmationInCurrentPlayingPhase(localTaggerConfirmationSentAt)
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
                guard self.canTrackLocalProximity else {
                    self.resetProximityTracking()
                    return
                }

                guard let hiderID = self.observedHiderID() else {
                    self.resetProximityTracking()
                    return
                }

                self.recordLocalProximity(
                    distance: reading.distance,
                    direction: convertedDirection,
                    observedAt: reading.timestamp
                )

                await self.gameModel.send(.observeProximity(
                    hiderID: hiderID,
                    distance: reading.distance,
                    direction: convertedDirection,
                    observedAt: reading.timestamp
                ))
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

    func resetProximityTracking() {
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
        isHiderWithinRecordingRange = false
    }

    private func recordLocalProximity(distance: Float?, direction: DirectionVector?, observedAt: Date) {
        didReceiveLocalReading = true
        latestObservedDistance = distance
        latestObservedDirection = direction
        latestObservedAt = observedAt
        scheduleProximityStalenessReset(for: observedAt)

        guard let distance else {
            isHiderWithinRecordingRange = false
            clearLocalProximityConfirmation()
            return
        }

        let isWithinWarningRadius = distance <= warningRadiusMeters
        isHiderWithinRecordingRange = isWithinWarningRadius

        if isWithinWarningRadius {
            if localEnteredWarningRadiusAt == nil {
                localEnteredWarningRadiusAt = observedAt
                scheduleLocalProximityConfirmation()
            }

            if let enteredAt = localEnteredWarningRadiusAt,
               observedAt.timeIntervalSince(enteredAt) >= requiredProximityDuration,
               localTaggerConfirmationSentAt == nil
            {
                expandDynamicIsland(observedAt: observedAt)
            }
        } else {
            clearLocalProximityConfirmation()
        }
    }

    private func scheduleLocalProximityConfirmation() {
        proximityConfirmationTask?.cancel()
        let enteredAt = localEnteredWarningRadiusAt ?? Date()
        let delay = max(0, requiredProximityDuration - Date().timeIntervalSince(enteredAt))

        proximityConfirmationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self,
                      self.canTrackLocalProximity,
                      self.isHiderWithinRecordingRange,
                      self.localEnteredWarningRadiusAt == enteredAt,
                      let latestObservedAt = self.latestObservedAt,
                      let distance = self.latestObservedDistance,
                      distance <= self.warningRadiusMeters,
                      Date().timeIntervalSince(latestObservedAt) <= self.readingStaleDuration else {
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

        proximityStalenessTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(staleDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self,
                      self.latestObservedAt == observedAt else {
                    return
                }

                self.latestObservedDistance = nil
                self.latestObservedDirection = nil
                self.latestObservedAt = nil
                self.isHiderWithinRecordingRange = false
                self.clearLocalProximityConfirmation()
            }
        }
    }

    private func expandDynamicIsland(observedAt: Date) {
        localTaggerConfirmationSentAt = observedAt
        logProximityState("expanded")
    }

    private func clearLocalProximityConfirmation() {
        proximityConfirmationTask?.cancel()
        proximityConfirmationTask = nil
        localEnteredWarningRadiusAt = nil
        localTaggerConfirmationSentAt = nil
        logProximityState("compact")
    }

    private func isConfirmationInCurrentPlayingPhase(_ confirmationSentAt: Date) -> Bool {
        guard gameModel.sharedState.phase == .playing else { return false }
        guard let phaseStartedAt = gameModel.sharedState.phaseStartedAt else { return false }
        return confirmationSentAt >= phaseStartedAt
    }

    private var canTrackLocalProximity: Bool {
        gameModel.sharedState.phase == .playing && gameModel.isLocalTagger
    }

    private func logProximityState(_ state: String) {
//        #if DEBUG
//        print(
//            "[TaggerSearchViewModel] dynamicIsland=\(state)",
//            "phase=\(gameModel.sharedState.phase)",
//            "isLocalTagger=\(gameModel.isLocalTagger)",
//            "distance=\(latestObservedDistance.map(String.init) ?? "nil")",
//            "latestAt=\(latestObservedAt?.description ?? "nil")",
//            "enteredAt=\(localEnteredWarningRadiusAt?.description ?? "nil")",
//            "confirmedAt=\(localTaggerConfirmationSentAt?.description ?? "nil")",
//            "isRecording=\(isHiderWithinRecordingRange)"
//        )
//        #endif
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
