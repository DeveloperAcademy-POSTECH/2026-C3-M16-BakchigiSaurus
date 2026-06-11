//
//  GameEngine+Commands.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation

extension GameEngine {
    func makeEvents(
        for command: GameCommand,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        switch command {
        case .upsertParticipant, .removeParticipant, .assignTagger:
            makeParticipantEvents(for: command, sourcePlayerID: sourcePlayerID)
        case .startHiding, .startPlaying, .useHint, .observeProximity, .confirmCapture, .evaluateDeadlines, .finishGame:
            makeGameplayEvents(for: command, sourcePlayerID: sourcePlayerID)
        case .startClip, .finishClip, .updateClipTransfer:
            makeClipEvents(for: command, sourcePlayerID: sourcePlayerID)
        }
    }

    func makeParticipantEvents(
        for command: GameCommand,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        switch command {
        case let .upsertParticipant(participant):
            return [makeEnvelope(.participantUpserted(participant), by: sourcePlayerID, at: .now)]
        case let .removeParticipant(participantID):
            return [makeEnvelope(.participantRemoved(participantID), by: sourcePlayerID, at: .now)]
        case let .assignTagger(preferredTaggerID):
            guard let taggerID = resolveTaggerID(preferredTaggerID: preferredTaggerID) else {
                return []
            }
            return [makeEnvelope(.taggerAssigned(taggerID), by: sourcePlayerID, at: .now)]
        default:
            return []
        }
    }

    func makeGameplayEvents(
        for command: GameCommand,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        switch command {
        case let .startHiding(startedAt):
            makeStartHidingEvents(startedAt: startedAt, sourcePlayerID: sourcePlayerID)
        case let .startPlaying(startedAt):
            makeStartPlayingEvents(startedAt: startedAt, sourcePlayerID: sourcePlayerID)
        case let .useHint(candidates, usedAt):
            makeHintEvents(candidates: candidates, usedAt: usedAt, sourcePlayerID: sourcePlayerID)
        case let .observeProximity(hiderID, distance, direction, observedAt):
            makeProximityEvents(
                hiderID: hiderID,
                distance: distance,
                direction: direction,
                observedAt: observedAt,
                sourcePlayerID: sourcePlayerID
            )
        case let .confirmCapture(hiderID, confirmedAt):
            makeCaptureConfirmationEvents(
                hiderID: hiderID,
                confirmedAt: confirmedAt,
                sourcePlayerID: sourcePlayerID
            )
        case let .evaluateDeadlines(evaluatedAt):
            makeDeadlineEvents(evaluatedAt: evaluatedAt, sourcePlayerID: sourcePlayerID)
        case let .finishGame(reason, endedAt):
            makeFinishGameEvents(reason: reason, endedAt: endedAt, sourcePlayerID: sourcePlayerID)
        default:
            []
        }
    }

    func makeClipEvents(
        for command: GameCommand,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        switch command {
        case let .startClip(ownerID, clipID, startedAt):
            let clip = ClipRecord(id: clipID, ownerID: ownerID, startedAt: startedAt)
            return [makeEnvelope(.clipStarted(clip), by: sourcePlayerID, at: startedAt)]
        case let .finishClip(clipID, endedAt):
            guard state.clips[clipID] != nil else { return [] }
            return [makeEnvelope(.clipEnded(clipID: clipID, endedAt: endedAt), by: sourcePlayerID, at: endedAt)]
        case let .updateClipTransfer(clipID, transferState):
            guard state.clips[clipID] != nil else { return [] }
            let update = ClipTransferUpdate(clipID: clipID, transferState: transferState)
            return [makeEnvelope(.clipTransferUpdated(update), by: sourcePlayerID, at: .now)]
        default:
            return []
        }
    }

    func makeStartHidingEvents(
        startedAt: Date,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        guard state.phase == .lobby || state.phase == .ended else { return [] }
        guard let taggerID = resolveTaggerID(preferredTaggerID: state.taggerID) else { return [] }

        let phaseState = PhaseState(
            phase: .hiding,
            startedAt: startedAt,
            hideDeadline: startedAt.addingTimeInterval(TimeInterval(state.session.settings.hideTimeSeconds)),
            gameDeadline: nil
        )

        return [
            makeEnvelope(.taggerAssigned(taggerID), by: sourcePlayerID, at: startedAt),
            makeEnvelope(.participantStatusesSet(makeHidingStatusAssignments()), by: sourcePlayerID, at: startedAt),
            makeEnvelope(.phaseChanged(phaseState), by: sourcePlayerID, at: startedAt)
        ]
    }

