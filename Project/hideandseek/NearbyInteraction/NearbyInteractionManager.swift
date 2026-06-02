//
//  NearbyInteractionManager.swift
//  hideandseek
//
//  Created by 허지우 on 5/29/26.
//

// import SwiftUI
import Foundation
import NearbyInteraction


final class NearbyInteractionManager: NSObject {
    var session: NISession?
    
    private(set) var state: NearbyInteractionState = .idle
    private(set) var sharedTokenWithPeer = false
    
    // 초기화 함수
    override init() {
        super.init()
    }
    
    // NI 세션을 시작 준비하는 함수
    func startSession() {
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            state = .unsupported
            return
        }
        
        // NI 세션 생성
        let newSession = NISession()
        newSession.delegate = self
        
        session = newSession
        sharedTokenWithPeer = false
        state = .ready
    }
    
    // NISession에서 내 token 가져오기
    func getMyDiscoveryToken() -> NIDiscoveryToken? {
        return session?.discoveryToken
    }
    
    // 세션 종료 함수
    func invalidateSession() {
        session?.invalidate()
        session = nil
        sharedTokenWithPeer = false
        state = .invalidated
    }
}


extension NearbyInteractionManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // 추후 브랜치에서 보완 예정
    }

    
}
