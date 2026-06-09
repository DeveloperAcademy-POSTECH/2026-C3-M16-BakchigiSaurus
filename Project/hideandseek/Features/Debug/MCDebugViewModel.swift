//
//  MCDebugViewModel.swift
//  hideandseek
//
//  Created by 서혜린 on 6/5/26.
//
//  MCDebugViewModel.swift
//  hideandseek
//

import Combine
import Foundation

@MainActor
final class MCDebugViewModel: ObservableObject {
    private let session: MultipeerGameSession

    @Published private(set) var localPeer: PeerID
    @Published private(set) var hostPeer: PeerID
    @Published private(set) var currentPeers: [PeerID] = []
    @Published private(set) var discoveredPeers: [PeerID] = []
    @Published private(set) var logs: [String] = []

    private var sessionEventTask: Task<Void, Never>?
    private var niTokenEventTask: Task<Void, Never>?

    init(session: MultipeerGameSession = MultipeerGameSession()) {
        self.session = session
        self.localPeer = session.localPeer
        self.hostPeer = session.hostPeer

        refreshPeers()
        observeSessionEvents()
        observeNITokenEvents()
    }

    deinit {
        sessionEventTask?.cancel()
        niTokenEventTask?.cancel()
    }

    func startHosting() {
        session.startHosting()
        appendLog("호스트 광고 시작")
        refreshPeers()
    }

    func stopHosting() {
        session.stopHosting()
        appendLog("호스트 광고 중지")
        refreshPeers()
    }

    func startBrowsing() {
        session.startBrowsing()
        appendLog("주변 호스트 탐색 시작")
        refreshPeers()
    }

    func stopBrowsing() {
        session.stopBrowsing()
        appendLog("주변 호스트 탐색 중지")
        refreshPeers()
    }

    func invite(_ peer: PeerID) {
        session.invite(peer)
        appendLog("초대 요청 전송: \(peer.displayName)")
        refreshPeers()
    }

    func refreshPeers() {
        localPeer = session.localPeer
        hostPeer = session.hostPeer
        currentPeers = session.currentPeers
        discoveredPeers = session.discoveredPeers
    }

    private func observeSessionEvents() {
        sessionEventTask = Task { [weak self, session] in
            let stream = session.makeEventStream()

            for await event in stream {
                await MainActor.run {
                    self?.handleSessionEvent(event)
                }
            }
        }
    }

    private func observeNITokenEvents() {
        niTokenEventTask = Task { [weak self, session] in
            let stream = session.makeNIDiscoveryTokenStream()

            for await event in stream {
                await MainActor.run {
                    self?.appendLog("NI token 수신: \(event.peer.displayName)")
                }
            }
        }
    }

    private func handleSessionEvent(_ event: SessionEvent) {
        switch event {
        case let .peerConnected(peer):
            appendLog("연결됨: \(peer.displayName)")

        case let .peerDisconnected(peer):
            appendLog("연결 끊김: \(peer.displayName)")

        case .discoveredRoomsChanged:
            appendLog("발견된 방 목록 갱신")
        }

        refreshPeers()
    }

    private func appendLog(_ message: String) {
        logs.insert(message, at: 0)
    }
}
