//
//  MultipeerMessage.swift
//  hideandseek
//
//  Created by 서혜린 on 6/5/26.
//
//
//  MultipeerMessage.swift
//  hideandseek
//

import Foundation

/// MCSession을 통해 주고받는 메시지 종류.
/// 수신 측은 kind를 보고 payload를 어떤 방식으로 해석할지 결정한다.
enum MultipeerMessageKind: String {
    /// MC 연결 이후 안정적인 앱 내부 PeerID를 교환하기 위한 메시지.
    case peerIdentity
    /// NearbyInteraction을 시작하기 위한 NIDiscoveryToken 메시지.
    case niDiscoveryToken
    /// 숨바꼭질 게임 진행 상태를 동기화하기 위한 메시지.
    case gameFlowMessage
    /// 게임 종료 후 촬영 사진 묶음을 공유하기 위한 메시지.
    case capturedPhotoBatch
    /// 사진 수신 실패 후 상대에게 사진 재전송을 요청하기 위한 메시지.
    case capturedPhotoShareRequest
}

extension MultipeerMessageKind: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        guard let kind = MultipeerMessageKind(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid multipeer message kind: \(rawValue)"
            )
        }

        self = kind
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// MCSession data 전송에 사용하는 공통 메시지 래퍼.
/// kind는 메시지 종류를 나타내고, payload에는 실제 전송할 Data가 들어간다.
struct MultipeerMessage {
    let kind: MultipeerMessageKind
    let payload: Data
}

extension MultipeerMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case payload
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.kind = try container.decode(
            MultipeerMessageKind.self,
            forKey: .kind
        )
        self.payload = try container.decode(
            Data.self,
            forKey: .payload
        )
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(
            kind,
            forKey: .kind
        )
        try container.encode(
            payload,
            forKey: .payload
        )
    }
}
