//
//  NearbyInteractionManager.swift
//  hideandseek
//
//  Created by 허지우 on 5/29/26.
//

// import SwiftUI
import AVFoundation
import Foundation
import NearbyInteraction
import UIKit

// startSession( ) 으로 NI 세션을 준비합니다.
// getMyDiscoveryToken( ) 으로 내 토큰을 가져와 MC로 전송합니다.
// 상대 토큰을 받으면 run 으로 측정을 시작합니다. (기본: 거리 전용 모드)
// onReadingUpdated 에서 거리와 방향을 받습니다.
// 게임 종료시 invalidateSession( ) 을 호출합니다.
//
// 측정 모드
// ---------
// · .distance  : 기본. ARSession 없음. 거리만 측정. 카메라(AVCaptureSession)와 충돌하지 않음.
// · .direction : 힌트 사용 시 잠깐만. 카메라가 닫힌 상태에서 NI camera assistance로 방향까지 측정.
//   전환 전제: 호출 측(CameraModel)이 카메라 세션을 먼저 닫아야 한다(자원 경합 방지).

/// NI 측정 모드.
enum NIMeasurementMode {
    /// 거리 전용. ARSession 미사용. (카메라 사진 촬영과 공존 가능)
    case distance
    /// 거리 + 방향. NI가 내부 ARSession을 사용하므로 카메라 세션을 닫은 뒤에만 진입해야 함.
    case direction
}

final class NearbyInteractionManager: NSObject {
    private var session: NISession?
    private var sessionsByPeerRawID: [String: NISession] = [:]
    private var peerRawIDBySessionID: [ObjectIdentifier: String] = [:]
    private var peersByRawID: [String: PeerID] = [:]
    private var peerDiscoveryTokensByRawID: [String: NIDiscoveryToken] = [:]
    private var activeDirectionPeerRawID: String?
    private var lastReadingPeerRawID: String?
    var onReadingUpdated: ((NearbyInteractionReading) -> Void)? // 거리, 방향 값 들어왔을 때 외부에 콜백
    var onSessionRestartRequired: (() -> Void)? // 연결 객체에 재시작 필요를 알려주는 콜백

    private(set) var state: NearbyInteractionState = .idle
    private(set) var sharedTokenWithPeer = false
    private(set) var mode: NIMeasurementMode = .distance
    private var peerDiscoveryToken: NIDiscoveryToken? // 상대방의 discovery token을 저장해두는 변수
    private var lastUpdateDebugLogAt: Date?
    private var lastConvergenceDebugLogAt: Date?
    private var lastDirectionSampleDebugLogAt: Date?
    private var didLogFirstDirectionSampleInCurrentRun = false
    private var directionRunSequence = 0
    private var directionNilUpdateCount = 0
    private var directionModeStartedAt: Date?

    var isDirectionModeActive: Bool {
        mode == .direction && activeDirectionPeerRawID != nil
    }

    var supportsDirectionMeasurement: Bool {
        if #available(iOS 16.0, *) {
            return NISession.deviceCapabilities.supportsDirectionMeasurement
        }

