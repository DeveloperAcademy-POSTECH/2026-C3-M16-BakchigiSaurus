//
//  GameModel.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation
import Observation

// MARK: - Shared Session Types

nonisolated enum GamePhase: String, Codable, Hashable, Sendable {
    case lobby
    case hiding
    case playing
    case ended
}

nonisolated enum TaggerSelectionPolicy: String, Codable, Hashable, Sendable {
    case manual
    case random
}

nonisolated enum PlayerRole: String, Codable, Hashable, Sendable {
    case unassigned
    case tagger
    case hider
}

nonisolated enum PlayerGameStatus: String, Codable, Hashable, Sendable {
    case waiting
    case hiding
    case seeking
    case captured
    case finished
}

nonisolated enum GameEndReason: String, Codable, Hashable, Sendable {
    case allHidersCaptured
    case timeExpired
    case hostEnded
    case aborted
}

nonisolated enum ParticipantConnectivity: String, Hashable, Sendable {
    case disconnected
    case multipeerConnected
    case nearbyConnected
}

nonisolated enum ClipTransferState: String, Codable, Hashable, Sendable {
    case localOnly
    case queuedForCollector
    case transferredToCollector
    case merged
}

nonisolated struct RoomSettings: Codable, Hashable, Sendable {
    var name: String
    var maxCount: Int
    var hintCount: Int
    var hideTimeSeconds: Int
    var gameMinutes: Int
    var taggerSelectionPolicy: TaggerSelectionPolicy

    var gameTotalSeconds: Int {
        gameMinutes * 60
    }

    static let `default` = RoomSettings(
        name: "",
        maxCount: 6,
        hintCount: 3,
        hideTimeSeconds: 10,
        gameMinutes: 10,
        taggerSelectionPolicy: .random
    )
}

nonisolated struct PlayerID: Codable, Hashable, Sendable, Identifiable, Comparable {
    let rawValue: UUID

    var id: UUID { rawValue }

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    static func < (lhs: PlayerID, rhs: PlayerID) -> Bool {
        lhs.rawValue.uuidString < rhs.rawValue.uuidString
    }
}

nonisolated struct DirectionVector: Codable, Hashable, Sendable {
    var x: Float
    var y: Float
    var z: Float

    init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    init(_ value: SIMD3<Float>) {
        self.init(x: value.x, y: value.y, z: value.z)
    }

    var simd: SIMD3<Float> {
        SIMD3(x, y, z)
    }
}

nonisolated struct GameParticipant: Codable, Hashable, Sendable, Identifiable {
    let id: PlayerID
    let peerID: PeerID?
    var name: String
    var isHost: Bool
    var role: PlayerRole
    var status: PlayerGameStatus

    init(
        id: PlayerID = PlayerID(),
        peerID: PeerID? = nil,
        name: String,
        isHost: Bool = false,
        role: PlayerRole = .unassigned,
        status: PlayerGameStatus = .waiting
    ) {
        self.id = id
        self.peerID = peerID
        self.name = name
        self.isHost = isHost
        self.role = role
        self.status = status
    }
}

nonisolated struct GameSessionDefinition: Codable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let hostID: PlayerID
    var settings: RoomSettings

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        hostID: PlayerID,
        settings: RoomSettings
    ) {
        self.id = id
        self.createdAt = createdAt
        self.hostID = hostID
        self.settings = settings
    }
}

nonisolated struct HintCandidate: Hashable, Sendable {
    let hiderID: PlayerID
    let direction: DirectionVector?
    let distance: Float?
}

nonisolated struct HintResolution: Codable, Hashable, Sendable {
    let taggerID: PlayerID
    let usedAt: Date
    let remainingCount: Int
    let selectedHiderID: PlayerID?
    let direction: DirectionVector?
}

nonisolated struct ProximityState: Codable, Hashable, Sendable {
    var lastDistance: Float?
    var lastDirection: DirectionVector?
    var lastObservedAt: Date?
    var enteredWarningRadiusAt: Date?
    var hiderWarningSentAt: Date?
    var taggerConfirmationSentAt: Date?
    var captureRequestSentAt: Date?

    static let empty = ProximityState()
}

nonisolated struct ClipRecord: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let ownerID: PlayerID
    var startedAt: Date
    var endedAt: Date?
    var transferState: ClipTransferState

    init(
        id: UUID = UUID(),
        ownerID: PlayerID,
        startedAt: Date,
        endedAt: Date? = nil,
        transferState: ClipTransferState = .localOnly
    ) {
        self.id = id
        self.ownerID = ownerID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transferState = transferState
    }
}

nonisolated struct PhaseState: Codable, Hashable, Sendable {
    var phase: GamePhase
    var startedAt: Date
    var hideDeadline: Date?
    var gameDeadline: Date?
}

