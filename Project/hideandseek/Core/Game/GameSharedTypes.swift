//
//  GameSharedTypes.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation

// MARK: - Shared Session Types

nonisolated enum GamePhase: String, Codable, Hashable {
    case lobby
    case hiding
    case playing
    case ended
}

nonisolated enum TaggerSelectionPolicy: String, Codable, Hashable {
    case manual
    case random
}

nonisolated enum PlayerRole: String, Codable, Hashable {
    case unassigned
    case tagger
    case hider
}

nonisolated enum PlayerGameStatus: String, Codable, Hashable {
    case waiting
    case waitingForHiders
    case hiding
    case seeking
    case captured
    case finished
}

nonisolated enum GameEndReason: String, Codable, Hashable {
    case allHidersCaptured
    case timeExpired
    case hostEnded
    case aborted
}

nonisolated enum ParticipantConnectivity: String, Hashable {
    case disconnected
    case multipeerConnected
    case nearbyConnected
}

nonisolated enum ClipTransferState: String, Codable, Hashable {
    case localOnly
    case queuedForCollector
    case transferredToCollector
    case merged
}

nonisolated struct RoomSettings: Codable, Hashable {
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

nonisolated struct PlayerID: Codable, Hashable, Identifiable, Comparable {
    let rawValue: UUID

    var id: UUID {
        rawValue
    }

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    static func < (lhs: PlayerID, rhs: PlayerID) -> Bool {
        lhs.rawValue.uuidString < rhs.rawValue.uuidString
    }
}

// swiftlint:disable identifier_name
nonisolated struct DirectionVector: Codable, Hashable {
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

// swiftlint:enable identifier_name

nonisolated struct GameParticipant: Codable, Hashable, Identifiable {
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

nonisolated struct GameSessionDefinition: Codable, Hashable {
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

nonisolated struct HintCandidate: Hashable {
    let hiderID: PlayerID
    let direction: DirectionVector?
    let distance: Float?
}

nonisolated struct HintResolution: Codable, Hashable {
    let taggerID: PlayerID
    let usedAt: Date
    let remainingCount: Int
    let selectedHiderID: PlayerID?
    let direction: DirectionVector?
}

nonisolated struct ProximityState: Codable, Hashable {
    var lastDistance: Float?
    var lastDirection: DirectionVector?
    var lastObservedAt: Date?
    var enteredWarningRadiusAt: Date?
    var hiderWarningSentAt: Date?
    var taggerConfirmationSentAt: Date?
    var captureRequestSentAt: Date?

    static let empty = ProximityState()
}

nonisolated struct ClipRecord: Codable, Hashable, Identifiable {
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

nonisolated struct PhaseState: Codable, Hashable {
    var phase: GamePhase
    var startedAt: Date
    var hideDeadline: Date?
    var gameDeadline: Date?
}

nonisolated struct CaptureRequest: Codable, Hashable {
    let taggerID: PlayerID
    let hiderID: PlayerID
    let requestedAt: Date
}

nonisolated struct GameConclusion: Codable, Hashable {
    let reason: GameEndReason
    let endedAt: Date
}

nonisolated struct GameState: Codable, Hashable {
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
        let deadline: Date? = switch phase {
        case .hiding:
            hideDeadline
        case .playing:
            gameDeadline
        case .lobby, .ended:
            nil
        }

        guard let deadline else { return 0 }
        return max(0, Int(deadline.timeIntervalSince(date).rounded(.down)))
    }

    func canUseHint(by playerID: PlayerID) -> Bool {
        phase == .playing && taggerID == playerID && hintCountRemaining > 0
    }
}
