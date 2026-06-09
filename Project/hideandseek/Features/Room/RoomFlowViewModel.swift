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

    @Published private(set) var localPeer: PeerID
    @Published private(set) var discoveredRooms: [RoomLobbySnapshot] = []
    @Published private(set) var currentPeers: [PeerID] = []
    @Published private(set) var activeRoom: RoomLobbySnapshot?
    @Published private(set) var joiningRoomID: String?
    @Published private(set) var isBrowsing = false
    @Published private(set) var gameStarted = false
    @Published private(set) var localAssignedRole: GameFlowRole?
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
        isHostInActiveRoom && currentPeers.count > 1
    }

    var sortedParticipants: [PeerID] {
        currentPeers.sorted { lhs, rhs in
            if lhs.rawID == activeRoom?.host.rawID { return true }
            if rhs.rawID == activeRoom?.host.rawID { return false }
            return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
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

        session.stopBrowsing()
        session.configureHostedRoom(with: settings)
        session.startHosting()

        isBrowsing = false
        joiningRoomID = nil
        gameStarted = false
        localAssignedRole = nil
        selectedTaggerRawID = nil
        statusMessage = "참가자를 기다리는 중입니다"
        activeRoom = session.hostedRoom
        refreshSnapshot()
    }

    func joinRoom(_ room: RoomLobbySnapshot) {
        guard !room.isFull else { return }

        joiningRoomID = room.id
        activeRoom = room
        gameStarted = false
        localAssignedRole = nil
        selectedTaggerRawID = nil
        statusMessage = "\(room.name)에 연결하는 중입니다"
        session.invite(room.host)
    }

    func leaveActiveRoom() {
        session.disconnect()
        activeRoom = nil
        joiningRoomID = nil
        selectedTaggerRawID = nil
        localAssignedRole = nil
        gameStarted = false
        statusMessage = nil
        currentPeers = [localPeer]
        activateLobby()
    }

    func toggleTagger(for peer: PeerID) {
        guard isHostInActiveRoom else { return }
        selectedTaggerRawID = selectedTaggerRawID == peer.rawID ? nil : peer.rawID
    }

    func startGame() {
        guard isHostInActiveRoom else { return }
        guard currentPeers.count > 1 else {
            statusMessage = "게임을 시작하려면 최소 2명이 필요합니다"
            return
        }

        let fallbackTagger = sortedParticipants.randomElement()?.rawID
        let taggerRawID = selectedTaggerRawID ?? fallbackTagger ?? localPeer.rawID

        for peer in currentPeers where peer.rawID != localPeer.rawID {
            let role: GameFlowRole = peer.rawID == taggerRawID ? .seeker : .hider
            session.sendRoleAssigned(role, to: peer)
        }

        localAssignedRole = localPeer.rawID == taggerRawID ? .seeker : .hider
        selectedTaggerRawID = taggerRawID
        session.sendGameStarted()
        gameStarted = true
        statusMessage = "게임 시작 신호를 전송했습니다"
    }

    func refreshSnapshot() {
        localPeer = session.localPeer
        currentPeers = session.currentPeers
        discoveredRooms = session.discoveredRooms

        if let activeRoom {
            if isHostInActiveRoom {
                self.activeRoom = session.hostedRoom
            } else {
                self.activeRoom = RoomLobbySnapshot(
                    id: activeRoom.id,
                    host: activeRoom.host,
                    name: activeRoom.name,
                    currentCount: currentPeers.count,
                    maxCount: activeRoom.maxCount,
                    hintCount: activeRoom.hintCount,
                    hideTimeSeconds: activeRoom.hideTimeSeconds,
                    gameMinutes: activeRoom.gameMinutes
                )
            }
        }
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
                joiningRoomID = nil
                activateLobby()
                return
            }

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
            localAssignedRole = message.role
            if message.role == .seeker {
                statusMessage = "당신이 술래입니다"
            } else if message.role == .hider {
                statusMessage = "숨는 역할이 배정됐습니다"
            }

        case .gameStarted:
            gameStarted = true
            if statusMessage == nil {
                statusMessage = "게임이 시작됐습니다"
            }

        default:
            break
        }
    }
}
