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
enum MultipeerMessageKind: String, Codable {
    case niDiscoveryToken
}

/// MCSession data 전송에 사용하는 공통 메시지 래퍼.
/// kind는 메시지 종류를 나타내고, payload에는 실제 전송할 Data가 들어간다.
struct MultipeerMessage: Codable {
    let kind: MultipeerMessageKind
    let payload: Data
}
