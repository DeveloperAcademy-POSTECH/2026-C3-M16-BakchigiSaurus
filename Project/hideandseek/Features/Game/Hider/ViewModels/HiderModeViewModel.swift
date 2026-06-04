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
    var remainingSeconds: Int = 600 // 남은 게임 시간
    var taggerDistance: Float? // 술래와의 거리 (값이 있을수도 없을수도)

    private let taggedDistanceThreshold: Float = 0.2 // 0.2m
    private let nearbyDistanceThreshold: Float = 3.0 // 3.0m
    private let warningDisplayDuration: UInt64 = 1_000_000_000 // 1초?. 경고 화면 보여주는 시간 (그 후 녹화)

    private var timer: Timer? // 1초마다 시간 줄임
    private var warningToRecordingTask: Task<Void, Never>? // 녹화 화면으로 전환
    private var hasRecordedForCurrentNearEvent = false // 술래와 근접 상황에서 녹화 되었는지 여부
    private var ignoresTaggedDistanceUntilSafe = false // 잡힘 확인 루프 예방

    func startHiding() {
        state = .hiding
        signal = .unknown
        taggerDistance = nil
        hasRecordedForCurrentNearEvent = false // 이번 근접 상황에서 녹화하지 않은 상태로 초기화
        ignoresTaggedDistanceUntilSafe = false // 잡힘 거리 무시 상태 해제
    }

    func updateRemainingSeconds(_ seconds: Int) {
        remainingSeconds = max(0, seconds)
    }

    func handleGameEnded() {
        warningToRecordingTask?.cancel()
        state = .gameEnded
    }

    /// 추후 Nearby와 연결
    func updateTaggerDistance(_ distance: Float?) {
        // 현재 상태가 거리 업데이트를 무시해야 하는 상태인지 확인 (뒤늦은 거리값이 들어와도 화면이 바뀌면 안됨)
        guard !state.shouldIgnoreTaggerUpdates else {
            return
        }

        taggerDistance = distance // 새 거리값 저장

        guard let distance else {
            signal = .unknown
            state = .hiding
            return
        }

        // 잡힘 판정을 무시해야 하는 상태인지 확인
        if ignoresTaggedDistanceUntilSafe {
            // 술래가 기준 거리보다 멀어졌다면 다시 잡힘 판정 허용
            if distance > taggedDistanceThreshold {
                ignoresTaggedDistanceUntilSafe = false
            }
            return
        }

        // 술래가 기준 거리 이내인지 확인 (잡힘 여부)
        if distance <= taggedDistanceThreshold {
            warningToRecordingTask?.cancel()
            signal = .veryNear
            showTaggedCheck()
            return
        }

        // 술래가 기준 거리 이내인지 확인 (경고 및 녹화)
        if distance <= nearbyDistanceThreshold {
            signal = .near
            state = .taggerNearby
            scheduleRecordingIfNeeded()
            return
        }

        signal = .far
        state = .hiding
        hasRecordedForCurrentNearEvent = false
        warningToRecordingTask?.cancel()
    }

    /// 경고 화면을 보여준 뒤 녹화 화면으로 전환
    private func scheduleRecordingIfNeeded() {
        // 해당 이벤트에서 녹화를 했다면 다시 x (중복 방지)
        guard !hasRecordedForCurrentNearEvent else {
            return
        }

        guard warningToRecordingTask == nil else {
            return
        }

        warningToRecordingTask = Task { [weak self] in
            // ViewModel이 아직 살아있는지 확인
            guard let self else {
                return
            }

            // 1초 기다림
            try? await Task.sleep(nanoseconds: self.warningDisplayDuration)
            // 해당 시간 동안 작업 취소 여부 확인
            guard !Task.isCancelled else {
                return
            }

            guard !self.state.shouldIgnoreTaggerUpdates else {
                return
            }

            self.hasRecordedForCurrentNearEvent = true
            self.state = .recording
            self.warningToRecordingTask = nil
        }
    }

    /// 2초 녹화가 끝났을 때 호출
    func finishRecording() {
        // 잡힘 확인/종료 상태라면 무시
        guard !state.shouldIgnoreTaggerUpdates else {
            return
        }

        state = .taggerNearby
        signal = .near
    }

    /// 잡힘 확인 화면으로 이동
    func showTaggedCheck() {
        // 이미 잡힘 확인 중이거나 종료 상태라면 다시 실행하지 않음
        guard !state.shouldIgnoreTaggerUpdates else {
            return
        }
        state = .taggedCheck
    }

    /// 네/아니오 선택
    func selectTaggedAnswer(_ answer: TaggedAnswer) {
        state = .taggedConfirm(answer: answer)
    }

    func cancelTaggedConfirm() {
        state = .taggedCheck
    }

    /// 한번 더 확인
    func confirmTaggedAnswer(_ answer: TaggedAnswer) {
        switch answer {
        case .yes:
            markTagged()

        case .no:
            ignoresTaggedDistanceUntilSafe = true // 잡힘화면 바로 다시 나타나는 것 예방
            state = .hiding
        }
    }

    /// 최종 잡힘 처리
    func markTagged() {
        warningToRecordingTask?.cancel()
        state = .tagged
        stopTimer()
    }

    /// 초기화
    func reset() {
        state = .idle
        signal = .unknown
        remainingSeconds = 600
        taggerDistance = nil
        hasRecordedForCurrentNearEvent = false
        ignoresTaggedDistanceUntilSafe = false
        stopTimer()
    }

    /// 타이머 시작
    private func startTimer() {
        stopTimer()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }

            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.stopTimer()
            }
        }
    }

    /// 타이머 정지
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

private extension HiderModeState {
    /// 현재 상태에서 술래 신호/거리 업데이트를 무시해야 하는지 알려주는 계산 속성
    var shouldIgnoreTaggerUpdates: Bool {
        switch self {
        // 거리 업데이트 무시
        case .taggedCheck, .taggedConfirm, .tagged:
            true

        // 거리 업데이트 받음
        case .idle, .hiding, .taggerNearby, .recording:
            false
        }
    }
}