nonisolated struct CaptureRequest: Codable, Hashable, Sendable {
    let taggerID: PlayerID
    let hiderID: PlayerID
    let requestedAt: Date
}

nonisolated struct GameConclusion: Codable, Hashable, Sendable {
    let reason: GameEndReason
    let endedAt: Date
}

nonisolated struct GameState: Codable, Hashable, Sendable {
    let session: GameSessionDefinition
    var phase: GamePhase
    var phaseStartedAt: Date?
    var hideDeadline: Date?
    var gameDeadline: Date?
    var endedAt: Date?
    var endReason: GameEndReason?
    var participants: [PlayerID: GameParticipant]
    var participantOrder: [PlayerID]
    var taggerID: PlayerID?
    var hintCountRemaining: Int
    var proximityByHiderID: [PlayerID: ProximityState]
    var lastHint: HintResolution?
    var activeCaptureRequests: [PlayerID: CaptureRequest]
    var clips: [UUID: ClipRecord]

    init(
        session: GameSessionDefinition,
        phase: GamePhase = .lobby,
        participants: [PlayerID: GameParticipant],
        participantOrder: [PlayerID],
        taggerID: PlayerID? = nil,
        hintCountRemaining: Int? = nil
    ) {
        self.session = session
        self.phase = phase
        self.phaseStartedAt = nil
        self.hideDeadline = nil
        self.gameDeadline = nil
        self.endedAt = nil
        self.endReason = nil
        self.participants = participants
        self.participantOrder = participantOrder
        self.taggerID = taggerID
        self.hintCountRemaining = hintCountRemaining ?? session.settings.hintCount
        self.proximityByHiderID = [:]
        self.lastHint = nil
        self.activeCaptureRequests = [:]
        self.clips = [:]
    }

    var tagger: GameParticipant? {
        guard let taggerID else { return nil }
        return participants[taggerID]
    }

    var hiders: [GameParticipant] {
        participantOrder.compactMap { participantID in
            guard let participant = participants[participantID], participant.role == .hider else {
                return nil
            }
            return participant
        }
    }

    var allHidersCaptured: Bool {
        let activeHiders = hiders
        guard !activeHiders.isEmpty else { return false }
        return activeHiders.allSatisfy { $0.status == .captured }
    }

    func remainingSeconds(at date: Date = .now) -> Int {
        let deadline: Date?
        switch phase {
        case .hiding:
            deadline = hideDeadline
        case .playing:
            deadline = gameDeadline
        case .lobby, .ended:
            deadline = nil
        }

        guard let deadline else { return 0 }
        return max(0, Int(deadline.timeIntervalSince(date).rounded(.down)))
    }

    func canUseHint(by playerID: PlayerID) -> Bool {
        phase == .playing && taggerID == playerID && hintCountRemaining > 0
    }
}

// MARK: - Local Device State

nonisolated struct LocalNearbyObservation: Hashable, Sendable {
    var distance: Float?
    var direction: DirectionVector?
    var observedAt: Date?

    init(
        distance: Float? = nil,
        direction: DirectionVector? = nil,
        observedAt: Date? = nil
    ) {
        self.distance = distance
        self.direction = direction
        self.observedAt = observedAt
    }
}

nonisolated struct LocalParticipantState: Hashable, Sendable {
    var connectivity: ParticipantConnectivity
    var lastSeenAt: Date?
    var lastSyncAt: Date?
    var nearbyObservation: LocalNearbyObservation

    init(
        connectivity: ParticipantConnectivity = .disconnected,
        lastSeenAt: Date? = nil,
        lastSyncAt: Date? = nil,
        nearbyObservation: LocalNearbyObservation = LocalNearbyObservation()
    ) {
        self.connectivity = connectivity
        self.lastSeenAt = lastSeenAt
        self.lastSyncAt = lastSyncAt
        self.nearbyObservation = nearbyObservation
    }
}

nonisolated struct LocalDeviceState: Hashable, Sendable {
    let localPlayerID: PlayerID
    let hostPlayerID: PlayerID
    var participantStates: [PlayerID: LocalParticipantState]
    var pendingOutboundEvents: [GameEventEnvelope]

    init(
        localPlayerID: PlayerID,
        hostPlayerID: PlayerID,
        participantStates: [PlayerID: LocalParticipantState] = [:],
        pendingOutboundEvents: [GameEventEnvelope] = []
    ) {
        self.localPlayerID = localPlayerID
        self.hostPlayerID = hostPlayerID
        self.participantStates = participantStates
        self.pendingOutboundEvents = pendingOutboundEvents
    }
}

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

