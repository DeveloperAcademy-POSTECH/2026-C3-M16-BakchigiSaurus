//
//  GameFlowMessage.swift
//  hideandseek
//
//  Created by 서혜린 on 6/5/26.
//
//  GameFlowMessage.swift
//  hideandseek
//

import Foundation

/// MCSession을 통해 주고받는 숨바꼭질 게임 진행 메시지 종류.
enum GameFlowMessageKind: String {
    case gameStarted
    case roleAssigned
    case countdownStarted
    case searchStarted
    case playerFound
    case gameEnded
}

/// 숨바꼭질 게임에서 사용하는 역할.
enum GameFlowRole: String {
    case seeker
    case hider
}

/// 게임 종료 시 승리한 역할.
enum GameFlowWinner: String {
    case seeker
    case hider
    case unknown
}

/// MCSession으로 전달할 게임 진행 메시지.
/// associated enum 대신 struct로 구성해 메시지 확장과 디코딩을 단순하게 유지한다.
struct GameFlowMessage {
    let kind: GameFlowMessageKind
    let role: GameFlowRole?
    let seconds: Int?
    let targetPeerRawID: String?
    let targetPeerDisplayName: String?
    let winner: GameFlowWinner?

    /// 게임 시작 메시지를 만든다.
    static func gameStarted() -> GameFlowMessage {
        GameFlowMessage(
            kind: .gameStarted,
            role: nil,
            seconds: nil,
            targetPeerRawID: nil,
            targetPeerDisplayName: nil,
            winner: nil
        )
    }

    /// 역할 배정 메시지를 만든다.
    static func roleAssigned(_ role: GameFlowRole) -> GameFlowMessage {
        GameFlowMessage(
            kind: .roleAssigned,
            role: role,
            seconds: nil,
            targetPeerRawID: nil,
            targetPeerDisplayName: nil,
            winner: nil
        )
    }

    /// 카운트다운 시작 메시지를 만든다.
    static func countdownStarted(seconds: Int) -> GameFlowMessage {
        GameFlowMessage(
            kind: .countdownStarted,
            role: nil,
            seconds: seconds,
            targetPeerRawID: nil,
            targetPeerDisplayName: nil,
            winner: nil
        )
    }

    /// 탐색 시작 메시지를 만든다.
    static func searchStarted() -> GameFlowMessage {
        GameFlowMessage(
            kind: .searchStarted,
            role: nil,
            seconds: nil,
            targetPeerRawID: nil,
            targetPeerDisplayName: nil,
            winner: nil
        )
    }

    /// 특정 peer를 찾았다는 메시지를 만든다.
    static func playerFound(_ peer: PeerID) -> GameFlowMessage {
        GameFlowMessage(
            kind: .playerFound,
            role: nil,
            seconds: nil,
            targetPeerRawID: peer.rawID,
            targetPeerDisplayName: peer.displayName,
            winner: nil
        )
    }

    /// 게임 종료 메시지를 만든다.
    static func gameEnded(winner: GameFlowWinner) -> GameFlowMessage {
        GameFlowMessage(
            kind: .gameEnded,
            role: nil,
            seconds: nil,
            targetPeerRawID: nil,
            targetPeerDisplayName: nil,
            winner: winner
        )
    }
}

extension GameFlowMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case role
        case seconds
        case targetPeerRawID
        case targetPeerDisplayName
        case winner
    }

    /// 수신한 Data를 GameFlowMessage로 복원한다.
    /// 메시지 종류, 역할, 승리자 값은 rawValue를 검증해 안전하게 변환한다.
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let kindRawValue = try container.decode(
            String.self,
            forKey: .kind
        )

        guard let kind = GameFlowMessageKind(rawValue: kindRawValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Invalid game flow message kind: \(kindRawValue)"
            )
        }

        let roleRawValue = try container.decodeIfPresent(
            String.self,
            forKey: .role
        )
        let role = try roleRawValue.map { rawValue in
            guard let role = GameFlowRole(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .role,
                    in: container,
                    debugDescription: "Invalid game flow role: \(rawValue)"
                )
            }

            return role
        }

        let winnerRawValue = try container.decodeIfPresent(
            String.self,
            forKey: .winner
        )
        let winner = try winnerRawValue.map { rawValue in
            guard let winner = GameFlowWinner(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .winner,
                    in: container,
                    debugDescription: "Invalid game flow winner: \(rawValue)"
                )
            }

            return winner
        }

        self.kind = kind
        self.role = role
        self.seconds = try container.decodeIfPresent(
            Int.self,
            forKey: .seconds
        )
        self.targetPeerRawID = try container.decodeIfPresent(
            String.self,
            forKey: .targetPeerRawID
        )
        self.targetPeerDisplayName = try container.decodeIfPresent(
            String.self,
            forKey: .targetPeerDisplayName
        )
        self.winner = winner
    }

    /// GameFlowMessage를 MCSession으로 전송 가능한 Data로 변환하기 위해 인코딩한다.
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(
            kind.rawValue,
            forKey: .kind
        )
        try container.encodeIfPresent(
            role?.rawValue,
            forKey: .role
        )
        try container.encodeIfPresent(
            seconds,
            forKey: .seconds
        )
        try container.encodeIfPresent(
            targetPeerRawID,
            forKey: .targetPeerRawID
        )
        try container.encodeIfPresent(
            targetPeerDisplayName,
            forKey: .targetPeerDisplayName
        )
        try container.encodeIfPresent(
            winner?.rawValue,
            forKey: .winner
        )
    }
}
