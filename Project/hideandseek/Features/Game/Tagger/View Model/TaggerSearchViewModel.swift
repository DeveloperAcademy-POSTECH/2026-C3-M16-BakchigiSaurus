//
//  TaggerSearchViewModel.swift
//  hideandseek
//
//  Created by 캄초 on 6/8/26.
//

import Foundation
import Observation
import SwiftUI

enum HintDisplayResult: Hashable, Identifiable {
    case success(angleRadians: Double?)
    case failure

    var id: Self {
        self
    }

    var isSuccess: Bool {
        if case .success = self {
            return true
        }

        return false
    }

    var angleRadians: Double? {
        if case let .success(angleRadians) = self {
            return angleRadians
        }

        return nil
    }
}

@Observable
@MainActor
final class TaggerSearchViewModel {
    let gameModel: GameModel
    private let mcSession: MultipeerGameSession
    private let niManager: NearbyInteractionManager

    var isHintActive: Bool = false
    var latestObservedDistance: Float?
    var latestObservedDirection: DirectionVector?
    var latestObservedHorizontalAngle: Float?
    var latestObservedAt: Date?
    var localTaggerConfirmationSentAt: Date?
    var didReceiveLocalReading: Bool = false
    var isHiderWithinWarningRadius: Bool = false

    private var hintDisplayTask: Task<Void, Never>?
    private var proximityConfirmationTask: Task<Void, Never>?
    private var proximityStalenessTask: Task<Void, Never>?
    private var trackingTargetID: PlayerID?
    private var localEnteredWarningRadiusAt: Date?
    private var isProximityTrackingActive = false
    @ObservationIgnored private var lastProximityReadingLogAt: Date?
    @ObservationIgnored private var lastLoggedWithinWarningRadius: Bool?
    @ObservationIgnored private var isHintDirectionModeActive = false
    @ObservationIgnored private var lastHintAngleDebugLogAt: Date?
    @ObservationIgnored private var lastStalenessScheduleDebugLogAt: Date?
    private var cachedHintHorizontalAngle: Float?
    private var cachedHintAngleObservedAt: Date?

    private let warningRadiusMeters: Float = 5
    private let requiredProximityDuration: TimeInterval = 5
    private let readingStaleGraceDuration: TimeInterval = 3
    private let hintDisplayDuration: TimeInterval = 7
    private let hintDirectionConvergenceTimeout: TimeInterval = 8
    private let cameraToDirectionHandoffDelayNanos: UInt64 = 150_000_000
    private let directionToCameraHandoffDelayNanos: UInt64 = 250_000_000

    private var readingStaleDuration: TimeInterval {
        requiredProximityDuration + readingStaleGraceDuration
    }

    init(gameModel: GameModel, mcSession: MultipeerGameSession, niManager: NearbyInteractionManager) {
        self.gameModel = gameModel
        self.mcSession = mcSession
        self.niManager = niManager

    }

    var hintCountRemaining: Int {
        gameModel.sharedState.hintCountRemaining
    }

    var canUseHint: Bool {
        gameModel.sharedState.canUseHint(by: gameModel.localPlayerID)
    }

    var supportsDirectionalHint: Bool {
        niManager.supportsCameraAssistedDirection
    }

    var nearestHiderDistance: Float? {
        currentObservedDistance
    }

    var nearestHiderDirection: DirectionVector? {
        if let live = currentObservedDirection {
            return live
        }

        if isHintActive, let hintedDirection = gameModel.sharedState.lastHint?.direction {
            return hintedDirection
        }

        return nil
    }

    var currentHintAngleRadians: Double? {
        let latestAngle = latestObservedHorizontalAngle.map(Double.init)
        let cachedAngle = cachedHintHorizontalAngle.map(Double.init)
        let fallbackAngle = gameModel.sharedState.lastHint?.horizontalAngle.map(Double.init)
        return latestAngle ?? cachedAngle ?? fallbackAngle
    }

    /// 다이내믹 아일랜드(=촬영 가능) 상태. 5m 이내 5초 머물러 확정된 경우.
    var isIslandExpanded: Bool {
        guard gameModel.sharedState.phase == .playing, gameModel.isLocalTagger else { return false }
        return isHiderWithinWarningRadius && localTaggerConfirmationSentAt != nil
    }

