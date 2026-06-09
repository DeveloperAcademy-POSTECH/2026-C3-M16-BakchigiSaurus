//
//  CollectorSession.swift
//  hideandseek
//
//  Created by Gosan on 6/1/26.
//

import Foundation

/// 수집 단계 세션 상태 관리: 역할(수집자/참가자) 판별 + 호스트 도달성 추적.
@MainActor
@Observable
final class CollectorSession {
    enum Role {
        case host // 이 기기가 영상 수집자
        case participant // 클립을 호스트에게 보내는 쪽
    }

    /// 이 기기의 역할. (게임 생성 호스트 = 수집자)
    let role: Role

    /// 현재 연결된 피어. (UI에서 호스트 제외/참가자만 가공해서 사용)
    private(set) var connectedPeers: [PeerID]

    /// 호스트(수집자) 도달 가능 여부. 끊기면 false → 리스트에서 "호스트 끊김" 노출.
    private(set) var isHostReachable: Bool = true

    private let session: any GameSession

    /// - Parameter session: MC seam. 개발 땐 `MockGameSession`, 통합 땐 실제 구현 주입.
    init(session: any GameSession) {
        self.session = session

        let role: Role = (session.localPeer == session.hostPeer) ? .host : .participant
        self.role = role
        self.connectedPeers = session.currentPeers

        self.isHostReachable = role == .host || session.currentPeers.contains(session.hostPeer)
    }

    /// 편의 프로퍼티: 이 기기가 수집자인지.
    var isHost: Bool {
        role == .host
    }

    /// 세션 이벤트를 구독하며 연결 상태를 추적한다. View의 `.task`에서 호출.
    func observe() async {
        for await event in session.makeEventStream() {
            switch event {
            case let .peerConnected(peer):
                if !connectedPeers.contains(peer) { connectedPeers.append(peer) }
                if peer == session.hostPeer { isHostReachable = true }

            case let .peerDisconnected(peer):
                connectedPeers.removeAll { $0 == peer }
                if peer == session.hostPeer { isHostReachable = false } // 호스트 끊김

            case .discoveredRoomsChanged:
                break
            }
        }
    }
}

// 사용 예시
//
//  let session = MockGameSession(asHost: false)   // 개발 중
//  let collector = CollectorSession(session: session)
//  // SwiftUI: .task { await collector.observe() }
//
//  // 통합 시 — 이 한 줄만 교체. 아래 CollectorSession 코드는 그대로.
//  // let session = MultipeerGameSession(...)
