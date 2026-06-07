//
//  GameEngine.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation

// MARK: - Engine

actor GameEngine {
    private var state: GameState
    private var appliedEventIDs: Set<GameEventID>
    private var nextSequenceBySource: [PlayerID: Int]

    init(initialState: GameState) {
        self.state = initialState
        self.appliedEventIDs = []
        self.nextSequenceBySource = [:]
    }

    func snapshot() -> GameState {
        state
    }

    func apply(_ command: GameCommand, as sourcePlayerID: PlayerID) -> GameMutation {
        let events = makeEvents(for: command, sourcePlayerID: sourcePlayerID)
        apply(envelopes: events)
        return GameMutation(sharedState: state, newEvents: events)
    }

    func merge(_ remoteEvents: [GameEventEnvelope]) -> GameMutation {
        let acceptedEvents = remoteEvents
            .sorted(by: eventOrder(lhs:rhs:))
            .filter(isAuthorizedRemoteEvent(_:))

        apply(envelopes: acceptedEvents)
        return GameMutation(sharedState: state, newEvents: acceptedEvents)
    }
}

private extension GameEngine {
    func makeEvents(
        for command: GameCommand,
        sourcePlayerID: PlayerID
    ) -> [GameEventEnvelope] {
        switch command {
        case .upsertParticipant(let participant):
            return [makeEnvelope(.participantUpserted(participant), by: sourcePlayerID, at: .now)]

        case .removeParticipant(let participantID):
            return [makeEnvelope(.participantRemoved(participantID), by: sourcePlayerID, at: .now)]

        case .assignTagger(let preferredTaggerID):
            guard let taggerID = resolveTaggerID(preferredTaggerID: preferredTaggerID) else {
                return []
            }
            return [makeEnvelope(.taggerAssigned(taggerID), by: sourcePlayerID, at: .now)]

        case .startHiding(let startedAt):
            guard state.phase == .lobby || state.phase == .ended else { return [] }
            guard let taggerID = resolveTaggerID(preferredTaggerID: state.taggerID) else { return [] }

            let statusAssignments = state.participantOrder.compactMap { participantID -> ParticipantStatusAssignment? in
                guard state.participants[participantID] != nil else { return nil }
                return ParticipantStatusAssignment(playerID: participantID, status: .hiding)
            }

            let phaseState = PhaseState(
                phase: .hiding,
                startedAt: startedAt,
                hideDeadline: startedAt.addingTimeInterval(TimeInterval(state.session.settings.hideTimeSeconds)),
                gameDeadline: nil
            )

            return [
                makeEnvelope(.taggerAssigned(taggerID), by: sourcePlayerID, at: startedAt),
                makeEnvelope(.participantStatusesSet(statusAssignments), by: sourcePlayerID, at: startedAt),
                makeEnvelope(.phaseChanged(phaseState), by: sourcePlayerID, at: startedAt)
            ]

        case .startPlaying(let startedAt):
            guard state.phase == .hiding else { return [] }
            guard let taggerID = state.taggerID else { return [] }

            let statusAssignments = state.participantOrder.compactMap { participantID -> ParticipantStatusAssignment? in
                guard state.participants[participantID] != nil else { return nil }
                let status: PlayerGameStatus = participantID == taggerID ? .seeking : .hiding
                return ParticipantStatusAssignment(playerID: participantID, status: status)
            }

            let phaseState = PhaseState(
                phase: .playing,
                startedAt: startedAt,
                hideDeadline: state.hideDeadline,
                gameDeadline: startedAt.addingTimeInterval(TimeInterval(state.session.settings.gameTotalSeconds))
            )

            return [
                makeEnvelope(.participantStatusesSet(statusAssignments), by: sourcePlayerID, at: startedAt),
                makeEnvelope(.phaseChanged(phaseState), by: sourcePlayerID, at: startedAt)
            ]

        case .useHint(let candidates, let usedAt):
            guard state.canUseHint(by: sourcePlayerID) else { return [] }
            let availableCandidates = candidates.filter { candidate in
                guard let participant = state.participants[candidate.hiderID] else { return false }
                return participant.role == .hider && participant.status != .captured
            }
            let selectedCandidate = availableCandidates.randomElement()
            let resolution = HintResolution(
                taggerID: sourcePlayerID,
                usedAt: usedAt,
                remainingCount: max(0, state.hintCountRemaining - 1),
                selectedHiderID: selectedCandidate?.hiderID,
                direction: selectedCandidate?.direction
            )
            return [makeEnvelope(.hintConsumed(resolution), by: sourcePlayerID, at: usedAt)]

        case .observeProximity(let hiderID, let distance, let direction, let observedAt):
            guard state.phase == .playing else { return [] }
            guard sourcePlayerID == state.taggerID else { return [] }
            guard let participant = state.participants[hiderID], participant.role == .hider else { return [] }
            guard participant.status != .captured else { return [] }

            let current = state.proximityByHiderID[hiderID] ?? .empty
            let next = reduceProximity(current, distance: distance, direction: direction, observedAt: observedAt)

            var events = [
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

        case .confirmCapture(let hiderID, let confirmedAt):
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

        case .startClip(let ownerID, let clipID, let startedAt):
            let clip = ClipRecord(id: clipID, ownerID: ownerID, startedAt: startedAt)
            return [makeEnvelope(.clipStarted(clip), by: sourcePlayerID, at: startedAt)]

        case .finishClip(let clipID, let endedAt):
            guard state.clips[clipID] != nil else { return [] }
            return [makeEnvelope(.clipEnded(clipID: clipID, endedAt: endedAt), by: sourcePlayerID, at: endedAt)]

        case .updateClipTransfer(let clipID, let transferState):
            guard state.clips[clipID] != nil else { return [] }
            let update = ClipTransferUpdate(clipID: clipID, transferState: transferState)
            return [makeEnvelope(.clipTransferUpdated(update), by: sourcePlayerID, at: .now)]

        case .evaluateDeadlines(let now):
            guard state.phase == .playing else { return [] }
            guard let gameDeadline = state.gameDeadline, now >= gameDeadline else { return [] }
            let conclusion = GameConclusion(reason: .timeExpired, endedAt: now)
            return [makeEnvelope(.gameFinished(conclusion), by: sourcePlayerID, at: now)]

        case .finishGame(let reason, let endedAt):
            guard state.phase != .ended else { return [] }
            let conclusion = GameConclusion(reason: reason, endedAt: endedAt)
            return [makeEnvelope(.gameFinished(conclusion), by: sourcePlayerID, at: endedAt)]
        }
    }

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
        case .participantUpserted(let participant):
            state.participants[participant.id] = participant
            if !state.participantOrder.contains(participant.id) {
                state.participantOrder.append(participant.id)
            }
            normalizeRolesAndStatuses()

        case .participantRemoved(let participantID):
            state.participants.removeValue(forKey: participantID)
            state.participantOrder.removeAll { $0 == participantID }
            state.proximityByHiderID.removeValue(forKey: participantID)
            state.activeCaptureRequests.removeValue(forKey: participantID)
            if state.taggerID == participantID {
                state.taggerID = nil
            }
            normalizeRolesAndStatuses()

        case .taggerAssigned(let taggerID):
            state.taggerID = taggerID
            normalizeRolesAndStatuses()

        case .phaseChanged(let phaseState):
            state.phase = phaseState.phase
            state.phaseStartedAt = phaseState.startedAt
            state.hideDeadline = phaseState.hideDeadline
            state.gameDeadline = phaseState.gameDeadline

            if phaseState.phase == .hiding {
                state.endedAt = nil
                state.endReason = nil
                state.lastHint = nil
                state.hintCountRemaining = state.session.settings.hintCount
                state.proximityByHiderID.removeAll()
                state.activeCaptureRequests.removeAll()
                state.clips.removeAll()
            }

            normalizeRolesAndStatuses()

        case .participantStatusesSet(let assignments):
            for assignment in assignments {
                guard var participant = state.participants[assignment.playerID] else { continue }
                participant.status = assignment.status
                state.participants[assignment.playerID] = participant
            }

        case .hintConsumed(let resolution):
            state.lastHint = resolution
            state.hintCountRemaining = resolution.remainingCount

        case .proximityUpdated(let update):
            state.proximityByHiderID[update.hiderID] = ProximityState(
                lastDistance: update.distance,
                lastDirection: update.direction,
                lastObservedAt: update.observedAt,
                enteredWarningRadiusAt: update.enteredWarningRadiusAt,
                hiderWarningSentAt: update.hiderWarningSentAt,
                taggerConfirmationSentAt: update.taggerConfirmationSentAt,
                captureRequestSentAt: update.captureRequestSentAt
            )

        case .captureRequested(let request):
            state.activeCaptureRequests[request.hiderID] = request

        case .captureConfirmed(let hiderID, _):
            state.activeCaptureRequests.removeValue(forKey: hiderID)
            state.proximityByHiderID.removeValue(forKey: hiderID)
            guard var participant = state.participants[hiderID] else { return }
            participant.status = .captured
            state.participants[hiderID] = participant

        case .clipStarted(let clip):
            state.clips[clip.id] = clip

        case .clipEnded(let clipID, let endedAt):
            guard var clip = state.clips[clipID] else { return }
            clip.endedAt = endedAt
            state.clips[clipID] = clip

        case .clipTransferUpdated(let update):
            guard var clip = state.clips[update.clipID] else { return }
            clip.transferState = update.transferState
            state.clips[update.clipID] = clip

        case .gameFinished(let conclusion):
            state.phase = .ended
            state.endedAt = conclusion.endedAt
            state.endReason = conclusion.reason
            state.hideDeadline = nil
            state.gameDeadline = nil
            normalizeRolesAndStatuses()
        }
    }

    func normalizeRolesAndStatuses() {
        for participantID in state.participantOrder {
            guard var participant = state.participants[participantID] else { continue }

            if participantID == state.taggerID {
                participant.role = .tagger
                if state.phase == .playing {
                    participant.status = .seeking
                } else if state.phase == .ended {
                    participant.status = participant.status == .captured ? .captured : .finished
                } else if participant.status != .captured {
                    participant.status = .hiding
                }
            } else {
                participant.role = state.taggerID == nil ? .unassigned : .hider
                if participant.status != .captured {
                    switch state.phase {
                    case .lobby:
                        participant.status = .waiting
                    case .hiding, .playing:
                        participant.status = .hiding
                    case .ended:
                        participant.status = .finished
                    }
                }
            }

            state.participants[participantID] = participant
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

    func eventOrder(lhs: GameEventEnvelope, rhs: GameEventEnvelope) -> Bool {
        if lhs.occurredAt == rhs.occurredAt {
            return lhs.id < rhs.id
        }
        return lhs.occurredAt < rhs.occurredAt
    }

    func isAuthorizedRemoteEvent(_ envelope: GameEventEnvelope) -> Bool {
        let sourcePlayerID = envelope.id.sourcePlayerID

        switch envelope.event {
        case .participantUpserted(let participant):
            guard participant.id == sourcePlayerID else { return false }
            if participant.isHost {
                return participant.id == state.session.hostID
            }
            return true

        case .participantRemoved(let participantID):
            return participantID == sourcePlayerID || sourcePlayerID == state.session.hostID

        case .taggerAssigned(let taggerID):
            return sourcePlayerID == state.session.hostID && state.participants[taggerID] != nil

        case .phaseChanged(let phaseState):
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

        case .participantStatusesSet(let assignments):
            guard sourcePlayerID == state.session.hostID else { return false }
            let knownPlayers = Set(state.participantOrder)
            return assignments.allSatisfy { assignment in
                knownPlayers.contains(assignment.playerID)
            }

        case .hintConsumed(let resolution):
            return sourcePlayerID == state.taggerID && resolution.taggerID == sourcePlayerID

        case .proximityUpdated(let update):
            guard sourcePlayerID == state.taggerID else { return false }
            guard let participant = state.participants[update.hiderID] else { return false }
            return participant.role == .hider

        case .captureRequested(let request):
            return sourcePlayerID == state.taggerID && request.taggerID == sourcePlayerID

        case .captureConfirmed(let hiderID, _):
            return sourcePlayerID == hiderID && state.activeCaptureRequests[hiderID] != nil

        case .clipStarted(let clip):
            return clip.ownerID == sourcePlayerID

        case .clipEnded(let clipID, _):
            return state.clips[clipID]?.ownerID == sourcePlayerID

        case .clipTransferUpdated(let update):
            return sourcePlayerID == state.session.hostID || state.clips[update.clipID]?.ownerID == sourcePlayerID

        case .gameFinished(let conclusion):
            switch conclusion.reason {
            case .allHidersCaptured:
                return sourcePlayerID == state.taggerID || sourcePlayerID == state.session.hostID
            case .timeExpired:
                return state.participants[sourcePlayerID] != nil
            case .hostEnded:
                return sourcePlayerID == state.session.hostID
            case .aborted:
                return state.participants[sourcePlayerID] != nil
            }
        }
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
            if
                let enteredAt = next.enteredWarningRadiusAt,
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