    /// 술래 촬영 가능 여부. (아일랜드 확장 상태에서만)
    var canCapturePhoto: Bool {
        isIslandExpanded
    }

    private var currentObservedDistance: Float? {
        didReceiveLocalReading ? latestObservedDistance : nearestHiderProximity?.lastDistance
    }

    private var currentObservedDirection: DirectionVector? {
        didReceiveLocalReading ? latestObservedDirection : nearestHiderProximity?.lastDirection
    }

    var nearestHiderProximity: ProximityState? {
        gameModel.sharedState.proximityByHiderID.values
            .filter { $0.lastDistance != nil }
            .min { lhs, rhs in
                (lhs.lastDistance ?? .greatestFiniteMagnitude) < (rhs.lastDistance ?? .greatestFiniteMagnitude)
            }
    }

    var activeHiderIDs: [PlayerID] {
        gameModel.participants.compactMap { participant in
            guard participant.id != gameModel.localPlayerID,
                  participant.role != .tagger,
                  participant.status != .captured
            else {
                return nil
            }
            return participant.id
        }
    }

    private func setupNearbyInteractionCallbacks() {
        self.niManager.onReadingUpdated = { [weak self] (reading: NearbyInteractionReading) in
            guard let self else { return }

            let convertedDirection: DirectionVector? = {
                if let simdDir = reading.direction {
                    return DirectionVector(simdDir)
                }
                return nil
            }()

            Task { @MainActor in
                let shouldLogReading = self.shouldLogProximityReading(at: reading.timestamp)
                if shouldLogReading {
                }

                guard self.canTrackLocalProximity else {
                    self.resetProximityTracking(reason: "cannot track local proximity")
                    return
                }

                guard let hiderID = self.observedHiderID(for: reading.peer) else {
                    self.resetProximityTracking(reason: "no active hider")
                    return
                }

                guard self.shouldUseReading(for: hiderID, distance: reading.distance) else {
                    if shouldLogReading {
                    }
                    return
                }

                if shouldLogReading {
                }

                self.recordLocalProximity(
                    distance: reading.distance,
                    direction: convertedDirection,
                    horizontalAngle: reading.horizontalAngle,
                    observedAt: reading.timestamp
                )

                let events = await self.gameModel.send(.observeProximity(
                    hiderID: hiderID,
                    distance: reading.distance,
                    direction: convertedDirection,
                    observedAt: reading.timestamp
                ))
                self.broadcastCaptureRequests(from: events)
                if shouldLogReading {
                }
            }
        }
    }

    /// 힌트 시작: 카메라 세션을 닫고 NI를 방향 모드로 전환한 뒤 힌트 결과를 계산한다.
    /// 카메라 복구는 힌트 화면이 사라질 때 ``endHintDirectionMode(camera:)``로 한다.
    /// - Returns: nil이면 힌트 사용 불가(카메라/NI 변경 없음). non-nil이면 결과 표시 후 반드시
    ///   ``endHintDirectionMode(camera:)``를 호출해 거리 모드 + 카메라를 복구해야 한다.
    /// - Parameter camera: 게임 루트에서 공유 중인 카메라 모델.
    func beginHintWithDirection(camera: CameraModel) async -> HintDisplayResult? {

        guard canUseHint else {
            return nil
        }

        let directionPeer = trackingTargetID.flatMap(peerForHiderID)
        guard niManager.canEnterDirectionMode(for: directionPeer) else {
            return .failure
        }

        resetHintDirectionSample()
        guard supportsDirectionalHint else {
            return await tapHintButton()
        }

        isHintDirectionModeActive = false

        // 카메라를 닫아 자원을 양보하고 NI 방향 모드로 전환.
        await camera.closeSession()
        try? await Task.sleep(nanoseconds: cameraToDirectionHandoffDelayNanos)

        let didEnableDirectionMode = await niManager.enableDirectionMode(for: directionPeer)
        guard didEnableDirectionMode else {
            await camera.openSession()
            return nil
        }

        isHintDirectionModeActive = true
        guard niManager.isDirectionModeActive else {
            isHintDirectionModeActive = false
            await camera.openSession()
            return nil
        }

        let firstAngle = await waitForFirstHorizontalAngle(timeout: hintDirectionConvergenceTimeout)
        if let firstAngle {
        } else {
        }

        // 힌트 결과 계산(기존 로직). isHintActive 및 표시 타이머는 tapHintButton이 관리.
        let result = await tapHintButton()
        if result == nil {
            isHintDirectionModeActive = false
            niManager.disableDirectionMode()
            resetHintDirectionSample()
            try? await Task.sleep(nanoseconds: directionToCameraHandoffDelayNanos)
            await camera.openSession()
        }
        return result
    }