        return false
    }

    var supportsCameraAssistedDirection: Bool {
        NISession.deviceCapabilities.supportsCameraAssistance
    }

    var canEnterDirectionMode: Bool {
        supportsCameraAssistedDirection &&
            (peerDiscoveryToken != nil || !peerDiscoveryTokensByRawID.isEmpty)
    }

    func canEnterDirectionMode(for peer: PeerID?) -> Bool {
        guard supportsCameraAssistedDirection else { return false }
        guard let peer else { return canEnterDirectionMode }
        return sessionsByPeerRawID[peer.rawID] != nil &&
            peerDiscoveryTokensByRawID[peer.rawID] != nil
    }

    /// 초기화 함수
    override init() {
        super.init()
    }

    /// NI 세션을 시작 준비하는 함수
    /// NISession만 생성한다(거리 전용 준비 상태). 방향 모드 진입 시 camera assistance만 켠다.
    func startSession() {
        startSession(for: nil)
    }

    /// 특정 peer와의 NI 세션을 준비한다.
    /// 다자 연결에서는 peer마다 별도 NISession/DiscoveryToken을 유지한다.
    func startSession(for peer: PeerID?) {
        #if DEBUG
            let caps = NISession.deviceCapabilities
            print("[NIDiag] supportsPreciseDistance=\(caps.supportsPreciseDistanceMeasurement)")
            print("[NIDiag] supportsCameraAssistance=\(caps.supportsCameraAssistance)")
            if #available(iOS 16.0, *) {
                print("[NIDiag] supportsDirectionMeasurement=\(caps.supportsDirectionMeasurement)")
            }
            if #available(iOS 17.4, *) {
                print("[NIDiag] supportsExtendedDistance=\(caps.supportsExtendedDistanceMeasurement)")
            }
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            print(
                "[NIDiag] cameraAuthStatus=\(cameraStatus.rawValue) (0=notDetermined 1=restricted 2=denied 3=authorized)"
            )
            print("[NIDiag] deviceModel=\(UIDevice.current.model) systemVersion=\(UIDevice.current.systemVersion)")

            var sysInfo = utsname()
            uname(&sysInfo)
            let modelCode = withUnsafePointer(to: &sysInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) { ptr in String(cString: ptr) }
            }
            print("[NIDiag] modelIdentifier=\(modelCode)")
        #endif

        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            state = .unsupported
            return
        }

        if let peer {
            if let existingSession = sessionsByPeerRawID[peer.rawID] {
                existingSession.delegate = nil
                existingSession.pause()
                existingSession.invalidate()
                peerRawIDBySessionID.removeValue(forKey: ObjectIdentifier(existingSession))
            }

            peerDiscoveryTokensByRawID.removeValue(forKey: peer.rawID)
            peersByRawID[peer.rawID] = peer
            if activeDirectionPeerRawID == peer.rawID {
                activeDirectionPeerRawID = nil
                mode = .distance
            }
        } else if let session {
            session.delegate = nil
            session.pause()
            session.invalidate()
        }

        // 기본은 거리 전용 → camera assistance는 켜지 않는다(카메라와 경합 방지).
        if activeDirectionPeerRawID == nil {
            mode = .distance
        }

        let newSession = NISession()
        newSession.delegate = self

        if let peer {
            sessionsByPeerRawID[peer.rawID] = newSession
            peerRawIDBySessionID[ObjectIdentifier(newSession)] = peer.rawID
        } else {
            session = newSession
            peerDiscoveryToken = nil
            sharedTokenWithPeer = false
        }
        lastUpdateDebugLogAt = nil
        lastDirectionSampleDebugLogAt = nil
        didLogFirstDirectionSampleInCurrentRun = false
        state = .ready
        #if DEBUG
            print("[NIDiag] startSession peer=\(peer?.displayName ?? "legacy") (distance-only, no ARSession)")
        #endif
    }

    /// 상대에게 전송할 내 NI DiscoveryToken 반환 (가져오기)
    func getMyDiscoveryToken() -> NIDiscoveryToken? {
        session?.discoveryToken
    }

    /// 특정 peer에게 전송할 내 NI DiscoveryToken 반환.
    func getMyDiscoveryToken(for peer: PeerID) -> NIDiscoveryToken? {
        sessionsByPeerRawID[peer.rawID]?.discoveryToken
    }

    /// NI Session 실행 함수 (기본: 거리 전용 모드)
    /// 상대 기기의 DiscoveryToken 으로 거리 측정을 시작합니다.
    func run(with peerToken: NIDiscoveryToken) {
        guard let session else {
            state = .failed(.missingSession)
            return
        }

        peerDiscoveryToken = peerToken
        mode = .distance
        directionNilUpdateCount = 0
        directionModeStartedAt = nil
        lastDirectionSampleDebugLogAt = nil
        didLogFirstDirectionSampleInCurrentRun = false
        session.run(distanceConfiguration(peerToken: peerToken))
        sharedTokenWithPeer = true
        debugLog(
            "run (distance mode) " +
                "localCaps={\(localCapabilitySummary)} " +
                "peerCaps={\(peerCapabilitySummary(peerToken))}"
        )
    }

    /// 특정 peer의 token으로 거리 측정을 시작한다.
    func run(with peerToken: NIDiscoveryToken, peer: PeerID) {
        if sessionsByPeerRawID[peer.rawID] == nil {
            startSession(for: peer)
        }

        guard let session = sessionsByPeerRawID[peer.rawID] else {
            state = .failed(.missingSession)
            return
        }

        peersByRawID[peer.rawID] = peer
        peerDiscoveryTokensByRawID[peer.rawID] = peerToken
        if activeDirectionPeerRawID == nil {
            mode = .distance
        }
        directionNilUpdateCount = 0
        directionModeStartedAt = nil
        lastDirectionSampleDebugLogAt = nil
        didLogFirstDirectionSampleInCurrentRun = false
        session.run(distanceConfiguration(peerToken: peerToken))
        sharedTokenWithPeer = true
        state = .running
        debugLog(
            "run (distance mode) peer=\(peerSummary(peer)) " +
                "trackedPeers=\(peerDiscoveryTokensByRawID.count) " +
                "localCaps={\(localCapabilitySummary)} " +
                "peerCaps={\(peerCapabilitySummary(peerToken))}"
        )
    }

    @discardableResult
    func resumeSessionIfPossible() -> Bool {
        if !peerDiscoveryTokensByRawID.isEmpty {
            var didResume = false
            for (rawID, token) in peerDiscoveryTokensByRawID {
                guard let session = sessionsByPeerRawID[rawID] else { continue }
                let configuration = configuration(for: rawID, peerToken: token)
                session.run(configuration)
                didResume = true
            }

            debugLog("resumeSessionIfPossible rerun requested peers=\(peerDiscoveryTokensByRawID.count)")
            return didResume
        }

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

    // =====================================================================
    // MARK: - 방향 모드 토글 (힌트 사용 시)

    // =====================================================================

    /// 방향 모드로 전환한다.
    /// - Important: **카메라 세션이 닫힌 상태에서** 호출해야 한다(자원 경합 → -5883 회피).
    ///   별도 ARSession을 주입하지 않고 NI가 자동으로 호환 ARSession을 만들게 둔다.
    @discardableResult
    func enableDirectionMode(for peer: PeerID? = nil) async -> Bool {
        if let peer {
            return await enableDirectionMode(forPeerRawID: peer.rawID)
        }

        if let rawID = activeDirectionPeerRawID ?? lastReadingPeerRawID ?? peerDiscoveryTokensByRawID.keys.sorted().first {
            return await enableDirectionMode(forPeerRawID: rawID)
        }

        guard let session, let peerToken = peerDiscoveryToken else {
            debugLog("enableDirectionMode skipped: session/peerToken nil")
            return false
        }

        guard supportsCameraAssistedDirection else {
            debugLog("enableDirectionMode skipped: camera assistance unsupported")
            return false
        }

        mode = .direction
        directionRunSequence += 1
        directionNilUpdateCount = 0
        directionModeStartedAt = Date()
        lastDirectionSampleDebugLogAt = nil
        didLogFirstDirectionSampleInCurrentRun = false
        let directionConfig = NINearbyPeerConfiguration(peerToken: peerToken)
        directionConfig.isCameraAssistanceEnabled = true
        session.run(directionConfig)
        debugLog(
            "enableDirectionMode run directionRun=\(directionRunSequence) " +
                "cameraAssist=\(directionConfig.isCameraAssistanceEnabled) autoARSession=true " +
                "stateBeforeRun=\(state) localCaps={\(localCapabilitySummary)} " +
                "peerCaps={\(peerCapabilitySummary(peerToken))}"
        )
        return true
    }

    @discardableResult
    private func enableDirectionMode(forPeerRawID rawID: String) async -> Bool {
        guard let session = sessionsByPeerRawID[rawID],
              let peerToken = peerDiscoveryTokensByRawID[rawID]
        else {
            debugLog("enableDirectionMode skipped: session/peerToken nil peer=\(shortRawID(rawID))")
            return false
        }

        guard supportsCameraAssistedDirection else {
            debugLog("enableDirectionMode skipped: camera assistance unsupported peer=\(shortRawID(rawID))")
            return false
        }

        if let previousRawID = activeDirectionPeerRawID,
           previousRawID != rawID,
           let previousSession = sessionsByPeerRawID[previousRawID],
           let previousToken = peerDiscoveryTokensByRawID[previousRawID]
        {
            previousSession.pause()
            previousSession.run(distanceConfiguration(peerToken: previousToken))
        }

        activeDirectionPeerRawID = rawID
        mode = .direction
        directionRunSequence += 1
        directionNilUpdateCount = 0
        directionModeStartedAt = Date()
        lastDirectionSampleDebugLogAt = nil
        didLogFirstDirectionSampleInCurrentRun = false
        let directionConfig = NINearbyPeerConfiguration(peerToken: peerToken)
        directionConfig.isCameraAssistanceEnabled = true
        session.run(directionConfig)
        debugLog(
            "enableDirectionMode run directionRun=\(directionRunSequence) " +
                "peer=\(peerSummary(peersByRawID[rawID])) " +
                "cameraAssist=\(directionConfig.isCameraAssistanceEnabled) autoARSession=true " +
                "stateBeforeRun=\(state) localCaps={\(localCapabilitySummary)} " +
                "peerCaps={\(peerCapabilitySummary(peerToken))}"
        )
        return true
    }

    /// 방향 모드 종료 → 거리 전용으로 복귀하고 ARSession을 내린다.
    /// (NISession/토큰은 그대로라 재핸드셰이크 불필요)
    func disableDirectionMode() {
        if let rawID = activeDirectionPeerRawID {
            guard let session = sessionsByPeerRawID[rawID],
                  let peerToken = peerDiscoveryTokensByRawID[rawID]
            else {
                activeDirectionPeerRawID = nil
                mode = .distance
                return
            }

            session.pause()
            activeDirectionPeerRawID = nil
            mode = .distance
            directionNilUpdateCount = 0
            directionModeStartedAt = nil
            lastDirectionSampleDebugLogAt = nil
            didLogFirstDirectionSampleInCurrentRun = false
            session.run(distanceConfiguration(peerToken: peerToken))
            debugLog("disableDirectionMode -> distance peer=\(shortRawID(rawID)) pausedBeforeRun=true")
            return
        }

        guard let session, let peerToken = peerDiscoveryToken else {
            mode = .distance
            return
        }

        let wasDirectionMode = mode == .direction
        if wasDirectionMode {
            session.pause()
        }
        mode = .distance
        directionNilUpdateCount = 0
        directionModeStartedAt = nil
        lastDirectionSampleDebugLogAt = nil
        didLogFirstDirectionSampleInCurrentRun = false
        session.run(distanceConfiguration(peerToken: peerToken))
        debugLog("disableDirectionMode -> distance pausedBeforeRun=\(wasDirectionMode)")
    }

    /// 세션  종료  함수
    /// NI 측정을 종료하고 세션 및 상대 토큰을 초기화 합니다.
    /// 게임 종료 또는 상대방 이탈시 자동 처리(호출) 됩니다.
    func invalidateSession() {
        session?.delegate = nil
        session?.pause()
        session?.invalidate()
        for session in sessionsByPeerRawID.values {
            session.delegate = nil
            session.pause()
            session.invalidate()
        }
        session = nil
        sessionsByPeerRawID.removeAll()
        peerRawIDBySessionID.removeAll()
        peersByRawID.removeAll()
        peerDiscoveryTokensByRawID.removeAll()
        activeDirectionPeerRawID = nil
        lastReadingPeerRawID = nil
        peerDiscoveryToken = nil
        sharedTokenWithPeer = false
        mode = .distance
        lastUpdateDebugLogAt = nil
        lastConvergenceDebugLogAt = nil
        lastDirectionSampleDebugLogAt = nil
        didLogFirstDirectionSampleInCurrentRun = false
        directionNilUpdateCount = 0
        directionModeStartedAt = nil
        state = .invalidated
    }

    deinit {
        session?.delegate = nil
        session?.pause()
        session?.invalidate()
        for session in sessionsByPeerRawID.values {
            session.delegate = nil
            session.pause()
            session.invalidate()
        }
    }

    /// 현재 모드에 맞는 NI 설정.
    private func currentConfiguration(peerToken: NIDiscoveryToken) -> NINearbyPeerConfiguration {
        switch mode {
        case .distance:
            return distanceConfiguration(peerToken: peerToken)
        case .direction:
            let configuration = NINearbyPeerConfiguration(peerToken: peerToken)
            configuration.isCameraAssistanceEnabled = true
            return configuration
        }
    }

    private func distanceConfiguration(peerToken: NIDiscoveryToken) -> NINearbyPeerConfiguration {
        let configuration = NINearbyPeerConfiguration(peerToken: peerToken)
        configuration.isCameraAssistanceEnabled = false
        return configuration
    }

    private func configuration(for rawID: String, peerToken: NIDiscoveryToken) -> NINearbyPeerConfiguration {
        if mode == .direction, activeDirectionPeerRawID == rawID {
            let configuration = NINearbyPeerConfiguration(peerToken: peerToken)
            configuration.isCameraAssistanceEnabled = true
            return configuration
        }

        return distanceConfiguration(peerToken: peerToken)
    }

    private func peerRawID(for session: NISession) -> String? {
        peerRawIDBySessionID[ObjectIdentifier(session)]
    }
}

