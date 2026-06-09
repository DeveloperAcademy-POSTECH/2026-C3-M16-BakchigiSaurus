//
//  GameModel.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation
import Observation

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

    func participantState(for participantID: PlayerID) -> LocalParticipantState? {
        localState.participantStates[participantID]
    }

    func proximityState(for hiderID: PlayerID) -> ProximityState? {
        sharedState.proximityByHiderID[hiderID]
    }

    var activeLocalCaptureRequest: CaptureRequest? {
        sharedState.activeCaptureRequests[localPlayerID]
    }

    var latestHint: HintResolution? {
        sharedState.lastHint
    }

    @discardableResult
    func send(_ command: GameCommand, as sourcePlayerID: PlayerID? = nil) async -> [GameEventEnvelope] {
        let actorID = sourcePlayerID ?? localPlayerID
        let mutation = await engine.apply(command, as: actorID)
        sharedState = mutation.sharedState
        localState.pendingOutboundEvents.append(contentsOf: mutation.newEvents)
        return mutation.newEvents
    }

    func applyBridgeCommand(_ command: GameCommand, as sourcePlayerID: PlayerID) async {
        let mutation = await engine.apply(command, as: sourcePlayerID)
        sharedState = mutation.sharedState
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