    /// 힌트 종료: NI를 거리 모드로 되돌리고 카메라 세션을 다시 연다.
    /// 힌트 화면의 onFinished(또는 화면 이탈) 시점에 호출한다.
    func endHintDirectionMode(camera: CameraModel) async {
        let wasDirectionModeActive = isHintDirectionModeActive
        isHintDirectionModeActive = false
        niManager.disableDirectionMode()
        resetHintDirectionSample()
        try? await Task.sleep(nanoseconds: directionToCameraHandoffDelayNanos)
        await camera.openSession()
    }

    private func waitForFirstHorizontalAngle(timeout: TimeInterval) async -> Float? {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let angle = latestObservedHorizontalAngle ?? cachedHintHorizontalAngle {
                return angle
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return nil
    }

    func tapHintButton() async -> HintDisplayResult? {

        guard canUseHint else {
            return nil
        }

        let candidates: [HintCandidate] = gameModel.participants
            .filter { $0.role == .hider && $0.status != .captured }
            .compactMap { participant in
                let proximity = gameModel.sharedState.proximityByHiderID[participant.id]
                let distance = currentDistance(for: participant.id, proximity: proximity)
                guard let distance, distance <= 5 else {
                    return nil
                }

                let horizontalAngle = currentHorizontalAngle(for: participant.id)
                let direction = currentDirection(for: participant.id, proximity: proximity)

                return HintCandidate(
                    hiderID: participant.id,
                    direction: direction,
                    horizontalAngle: horizontalAngle,
                    distance: distance
                )
            }


        let events = await gameModel.send(.useHint(candidates: candidates))
        guard let resolution = hintResolution(from: events) else {
            return .failure
        }


        hintDisplayTask?.cancel()
        let result: HintDisplayResult
        if resolution.selectedHiderID == nil {
            result = .failure
        } else {
            let resolvedAngle = resolution.horizontalAngle ?? cachedHintHorizontalAngle
            result = .success(angleRadians: resolvedAngle.map(Double.init))
        }
        isHintActive = result.isSuccess

        guard result.isSuccess else {
            hintDisplayTask = nil
            return result
        }

        hintDisplayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.hintDisplayDuration ?? 7) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.isHintActive = false
                self?.hintDisplayTask = nil
            }
        }

        return result
    }

    func cancelHintDisplay() {
        hintDisplayTask?.cancel()
        hintDisplayTask = nil
        isHintActive = false
        resetHintDirectionSample()
    }

    func activateProximityTracking(reason: String = "manual") {
        guard gameModel.isLocalTagger else {
            return
        }

        setupNearbyInteractionCallbacks()
        isProximityTrackingActive = true
        let didResume = niManager.resumeSessionIfPossible()
    }

    func deactivateProximityTracking(reason: String = "manual") {
        guard isProximityTrackingActive else {
            return
        }

        niManager.onReadingUpdated = nil
        isProximityTrackingActive = false
    }

    func resetProximityTracking(reason: String = "manual") {
        proximityConfirmationTask?.cancel()
        proximityConfirmationTask = nil
        proximityStalenessTask?.cancel()
        proximityStalenessTask = nil
        localEnteredWarningRadiusAt = nil
        localTaggerConfirmationSentAt = nil
        trackingTargetID = nil
        latestObservedDistance = nil
        latestObservedDirection = nil
        latestObservedHorizontalAngle = nil
        latestObservedAt = nil
        resetHintDirectionSample()
        didReceiveLocalReading = false
        isHiderWithinWarningRadius = false
        lastProximityReadingLogAt = nil
        lastLoggedWithinWarningRadius = nil
    }

    private func recordLocalProximity(
        distance: Float?,
        direction: DirectionVector?,
        horizontalAngle: Float?,
        observedAt: Date
    ) {
        didReceiveLocalReading = true
        latestObservedDistance = distance
        latestObservedDirection = direction
        recordHintHorizontalAngle(horizontalAngle, observedAt: observedAt)
        latestObservedAt = observedAt
        scheduleProximityStalenessReset(for: observedAt)

        guard let distance else {
            isHiderWithinWarningRadius = false
            clearLocalProximityConfirmation(reason: "distance nil")
            return
        }

        let isWithinWarningRadius = distance <= warningRadiusMeters
        isHiderWithinWarningRadius = isWithinWarningRadius
        if lastLoggedWithinWarningRadius != isWithinWarningRadius {
            lastLoggedWithinWarningRadius = isWithinWarningRadius
        }

        if isWithinWarningRadius {
            if localEnteredWarningRadiusAt == nil {
                localEnteredWarningRadiusAt = observedAt
                scheduleLocalProximityConfirmation()
            }

            if let enteredAt = localEnteredWarningRadiusAt,
               observedAt.timeIntervalSince(enteredAt) >= requiredProximityDuration,
               localTaggerConfirmationSentAt == nil
            {
                expandDynamicIsland(observedAt: observedAt)
            }
        } else {
            clearLocalProximityConfirmation(reason: "distance greater than warning radius")
        }
    }

    private func scheduleLocalProximityConfirmation() {
        proximityConfirmationTask?.cancel()
        let enteredAt = localEnteredWarningRadiusAt ?? Date()
        let delay = max(0, requiredProximityDuration - Date().timeIntervalSince(enteredAt))


        proximityConfirmationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else {
return
                }

                let now = Date()
                let latestAge = self.latestObservedAt.map { now.timeIntervalSince($0) }

                guard self.canTrackLocalProximity else {
                    return
                }

                guard self.isHiderWithinWarningRadius else {
                    return
                }

                guard self.localEnteredWarningRadiusAt == enteredAt else {
                    return
                }

                guard let latestObservedAt = self.latestObservedAt else {
                    return
                }

                guard let distance = self.latestObservedDistance else {
                    return
                }

                guard distance <= self.warningRadiusMeters else {
                    return
                }

                guard now.timeIntervalSince(latestObservedAt) <= self.readingStaleDuration else {
                    return
                }

                self.expandDynamicIsland(observedAt: Date())
                self.proximityConfirmationTask = nil
            }
        }
    }

    private func scheduleProximityStalenessReset(for observedAt: Date) {
        proximityStalenessTask?.cancel()
        let staleDuration = readingStaleDuration

        if shouldLogStalenessSchedule(at: observedAt) {
        }

        proximityStalenessTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(staleDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else {
return
                }


                guard self.latestObservedAt == observedAt else {
                    return
                }

                self.latestObservedDistance = nil
                self.latestObservedDirection = nil
                self.latestObservedHorizontalAngle = nil
                self.resetHintDirectionSample()
                self.latestObservedAt = nil
                self.isHiderWithinWarningRadius = false
                self.clearLocalProximityConfirmation(reason: "latest reading stale")
            }
        }
    }

    private func expandDynamicIsland(observedAt: Date) {
        localTaggerConfirmationSentAt = observedAt
        logProximityState("expanded")
    }

    private func clearLocalProximityConfirmation(reason: String = "unspecified") {
        proximityConfirmationTask?.cancel()
        proximityConfirmationTask = nil
        localEnteredWarningRadiusAt = nil
        localTaggerConfirmationSentAt = nil
        logProximityState("compact")
    }

    private var canTrackLocalProximity: Bool {
        gameModel.sharedState.phase == .playing && gameModel.isLocalTagger
    }

    private func logProximityState(_ state: String) {
    }

    private func shouldLogProximityReading(at observedAt: Date) -> Bool {
        guard let lastProximityReadingLogAt else {
            self.lastProximityReadingLogAt = observedAt
            return true
        }

        guard observedAt.timeIntervalSince(lastProximityReadingLogAt) >= 1 else {
            return false
        }

        self.lastProximityReadingLogAt = observedAt
        return true
    }

    private func shouldLogStalenessSchedule(at observedAt: Date) -> Bool {
        guard let lastStalenessScheduleDebugLogAt else {
            self.lastStalenessScheduleDebugLogAt = observedAt
            return true
        }

        guard observedAt.timeIntervalSince(lastStalenessScheduleDebugLogAt) >= 1 else {
            return false
        }

        self.lastStalenessScheduleDebugLogAt = observedAt
        return true
    }

    private func shouldLogHintAngleUpdate(at observedAt: Date) -> Bool {
        guard let lastHintAngleDebugLogAt else {
            self.lastHintAngleDebugLogAt = observedAt
            return true
        }

        guard observedAt.timeIntervalSince(lastHintAngleDebugLogAt) >= 1 else {
            return false
        }

        self.lastHintAngleDebugLogAt = observedAt
        return true
    }

    private func recordHintHorizontalAngle(_ horizontalAngle: Float?, observedAt: Date) {
        latestObservedHorizontalAngle = horizontalAngle

        guard let horizontalAngle else {
            guard isHintActive || isHintDirectionModeActive else {
                cachedHintHorizontalAngle = nil
                cachedHintAngleObservedAt = nil
                return
            }

            if cachedHintHorizontalAngle != nil, shouldLogHintAngleUpdate(at: observedAt) {
            }
            return
        }

        guard isHintActive || isHintDirectionModeActive else {
            cachedHintHorizontalAngle = nil
            cachedHintAngleObservedAt = nil
            return
        }

        cachedHintHorizontalAngle = horizontalAngle
        cachedHintAngleObservedAt = observedAt
        if shouldLogHintAngleUpdate(at: observedAt) {
        }
    }

    private func resetHintDirectionSample() {
        latestObservedHorizontalAngle = nil
        latestObservedDirection = nil
        cachedHintHorizontalAngle = nil
        cachedHintAngleObservedAt = nil
        lastHintAngleDebugLogAt = nil
    }

    private var debugStateSummary: String {
        [
            "phase=\(gameModel.sharedState.phase)",
            "isLocalTagger=\(gameModel.isLocalTagger)",
            "distance=\(format(distance: latestObservedDistance))",
            "horizontalAngle=\(format(angle: latestObservedHorizontalAngle))",
            "cachedHintAngle=\(format(angle: cachedHintHorizontalAngle))",
            "cachedHintAt=\(format(date: cachedHintAngleObservedAt))",
            "within5m=\(isHiderWithinWarningRadius)",
            "enteredAt=\(format(date: localEnteredWarningRadiusAt))",
            "latestAt=\(format(date: latestObservedAt))",
            "confirmedAt=\(format(date: localTaggerConfirmationSentAt))",
            "isIslandExpanded=\(isIslandExpanded)",
            "canCapturePhoto=\(canCapturePhoto)"
        ].joined(separator: " ")
    }

    private var activeHiderIDSummary: String {
        let ids = activeHiderIDs.map(shortID)
        return ids.isEmpty ? "[]" : "[\(ids.joined(separator: ","))]"
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
        return String(format: "%.2frad", angle)
    }

    private func format(angleRadians: Double?) -> String {
        guard let angleRadians else { return "nil" }
        return String(format: "%.3frad", angleRadians)
    }

    private func format(direction: DirectionVector?) -> String {
        guard let direction else { return "nil" }
        return String(
            format: "(x: %.3f, y: %.3f, z: %.3f)",
            direction.x,
            direction.y,
            direction.z
        )
    }

    private func format(peer: PeerID?) -> String {
        guard let peer else { return "nil" }
        return "\(peer.displayName)(\(String(peer.rawID.prefix(8))))"
    }

    private func format(candidates: [HintCandidate]) -> String {
        guard !candidates.isEmpty else { return "[]" }

        return candidates
            .map { candidate in
                "hider=\(shortID(candidate.hiderID)) " +
                    "distance=\(format(distance: candidate.distance)) " +
                    "angle=\(format(angle: candidate.horizontalAngle)) " +
                    "direction=\(format(direction: candidate.direction))"
            }
            .joined(separator: " | ")
    }

    private func format(date: Date?) -> String {
        guard let date else { return "nil" }
        return String(format: "%.3f", date.timeIntervalSince1970)
    }

    private func shortID(_ playerID: PlayerID) -> String {
        String(playerID.rawValue.uuidString.prefix(8))
    }

    private func currentDistance(for hiderID: PlayerID, proximity: ProximityState?) -> Float? {
        if hiderID == trackingTargetID, didReceiveLocalReading {
            return latestObservedDistance
        }

        return proximity?.lastDistance
    }

    private func currentDirection(for hiderID: PlayerID, proximity: ProximityState?) -> DirectionVector? {
        if hiderID == trackingTargetID, didReceiveLocalReading {
            return latestObservedDirection
        }

        return proximity?.lastDirection
    }

    private func currentHorizontalAngle(for hiderID: PlayerID) -> Float? {
        guard hiderID == trackingTargetID, didReceiveLocalReading else {
            return nil
        }

        let angle = latestObservedHorizontalAngle ?? cachedHintHorizontalAngle
        return angle
    }

    private func hintResolution(from events: [GameEventEnvelope]) -> HintResolution? {
        events.compactMap { envelope in
            if case let .hintConsumed(resolution) = envelope.event {
                return resolution
            }

            return nil
        }
        .first
    }

    private func broadcastCaptureRequests(from events: [GameEventEnvelope]) {
        for envelope in events {
            guard case let .captureRequested(request) = envelope.event else {
                continue
            }

            guard let hiderPeer = peerForHiderID(request.hiderID) else {
                continue
            }

            mcSession.sendCaptureRequested(hiderPeer: hiderPeer)
        }
    }

    private func peerForHiderID(_ hiderID: PlayerID) -> PeerID? {
        gameModel.participants.first { participant in
            participant.id == hiderID
        }?.peerID
    }

    private func observedHiderID(for peer: PeerID?) -> PlayerID? {
        if let peer {
            return gameModel.participants.first { participant in
                participant.id != gameModel.localPlayerID &&
                    participant.role != .tagger &&
                    participant.status != .captured &&
                    participant.peerID?.rawID == peer.rawID
            }?.id
        }

        return observedHiderID()
    }

    private func shouldUseReading(for hiderID: PlayerID, distance: Float?) -> Bool {
        guard let trackingTargetID, trackingTargetID != hiderID else {
            self.trackingTargetID = hiderID
            return true
        }

        if isHiderWithinWarningRadius || localTaggerConfirmationSentAt != nil {
            return false
        }

        if let distance, distance <= warningRadiusMeters {
            resetProximityTrackingForTargetSwitch(to: hiderID)
            return true
        }

        self.trackingTargetID = hiderID
        return true
    }

    private func resetProximityTrackingForTargetSwitch(to hiderID: PlayerID) {
        proximityConfirmationTask?.cancel()
        proximityConfirmationTask = nil
        proximityStalenessTask?.cancel()
        proximityStalenessTask = nil
        localEnteredWarningRadiusAt = nil
        localTaggerConfirmationSentAt = nil
        latestObservedDistance = nil
        latestObservedDirection = nil
        latestObservedHorizontalAngle = nil
        latestObservedAt = nil
        resetHintDirectionSample()
        didReceiveLocalReading = false
        isHiderWithinWarningRadius = false
        lastLoggedWithinWarningRadius = nil
        trackingTargetID = hiderID
    }

    private func observedHiderID() -> PlayerID? {
        if let trackingTargetID, activeHiderIDs.contains(trackingTargetID) {
            return trackingTargetID
        }

        trackingTargetID = activeHiderIDs.first
        return trackingTargetID
    }
}
