//
//  GameLocalState.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation

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