/// NI가 주변 기기 정보를 업데이트 했을 때 자동으로 호출되는 함수
/// 직접 호출하지 않습니다.
extension NearbyInteractionManager: NISessionDelegate {
    /// 시스템  호출  콜백
    func sessionDidStartRunning(_ session: NISession) {
        state = .running
        debugLog("sessionDidStartRunning")
    }

    /// 거리, 방향 값 들어왔을 때 업데이트 과정
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        let peerRawID = peerRawID(for: session)
        let matchedPeerToken = peerRawID.flatMap { peerDiscoveryTokensByRawID[$0] } ?? peerDiscoveryToken

        guard let matchedPeerToken else {
            debugLog("didUpdate ignored: peerDiscoveryToken=nil objects=\(nearbyObjects.count)")
            return
        }

        guard let nearbyObject = nearbyObjects.first(where: {
            $0.discoveryToken == matchedPeerToken
        }) else {
            debugLog(
                "didUpdate ignored: no matching peer objects=\(nearbyObjects.count) " +
                    "peer=\(peerRawID.map(shortRawID) ?? "legacy")"
            )
            return
        }

        if let peerRawID {
            lastReadingPeerRawID = peerRawID
        }

        let reading = NearbyInteractionReading(
            peer: peerRawID.flatMap { peersByRawID[$0] },
            distance: nearbyObject.distance,
            direction: nearbyObject.direction,
            timestamp: Date(),
            horizontalAngle: nearbyObject.horizontalAngle
        )

