//
//  GameEvents.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation

// MARK: - Event Model

nonisolated struct ParticipantStatusAssignment: Codable, Hashable, Sendable {
    let playerID: PlayerID
    let status: PlayerGameStatus
}

nonisolated struct ClipTransferUpdate: Codable, Hashable, Sendable {
    let clipID: UUID
    let transferState: ClipTransferState
}

nonisolated struct ProximityUpdate: Codable, Hashable, Sendable {
    let hiderID: PlayerID
    let distance: Float?
    let direction: DirectionVector?
    let observedAt: Date
    let enteredWarningRadiusAt: Date?
    let hiderWarningSentAt: Date?
    let taggerConfirmationSentAt: Date?
    let captureRequestSentAt: Date?
}

nonisolated struct GameEventID: Codable, Hashable, Comparable, Sendable {
    let sourcePlayerID: PlayerID
    let sequence: Int

    static func < (lhs: GameEventID, rhs: GameEventID) -> Bool {
        if lhs.sequence == rhs.sequence {
            return lhs.sourcePlayerID < rhs.sourcePlayerID
        }
        return lhs.sequence < rhs.sequence
    }
}

nonisolated enum GameEvent: Codable, Hashable, Sendable {
    case participantUpserted(GameParticipant)
    case participantRemoved(PlayerID)
    case taggerAssigned(PlayerID)
    case phaseChanged(PhaseState)
    case participantStatusesSet([ParticipantStatusAssignment])
    case hintConsumed(HintResolution)
    case proximityUpdated(ProximityUpdate)
    case captureRequested(CaptureRequest)
    case captureConfirmed(hiderID: PlayerID, confirmedAt: Date)
    case clipStarted(ClipRecord)
    case clipEnded(clipID: UUID, endedAt: Date)
    case clipTransferUpdated(ClipTransferUpdate)
    case gameFinished(GameConclusion)
}

nonisolated struct GameEventEnvelope: Codable, Hashable, Sendable {
    let id: GameEventID
    let sessionID: UUID
    let occurredAt: Date
    let event: GameEvent
}

nonisolated struct GameMutation: Sendable {
    let sharedState: GameState
    let newEvents: [GameEventEnvelope]
}

nonisolated enum GameCommand: Sendable {
    case upsertParticipant(GameParticipant)
    case removeParticipant(PlayerID)
    case assignTagger(PlayerID?)
    case startHiding(startedAt: Date = .now)
    case startPlaying(startedAt: Date = .now)
    case useHint(candidates: [HintCandidate], usedAt: Date = .now)
    case observeProximity(hiderID: PlayerID, distance: Float?, direction: DirectionVector?, observedAt: Date = .now)
    case confirmCapture(hiderID: PlayerID, confirmedAt: Date = .now)
    case startClip(ownerID: PlayerID, clipID: UUID = UUID(), startedAt: Date = .now)
    case finishClip(clipID: UUID, endedAt: Date = .now)
    case updateClipTransfer(clipID: UUID, state: ClipTransferState)
    case evaluateDeadlines(evaluatedAt: Date = .now)
    case finishGame(reason: GameEndReason, endedAt: Date = .now)
}
