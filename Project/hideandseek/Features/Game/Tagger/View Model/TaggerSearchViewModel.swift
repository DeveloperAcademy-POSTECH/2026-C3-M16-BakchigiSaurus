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
    var localTaggerConfirmationSentAt: Date?
    var didReceiveLocalReading: Bool = false
    var isHiderWithinRecordingRange: Bool = false

    private var hintDisplayTask: Task<Void, Never>?
    private var proximityConfirmationTask: Task<Void, Never>?
    private var trackingTargetID: PlayerID?
    private var localEnteredWarningRadiusAt: Date?

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
                self.recordLocalProximity(
                    distance: reading.distance,
                    direction: convertedDirection,
                    observedAt: reading.timestamp
                )

                guard let hiderID = self.observedHiderID() else { return }
                let events = await self.gameModel.send(.observeProximity(
                    hiderID: hiderID,
                    distance: reading.distance,
                    direction: convertedDirection,
                    observedAt: reading.timestamp
                ))
                self.applyProximityRule(from: events)
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
        localEnteredWarningRadiusAt = nil
        localTaggerConfirmationSentAt = nil
        latestObservedDistance = nil
        latestObservedDirection = nil
        didReceiveLocalReading = false
        isHiderWithinRecordingRange = false
    }

    private func recordLocalProximity(distance: Float?, direction: DirectionVector?, observedAt: Date) {
        didReceiveLocalReading = true
        latestObservedDistance = distance
        latestObservedDirection = direction

        guard let distance else {
            isHiderWithinRecordingRange = false
            clearLocalProximityConfirmation()
            return
        }

        let isWithinWarningRadius = distance <= 5
        isHiderWithinRecordingRange = isWithinWarningRadius

        if isWithinWarningRadius {
            if localEnteredWarningRadiusAt == nil {
                localEnteredWarningRadiusAt = observedAt
                scheduleLocalProximityConfirmation()
            }

            if let enteredAt = localEnteredWarningRadiusAt,
               observedAt.timeIntervalSince(enteredAt) >= 5,
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
        proximityConfirmationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self,
                      let distance = self.latestObservedDistance,
                      self.isHiderWithinRecordingRange,
                      distance <= 5 else {
                    return
                }

                self.expandDynamicIsland(observedAt: Date())
                self.proximityConfirmationTask = nil
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

    private func applyProximityRule(from events: [GameEventEnvelope]) {
        for event in events {
            guard case let .proximityUpdated(update) = event.event else { continue }
            applyProximityRule(from: update)
        }
    }

    private func applyProximityRule(from update: ProximityUpdate) {
        guard let distance = update.distance else {
            isHiderWithinRecordingRange = false
            clearLocalProximityConfirmation()
            return
        }

        let isWithinWarningRadius = distance <= 5
        isHiderWithinRecordingRange = isWithinWarningRadius

        guard isWithinWarningRadius else {
            clearLocalProximityConfirmation()
            return
        }

        if let confirmationSentAt = update.taggerConfirmationSentAt,
           isConfirmationInCurrentPlayingPhase(confirmationSentAt)
        {
            expandDynamicIsland(observedAt: confirmationSentAt)
        }
    }

    private func isConfirmationInCurrentPlayingPhase(_ confirmationSentAt: Date) -> Bool {
        guard gameModel.sharedState.phase == .playing else { return false }
        guard let phaseStartedAt = gameModel.sharedState.phaseStartedAt else { return true }
        return confirmationSentAt >= phaseStartedAt
    }

    private func logProximityState(_ state: String) {
//        #if DEBUG
//        print(
//            "[TaggerSearchViewModel] dynamicIsland=\(state)",
//            "distance=\(latestObservedDistance.map(String.init) ?? "nil")"
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
