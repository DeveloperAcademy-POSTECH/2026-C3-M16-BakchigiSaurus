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

    /// 초기화 함수
    override init() {
        super.init()
    }

    /// NI 세션을 시작 준비하는 함수
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

    /// NISession에서 내 token 가져오기
    func getMyDiscoveryToken() -> NIDiscoveryToken? {
        session?.discoveryToken
    }
    
    // 내 token을 MC가 보낼 수있는 Data로 변환
    func makeLocalDiscoveryTokenData() throws -> Data {
        guard let discoveryToken = session?.discoveryToken else {
            throw NearbyInteractionError.missingDiscoveryToken
        }
        
        let tokenData = try NSKeyedArchiver.archivedData(withRootObject: discoveryToken, requiringSecureCoding: true)
        
        return tokenData
    }
    
    // MC에게 받은 Data를 다시 token으로 바꿈
    func decodeDiscoveryToken(from data: Data) throws -> NIDiscoveryToken {
        guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data
        ) else {
            throw NearbyInteractionError.invalidDiscoveryToken
        }
        
        return token
    }
    
    /// 세션 종료 함수
    func invalidateSession() {
        session?.invalidate()
        session = nil
        sharedTokenWithPeer = false
        state = .invalidated
    }
}

extension NearbyInteractionManager: NISessionDelegate {
    /// 시스템 호출 콜백
    func sessionDidStartRunning(_ session: NISession) {
        state = .running
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // 추후 브랜치 feat/ni-update에서 distance.direction 처리
    }

    func session(
        _ session: NISession,
        didRemove nearbyObjects: [NINearbyObject],
        reason: NINearbyObject.RemovalReason
    ) {
        // feat/ni-error에서 timeout.peerEnded 처리
    }

    /// 중단 관리
    func sessionWasSuspended(_ session: NISession) {
        state = .suspended
    }

    func sessionSuspensionEnded(_ session: NISession) {
        state = .ready
    }

    /// 오류 처리
    func session(_ session: NISession, didInvalidateWith error: Error) {
        self.session = nil
        sharedTokenWithPeer = false
        state = .failed(.sessionInvalidated(error))
    }
}
