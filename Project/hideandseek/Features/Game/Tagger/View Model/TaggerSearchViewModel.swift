//
//  TaggerSearchViewModel.swift
//  hideandseek
//
//  Created by 캄초 on 6/8/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class TaggerSearchViewModel {
    let gameModel: GameModel
    private let niManager: NearbyInteractionManager

    var isHintActive = false
    private var trackedHiderID: PlayerID?

    init(gameModel: GameModel, niManager: NearbyInteractionManager) {
        self.gameModel = gameModel
        self.niManager = niManager

        setupNearbyInteractionCallbacks()
    }

    var hintCountRemaining: Int {
        gameModel.sharedState.hintCountRemaining
    }

    var nearestHiderDistance: Float? {
        guard let trackedHiderID else { return nil }
        return gameModel.participantState(for: trackedHiderID)?.nearbyObservation.distance
    }

    var nearestHiderDirection: DirectionVector? {
        if isHintActive, let direction = gameModel.latestHint?.direction {
            return direction
        }

        guard let trackedHiderID else { return nil }
        return gameModel.participantState(for: trackedHiderID)?.nearbyObservation.direction
    }

    var didResolveHint: Bool {
        gameModel.latestHint?.selectedHiderID != nil
    }

    var isTagConfirmationReady: Bool {
        guard let trackedHiderID else { return false }
        return gameModel.proximityState(for: trackedHiderID)?.taggerConfirmationSentAt != nil
    }

    private func setupNearbyInteractionCallbacks() {
        niManager.onReadingUpdated = { [weak self] (reading: NearbyInteractionReading) in
            guard let self else { return }

            let convertedDirection = reading.direction.map(DirectionVector.init)
            guard let hiderID = resolveTrackedHiderID() else { return }

            Task { @MainActor in
                self.gameModel.markNearbyObservation(
                    for: hiderID,
                    distance: reading.distance,
                    direction: convertedDirection,
                    at: reading.timestamp
                )

                await self.gameModel.send(
                    .observeProximity(
                        hiderID: hiderID,
                        distance: reading.distance,
                        direction: convertedDirection,
                        observedAt: reading.timestamp
                    )
                )
            }
        }
    }

    private func resolveTrackedHiderID() -> PlayerID? {
        if let trackedHiderID,
           let participant = gameModel.sharedState.participants[trackedHiderID],
           participant.role == .hider,
           participant.status != .captured
        {
            return trackedHiderID
        }

        if let hintedHiderID = gameModel.latestHint?.selectedHiderID,
           let participant = gameModel.sharedState.participants[hintedHiderID],
           participant.role == .hider,
           participant.status != .captured
        {
            trackedHiderID = hintedHiderID
            return hintedHiderID
        }

        let fallback = gameModel.sharedState.hiders.first(where: { $0.status != .captured })?.id
        trackedHiderID = fallback
        return fallback
    }

    func tapHintButton() async {
        guard hintCountRemaining > 0 else { return }

        let candidates = gameModel.participants
            .filter { $0.role == .hider && $0.status != .captured }
            .map { participant in
                let localObservation = gameModel.participantState(for: participant.id)?.nearbyObservation
                return HintCandidate(
                    hiderID: participant.id,
                    direction: localObservation?.direction,
                    distance: localObservation?.distance
                )
            }

        await gameModel.send(.useHint(candidates: candidates))
        trackedHiderID = gameModel.latestHint?.selectedHiderID ?? trackedHiderID
        isHintActive = true

        try? await Task.sleep(nanoseconds: 7 * 1_000_000_000)
        isHintActive = false
    }
}
