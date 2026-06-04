//
//  ClipTransferService.swift
//  hideandseek
//
//  Created by Gosan on 6/4/26.
//

import Foundation

/// 클립 전송/수집 오케스트레이션. 실제 MC 전송은 `ClipTransport` 구현에 위임한다.
/// 호스트는 도착 클립을 참가자별로 모으고, 참가자는 자기 클립을 호스트에 보낸다.
@MainActor
@Observable
final class ClipTransferService {
    /// 참가자 측 전송 상태.
    enum SendState {
        case idle
        case sending
        case done
        case failed
    }

    /// (호스트) 참가자별로 수집된 클립.
    private(set) var collected: [PeerID: [URL]] = [:]
    /// (참가자) 내 클립 전송 상태.
    private(set) var sendState: SendState = .idle

    private let transport: any ClipTransport

    init(transport: any ClipTransport) {
        self.transport = transport
    }

    /// (호스트) 도착하는 클립을 참가자별로 수집한다. View의 `.task`에서 호출.
    func collectIncoming() async {
        for await clip in transport.makeIncomingClipStream() {
            collected[clip.from, default: []].append(clip.url)
        }
    }

    /// (참가자) 내 클립들을 호스트에게 순차 전송한다.
    func send(_ clips: [URL], to host: PeerID) async {
        sendState = .sending
        do {
            for url in clips {
                try await transport.sendClip(at: url, to: host)
            }
            sendState = .done
        } catch {
            sendState = .failed
        }
    }
}