nonisolated struct GameEventID: Codable, Hashable, Sendable, Comparable {
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
    case startHiding(at: Date = .now)
    case startPlaying(at: Date = .now)
    case useHint(candidates: [HintCandidate], at: Date = .now)
    case observeProximity(hiderID: PlayerID, distance: Float?, direction: DirectionVector?, at: Date = .now)
    case confirmCapture(hiderID: PlayerID, at: Date = .now)
    case startClip(ownerID: PlayerID, clipID: UUID = UUID(), at: Date = .now)
    case finishClip(clipID: UUID, at: Date = .now)
    case updateClipTransfer(clipID: UUID, state: ClipTransferState)
    case evaluateDeadlines(at: Date = .now)
    case finishGame(reason: GameEndReason, at: Date = .now)
}

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

// MARK: - UI Store

@Observable
@MainActor
final class GameModel {
    private let engine: GameEngine

    private(set) var sharedState: GameState
    private(set) var localState: LocalDeviceState

    init(initialState: GameState, localPlayerID: PlayerID) {
        self.sharedState = initialState
        self.localState = LocalDeviceState(
            localPlayerID: localPlayerID,
            hostPlayerID: initialState.session.hostID
        )
        self.engine = GameEngine(initialState: initialState)
        ensureLocalParticipantState(for: localPlayerID)
    }

    convenience init(
        settings: RoomSettings = .default,
        localPlayerName: String,
        localPeerID: PeerID? = nil,
        isHost: Bool = true
    ) {
        let localPlayerID = PlayerID()
        let localParticipant = GameParticipant(
            id: localPlayerID,
            peerID: localPeerID,
            name: localPlayerName,
            isHost: isHost
        )
        let session = GameSessionDefinition(
            hostID: localPlayerID,
            settings: settings
        )
        let initialState = GameState(
            session: session,
            participants: [localPlayerID: localParticipant],
            participantOrder: [localPlayerID]
        )
        self.init(initialState: initialState, localPlayerID: localPlayerID)
    }

    var localPlayerID: PlayerID {
        localState.localPlayerID
    }

    var localParticipant: GameParticipant? {
        sharedState.participants[localPlayerID]
    }

    var isLocalTagger: Bool {
        sharedState.taggerID == localPlayerID
    }

    var participants: [GameParticipant] {
        sharedState.participantOrder.compactMap { sharedState.participants[$0] }
    }

    var remainingSeconds: Int {
        sharedState.remainingSeconds()
    }

    @discardableResult
    func send(_ command: GameCommand, as sourcePlayerID: PlayerID? = nil) async -> [GameEventEnvelope] {
        let actorID = sourcePlayerID ?? localPlayerID
        let mutation = await engine.apply(command, as: actorID)
        sharedState = mutation.sharedState
        localState.pendingOutboundEvents.append(contentsOf: mutation.newEvents)
        return mutation.newEvents
    }

    func merge(remoteEvents: [GameEventEnvelope], syncedAt: Date = .now) async {
        let mutation = await engine.merge(remoteEvents)
        sharedState = mutation.sharedState

        let remoteSources = Set(remoteEvents.map(\.id.sourcePlayerID))
        for sourcePlayerID in remoteSources {
            ensureLocalParticipantState(for: sourcePlayerID)
            localState.participantStates[sourcePlayerID]?.lastSyncAt = syncedAt
        }

        let mergedIDs = Set(remoteEvents.map(\.id))
        localState.pendingOutboundEvents.removeAll { mergedIDs.contains($0.id) }
    }

    func markConnectivity(
        for participantID: PlayerID,
        as connectivity: ParticipantConnectivity,
        at observedAt: Date = .now
    ) {
        ensureLocalParticipantState(for: participantID)
        localState.participantStates[participantID]?.connectivity = connectivity
        localState.participantStates[participantID]?.lastSeenAt = observedAt
    }

    func markNearbyObservation(
        for participantID: PlayerID,
        distance: Float?,
        direction: DirectionVector?,
        at observedAt: Date = .now
    ) {
        ensureLocalParticipantState(for: participantID)
        localState.participantStates[participantID]?.nearbyObservation = LocalNearbyObservation(
            distance: distance,
            direction: direction,
            observedAt: observedAt
        )
        localState.participantStates[participantID]?.lastSeenAt = observedAt
    }

    func pendingOutboundEventsSnapshot() -> [GameEventEnvelope] {
        localState.pendingOutboundEvents
    }

    func acknowledgeOutboundEvents(_ eventIDs: Set<GameEventID>) {
        localState.pendingOutboundEvents.removeAll { eventIDs.contains($0.id) }
    }

    private func ensureLocalParticipantState(for participantID: PlayerID) {
        if localState.participantStates[participantID] == nil {
            localState.participantStates[participantID] = LocalParticipantState()
        }
    }
}