    func makeStartPlayingEvents(
        startedAt: Date,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        guard state.phase == .hiding else { return [] }
        guard let taggerID = state.taggerID else { return [] }

        let phaseState = PhaseState(
            phase: .playing,
            startedAt: startedAt,
            hideDeadline: state.hideDeadline,
            gameDeadline: startedAt.addingTimeInterval(TimeInterval(state.session.settings.gameTotalSeconds))
        )

        return [
            makeEnvelope(
                .participantStatusesSet(makePlayingStatusAssignments(taggerID: taggerID)),
                by: sourcePlayerID,
                at: startedAt
            ),
            makeEnvelope(.phaseChanged(phaseState), by: sourcePlayerID, at: startedAt)
        ]
    }

    func makeHintEvents(
        candidates: [HintCandidate],
        usedAt: Date,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        guard state.canUseHint(by: sourcePlayerID) else { return [] }

        let selectedCandidate = availableHintCandidates(from: candidates).randomElement()
        let resolution = HintResolution(
            taggerID: sourcePlayerID,
            usedAt: usedAt,
            remainingCount: max(0, state.hintCountRemaining - 1),
            selectedHiderID: selectedCandidate?.hiderID,
            direction: selectedCandidate?.direction,
            horizontalAngle: selectedCandidate?.horizontalAngle
        )

        return [makeEnvelope(.hintConsumed(resolution), by: sourcePlayerID, at: usedAt)]
    }

    func makeProximityEvents(
        hiderID: PlayerID,
        distance: Float?,
        direction: DirectionVector?,
        observedAt: Date,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        guard canObserveProximity(for: hiderID, sourcePlayerID: sourcePlayerID) else { return [] }

        let current = state.proximityByHiderID[hiderID] ?? .empty
        let next = reduceProximity(current, distance: distance, direction: direction, observedAt: observedAt)
        var events = [
            makeProximityUpdateEnvelope(
                hiderID: hiderID,
                next: next,
                observedAt: observedAt,
                sourcePlayerID: sourcePlayerID
            )
        ]

        if current.captureRequestSentAt == nil, let requestAt = next.captureRequestSentAt {
            let request = CaptureRequest(
                taggerID: sourcePlayerID,
                hiderID: hiderID,
                requestedAt: requestAt
            )
            events.append(makeEnvelope(.captureRequested(request), by: sourcePlayerID, at: requestAt))
        }

        return events
    }

    func makeCaptureConfirmationEvents(
        hiderID: PlayerID,
        confirmedAt: Date,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        guard state.phase == .playing else { return [] }
        guard sourcePlayerID == hiderID else { return [] }
        guard state.activeCaptureRequests[hiderID] != nil else { return [] }

        var events = [
            makeEnvelope(
                .captureConfirmed(hiderID: hiderID, confirmedAt: confirmedAt),
                by: sourcePlayerID,
                at: confirmedAt
            )
        ]

        if willAllHidersBeCaptured(afterCapturing: hiderID) {
            let conclusion = GameConclusion(reason: .allHidersCaptured, endedAt: confirmedAt)
            events.append(makeEnvelope(.gameFinished(conclusion), by: sourcePlayerID, at: confirmedAt))
        }

        return events
    }

    func makeDeadlineEvents(
        evaluatedAt: Date,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        guard state.phase == .playing else { return [] }
        guard let gameDeadline = state.gameDeadline, evaluatedAt >= gameDeadline else { return [] }
        let conclusion = GameConclusion(reason: .timeExpired, endedAt: evaluatedAt)
        return [makeEnvelope(.gameFinished(conclusion), by: sourcePlayerID, at: evaluatedAt)]
    }

    func makeFinishGameEvents(
        reason: GameEndReason,
        endedAt: Date,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        guard state.phase != .ended else { return [] }
        let conclusion = GameConclusion(reason: reason, endedAt: endedAt)
        return [makeEnvelope(.gameFinished(conclusion), by: sourcePlayerID, at: endedAt)]
    }
}
