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

    private let taggedDistanceThresholdMeters: Float = 0.2 // 20cm
    private let taggedDistanceResetThresholdMeters: Float = 0.35 // 35cm, 잡힘에 대해 아니오를 누른 뒤 다시 잡힘 화면 뜨는 것 방지
    private let nearbyDistanceThresholdMeters: Float = 5.0 // 5m

    private let warningDisplayDuration: UInt64 = 1_000_000_000 // 1초?. 경고 화면 보여주는 시간 (그 후 녹화)
    private let nearbyCooldownDuration: TimeInterval = 60 // 1분

    private var warningToRecordingTask: Task<Void, Never>? // 녹화 화면으로 전환
    private var activeNearbyTaggerID: String? // 경고 발생시킨 술래 ID
    private var nearbyCooldownUntilByTaggerID: [String: Date] = [:] // 경고 발생 후 일정 시간 재발생 금지 기간
    private var ignoresTaggedDistanceUntilSafe = false // 잡힘 확인 루프 예방

    func startHiding() {
        state = .hiding
        taggerDistance = nil
        activeNearbyTaggerID = nil
        ignoresTaggedDistanceUntilSafe = false // 잡힘 거리 무시 상태 해제
        cancelWarningToRecording()
    }

    func updateTimeLeft(_ seconds: Int) {
        timeLeft = max(0, seconds)
    }

    /// 추후 Nearby와 연결
    func updateTaggerDistance(_ distance: Float?, taggerID: String = "default") {
        // 현재 상태가 거리 업데이트를 무시해야 하는 상태인지 확인 (뒤늦은 거리값이 들어와도 화면이 바뀌면 안됨)
        taggerDistance = distance
        // 들어온 거리값 저장
        
        guard let distance else {
            if state == .taggerNearby || state == .recording {
                return
            }
            
            state = .hiding
            activeNearbyTaggerID = nil
            cancelWarningToRecording()
            return
        }
        
        // 잡힘 판정을 무시해야 하는 상태인지 확인
        if ignoresTaggedDistanceUntilSafe {
            if distance > taggedDistanceResetThresholdMeters {
                ignoresTaggedDistanceUntilSafe = false
            }
            return
        }
        
        // 0.2m 이내면 술래에게 잡힘 화면
        if distance <= taggedDistanceThresholdMeters {
            activeNearbyTaggerID = nil
            cancelWarningToRecording()
            showTaggedCheck()
            return
        }
        
        // 주변 술래 경고 및 녹화 시, 5m 판정으로 화면을 다시 바꾸지 않음
        if state == .taggerNearby || state == .recording {
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
        cancelWarningToRecording()
    }

    private func showTaggerWarning() {
        state = .taggerNearby
        scheduleRecordingIfNeeded()
    }

    // 녹화 전환 중복 방지
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

            self.state = .recording
            self.warningToRecordingTask = nil
        }
    }

    /// 2초 녹화가 끝났을 때 호출
    func finishRecording() {
        cancelWarningToRecording()

        if let activeNearbyTaggerID {
            nearbyCooldownUntilByTaggerID[activeNearbyTaggerID] = Date().addingTimeInterval(nearbyCooldownDuration)
        }

        activeNearbyTaggerID = nil
        state = .hiding
    }

    /// 잡힘 확인 화면으로 이동
    func showTaggedCheck() {
        cancelWarningToRecording()
        state = .taggedCheck
    }

    /// 한번 더 확인
    func confirmTaggedAnswer(_ answer: TaggedAnswer) {
        switch answer {
        case .yes:
            state = .taggedCheck

        case .no:
            ignoresTaggedDistanceUntilSafe = true
            activeNearbyTaggerID = nil
            cancelWarningToRecording()
            state = .hiding
        }
    }

    /// 초기화
    func reset() {
        cancelWarningToRecording()

        state = .hiding
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
