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
    private var phaseTransitionTask: Task<Void, Never>?
    private var playerIDByPeerRawID: [String: PlayerID] = [:]

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
        phaseTransitionTask?.cancel()
        niManager.invalidateSession()
    }

    var gameSession: MultipeerGameSession {
        session
    }

    var nearbyInteractionManager: NearbyInteractionManager {
        niManager
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
        gameModel = nil
        playerIDByPeerRawID.removeAll()
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
        gameModel = nil
        playerIDByPeerRawID.removeAll()
        session.invite(room.host)
    }

    func leaveActiveRoom() {
        phaseTransitionTask?.cancel()
        session.disconnect()
        activeRoom = nil
        joiningRoomID = nil
        selectedTaggerRawID = nil
        localAssignedRole = nil
        gameStarted = false
        gameModel = nil
        playerIDByPeerRawID.removeAll()
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

        let fallbackTagger = sortedParticipants.randomElement()?.rawID
        let taggerRawID = selectedTaggerRawID ?? fallbackTagger ?? localPeer.rawID
        let gameModel = makeGameModel(selectedTaggerRawID: taggerRawID)

        for peer in currentPeers where peer.rawID != localPeer.rawID {
            let role: GameFlowRole = peer.rawID == taggerRawID ? .seeker : .hider
            session.sendRoleAssigned(role, to: peer)
        }

        localAssignedRole = localPeer.rawID == taggerRawID ? .seeker : .hider
        selectedTaggerRawID = taggerRawID
        session.sendGameStarted()
        session.sendCountdownStarted(seconds: gameModel.sharedState.session.settings.hideTimeSeconds)
        gameStarted = true
        statusMessage = "게임 시작 신호를 전송했습니다"

        let taggerID = playerIDByPeerRawID[taggerRawID]
        Task {
            await gameModel.send(.assignTagger(taggerID))
            await gameModel.send(.startHiding())
            scheduleSearchStart(for: gameModel)
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
            gameStarted = true
            ensureGameModelForReceivedStart()
            if statusMessage == nil {
                statusMessage = "게임이 시작됐습니다"
            }

        case .countdownStarted:
            let model = ensureGameModelForReceivedStart()
            let taggerID = inferredTaggerIDForReceivedStart()
            Task {
                await model.send(.assignTagger(taggerID))
                await model.send(.startHiding())
                if let seconds = message.seconds {
                    scheduleSearchStart(for: model, after: seconds)
                }
            }

        case .searchStarted:
            guard let gameModel else { return }
            Task {
                await gameModel.send(.startPlaying())
            }

        default:
            break
        }
    }

    private func makeGameModel(selectedTaggerRawID: String?) -> GameModel {
        let room = activeRoom ?? session.hostedRoom
        let settings = RoomSettings(
            name: room.name,
            maxCount: room.maxCount,
            hintCount: room.hintCount,
            hideTimeSeconds: room.hideTimeSeconds,
            gameMinutes: room.gameMinutes,
            taggerSelectionPolicy: selectedTaggerRawID == nil ? .random : .manual
        )

        let peers = sortedParticipants.isEmpty ? [localPeer] : sortedParticipants
        for peer in peers where playerIDByPeerRawID[peer.rawID] == nil {
            playerIDByPeerRawID[peer.rawID] = PlayerID()
        }

        let hostPeer = room.host
        let hostID = playerIDByPeerRawID[hostPeer.rawID] ?? PlayerID()
        playerIDByPeerRawID[hostPeer.rawID] = hostID

        let participants = Dictionary(
            uniqueKeysWithValues: peers.map { peer in
                let playerID = playerIDByPeerRawID[peer.rawID] ?? PlayerID()
                playerIDByPeerRawID[peer.rawID] = playerID
                return (
                    playerID,
                    GameParticipant(
                        id: playerID,
                        peerID: peer,
                        name: peer.displayName,
                        isHost: peer.rawID == hostPeer.rawID
                    )
                )
            }
        )

        let participantOrder = peers.compactMap { playerIDByPeerRawID[$0.rawID] }
        let sessionDefinition = GameSessionDefinition(
            hostID: hostID,
            settings: settings
        )
        let initialState = GameState(
            session: sessionDefinition,
            participants: participants,
            participantOrder: participantOrder
        )
        let localPlayerID = playerIDByPeerRawID[localPeer.rawID] ?? PlayerID()
        let model = GameModel(
            initialState: initialState,
            localPlayerID: localPlayerID
        )

        gameModel = model
        return model
    }

    @discardableResult
    private func ensureGameModelForReceivedStart() -> GameModel {
        if let gameModel {
            return gameModel
        }

        let model = makeGameModel(selectedTaggerRawID: inferredTaggerRawIDForReceivedStart())
        return model
    }

    private func inferredTaggerIDForReceivedStart() -> PlayerID? {
        guard let rawID = inferredTaggerRawIDForReceivedStart() else {
            return nil
        }

        return playerIDByPeerRawID[rawID]
    }

    private func inferredTaggerRawIDForReceivedStart() -> String? {
        switch localAssignedRole {
        case .seeker:
            return localPeer.rawID
        case .hider:
            return sortedParticipants.first { $0.rawID != localPeer.rawID }?.rawID
        case nil:
            return selectedTaggerRawID
        }
    }

    private func scheduleSearchStart(for model: GameModel, after seconds: Int? = nil) {
        phaseTransitionTask?.cancel()
        let hideSeconds = seconds ?? model.sharedState.session.settings.hideTimeSeconds

        phaseTransitionTask = Task { [weak self, session] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, hideSeconds)) * 1_000_000_000)
            guard !Task.isCancelled else { return }

            await model.send(.startPlaying())

            await MainActor.run {
                if self?.isHostInActiveRoom == true {
                    session.sendSearchStarted()
                }
            }
        }
    }
}
