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
    var state: HiderModeState = .idle // 숨는 사람 화면 상태
    var signal: TaggerSignal = .unknown // 술래가 얼마나 가까운지 나타내는 신호
    var timeLeft: Int = 600 // 남은 게임 시간
    var taggerDistance: Float? // 술래와의 거리 (값이 있을수도 없을수도)

    private let taggedDistanceThresholdMeters: Float = 0.2 // 20cm
    private let taggedDistanceResetThresholdMeters: Float = 0.35 // 35cm
    private let nearbyDistanceThresholdMeters: Float = 5.0 // 5m

    private let warningDisplayDuration: UInt64 = 1_000_000_000 // 1초?. 경고 화면 보여주는 시간 (그 후 녹화)
    private let nearbyCooldownDuration: TimeInterval = 60 // 1분

    private var warningToRecordingTask: Task<Void, Never>? // 녹화 화면으로 전환
    private var activeNearbyTaggerID: String?
    private var nearbyCooldownUntilByTaggerID: [String: Date] = [:]
    private var ignoresTaggedDistanceUntilSafe = false // 잡힘 확인 루프 예방

    func startHiding() {
        state = .hiding
        signal = .unknown
        taggerDistance = nil
        activeNearbyTaggerID = nil
        ignoresTaggedDistanceUntilSafe = false // 잡힘 거리 무시 상태 해제
        cancelWarningToRecording()
    }

    func updateTimeLeft(_ seconds: Int) {
        timeLeft = max(0, seconds)
    }

    func handleGameEnded() {
        cancelWarningToRecording()
        state = .gameEnded
    }

    /// 추후 Nearby와 연결
    func updateTaggerDistance(_ distance: Float?, taggerID: String = "default") {
        // 현재 상태가 거리 업데이트를 무시해야 하는 상태인지 확인 (뒤늦은 거리값이 들어와도 화면이 바뀌면 안됨)
        guard !state.shouldIgnoreTaggerUpdates else {
            return
        }

        taggerDistance = distance // 새 거리값 저장

        guard let distance else {
            if state == .taggerNearby || state == .recording {
                return
            }

            signal = .unknown
            state = .hiding
            activeNearbyTaggerID = nil
            cancelWarningToRecording()
            return
        }

        // 잡힘 판정을 무시해야 하는 상태인지 확인
        if ignoresTaggedDistanceUntilSafe {
            // 술래가 기준 거리보다 멀어졌다면 다시 잡힘 판정 허용
            if distance > taggedDistanceResetThresholdMeters {
                ignoresTaggedDistanceUntilSafe = false
            }
            return
        }

        // 술래가 기준 거리 이내인지 확인 (잡힘 여부)
        if distance <= taggedDistanceThresholdMeters {
            signal = .veryNear
            activeNearbyTaggerID = nil
            cancelWarningToRecording()
            showTaggedCheck()
            return
        }

        // 경고/카메라녹화 진행중이면 거리 업데이트 방해 금지
        if state == .taggerNearby || state == .recording {
            return
        }

        // 술래가 기준 거리 이내인지 확인 (경고 및 녹화)
        if distance <= nearbyDistanceThresholdMeters {
            guard canRunNearbyProcess(for: taggerID) else {
                signal = .near
                state = .hiding
                return
            }

            signal = .near
            activeNearbyTaggerID = taggerID
            showTaggerWarning()
            return
        }

        signal = .far
        state = .hiding
        activeNearbyTaggerID = nil
        cancelWarningToRecording()
    }

    private func showTaggerWarning() {
        state = .taggerNearby
        scheduleRecordingIfNeeded()
    }

    private func scheduleRecordingIfNeeded() {
        guard warningToRecordingTask == nil else {
            return
        }

        warningToRecordingTask = Task { [weak self] in
            guard let self else {
                return
            }

            try? await Task.sleep(nanoseconds: self.warningDisplayDuration)

            guard !Task.isCancelled else {
                return
            }

            guard !self.state.shouldIgnoreTaggerUpdates else {
                return
            }

            self.state = .recording
            self.warningToRecordingTask = nil
        }
    }

    /// 2초 녹화가 끝났을 때 호출
    func finishRecording() {
        guard !state.shouldIgnoreTaggerUpdates else {
            return
        }

        cancelWarningToRecording()

        if let activeNearbyTaggerID {
            nearbyCooldownUntilByTaggerID[activeNearbyTaggerID] = Date().addingTimeInterval(nearbyCooldownDuration)
        }

        activeNearbyTaggerID = nil
        signal = .unknown
        state = .hiding
    }

    /// 잡힘 확인 화면으로 이동
    func showTaggedCheck() {
        guard !state.shouldIgnoreTaggerUpdates else {
            return
        }

        state = .taggedCheck
    }

    /// 한번 더 확인
    func confirmTaggedAnswer(_ answer: TaggedAnswer) {
        switch answer {
        case .yes:
            markTagged()

        case .no:
            ignoresTaggedDistanceUntilSafe = true
            activeNearbyTaggerID = nil
            cancelWarningToRecording()
            state = .hiding
        }
    }

    /// 최종 잡힘 처리
    func markTagged() {
        activeNearbyTaggerID = nil
        cancelWarningToRecording()
        state = .tagged
    }

    /// 초기화
    func reset() {
        cancelWarningToRecording()

        state = .idle
        signal = .unknown
        timeLeft = 600
        taggerDistance = nil
        activeNearbyTaggerID = nil
        nearbyCooldownUntilByTaggerID.removeAll()
        ignoresTaggedDistanceUntilSafe = false
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

    private func cancelWarningToRecording() {
        warningToRecordingTask?.cancel()
        warningToRecordingTask = nil
    }
}

private extension HiderModeState {
    /// 현재 상태에서 술래 신호/거리 업데이트를 무시해야 하는지 알려주는 계산 속성
    var shouldIgnoreTaggerUpdates: Bool {
        switch self {
        // 거리 업데이트 무시
        case .taggedCheck, .tagged, .gameEnded:
            true

        // 거리 업데이트 받음
        case .idle, .hiding, .taggerNearby, .recording:
            false
        }
    }
}
