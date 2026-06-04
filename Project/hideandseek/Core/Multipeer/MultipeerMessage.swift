//
//  MultipeerMessage.swift
//  hideandseek
//
//  Created by 서혜린 on 6/5/26.
//
//  MultipeerMessage.swift
//  hideandseek
//

import Foundation

/// MCSession을 통해 주고받는 메시지 종류.
enum MultipeerMessageKind: String, Codable {
    case niDiscoveryToken
} 

/// MCSession data 전송에 사용하는 공통 메시지 래퍼.
/// payload에는 실제 전송할 Data가 들어간다.
struct MultipeerMessage: Codable {
    let kind: MultipeerMessageKind
    let payload: Data
}