        recordDirectionUpdateDiagnostics(reading)
        if shouldLogUpdate(for: reading) {
            debugLog(
                "didUpdate matched distance=\(format(distance: reading.distance)) " +
                    "peer=\(peerSummary(reading.peer)) " +
                    "horizontalAngle=\(format(angle: reading.horizontalAngle)) " +
                    "direction=\(format(direction: reading.direction)) mode=\(mode) " +
                    "directionRun=\(directionRunSequence) nilStreak=\(directionNilUpdateCount) " +
                    "elapsed=\(format(seconds: directionModeElapsed))"
            )
        }
        onReadingUpdated?(reading)
    }

    /// 세션이 추적하던 nearbyObject를 더이상 추적하지 못하게 되었을 때
    func session(
        _ session: NISession,
        didRemove nearbyObjects: [NINearbyObject],
        reason: NINearbyObject.RemovalReason
    ) {
        let peerRawID = peerRawID(for: session)
        switch reason {
        case .peerEnded:
            state = .peerEnded
            debugLog(
                "didRemove peerEnded objects=\(nearbyObjects.count) " +
                    "peer=\(peerRawID.map(shortRawID) ?? "legacy")"
            )

        case .timeout:
            state = .peerLost
            if let peerRawID {
                sessionsByPeerRawID.removeValue(forKey: peerRawID)
                peerDiscoveryTokensByRawID.removeValue(forKey: peerRawID)
                peersByRawID.removeValue(forKey: peerRawID)
                peerRawIDBySessionID.removeValue(forKey: ObjectIdentifier(session))
                if activeDirectionPeerRawID == peerRawID {
                    activeDirectionPeerRawID = nil
                    mode = .distance
                }
            } else {
                self.session = nil
                peerDiscoveryToken = nil
            }
            sharedTokenWithPeer = peerDiscoveryToken != nil || !peerDiscoveryTokensByRawID.isEmpty
            directionNilUpdateCount = 0
            directionModeStartedAt = nil
            onSessionRestartRequired?()

        default:
            state = .failed(.peerRemoved(reason))
            debugLog(
                "didRemove failed reason=\(reason) objects=\(nearbyObjects.count) " +
                    "peer=\(peerRawID.map(shortRawID) ?? "legacy")"
            )
        }
    }

    /// 세션이 일시중단 되었을 때
    func sessionWasSuspended(_ session: NISession) {
        state = .suspended
        let peerRawID = peerRawID(for: session)
        debugLog(
            "sessionWasSuspended mode=\(mode) " +
                "peer=\(peerRawID.map(shortRawID) ?? "legacy") " +
                "cameraAssist=\(formatCameraAssistanceEnabled(session.configuration)) " +
                "directionRun=\(directionRunSequence)"
        )
    }

    /// 세션 중단이 종료되었을 때 (= 재실행 가능 상태, 세션 재호출)
    func sessionSuspensionEnded(_ session: NISession) {
        if let peerRawID = peerRawID(for: session) {
            guard let peerDiscoveryToken = peerDiscoveryTokensByRawID[peerRawID] else {
                state = .ready
                debugLog("sessionSuspensionEnded without peer token peer=\(shortRawID(peerRawID))")
                return
            }

            let configuration = configuration(for: peerRawID, peerToken: peerDiscoveryToken)
            session.run(configuration)
            debugLog(
                "sessionSuspensionEnded rerun mode=\(mode) " +
                    "peer=\(shortRawID(peerRawID)) " +
                    "cameraAssist=\(formatCameraAssistanceEnabled(configuration)) " +
                    "directionRun=\(directionRunSequence)"
            )
            return
        }

        guard let peerDiscoveryToken else {
            state = .ready
            debugLog("sessionSuspensionEnded without peer token")
            return
        }

        let configuration = currentConfiguration(peerToken: peerDiscoveryToken)
        session.run(configuration)
        debugLog(
            "sessionSuspensionEnded rerun mode=\(mode) " +
                "cameraAssist=\(formatCameraAssistanceEnabled(configuration)) " +
                "directionRun=\(directionRunSequence)"
        )
    }

    /// 세션이 에러와 함께 완전 종료되었을 때
    func session(_ session: NISession, didInvalidateWith error: Error) {
        let invalidatedPeerRawID = peerRawID(for: session)

        if let peerRawID = invalidatedPeerRawID {
            sessionsByPeerRawID.removeValue(forKey: peerRawID)
            peerDiscoveryTokensByRawID.removeValue(forKey: peerRawID)
            peersByRawID.removeValue(forKey: peerRawID)
            peerRawIDBySessionID.removeValue(forKey: ObjectIdentifier(session))
            if activeDirectionPeerRawID == peerRawID {
                activeDirectionPeerRawID = nil
                mode = .distance
            }
        } else {
            self.session = nil
            peerDiscoveryToken = nil
        }
        sharedTokenWithPeer = peerDiscoveryToken != nil || !peerDiscoveryTokensByRawID.isEmpty
        if activeDirectionPeerRawID == nil {
            mode = .distance
        }
        lastUpdateDebugLogAt = nil
        lastConvergenceDebugLogAt = nil
        lastDirectionSampleDebugLogAt = nil
        didLogFirstDirectionSampleInCurrentRun = false
        directionNilUpdateCount = 0
        directionModeStartedAt = nil
        state = .failed(.sessionInvalidated(error))
        debugLog(
            "didInvalidateWith error=\(error) " +
                "peer=\(invalidatedPeerRawID.map(shortRawID) ?? "legacy")"
        )
        onSessionRestartRequired?()
    }

    func session(
        _ session: NISession,
        didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence,
        for object: NINearbyObject?
    ) {
        guard shouldLogConvergenceUpdate(for: convergence) else { return }

        let peerRawID = peerRawID(for: session)
        let matchedPeerToken = peerRawID.flatMap { peerDiscoveryTokensByRawID[$0] } ?? peerDiscoveryToken
        let isPeerObject = object?.discoveryToken == matchedPeerToken
        debugLog(
            "didUpdateAlgorithmConvergence status=\(format(convergence.status)) " +
                "object=\(object == nil ? "session" : "nearbyObject") " +
                "isPeerObject=\(isPeerObject) peer=\(peerRawID.map(shortRawID) ?? "legacy") mode=\(mode) " +
                "directionRun=\(directionRunSequence) elapsed=\(format(seconds: directionModeElapsed))"
        )
    }

    private func debugLog(_ message: String) {
        #if DEBUG
            print("[NearbyInteractionManager] \(message) state=\(state)")
        #endif
    }

    private func shouldLogUpdate(for reading: NearbyInteractionReading) -> Bool {
        if mode == .direction,
           reading.horizontalAngle != nil || reading.direction != nil
        {
            guard didLogFirstDirectionSampleInCurrentRun else {
                didLogFirstDirectionSampleInCurrentRun = true
                lastDirectionSampleDebugLogAt = reading.timestamp
                lastUpdateDebugLogAt = reading.timestamp
                return true
            }

            guard let lastDirectionSampleDebugLogAt,
                  reading.timestamp.timeIntervalSince(lastDirectionSampleDebugLogAt) < 1
            else {
                self.lastDirectionSampleDebugLogAt = reading.timestamp
                lastUpdateDebugLogAt = reading.timestamp
                return true
            }

            return false
        }

        guard let lastUpdateDebugLogAt else {
            self.lastUpdateDebugLogAt = reading.timestamp
            return true
        }

        guard reading.timestamp.timeIntervalSince(lastUpdateDebugLogAt) >= 1 else {
            return false
        }

        self.lastUpdateDebugLogAt = reading.timestamp
        return true
    }

    private func shouldLogConvergenceUpdate(for convergence: NIAlgorithmConvergence) -> Bool {
        if case .notConverged = convergence.status {
            let now = Date()
            guard let lastConvergenceDebugLogAt else {
                self.lastConvergenceDebugLogAt = now
                return true
            }

            guard now.timeIntervalSince(lastConvergenceDebugLogAt) >= 1 else {
                return false
            }

            self.lastConvergenceDebugLogAt = now
            return true
        }

        lastConvergenceDebugLogAt = Date()
        return true
    }

    private func recordDirectionUpdateDiagnostics(_ reading: NearbyInteractionReading) {
        guard mode == .direction else { return }
        guard reading.peer?.rawID == activeDirectionPeerRawID else { return }

        if reading.horizontalAngle == nil, reading.direction == nil {
            directionNilUpdateCount += 1
        } else {
            directionNilUpdateCount = 0
        }
    }

    private var directionModeElapsed: TimeInterval? {
        guard let directionModeStartedAt else { return nil }
        return Date().timeIntervalSince(directionModeStartedAt)
    }

    private var localCapabilitySummary: String {
        let caps = NISession.deviceCapabilities
        var values = [
            "precise=\(caps.supportsPreciseDistanceMeasurement)",
            "cameraAssist=\(caps.supportsCameraAssistance)"
        ]

        if #available(iOS 16.0, *) {
            values.append("direction=\(caps.supportsDirectionMeasurement)")
        }

        if #available(iOS 17.4, *) {
            values.append("extended=\(caps.supportsExtendedDistanceMeasurement)")
        }

        return values.joined(separator: " ")
    }

    private func peerCapabilitySummary(_ peerToken: NIDiscoveryToken) -> String {
        guard #available(iOS 17.0, *) else {
            return "unavailable-before-iOS17"
        }

        let caps = peerToken.deviceCapabilities
        var values = [
            "precise=\(caps.supportsPreciseDistanceMeasurement)",
            "cameraAssist=\(caps.supportsCameraAssistance)",
            "direction=\(caps.supportsDirectionMeasurement)"
        ]

        if #available(iOS 17.4, *) {
            values.append("extended=\(caps.supportsExtendedDistanceMeasurement)")
        }

        return values.joined(separator: " ")
    }

    private func format(_ status: NIAlgorithmConvergenceStatus) -> String {
        switch status {
        case .unknown:
            return "unknown"
        case .converged:
            return "converged"
        case let .notConverged(reasons):
            let reasonSummary = reasons
                .map { reason in
                    let description = reason.localizedDescription ?? "no localized description"
                    return "\(reason.rawValue)(\(description))"
                }
                .joined(separator: ", ")
            return "notConverged reasons=[\(reasonSummary)]"
        @unknown default:
            return "unknown-default"
        }
    }

    private func formatCameraAssistanceEnabled(_ configuration: NIConfiguration?) -> String {
        guard let configuration else { return "nil" }

        if let peerConfiguration = configuration as? NINearbyPeerConfiguration {
            return "\(peerConfiguration.isCameraAssistanceEnabled)"
        }

        if let accessoryConfiguration = configuration as? NINearbyAccessoryConfiguration {
            return "\(accessoryConfiguration.isCameraAssistanceEnabled)"
        }

        return "unsupportedConfiguration"
    }

    private func format(distance: Float?) -> String {
        guard let distance else { return "nil" }
        return String(format: "%.2fm", distance)
    }

    private func format(seconds: TimeInterval?) -> String {
        guard let seconds else { return "nil" }
        return String(format: "%.2fs", seconds)
    }

    private func format(angle: Float?) -> String {
        guard let angle else { return "nil" }
        return String(format: "%.3frad", angle)
    }

    private func format(direction: SIMD3<Float>?) -> String {
        guard let direction else { return "nil" }
        return String(
            format: "(x: %.3f, y: %.3f, z: %.3f)",
            direction.x,
            direction.y,
            direction.z
        )
    }

    private func peerSummary(_ peer: PeerID?) -> String {
        guard let peer else { return "legacy" }
        return "\(peer.displayName)(\(shortRawID(peer.rawID)))"
    }

    private func shortRawID(_ rawID: String) -> String {
        String(rawID.prefix(8))
    }
}
