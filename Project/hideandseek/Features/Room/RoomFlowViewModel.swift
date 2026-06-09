//
//  RoomFlowViewModel.swift
//  hideandseek
//
//  Created by Codex on 6/8/26.
//

import Combine
import Foundation

@MainActor
final class RoomFlowViewModel: ObservableObject {
    private let session: MultipeerGameSession
    private let niManager: NearbyInteractionManager
    private let connection: McniConnection

    private var sessionEventTask: Task<Void, Never>?
    private var gameEventTask: Task<Void, Never>?
    private var playerIDByPeerRawID: [String: PlayerID] = [:]
    private var peerIDByPlayerID: [PlayerID: PeerID] = [:]

    @Published private(set) var localPeer: PeerID
    @Published private(set) var discoveredRooms: [RoomLobbySnapshot] = []
    @Published private(set) var currentPeers: [PeerID] = []
    @Published private(set) var activeRoom: RoomLobbySnapshot?
    @Published private(set) var joiningRoomID: String?
    @Published private(set) var isBrowsing = false
    @Published private(set) var gameStarted = false
    @Published private(set) var localAssignedRole: GameFlowRole?
    @Published private(set) var gameModel: GameModel?
    @Published var selectedTaggerRawID: String?
    @Published var statusMessage: String?

    init(
        session: MultipeerGameSession = MultipeerGameSession(),
        niManager: NearbyInteractionManager = NearbyInteractionManager()
    ) {
        self.session = session
        self.niManager = niManager
        self.connection = McniConnection(
            mcManager: session,
            niManager: niManager
        )
        self.localPeer = session.localPeer
        self.currentPeers = session.currentPeers

        observeSessionEvents()
        observeGameEvents()
        refreshSnapshot()
    }

    deinit {
        sessionEventTask?.cancel()
        gameEventTask?.cancel()
        niManager.invalidateSession()
    }

    var isHostInActiveRoom: Bool {
        activeRoom?.host.rawID == localPeer.rawID
    }

    var canStartGame: Bool {
        isHostInActiveRoom && sortedParticipants.count > 1
    }

