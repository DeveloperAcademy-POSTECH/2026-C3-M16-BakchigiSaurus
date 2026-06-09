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
    private var gameFlowTask: Task<Void, Never>?
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
        observeGameFlowMessages()
        refreshSnapshot()
    }

    deinit {
        sessionEventTask?.cancel()
        gameFlowTask?.cancel()
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
        session.configureHostedRoom(with: settings)
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

    private func observeGameFlowMessages() {
        gameFlowTask = Task { [weak self, session] in
            for await event in session.makeGameFlowMessageStream() {
                await MainActor.run {
                    self?.handleGameFlowMessage(event.message)
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

    private func handleGameFlowMessage(_ message: GameFlowMessage) {
        switch message.kind {
        case .roleAssigned:
            Task { @MainActor [weak self] in
                await self?.applyRoleAssignmentMessage(message)
            }

        case .gameStarted:
            Task { @MainActor [weak self] in
                await self?.applyGameStartedMessage()
            }

        default:
            break
        }
    }

    private func bootstrapHostedGameModel(settings: RoomSettings) {
        let localPlayerID = PlayerID()
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

        playerIDByPeerRawID[localPeer.rawID] = localPlayerID
        peerIDByPlayerID[localPlayerID] = localPeer
        gameModel = GameModel(
            initialState: initialState,
            localPlayerID: localPlayerID
        )
        syncPublishedStateFromGameModel()
    }

    private func bootstrapJoinedGameModel(for room: RoomLobbySnapshot) {
        let hostPlayerID = PlayerID()
        let localPlayerID = PlayerID()
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

        playerIDByPeerRawID[room.host.rawID] = hostPlayerID
        peerIDByPlayerID[hostPlayerID] = room.host
        playerIDByPeerRawID[localPeer.rawID] = localPlayerID
        peerIDByPlayerID[localPlayerID] = localPeer
        gameModel = GameModel(
            initialState: initialState,
            localPlayerID: localPlayerID
        )
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
            await gameModel.send(.upsertParticipant(participant), as: playerID)
        }

        for participantID in remainingParticipantIDs where participantID != gameModel.localPlayerID {
            await gameModel.send(.removeParticipant(participantID), as: participantID)

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

        await gameModel.send(.assignTagger(taggerPlayerID))
        await gameModel.send(.startHiding())

        syncPublishedStateFromGameModel()

        for participant in sortedParticipants {
            guard let peer = participant.peerID, peer.rawID != localPeer.rawID else { continue }

            let role: GameFlowRole = participant.id == taggerPlayerID ? .seeker : .hider
            session.sendRoleAssigned(
                role,
                taggerPeer: taggerPeer,
                to: peer
            )
        }

        session.sendGameStarted()
        statusMessage = "게임 시작 신호를 전송했습니다"
        refreshSnapshot()
    }

    private func applyRoleAssignmentMessage(_ message: GameFlowMessage) async {
        localAssignedRole = message.role

        guard let gameModel else {
            updateStatusMessage(for: message.role)
            return
        }

        let taggerPeer: PeerID
        if let referencedPeer = message.referencedPeer {
            taggerPeer = referencedPeer
        } else if message.role == .seeker {
            taggerPeer = localPeer
        } else if let hostPeer = activeRoom?.host {
            taggerPeer = hostPeer
        } else {
            updateStatusMessage(for: message.role)
            return
        }

        let taggerPlayerID = ensurePlayerID(
            for: taggerPeer,
            isHost: taggerPeer.rawID == activeRoom?.host.rawID
        )
        await gameModel.send(.assignTagger(taggerPlayerID))
        syncPublishedStateFromGameModel()
        updateStatusMessage(for: message.role)
        refreshSnapshot()
    }

    private func applyGameStartedMessage() async {
        guard let gameModel else {
            gameStarted = true
            if statusMessage == nil {
                statusMessage = "게임이 시작됐습니다"
            }
            return
        }

        await gameModel.send(.startHiding())
        syncPublishedStateFromGameModel()

        if statusMessage == nil {
            statusMessage = "게임이 시작됐습니다"
        }

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
        gameStarted = gameModel.map { $0.sharedState.phase != .lobby } ?? false

        if let assignedTaggerID = gameModel?.sharedState.taggerID,
           let taggerPeer = peerIDByPlayerID[assignedTaggerID]
        {
            selectedTaggerRawID = taggerPeer.rawID
        }

        if let role = mapRole(gameModel?.localParticipant?.role) {
            localAssignedRole = role
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

    private func ensurePlayerID(for peer: PeerID, isHost: Bool) -> PlayerID {
        if let existingPlayerID = playerIDByPeerRawID[peer.rawID] {
            peerIDByPlayerID[existingPlayerID] = peer
            return existingPlayerID
        }

        let playerID = PlayerID()
        playerIDByPeerRawID[peer.rawID] = playerID
        peerIDByPlayerID[playerID] = peer

        if isHost, gameModel?.sharedState.session.hostID != playerID {
            // host는 초기 상태에서 반드시 고정되도록 bootstrap 단계에서 먼저 생성한다.
        }

        return playerID
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
