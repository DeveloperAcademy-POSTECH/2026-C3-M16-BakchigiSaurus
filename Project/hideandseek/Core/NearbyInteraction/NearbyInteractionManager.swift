//
//  NearbyInteractionManager.swift
//  hideandseek
//
//  Created by 허지우 on 5/29/26.
//

// import SwiftUI
import Foundation
import NearbyInteraction

// startSession( ) 으로 NI 세션을 준비합니다.
// getMyDiscoveryToken( ) 으로 내 토큰을 가져와 MC로 전송합니다.
// 상대 토큰을 받으면 run 으로 측정을 시작합니다.
// onReadingUpdated 에서 거리와 방향을 받습니다.
// 게임 종료시 invalidateSession( ) 을 호출합니다.
// 거리 방향 측정값이 갱신될 때 호출, 실제 게임 ViewModel에서 한번 등록해 사용

final class NearbyInteractionManager: NSObject {
    private var session: NISession?
    var onReadingUpdated: ((NearbyInteractionReading) -> Void)? // 거리, 방향 값 들어왔을 때 외부에 콜백
    var onSessionRestartRequired: (() -> Void)? // 연결 객체에 재시작 필요를 알려주는 콜백

    private(set) var state: NearbyInteractionState = .idle
    private(set) var sharedTokenWithPeer = false
    private var peerDiscoveryToken: NIDiscoveryToken? // 상대방의 discovery token을 저장해두는 변수

    /// 초기화 함수
    override init() {
        super.init()
    }

    /// NI 세션을 시작 준비하는 함수
    /// NI 세션을 생성하고 측정 준비상태로 전환합니다.
    /// 상대 토큰으로 측정 시작전에 호출해야 합니다.
    /// McniConnection 을 사용하면 MC 연결 완료시 자동으로 호출됩니다.
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

    /// 상대에게 전송할 내 NI DiscoveryToken 반환 (가져오기)
    func getMyDiscoveryToken() -> NIDiscoveryToken? {
        session?.discoveryToken
    }

    /// NI Session 실행 함수
    /// 상대 기기의 DiscoveryToken 으로 거리 및 방향 측정을 시작합니다.
    /// MC 에서 상대 토큰을 받은 뒤 호출, (McnoConnection 사용시 자동 호출)
    /// parameter peerToken: MC를 통해 받은 상대 기기의 DiscoveryToken
    func run(with peerToken: NIDiscoveryToken) { // NI에서 부르는 상대토큰 변수명: peerToken

        guard session != nil else {
            state = .failed(.missingSession)
            return
        }

        peerDiscoveryToken = peerToken // NIDiscoveryToken에 저장한 변수를 peerDiscoveryToken에 저장함

        let configuration = NINearbyPeerConfiguration(peerToken: peerToken) // 위에서 받은 상대의 token? peerToken 이 이름이 맞는지

        // camera Assistance 지원 여부 확인 필요
        configuration.isCameraAssistanceEnabled = NISession.deviceCapabilities.supportsCameraAssistance

        print("NI session.run 호출")
        print("camera assistance supported:", NISession.deviceCapabilities.supportsCameraAssistance)
        print("camera assistance enabled:", configuration.isCameraAssistanceEnabled)

        session?.run(configuration)
        sharedTokenWithPeer = true
    }

    /// 세션  종료  함수
    /// NI 측정을 종료하고 세션 및 상대 토큰을 초기화 합니다.
    /// 게임 종료 또는 상대방 이탈시 자동 처리(호출) 됩니다.
    func invalidateSession() {
        session?.pause()
        session?.invalidate()
        session = nil
        // peerDiscoveryToken = nil
        // sharedTokenWithPeer = false
        peerDiscoveryToken = nil // 세션 종료시 상대토큰 남는 것 초기화
        state = .invalidated
    }

    deinit {
        session?.pause()
        session?.invalidate()
    }
}

/// NI가 주변 기기 정보를 업데이트 했을 때 자동으로 호출되는 함수
/// 직접 호출하지 않습니다.
extension NearbyInteractionManager: NISessionDelegate {
    /// 시스템  호출  콜백
    func sessionDidStartRunning(_ session: NISession) {
        state = .running
    }

    /// 거리, 방향 값 들어왔을 때 업데이트 과정
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let peerDiscoveryToken else {
            return
        }
        // 배열 안에서 상대방 object 찾기
        guard let nearbyObject = nearbyObjects.first(where: {
            $0.discoveryToken == peerDiscoveryToken
        }) else {
            return
        }
        // 상대와의 거리, 방향, 시각을 하나의 모델로 정리
        let reading = NearbyInteractionReading(
            distance: nearbyObject.distance,
            direction: nearbyObject.direction,
            timestamp: Date(),
            horizontalAngle: nearbyObject.horizontalAngle
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

        case .timeout: // 새 NI 생성 및 token 수신 필요
            state = .peerLost
            self.session = nil
            peerDiscoveryToken = nil
            onSessionRestartRequired?()

        default:
            state = .failed(.peerRemoved(reason))
        }
    }

    /// 세션이 일시중단 되었을 때
    func sessionWasSuspended(_ session: NISession) {
        state = .suspended
    }

    /// 세션 중단이 종료되었을 때 (= 재실행 가능 상태, 세션 재호출)
    func sessionSuspensionEnded(_ session: NISession) {
        guard let peerDiscoveryToken else {
            state = .ready
            return
        }

        let configuration = NINearbyPeerConfiguration(peerToken: peerDiscoveryToken)

        // 세션 재개시 camera Assistance 다시 활성화
        configuration.isCameraAssistanceEnabled = NISession.deviceCapabilities.supportsCameraAssistance

        session.run(configuration)
    }

    /// 세션이 에러와 함께 완전 종료되었을 때
    func session(_ session: NISession, didInvalidateWith error: Error) {
        self.session = nil
        peerDiscoveryToken = nil // 재사용 불가한 peer token 정리
        // sharedTokenWithPeer = false
        state = .failed(.sessionInvalidated(error))
    }
}
