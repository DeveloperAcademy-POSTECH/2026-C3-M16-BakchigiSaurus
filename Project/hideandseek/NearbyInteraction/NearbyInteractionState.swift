//
//  NearbyInteractionState.swift
//  hideandseek
//
//  Created by 허지우 on 5/29/26.
//

// import SwiftUI
//
// struct NearbyInteractionState: View {
//    var body: some View {
//        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
//    }
// }
//
// #Preview {
//    NearbyInteractionState()
// }

import Foundation
import NearbyInteraction

/// NI의 상태
enum NearbyInteractionState {
    case idle // 아무것도 시작 안한 상태
    case ready // NI 세션 만듦
    case running // 상대 token 받아서 측정 시작
    case suspended // 세션 일시 중단
    case invalidated // 세션 완전 종료
    case unsupported // 기기 지원 안함
    case peerLost // 상대방을 잃어버림
    case peerEnded // 상대방이 종료함
    case failed(NearbyInteractionError) // 처리중 에러 발생
}

/// NI에서 발생할 수 있는 에러 종류를 정의
enum NearbyInteractionError: Error {
    case unsupportedDevice // 기기 지원 안함
    case missingSession // 세션 없는데 뭔가 하려고 함
    case sessionInvalidated(Error) // 세션이 종료되면서 실제 에러를 감쌈

    // 토큰 변환 실패 case 추가
    case missingDiscoveryToken
    case invalidDiscoveryToken

    case peerRemoved(NINearbyObject.RemovalReason)
}

/// NI가 측정한 거리/ 방향 값
struct NearbyInteractionReading {
    let distance: Float?
    let direction: SIMD3<Float>?
    let timestamp: Date
}
