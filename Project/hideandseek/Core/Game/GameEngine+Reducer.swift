//
//  GameEngine+Reducer.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation

extension GameEngine {
    func apply(envelopes: [GameEventEnvelope]) {
        for envelope in envelopes.sorted(by: eventOrder(lhs:rhs:)) {
            guard envelope.sessionID == state.session.id else { continue }
            guard appliedEventIDs.insert(envelope.id).inserted else { continue }
            reduce(envelope.event)
            nextSequenceBySource[envelope.id.sourcePlayerID] = max(
                nextSequenceBySource[envelope.id.sourcePlayerID] ?? 0,
                envelope.id.sequence + 1
            )
        }
    }

    func reduce(_ event: GameEvent) {
        switch event {
        case .participantUpserted, .participantRemoved, .taggerAssigned:
            reduceParticipantEvent(event)
        case .phaseChanged, .participantStatusesSet, .hintConsumed,
             .proximityUpdated, .captureRequested, .captureConfirmed:
            reduceGameplayEvent(event)
        case .clipStarted, .clipEnded, .clipTransferUpdated:
            reduceClipEvent(event)
        case let .gameFinished(conclusion):
            reduceGameFinished(conclusion)
        }
    }

    func reduceParticipantEvent(_ event: GameEvent) {
        switch event {
        case let .participantUpserted(participant):
            state.participants[participant.id] = participant
            if !state.participantOrder.contains(participant.id) {
                state.participantOrder.append(participant.id)
            }
            normalizeRolesAndStatuses()
        case let .participantRemoved(participantID):
            state.participants.removeValue(forKey: participantID)
            state.participantOrder.removeAll { $0 == participantID }
            state.proximityByHiderID.removeValue(forKey: participantID)
            state.activeCaptureRequests.removeValue(forKey: participantID)
            if state.taggerID == participantID {
                state.taggerID = nil
            }
            normalizeRolesAndStatuses()
        case let .taggerAssigned(taggerID):
            state.taggerID = taggerID
            normalizeRolesAndStatuses()
        default:
            break
        }
    }

    func reduceGameplayEvent(_ event: GameEvent) {
        switch event {
        case let .phaseChanged(phaseState):
            reducePhaseChanged(phaseState)
        case let .participantStatusesSet(assignments):
            applyParticipantStatuses(assignments)
        case let .hintConsumed(resolution):
            state.lastHint = resolution
            state.hintCountRemaining = resolution.remainingCount
        case let .proximityUpdated(update):
            state.proximityByHiderID[update.hiderID] = ProximityState(
                lastDistance: update.distance,
                lastDirection: update.direction,
                lastObservedAt: update.observedAt,
                enteredWarningRadiusAt: update.enteredWarningRadiusAt,
                hiderWarningSentAt: update.hiderWarningSentAt,
                taggerConfirmationSentAt: update.taggerConfirmationSentAt,
                captureRequestSentAt: update.captureRequestSentAt
            )
        case let .captureRequested(request):
            state.activeCaptureRequests[request.hiderID] = request
        case let .captureConfirmed(hiderID, _):
            reduceCaptureConfirmed(hiderID: hiderID)
        default:
            break
        }
    }

    func reduceClipEvent(_ event: GameEvent) {
        switch event {
        case let .clipStarted(clip):
            state.clips[clip.id] = clip
        case let .clipEnded(clipID, endedAt):
            guard var clip = state.clips[clipID] else { return }
            clip.endedAt = endedAt
            state.clips[clipID] = clip
        case let .clipTransferUpdated(update):
            guard var clip = state.clips[update.clipID] else { return }
            clip.transferState = update.transferState
            state.clips[update.clipID] = clip
        default:
            break
        }
    }

    func reducePhaseChanged(_ phaseState: PhaseState) {
        state.phase = phaseState.phase
        state.phaseStartedAt = phaseState.startedAt
        state.hideDeadline = phaseState.hideDeadline
        state.gameDeadline = phaseState.gameDeadline

        if phaseState.phase == .hiding || phaseState.phase == .playing {
            resetTransientGameplayState()
        }

        normalizeRolesAndStatuses()
    }

    func applyParticipantStatuses(_ assignments: [ParticipantStatusAssignment]) {
        for assignment in assignments {
            guard var participant = state.participants[assignment.playerID] else { continue }
            participant.status = assignment.status
            state.participants[assignment.playerID] = participant
        }
    }

    func reduceCaptureConfirmed(hiderID: PlayerID) {
        state.activeCaptureRequests.removeValue(forKey: hiderID)
        state.proximityByHiderID.removeValue(forKey: hiderID)

        guard var participant = state.participants[hiderID] else { return }
        participant.status = .captured
        state.participants[hiderID] = participant
    }

    func reduceGameFinished(_ conclusion: GameConclusion) {
        state.phase = .ended
        state.endedAt = conclusion.endedAt
        state.endReason = conclusion.reason
        state.hideDeadline = nil
        state.gameDeadline = nil
        normalizeRolesAndStatuses()
    }

    func resetTransientGameplayState() {
        state.endedAt = nil
        state.endReason = nil
        state.lastHint = nil
        state.hintCountRemaining = state.session.settings.hintCount
        state.proximityByHiderID.removeAll()
        state.activeCaptureRequests.removeAll()
        state.clips.removeAll()
    }
}
