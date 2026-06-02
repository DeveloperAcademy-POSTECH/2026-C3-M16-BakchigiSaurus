//
//  GameSession.swift
//  hideandseek
//
//  Created by Gosan on 6/2/26.
//

//  실제 구현(MultipeerGameSession 등)은 Core 안의 MC 담당 코드가 이 protocol을 채택한다.
//  Feature는 이 protocol에만 의존한다.

import Foundation

/// 게임 참가자 식별자. (MC의 `MCPeerID`를 감싸는 추상 타입)
struct PeerID: Hashable, Sendable {
    let rawID: String        // MCPeerID 매핑용 안정 식별자
    let displayName: String  // 예: "캄초의 iPhone"
}

/// 세션 연결 변화 이벤트.
enum SessionEvent: Sendable {
    case peerConnected(PeerID)
    case peerDisconnected(PeerID)
}

/// 수집 세션이 MC에게 요구하는 최소 인터페이스 (= MC 담당자의 구현 스펙).
///
/// - Note: 클립 실제 송수신은 #3 `feat/clip-transfer`에서 확장한다. 여기엔 두지 않는다.
protocol GameSession: AnyObject, Sendable {
    /// 이 기기의 식별자.
    var localPeer: PeerID { get }
    /// 게임을 만든 호스트 = 영상 수집자. (고정)
    var hostPeer: PeerID { get }
    /// 현재 연결된 피어 스냅샷 (호스트 포함).
    var currentPeers: [PeerID] { get }
    /// 연결 변화 이벤트 스트림.
    func makeEventStream() -> AsyncStream<SessionEvent>
}
