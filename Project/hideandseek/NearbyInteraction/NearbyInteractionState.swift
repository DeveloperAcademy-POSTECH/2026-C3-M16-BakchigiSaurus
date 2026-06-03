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
    case idle
    case ready
    case running
    case suspended
    case invalidated
    case unsupported
    case failed(NearbyInteractionError)
}

/// NI에서 발생할 수 있는 에러 종류를 정의
enum NearbyInteractionError: Error {
    case unsupportedDevice
    case missingSession
    case sessionInvalidated(Error)
    
    // 토큰 변환 실패 case 추가
    case missingDiscoveryToken
    case invalidDiscoveryToken
}

/// NI가 측정한 거리/방향 값
struct NearbyInteractionReading {
    let distance: Float?
    let direction: SIMD3<Float>?
    let timestamp: Date
}
