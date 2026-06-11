//
//  HiderModeViewModel.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import Foundation
import Observation

@MainActor
@Observable // 해당 클래스 안의 값이 바뀌면 SwiftUI 화면이 자동으로 변화 감지
final class HiderModeViewModel {
    var state: HiderModeState = .hiding // 숨는 사람 화면 상태
    var timeLeft: Int = 600 // 남은 게임 시간
    var taggerDistance: Float? // 술래와의 거리 (값이 있을수도 없을수도)

    private let taggedDistanceThresholdMeters = GameProximityRules.captureDistanceThresholdMeters
    private let taggedDistanceResetThresholdMeters: Float = 0.35 // 35cm, 잡힘에 대해 아니오를 누른 뒤 다시 잡힘 화면 뜨는 것 방지
    private let nearbyDistanceThresholdMeters: Float = 5.0 // 5m

    private let warningVisibleDuration: UInt64 = 3_000_000_000 // 3초 동안 경고 표시
    private let nearbyCooldownDuration: TimeInterval = 60 // 1분

    private var warningDismissTask: Task<Void, Never>?
    private var activeNearbyTaggerID: String? // 경고 발생시킨 술래 ID
    private var nearbyCooldownUntilByTaggerID: [String: Date] = [:] // 경고 발생 후 일정 시간 재발생 금지 기간
    private var ignoresTaggedDistanceUntilSafe = false // 잡힘 확인 루프 예방
    private var activeCaptureRequestSentAt: Date?
    private var dismissedCaptureRequestSentAt: Date?

    func startHiding() {
        state = .hiding
        taggerDistance = nil
        activeNearbyTaggerID = nil
        ignoresTaggedDistanceUntilSafe = false // 잡힘 거리 무시 상태 해제
        activeCaptureRequestSentAt = nil
        dismissedCaptureRequestSentAt = nil
        cancelWarningDismiss()
    }

    func updateTimeLeft(_ seconds: Int) {
        timeLeft = max(0, seconds)
    }

    /// 추후 Nearby와 연결
    func updateTaggerDistance(_ distance: Float?, taggerID: String = "default") {
        // 현재 상태가 거리 업데이트를 무시해야 하는 상태인지 확인 (뒤늦은 거리값이 들어와도 화면이 바뀌면 안됨)
        taggerDistance = distance
        // 들어온 거리값 저장

        guard state != .taggedCheck, state != .captured else {
            return
        }

        guard let distance else {
            if state == .taggerNearby {
                return
            }

            state = .hiding
            activeNearbyTaggerID = nil
            cancelWarningDismiss()
            return
        }

        // 잡힘 판정을 무시해야 하는 상태인지 확인
        if ignoresTaggedDistanceUntilSafe {
            if distance > taggedDistanceResetThresholdMeters {
                ignoresTaggedDistanceUntilSafe = false
            }
            return
        }

        // 기기가 거의 맞닿은 거리면 술래에게 잡힘 확인 화면
        if distance <= taggedDistanceThresholdMeters {
            activeNearbyTaggerID = nil
            cancelWarningDismiss()
            showTaggedCheck()
            return
        }

        // 주변 술래 경고 시, 5m 판정으로 화면을 다시 바꾸지 않음
        if state == .taggerNearby {
            return
        }

        // 5m 이내면 주변 술래 경고 화면
        if distance <= nearbyDistanceThresholdMeters {
            guard canRunNearbyProcess(for: taggerID) else {
                state = .hiding
                return
            }

            activeNearbyTaggerID = taggerID
            showTaggerWarning()
            return
        }

        state = .hiding
        activeNearbyTaggerID = nil
        cancelWarningDismiss()
    }

    private func showTaggerWarning() {
        state = .taggerNearby
        scheduleWarningDismiss()
    }

    /// 경고를 일정 시간 보여준 뒤 숨는 화면으로 복귀하고 쿨다운을 적용
    private func scheduleWarningDismiss() {
        guard warningDismissTask == nil else {
            return
        }

        warningDismissTask = Task { [weak self] in
            guard let self else {
                return
            }

            try? await Task.sleep(nanoseconds: self.warningVisibleDuration)

            guard !Task.isCancelled else {
                return
            }

            self.dismissWarning()
        }
    }

    private func dismissWarning() {
        warningDismissTask = nil
        if let activeNearbyTaggerID {
            nearbyCooldownUntilByTaggerID[activeNearbyTaggerID] = Date().addingTimeInterval(nearbyCooldownDuration)
        }

        activeNearbyTaggerID = nil
        if state == .taggerNearby {
            state = .hiding
        }
    }

    /// 잡힘 확인 화면으로 이동
    func showTaggedCheck() {
        cancelWarningDismiss()
        state = .taggedCheck
    }

    func updateCaptureRequest(_ request: CaptureRequest?) {
        guard state != .captured else {
            return
        }

        guard let request else {
            activeCaptureRequestSentAt = nil
            return
        }

        activeCaptureRequestSentAt = request.requestedAt
        guard dismissedCaptureRequestSentAt != request.requestedAt else {
            return
        }

        activeNearbyTaggerID = nil
        cancelWarningDismiss()
        showTaggedCheck()
    }

    func markCapturedFromGameState() {
        cancelWarningDismiss()
        activeNearbyTaggerID = nil
        state = .captured
    }

    /// 한번 더 확인
    @discardableResult
    func confirmTaggedAnswer(_ answer: TaggedAnswer) -> Bool {
        switch answer {
        case .yes:
            state = .captured
            return true

        case .negative:
            ignoresTaggedDistanceUntilSafe = true
            dismissedCaptureRequestSentAt = activeCaptureRequestSentAt
            activeNearbyTaggerID = nil
            cancelWarningDismiss()
            state = .hiding
            return false
        }
    }

    /// 초기화
    func reset() {
        cancelWarningDismiss()

        state = .hiding
        timeLeft = 600
        taggerDistance = nil
        activeNearbyTaggerID = nil
        nearbyCooldownUntilByTaggerID.removeAll()
        ignoresTaggedDistanceUntilSafe = false
        activeCaptureRequestSentAt = nil
        dismissedCaptureRequestSentAt = nil
    }

    private func canRunNearbyProcess(for taggerID: String) -> Bool {
        guard let cooldownUntil = nearbyCooldownUntilByTaggerID[taggerID] else {
            return true
        }

        if Date() >= cooldownUntil {
            nearbyCooldownUntilByTaggerID[taggerID] = nil
            return true
        }

        return false
    }

    private func cancelWarningDismiss() {
        warningDismissTask?.cancel()
        warningDismissTask = nil
    }
}
