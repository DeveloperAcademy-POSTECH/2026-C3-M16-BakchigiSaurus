//
//  McniConnection.swift
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
    private var tokenExchangePeerRawID: String?

    private var connectedPeer: PeerID? // 현재 연결된 peer 저장한 뒤 다시 토큰 교환

    init(mcManager: MultipeerGameSession, niManager: NearbyInteractionManager) {
        self.mcSession = mcManager
        self.niManager = niManager

        // NI 가 timeout 발생시 새로운 세션과 토큰 교환 시작
        niManager.onSessionRestartRequired = { [weak self] in
            guard let self, let peer = connectedPeer else {
                return
            }

            startNITokenExchange(with: peer)
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
                    print("MC peer Connected:", peer)
                    connectedPeer = peer
                    startNITokenExchange(with: peer)

                case let .peerDisconnected(peer):
                    print("MC peer Disconnected:", peer)

                    if connectedPeer?.rawID == peer.rawID {
                        connectedPeer = nil
                    }

                    tokenExchangePeerRawID = nil
                    niManager.invalidateSession()

                case .discoveredRoomsChanged:
                    break
                }
            }
        }
    }

    /// 내 NI token 을 상대에게 보내는 함수
    /// NI 세션 시작 후 내 discoveryToken 을 가져와서 MC 를 통해 상대 peer 에게 내 token 보낸다
    private func startNITokenExchange(with peer: PeerID) {
        tokenExchangePeerRawID = peer.rawID
        niManager.startSession()

        guard let localToken = niManager.getMyDiscoveryToken() else {
            tokenExchangePeerRawID = nil
            print("Local NI token 생성 실패")
            return
        }

        mcSession.sendNIDiscoveryToken(localToken, to: peer)
        print("Local NI token sent to peer:", peer)
    }

    /// NI token 이벤트 구독 예정
    /// 상대가 보내준 NI Token 을 기다리는 함수
    private func observeNITokenEvents() {
        niTokenEventTask = Task { [weak self] in
            guard let self else { return }

            for await event in mcSession.makeNIDiscoveryTokenStream() {
                print("NI token received from:", event.peer)
                niManager.run(with: event.token)
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
