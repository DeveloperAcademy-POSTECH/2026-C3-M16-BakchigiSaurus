//
//  McniConncetion.swift
//  hideandseek
//
//  Created by 허지우 on 6/5/26.
//

import Combine
import Foundation
import NearbyInteraction

final class McniConnection {
    private let mcSession: MultipeerGameSession
    private let niManager: NearbyInteractionManager

    private var sessionEventTask: Task<Void, Error>?
    private var niTokenEventTask: Task<Void, Error>?
    private var tokenExchangePeerRawIDs: Set<String> = []
    private var connectedPeersByRawID: [String: PeerID] = [:]

    init(mcManager: MultipeerGameSession, niManager: NearbyInteractionManager) {
        self.mcSession = mcManager
        self.niManager = niManager

        // NI 가 timeout 발생시 새로운 세션과 토큰 교환 시작
        niManager.onSessionRestartRequired = { [weak self] in
            guard let self else { return }

            for peer in connectedPeersByRawID.values {
                startNITokenExchange(with: peer)
            }
        }

        observeSessionEvents()
        observeNITokenEvents()
    }

    /// MC 연결 상태 지켜보는 함수
    private func observeSessionEvents() {
        sessionEventTask = Task { [weak self] in
            guard let self else { return }

            for await event in mcSession.makeEventStream() {
                switch event {
                case let .peerConnected(peer):
                    let duplicateRawIDs = connectedPeersByRawID
                        .filter { rawID, connectedPeer in
                            rawID != peer.rawID &&
                                connectedPeer.displayName == peer.displayName
                        }
                        .map(\.key)

                    for rawID in duplicateRawIDs {
                        connectedPeersByRawID.removeValue(forKey: rawID)
                        tokenExchangePeerRawIDs.remove(rawID)
                    }

                    connectedPeersByRawID[peer.rawID] = peer

                    // 같은 peer와 중복 토큰 교환 방지
                    if !tokenExchangePeerRawIDs.contains(peer.rawID) {
                        startNITokenExchange(with: peer)
                    }

                case let .peerDisconnected(peer):
                    connectedPeersByRawID.removeValue(forKey: peer.rawID)
                    tokenExchangePeerRawIDs.remove(peer.rawID)

                    if connectedPeersByRawID.isEmpty {
                        niManager.invalidateSession()
                    }

                case .discoveredRoomsChanged:
                    break
                }
            }
        }
    }

    /// 내 NI token 을 상대에게 보내는 함수
    /// NI 세션 시작 후 내 discoveryToken 을 가져와서 MC 를 통해 상대 peer 에게 내 token 보낸다
    private func startNITokenExchange(with peer: PeerID) {
        tokenExchangePeerRawIDs.insert(peer.rawID)
        niManager.startSession(for: peer)

        guard let localToken = niManager.getMyDiscoveryToken(for: peer) else {
            tokenExchangePeerRawIDs.remove(peer.rawID)
            return
        }

        mcSession.sendNIDiscoveryToken(localToken, to: peer)
    }

    /// NI token 이벤트 구독 예정
    /// 상대가 보내준 NI Token 을 기다리는 함수
    private func observeNITokenEvents() {
        niTokenEventTask = Task { [weak self] in
            guard let self else { return }

            for await event in mcSession.makeNIDiscoveryTokenStream() {
                niManager.run(with: event.token, peer: event.peer)
            }
        }
    }

    deinit {
        sessionEventTask?.cancel()
        niTokenEventTask?.cancel()
        niManager.invalidateSession()
    }
}

final class McniConnectionHolder: ObservableObject {
    let connection: McniConnection

    init() {
        let mcSession = MultipeerGameSession()
        let niManager = NearbyInteractionManager()

        self.connection = McniConnection(mcManager: mcSession, niManager: niManager)
    }
}
