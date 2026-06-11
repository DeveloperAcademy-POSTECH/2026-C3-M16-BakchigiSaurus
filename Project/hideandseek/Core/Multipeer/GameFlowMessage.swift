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
    case captureRequested
    case captureRejected
    case captureConfirmed
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
    let participantPeerRawIDs: [String]?
    let participantPeerDisplayNames: [String]?
    let winner: GameFlowWinner?

    var referencedPeer: PeerID? {
        guard let targetPeerRawID, let targetPeerDisplayName else {
            return nil
        }

        return PeerID(
            rawID: targetPeerRawID,
            displayName: targetPeerDisplayName
        )
    }

    var participantPeers: [PeerID]? {
        guard let participantPeerRawIDs,
              let participantPeerDisplayNames,
              participantPeerRawIDs.count == participantPeerDisplayNames.count
        else {
            return nil
        }

        return zip(participantPeerRawIDs, participantPeerDisplayNames).map { rawID, displayName in
            PeerID(rawID: rawID, displayName: displayName)
        }
    }

    /// 게임 시작 메시지를 만든다.
    static func gameStarted(
        participants: [PeerID]? = nil,
        taggerPeer: PeerID? = nil
    ) -> GameFlowMessage {
        GameFlowMessage(
            kind: .gameStarted,
            role: nil,
            seconds: nil,
            targetPeerRawID: taggerPeer?.rawID,
            targetPeerDisplayName: taggerPeer?.displayName,
            participantPeerRawIDs: participants?.map(\.rawID),
            participantPeerDisplayNames: participants?.map(\.displayName),
            winner: nil
        )
    }

    /// 역할 배정 메시지를 만든다.
    static func roleAssigned(
        _ role: GameFlowRole,
        taggerPeer: PeerID? = nil
    ) -> GameFlowMessage {
        GameFlowMessage(
            kind: .roleAssigned,
            role: role,
            seconds: nil,
            targetPeerRawID: taggerPeer?.rawID,
            targetPeerDisplayName: taggerPeer?.displayName,
            participantPeerRawIDs: nil,
            participantPeerDisplayNames: nil,
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
            participantPeerRawIDs: nil,
            participantPeerDisplayNames: nil,
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
            participantPeerRawIDs: nil,
            participantPeerDisplayNames: nil,
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
            participantPeerRawIDs: nil,
            participantPeerDisplayNames: nil,
            winner: nil
        )
    }

    /// 술래가 특정 숨는 사람과 기기 접촉 수준으로 가까워졌다는 메시지를 만든다.
    static func captureRequested(hiderPeer: PeerID) -> GameFlowMessage {
        GameFlowMessage(
            kind: .captureRequested,
            role: nil,
            seconds: nil,
            targetPeerRawID: hiderPeer.rawID,
            targetPeerDisplayName: hiderPeer.displayName,
            participantPeerRawIDs: nil,
            participantPeerDisplayNames: nil,
            winner: nil
        )
    }

    /// 숨는 사람이 잡힘 요청을 부정했다는 메시지를 만든다.
    static func captureRejected(hiderPeer: PeerID) -> GameFlowMessage {
        GameFlowMessage(
            kind: .captureRejected,
            role: nil,
            seconds: nil,
            targetPeerRawID: hiderPeer.rawID,
            targetPeerDisplayName: hiderPeer.displayName,
            participantPeerRawIDs: nil,
            participantPeerDisplayNames: nil,
            winner: nil
        )
    }

    /// 숨는 사람이 잡힘을 직접 확정했다는 메시지를 만든다.
    static func captureConfirmed(hiderPeer: PeerID) -> GameFlowMessage {
        GameFlowMessage(
            kind: .captureConfirmed,
            role: nil,
            seconds: nil,
            targetPeerRawID: hiderPeer.rawID,
            targetPeerDisplayName: hiderPeer.displayName,
            participantPeerRawIDs: nil,
            participantPeerDisplayNames: nil,
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
            participantPeerRawIDs: nil,
            participantPeerDisplayNames: nil,
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
        case participantPeerRawIDs
        case participantPeerDisplayNames
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
        self.participantPeerRawIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .participantPeerRawIDs
        )
        self.participantPeerDisplayNames = try container.decodeIfPresent(
            [String].self,
            forKey: .participantPeerDisplayNames
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
            participantPeerRawIDs,
            forKey: .participantPeerRawIDs
        )
        try container.encodeIfPresent(
            participantPeerDisplayNames,
            forKey: .participantPeerDisplayNames
        )
        try container.encodeIfPresent(
            winner?.rawValue,
            forKey: .winner
        )
    }
}
