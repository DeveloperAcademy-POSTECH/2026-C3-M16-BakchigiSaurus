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
    private var session: NISession?
    var onReadingUpdated: ((NearbyInteractionReading) -> Void)? // 거리, 방향 값 들어왔을 때 외부에 콜백

    private(set) var state: NearbyInteractionState = .idle
    private(set) var sharedTokenWithPeer = false
    private var peerDiscoveryToken: NIDiscoveryToken? // 상대방의 discovery token을 저장해두는 변수

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

        if let session {
            session.pause()
            session.invalidate()
        }

        // NI 세션 생성
        let newSession = NISession()
        newSession.delegate = self

        session = newSession
        sharedTokenWithPeer = false
        peerDiscoveryToken = nil
        state = .ready
    }

    /// NISession에서 내 token 가져오기
    func getMyDiscoveryToken() -> NIDiscoveryToken? {
        session?.discoveryToken
    }

    /// 내 token을 MC가 보낼 수있는 Data로 변환
    func makeLocalDiscoveryTokenData() throws -> Data {
        guard let discoveryToken = session?.discoveryToken else {
            state = .failed(.missingDiscoveryToken)
            throw NearbyInteractionError.missingDiscoveryToken
        }

        return try NSKeyedArchiver.archivedData(withRootObject: discoveryToken, requiringSecureCoding: true)
    }

    /// MC에게 받은 Data를 다시 token으로 바꿈
    func decodeDiscoveryToken(from data: Data) throws -> NIDiscoveryToken {
        guard let token = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self,
            from: data
        ) else {
            state = .failed(.invalidDiscoveryToken)
            throw NearbyInteractionError.invalidDiscoveryToken
        }

        return token
    }

    /// MC가 받은 상대방 token data를 NI 세션 실행 함수에 이어줄때 사용하는 함수
    func run(with peerTokenData: Data) {
        do {
            let peerToken = try decodeDiscoveryToken(from: peerTokenData)
            run(with: peerToken)
        } catch {
            state = .failed(.invalidDiscoveryToken)
        }
    }

    /// NI Session 실행 함수
    func run(with peerToken: NIDiscoveryToken) { // NI에서 부르는 상대토큰 변수명: peerToken

        guard session != nil else {
            state = .failed(.missingSession)
            return
        }

        peerDiscoveryToken = peerToken // NIDiscoveryToken에 저장한 변수를 peerDiscoveryToken에 저장함

        session?.run(makeConfiguration(peerToken: peerToken))
        sharedTokenWithPeer = true
    }

    @discardableResult
    func resumeSessionIfPossible() -> Bool {
        guard let peerDiscoveryToken else {
            debugLog("resumeSessionIfPossible skipped: peerDiscoveryToken=nil")
            return false
        }

        guard session != nil else {
            state = .failed(.missingSession)
            debugLog("resumeSessionIfPossible skipped: session=nil")
            return false
        }

        run(with: peerDiscoveryToken)
        debugLog("resumeSessionIfPossible rerun requested")
        return true
    }

    /// 세션  종료  함수
    func invalidateSession() {
        session?.pause()
        session?.invalidate()
        session = nil
        peerDiscoveryToken = nil
        sharedTokenWithPeer = false
        state = .invalidated
    }

    deinit {
        session?.pause()
        session?.invalidate()
    }

    private func makeConfiguration(peerToken: NIDiscoveryToken) -> NINearbyPeerConfiguration {
        let configuration = NINearbyPeerConfiguration(peerToken: peerToken)
        configuration.isCameraAssistanceEnabled = false
        return configuration
    }
}

/// NI가 주변 기기 정보를 업데이트 했을 때 자동으로 호출되는 함수
extension NearbyInteractionManager: NISessionDelegate {
    /// 시스템  호출  콜백
    func sessionDidStartRunning(_ session: NISession) {
        state = .running
        debugLog("sessionDidStartRunning")
    }

    /// 거리, 방향 값 들어왔을 때 업데이트 과정
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let peerDiscoveryToken else {
            debugLog("didUpdate ignored: peerDiscoveryToken=nil objects=\(nearbyObjects.count)")
            return
        }
        // 배열 안에서 상대방 object 찾기
        guard let nearbyObject = nearbyObjects.first(where: {
            $0.discoveryToken == peerDiscoveryToken
        }) else {
            debugLog("didUpdate ignored: no matching peer objects=\(nearbyObjects.count)")
            return
        }
        // 상대와의 거리, 방향, 시각을 하나의 모델로 정리
        let reading = NearbyInteractionReading(
            distance: nearbyObject.distance,
            direction: nearbyObject.direction,
            timestamp: Date(),
            horizontalAngle: nearbyObject.horizontalAngle
        )

        debugLog(
            "didUpdate matched distance=\(format(distance: reading.distance)) " +
            "hasDirection=\(reading.direction != nil)"
        )
        onReadingUpdated?(reading) // 만든 값을 외부로 전달
    }

    /// 세션이 추적하던 nearbyObject를 더이상 추적하지 못하게 되었을 때
    func session(
        _ session: NISession,
        didRemove nearbyObjects: [NINearbyObject],
        reason: NINearbyObject.RemovalReason
    ) {
        switch reason {
        case .peerEnded:
            state = .peerEnded
            debugLog("didRemove peerEnded objects=\(nearbyObjects.count)")

        case .timeout:
            state = .peerLost
            debugLog("didRemove timeout objects=\(nearbyObjects.count)")

        default:
            state = .failed(.peerRemoved(reason))
            debugLog("didRemove failed reason=\(reason) objects=\(nearbyObjects.count)")
        }
    }

    /// 세션이 일시중단 되었을 때
    func sessionWasSuspended(_ session: NISession) {
        state = .suspended
        debugLog("sessionWasSuspended")
    }

    /// 세션 중단이 종료되었을 때 (= 재실행 가능 상태, 세션 재호출)
    func sessionSuspensionEnded(_ session: NISession) {
        guard let peerDiscoveryToken else {
            state = .ready
            debugLog("sessionSuspensionEnded without peer token")
            return
        }

        session.run(makeConfiguration(peerToken: peerDiscoveryToken))
        debugLog("sessionSuspensionEnded rerun")
    }

    /// 세션이 에러와 함께 완전 종료되었을 때
    func session(_ session: NISession, didInvalidateWith error: Error) {
        self.session = nil
        peerDiscoveryToken = nil // 재사용 불가한 peer token 정리
        sharedTokenWithPeer = false
        state = .failed(.sessionInvalidated(error))
        debugLog("didInvalidateWith error=\(error)")
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[NearbyInteractionManager] \(message) state=\(state)")
        #endif
    }

    private func format(distance: Float?) -> String {
        guard let distance else { return "nil" }
        return String(format: "%.2fm", distance)
    }
}