    var sortedParticipants: [GameParticipant] {
        let hostRawID = activeRoom?.host.rawID

        return (gameModel?.participants ?? []).sorted { lhs, rhs in
            let lhsRawID = lhs.peerID?.rawID
            let rhsRawID = rhs.peerID?.rawID

            if lhsRawID == hostRawID { return true }
            if rhsRawID == hostRawID { return false }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    func activateLobby() {
        guard activeRoom == nil else { return }

        if !isBrowsing {
            session.startBrowsing()
            isBrowsing = true
        }

        refreshSnapshot()
    }

    func createRoom(
        name: String,
        hintCount: Int,
        hideTimeSeconds: Int,
        gameMinutes: Int
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = trimmedName.isEmpty ? "\(localPeer.displayName)의 방" : trimmedName
        let settings = RoomSettings(
            name: normalizedName,
            maxCount: RoomSettings.default.maxCount,
            hintCount: hintCount,
            hideTimeSeconds: hideTimeSeconds,
            gameMinutes: gameMinutes,
            taggerSelectionPolicy: .random
        )

        resetGameSessionState()
        bootstrapHostedGameModel(settings: settings)

        session.stopBrowsing()
        if let sessionID = gameModel?.sharedState.session.id {
            session.configureHostedRoom(with: settings, sessionID: sessionID)
        }
        session.startHosting()

        isBrowsing = false
        statusMessage = "참가자를 기다리는 중입니다"
        activeRoom = session.hostedRoom
        refreshSnapshot()
        syncGameParticipants()
    }

    func joinRoom(_ room: RoomLobbySnapshot) {
        guard !room.isFull else { return }

        resetGameSessionState()
        bootstrapJoinedGameModel(for: room)

        joiningRoomID = room.id
        activeRoom = room
        statusMessage = "\(room.name)에 연결하는 중입니다"
        refreshSnapshot()
        syncGameParticipants()
        session.invite(room.host)
    }

    func leaveActiveRoom() {
        session.disconnect()
        activeRoom = nil
        joiningRoomID = nil
        statusMessage = nil
        currentPeers = [localPeer]
        resetGameSessionState()
        activateLobby()
    }

    func toggleTagger(for participant: GameParticipant) {
        guard isHostInActiveRoom else { return }
        guard let peerRawID = participant.peerID?.rawID else { return }
        selectedTaggerRawID = selectedTaggerRawID == peerRawID ? nil : peerRawID
    }

    func startGame() {
        guard isHostInActiveRoom else { return }
        guard sortedParticipants.count > 1 else {
            statusMessage = "게임을 시작하려면 최소 2명이 필요합니다"
            return
        }

        Task { @MainActor [weak self] in
            await self?.startGameUsingCoreModel()
        }
    }

    func refreshSnapshot() {
        localPeer = session.localPeer
        currentPeers = session.currentPeers
        discoveredRooms = session.discoveredRooms
        syncPublishedStateFromGameModel()

        guard let activeRoom else { return }

        let settings = gameModel?.sharedState.session.settings
        let currentCount = max(1, sortedParticipants.count)
        self.activeRoom = RoomLobbySnapshot(
            id: activeRoom.id,
            sessionID: gameModel?.sharedState.session.id ?? activeRoom.sessionID,
            host: activeRoom.host,
            name: settings?.name ?? activeRoom.name,
            currentCount: currentCount,
            maxCount: settings?.maxCount ?? activeRoom.maxCount,
            hintCount: settings?.hintCount ?? activeRoom.hintCount,
            hideTimeSeconds: settings?.hideTimeSeconds ?? activeRoom.hideTimeSeconds,
            gameMinutes: settings?.gameMinutes ?? activeRoom.gameMinutes
        )
    }

    private func observeSessionEvents() {
        sessionEventTask = Task { [weak self, session] in
            for await event in session.makeEventStream() {
                await MainActor.run {
                    self?.handleSessionEvent(event)
                }
            }
        }
    }

    private func observeGameEvents() {
        gameEventTask = Task { [weak self, session] in
            for await event in session.makeGameEventStream() {
                await MainActor.run {
                    self?.handleReceivedGameEvents(event)
                }
            }
        }
    }

    private func handleSessionEvent(_ event: SessionEvent) {
        refreshSnapshot()

        switch event {
        case let .peerConnected(peer):
            syncGameParticipants()

            if joiningRoomID != nil, peer.rawID == activeRoom?.host.rawID {
                joiningRoomID = nil
                statusMessage = "\(activeRoom?.name ?? "방")에 참가했습니다"
            } else if isHostInActiveRoom {
                statusMessage = "\(peer.displayName) 님이 참가했습니다"
            }

        case let .peerDisconnected(peer):
            if !isHostInActiveRoom, peer.rawID == activeRoom?.host.rawID {
                statusMessage = "호스트 연결이 끊어졌습니다"
                activeRoom = nil
                resetGameSessionState()
                activateLobby()
                return
            }

            syncGameParticipants()

            if isHostInActiveRoom {
                statusMessage = "\(peer.displayName) 님이 나갔습니다"
            }

        case .discoveredRoomsChanged:
            break
        }
    }

    private func handleReceivedGameEvents(_ event: GameEventEnvelopesEvent) {
        guard !event.envelopes.isEmpty else { return }

        Task { @MainActor [weak self] in
            await self?.mergeRemoteEvents(event.envelopes, from: event.peer)
        }
    }

    private func bootstrapHostedGameModel(settings: RoomSettings) {
        let localPlayerID = ensurePlayerID(for: localPeer)
        let localParticipant = GameParticipant(
            id: localPlayerID,
            peerID: localPeer,
            name: localPeer.displayName,
            isHost: true
        )
        let initialState = GameState(
            session: GameSessionDefinition(
                hostID: localPlayerID,
                settings: settings
            ),
            participants: [localPlayerID: localParticipant],
            participantOrder: [localPlayerID]
        )

        gameModel = GameModel(
            initialState: initialState,
            localPlayerID: localPlayerID
        )
        rebuildPeerMappings()
        syncPublishedStateFromGameModel()
    }

    private func bootstrapJoinedGameModel(for room: RoomLobbySnapshot) {
        let hostPlayerID = ensurePlayerID(for: room.host)
        let localPlayerID = ensurePlayerID(for: localPeer)
        let settings = RoomSettings(
            name: room.name,
            maxCount: room.maxCount,
            hintCount: room.hintCount,
            hideTimeSeconds: room.hideTimeSeconds,
            gameMinutes: room.gameMinutes,
            taggerSelectionPolicy: .random
        )
        let hostParticipant = GameParticipant(
            id: hostPlayerID,
            peerID: room.host,
            name: room.host.displayName,
            isHost: true
        )
        let localParticipant = GameParticipant(
            id: localPlayerID,
            peerID: localPeer,
            name: localPeer.displayName,
            isHost: false
        )
        let initialState = GameState(
            session: GameSessionDefinition(
                id: room.sessionID,
                hostID: hostPlayerID,
                settings: settings
            ),
            participants: [
                hostPlayerID: hostParticipant,
                localPlayerID: localParticipant
            ],
            participantOrder: [
                hostPlayerID,
                localPlayerID
            ]
        )

        gameModel = GameModel(
            initialState: initialState,
            localPlayerID: localPlayerID
        )
        rebuildPeerMappings()
        syncPublishedStateFromGameModel()
    }

    private func resetGameSessionState() {
        gameModel = nil
        playerIDByPeerRawID.removeAll()
        peerIDByPlayerID.removeAll()
        gameStarted = false
        localAssignedRole = nil
        selectedTaggerRawID = nil
        joiningRoomID = nil
    }

    private func syncGameParticipants() {
        Task { @MainActor [weak self] in
            await self?.syncGameParticipantsUsingCoreModel()
        }
    }

    private func syncGameParticipantsUsingCoreModel() async {
        guard let gameModel, let activeRoom else { return }
        guard isHostInActiveRoom else {
            rebuildPeerMappings()
            syncPublishedStateFromGameModel()
            refreshSnapshot()
            return
        }

        var activePeers = currentPeers
        if !activePeers.contains(where: { $0.rawID == activeRoom.host.rawID }) {
            activePeers.append(activeRoom.host)
        }

        var remainingParticipantIDs = Set(gameModel.sharedState.participantOrder)

        for peer in activePeers {
            let playerID = ensurePlayerID(
                for: peer,
                isHost: peer.rawID == activeRoom.host.rawID
            )
            let participant = GameParticipant(
                id: playerID,
                peerID: peer,
                name: peer.displayName,
                isHost: peer.rawID == activeRoom.host.rawID
            )

            remainingParticipantIDs.remove(playerID)
            await sendCommand(.upsertParticipant(participant), as: playerID)
        }

        for participantID in remainingParticipantIDs where participantID != gameModel.localPlayerID {
            await sendCommand(.removeParticipant(participantID), as: participantID)

            if let peer = peerIDByPlayerID.removeValue(forKey: participantID) {
                playerIDByPeerRawID.removeValue(forKey: peer.rawID)
            }
        }

        syncPublishedStateFromGameModel()
        refreshSnapshot()
    }

    private func startGameUsingCoreModel() async {
        guard let gameModel else { return }

        let fallbackTagger = sortedParticipants.randomElement()
        let taggerRawID = selectedTaggerRawID ?? fallbackTagger?.peerID?.rawID ?? localPeer.rawID
        let taggerPeer = peerIDByRawID(taggerRawID) ?? localPeer
        let taggerPlayerID = ensurePlayerID(
            for: taggerPeer,
            isHost: taggerPeer.rawID == activeRoom?.host.rawID
        )

        await sendCommand(.assignTagger(taggerPlayerID))
        await sendCommand(.startHiding())

        syncPublishedStateFromGameModel()
        statusMessage = "게임 시작 신호를 전송했습니다"
        refreshSnapshot()
    }

    private func mergeRemoteEvents(_ events: [GameEventEnvelope], from peer: PeerID) async {
        guard let gameModel else { return }

        await gameModel.merge(remoteEvents: events)
        peerIDByPlayerID[ensurePlayerID(for: peer)] = peer
        rebuildPeerMappings()
        syncPublishedStateFromGameModel()
        refreshSnapshot()
    }

    private func updateStatusMessage(for role: GameFlowRole?) {
        if role == .seeker {
            statusMessage = "당신이 술래입니다"
        } else if role == .hider {
            statusMessage = "숨는 역할이 배정됐습니다"
        }
    }

    private func syncPublishedStateFromGameModel() {
        rebuildPeerMappings()
        gameStarted = gameModel.map { $0.sharedState.phase != .lobby } ?? false

        if let assignedTaggerID = gameModel?.sharedState.taggerID,
           let taggerPeer = peerIDByPlayerID[assignedTaggerID]
        {
            selectedTaggerRawID = taggerPeer.rawID
        }

        if let role = mapRole(gameModel?.localParticipant?.role) {
            localAssignedRole = role
            updateStatusMessage(for: role)
        } else if gameModel == nil {
            localAssignedRole = nil
        }
    }

    private func mapRole(_ role: PlayerRole?) -> GameFlowRole? {
        switch role {
        case .tagger:
            .seeker
        case .hider:
            .hider
        case .unassigned, .none:
            nil
        }
    }

    private func ensurePlayerID(for peer: PeerID, isHost: Bool = false) -> PlayerID {
        if let existingPlayerID = playerIDByPeerRawID[peer.rawID] {
            peerIDByPlayerID[existingPlayerID] = peer
            return existingPlayerID
        }

        let playerID = PlayerID(stablePeerRawID: peer.rawID)
        playerIDByPeerRawID[peer.rawID] = playerID
        peerIDByPlayerID[playerID] = peer

        if isHost, gameModel?.sharedState.session.hostID != playerID {
            // host는 초기 상태에서 반드시 고정되도록 bootstrap 단계에서 먼저 생성한다.
        }

        return playerID
    }

    private func rebuildPeerMappings() {
        guard let participants = gameModel?.participants else { return }

        for participant in participants {
            guard let peer = participant.peerID else { continue }
            playerIDByPeerRawID[peer.rawID] = participant.id
            peerIDByPlayerID[participant.id] = peer
        }
    }

    @discardableResult
    private func sendCommand(
        _ command: GameCommand,
        as sourcePlayerID: PlayerID? = nil,
        to peer: PeerID? = nil
    ) async -> [GameEventEnvelope] {
        guard let gameModel else { return [] }

        let events = await gameModel.send(command, as: sourcePlayerID)
        if !events.isEmpty {
            session.sendGameEvents(events, to: peer)
        }
        rebuildPeerMappings()
        syncPublishedStateFromGameModel()
        return events
    }

    private func peerIDByRawID(_ rawID: String) -> PeerID? {
        if rawID == localPeer.rawID {
            return localPeer
        }

        if let matchedPeer = currentPeers.first(where: { $0.rawID == rawID }) {
            return matchedPeer
        }

        return activeRoom?.host.rawID == rawID ? activeRoom?.host : nil
    }
}
