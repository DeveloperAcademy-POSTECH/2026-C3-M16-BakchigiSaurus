//
//  Cliptransport.swift
//  hideandseek
//
//  Created by Gosan on 6/4/26.
//

import Foundation

/// 호스트가 수신한 클립 한 개.
struct IncomingClip {
    /// 보낸 참가자.
    let from: PeerID
    /// 로컬에 저장된 클립 파일 URL.
    let url: URL
}

/// 클립 송수신 계약. 연결/식별은 `GameSession`이, 전송은 이쪽이 담당한다.
/// `MultipeerGameSession`이 `GameSession`과 함께 채택한다. (추가 계약 — 기존 GameSession 불변)
protocol ClipTransport: AnyObject, Sendable {
    /// 클립 파일을 특정 피어에게 전송하고 완료까지 기다린다.
    /// - Throws: 전송 실패 시.
    func sendClip(at url: URL, to peer: PeerID) async throws
    /// (호스트) 도착하는 클립 스트림.
    func makeIncomingClipStream() -> AsyncStream<IncomingClip>
}
