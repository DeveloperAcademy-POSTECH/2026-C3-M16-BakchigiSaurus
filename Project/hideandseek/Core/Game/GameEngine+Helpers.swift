//
//  GameEngine+Helpers.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation

extension GameEngine {
    func makeHidingStatusAssignments() -> [ParticipantStatusAssignment] {
        state.participantOrder.compactMap { participantID in
            guard state.participants[participantID] != nil else { return nil }
            return ParticipantStatusAssignment(playerID: participantID, status: .hiding)
        }
    }

    func makePlayingStatusAssignments(taggerID: PlayerID) -> [ParticipantStatusAssignment] {
        state.participantOrder.compactMap { participantID in
            guard state.participants[participantID] != nil else { return nil }
            let status: PlayerGameStatus = participantID == taggerID ? .seeking : .hiding
            return ParticipantStatusAssignment(playerID: participantID, status: status)
        }
    }

    func availableHintCandidates(from candidates: [HintCandidate]) -> [HintCandidate] {
        candidates.filter { candidate in
            guard let participant = state.participants[candidate.hiderID] else { return false }
            return participant.role == .hider && participant.status != .captured
        }
    }

    func canObserveProximity(
        for hiderID: PlayerID,
        sourcePlayerID: PlayerID
    ) -> Bool {
        guard state.phase == .playing else { return false }
        guard sourcePlayerID == state.taggerID else { return false }
        guard let participant = state.participants[hiderID], participant.role == .hider else { return false }
        return participant.status != .captured
    }

    func makeProximityUpdateEnvelope(
        hiderID: PlayerID,
        next: ProximityState,
        observedAt: Date,
        sourcePlayerID: PlayerID
    ) -> GameEventEnvelope {
        makeEnvelope(
            .proximityUpdated(
                ProximityUpdate(
                    hiderID: hiderID,
                    distance: next.lastDistance,
                    direction: next.lastDirection,
                    observedAt: observedAt,
                    enteredWarningRadiusAt: next.enteredWarningRadiusAt,
                    hiderWarningSentAt: next.hiderWarningSentAt,
                    taggerConfirmationSentAt: next.taggerConfirmationSentAt,
                    captureRequestSentAt: next.captureRequestSentAt
                )
            ),
            by: sourcePlayerID,
            at: observedAt
        )
    }

    func normalizeRolesAndStatuses() {
        for participantID in state.participantOrder {
            guard var participant = state.participants[participantID] else { continue }

            if participantID == state.taggerID {
                normalizeTaggerStatus(&participant)
            } else {
                normalizeHiderStatus(&participant)
            }

            state.participants[participantID] = participant
        }
    }

    func normalizeTaggerStatus(_ participant: inout GameParticipant) {
        participant.role = .tagger

        if state.phase == .playing {
            participant.status = .seeking
        } else if state.phase == .ended {
            participant.status = participant.status == .captured ? .captured : .finished
        } else if participant.status != .captured {
            participant.status = .hiding
        }
    }

    func normalizeHiderStatus(_ participant: inout GameParticipant) {
        participant.role = state.taggerID == nil ? .unassigned : .hider

        guard participant.status != .captured else { return }

        switch state.phase {
        case .lobby:
            participant.status = .waiting
        case .hiding, .playing:
            participant.status = .hiding
        case .ended:
            participant.status = .finished
        }
    }

    func makeEnvelope(_ event: GameEvent, by sourcePlayerID: PlayerID, at occurredAt: Date) -> GameEventEnvelope {
        let sequence = nextSequenceBySource[sourcePlayerID, default: 0]
        nextSequenceBySource[sourcePlayerID] = sequence + 1

        return GameEventEnvelope(
            id: GameEventID(sourcePlayerID: sourcePlayerID, sequence: sequence),
            sessionID: state.session.id,
            occurredAt: occurredAt,
            event: event
        )
    }

    func resolveTaggerID(preferredTaggerID: PlayerID?) -> PlayerID? {
        if let preferredTaggerID, state.participants[preferredTaggerID] != nil {
            return preferredTaggerID
        }

        let orderedParticipants = state.participantOrder.compactMap { state.participants[$0] }
        guard !orderedParticipants.isEmpty else { return nil }

        switch state.session.settings.taggerSelectionPolicy {
        case .manual:
            return preferredTaggerID
        case .random:
            let sortedParticipants = orderedParticipants.sorted { $0.id < $1.id }
            let index = Int(deterministicTaggerBucket() % UInt64(sortedParticipants.count))
            return sortedParticipants[index].id
        }
    }

    func deterministicTaggerBucket() -> UInt64 {
        withUnsafeBytes(of: state.session.id.uuid) { rawBuffer in
            rawBuffer.reduce(into: UInt64(0)) { partialResult, byte in
                partialResult = (partialResult << 5) &+ UInt64(byte)
            }
        }
    }

    func reduceProximity(
        _ current: ProximityState,
        distance: Float?,
        direction: DirectionVector?,
        observedAt: Date
    ) -> ProximityState {
        var next = current
        next.lastDistance = distance
        next.lastDirection = direction
        next.lastObservedAt = observedAt

        guard let distance else {
            next.enteredWarningRadiusAt = nil
            next.hiderWarningSentAt = nil
            next.taggerConfirmationSentAt = nil
            next.captureRequestSentAt = nil
            return next
        }

        if distance <= 5 {
            if next.enteredWarningRadiusAt == nil {
                next.enteredWarningRadiusAt = observedAt
            }
            if next.hiderWarningSentAt == nil {
                next.hiderWarningSentAt = observedAt
            }
            if let enteredAt = next.enteredWarningRadiusAt,
               observedAt.timeIntervalSince(enteredAt) >= 5,
               next.taggerConfirmationSentAt == nil
            {
                next.taggerConfirmationSentAt = observedAt
            }
        } else {
            next.enteredWarningRadiusAt = nil
            next.hiderWarningSentAt = nil
            next.taggerConfirmationSentAt = nil
        }

        if distance <= 0.2 {
            if next.captureRequestSentAt == nil {
                next.captureRequestSentAt = observedAt
            }
        } else {
            next.captureRequestSentAt = nil
        }

        return next
    }

    func willAllHidersBeCaptured(afterCapturing hiderID: PlayerID) -> Bool {
        let hiderIDs = state.participantOrder.filter { participantID in
            state.participants[participantID]?.role == .hider
        }

        guard !hiderIDs.isEmpty else { return false }

        return hiderIDs.allSatisfy { candidateID in
            if candidateID == hiderID {
                return true
            }
            return state.participants[candidateID]?.status == .captured
        }
    }
}
