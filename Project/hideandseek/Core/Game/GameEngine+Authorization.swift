//
//  GameEngine+Authorization.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation

extension GameEngine {
    func eventOrder(lhs: GameEventEnvelope, rhs: GameEventEnvelope) -> Bool {
        if lhs.occurredAt == rhs.occurredAt {
            return lhs.id < rhs.id
        }
        return lhs.occurredAt < rhs.occurredAt
    }

    func isAuthorizedRemoteEvent(_ envelope: GameEventEnvelope) -> Bool {
        switch envelope.event {
        case .participantUpserted, .participantRemoved, .taggerAssigned:
            isAuthorizedParticipantEvent(envelope)
        case .phaseChanged, .participantStatusesSet, .hintConsumed,
             .proximityUpdated, .captureRequested, .captureConfirmed, .captureRejected:
            isAuthorizedGameplayEvent(envelope)
        case .clipStarted, .clipEnded, .clipTransferUpdated:
            isAuthorizedClipEvent(envelope)
        case let .gameFinished(conclusion):
            isAuthorizedGameFinished(conclusion, sourcePlayerID: envelope.id.sourcePlayerID)
        }
    }

    func isAuthorizedParticipantEvent(_ envelope: GameEventEnvelope) -> Bool {
        let sourcePlayerID = envelope.id.sourcePlayerID

        switch envelope.event {
        case let .participantUpserted(participant):
            guard participant.id == sourcePlayerID else { return false }
            return !participant.isHost || participant.id == state.session.hostID
        case let .participantRemoved(participantID):
            return participantID == sourcePlayerID || sourcePlayerID == state.session.hostID
        case let .taggerAssigned(taggerID):
            return sourcePlayerID == state.session.hostID && state.participants[taggerID] != nil
        default:
            return false
        }
    }

    func isAuthorizedGameplayEvent(_ envelope: GameEventEnvelope) -> Bool {
        let sourcePlayerID = envelope.id.sourcePlayerID

        switch envelope.event {
        case let .phaseChanged(phaseState):
            return isAuthorizedPhaseChange(phaseState, sourcePlayerID: sourcePlayerID)
        case let .participantStatusesSet(assignments):
            guard sourcePlayerID == state.session.hostID else { return false }
            let knownPlayers = Set(state.participantOrder)
            return assignments.allSatisfy { knownPlayers.contains($0.playerID) }
        case let .hintConsumed(resolution):
            return sourcePlayerID == state.taggerID && resolution.taggerID == sourcePlayerID
        case let .proximityUpdated(update):
            guard sourcePlayerID == state.taggerID else { return false }
            guard let participant = state.participants[update.hiderID] else { return false }
            return participant.role == .hider
        case let .captureRequested(request):
            return sourcePlayerID == state.taggerID && request.taggerID == sourcePlayerID
        case let .captureConfirmed(hiderID, _):
            return sourcePlayerID == hiderID && state.activeCaptureRequests[hiderID] != nil
        case let .captureRejected(hiderID, _):
            return sourcePlayerID == hiderID && state.activeCaptureRequests[hiderID] != nil
        default:
            return false
        }
    }

    func isAuthorizedClipEvent(_ envelope: GameEventEnvelope) -> Bool {
        let sourcePlayerID = envelope.id.sourcePlayerID

        switch envelope.event {
        case let .clipStarted(clip):
            return clip.ownerID == sourcePlayerID
        case let .clipEnded(clipID, _):
            return state.clips[clipID]?.ownerID == sourcePlayerID
        case let .clipTransferUpdated(update):
            return sourcePlayerID == state.session.hostID || state.clips[update.clipID]?.ownerID == sourcePlayerID
        default:
            return false
        }
    }

    func isAuthorizedPhaseChange(
        _ phaseState: PhaseState,
        sourcePlayerID: PlayerID
    ) -> Bool {
        guard sourcePlayerID == state.session.hostID else { return false }

        switch phaseState.phase {
        case .hiding:
            return state.phase == .lobby || state.phase == .ended
        case .playing:
            return state.phase == .hiding && state.taggerID != nil
        case .ended:
            return true
        case .lobby:
            return false
        }
    }

    func isAuthorizedGameFinished(
        _ conclusion: GameConclusion,
        sourcePlayerID: PlayerID
    ) -> Bool {
        switch conclusion.reason {
        case .allHidersCaptured:
            sourcePlayerID == state.taggerID || sourcePlayerID == state.session.hostID
        case .timeExpired, .aborted:
            state.participants[sourcePlayerID] != nil
        case .hostEnded:
            sourcePlayerID == state.session.hostID
        }
    }
}
