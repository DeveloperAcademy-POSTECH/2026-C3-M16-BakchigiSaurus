//
//  HiderModeViewModel.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import Foundation
import Observation

@Observable // 해당 클래스 안의 값이 바뀌면 SwiftUI 화면이 자동으로 변화 감지
final class HiderModeViewModel {
    var state: HiderModeState = .idle // 숨는 사람 화면 상태
    var signal: TaggerSignal = .unknown // 술래가 얼마나 가까운지 나타내는 신호
    var remainingSeconds: Int = 600 // 남은 게임 시간(게임 설정시 내용과 연동 필요!)
    var taggerDistance: Float? // 술래와의 거리

    private let taggedDistanceThreshold: Float = 0.2
    private var timer: Timer? // 1초마다 시간 줄임
    private var ignoresTaggedDistanceUntilSafe = false // 잡힘 확인 루프 예방

    func startHiding() {
        state = .hiding
        signal = .unknown
        remainingSeconds = 600
        taggerDistance = nil
        ignoresTaggedDistanceUntilSafe = false
        startTimer()
    }

    /// 술래에 대한 신호 호출 - 가까운지 먼지 여부
    func receiveTaggerSignal(_ newSignal: TaggerSignal) {
        guard !state.shouldIgnoreTaggerUpdates else {
            return
        // 현재 상태가 신호/거리 업데이트를 무시해야 하는 상태가 아니라면 계속 진행. but 무시해야 하는 상태라면 바로 return
        }

        signal = newSignal

        switch newSignal {
        case .unknown, .far:
            state = .hiding

        // 술래가 가까우면 경고 화면 상태로 바뀜
        case .near:
            state = .taggerNearby

        // 술래가 매우 가까이 있을 때 카메라 작동
        case .veryNear:
            state = .recording
        }
    }

    func updateTaggerDistance(_ distance: Float?) {
        guard !state.shouldIgnoreTaggerUpdates else {
            return
        // 현재 상태가 잡힘 확인/종료 흐름이면 거리 업데이트 무시
        }
        
        taggerDistance = distance
        
        guard let distance else {
            return
        // 거리값이 없으면 잡힘 판정 하지 않음
        }
        
        if ignoresTaggedDistanceUntilSafe {
            if distance > taggedDistanceThreshold {
                ignoresTaggedDistanceUntilSafe = false
            // 술래가 기준 거리보다 멀어졌다면 다시 거리 판정 허용
            }
            return
        }
        
        // 거리가 기준 이하라면 잡힘 화면으로 이동
        if distance <= taggedDistanceThreshold {
            showTaggedCheck()
        }
    }

    /// 잡힘 확인 화면으로 이동
    func showTaggedCheck() {
        guard !state.shouldIgnoreTaggerUpdates else {
            return
        // 이미 잡힘 확인 중이거나 종료 상태라면 다시 실행하지 않음
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
        state = .tagged
        stopTimer()
    }

    /// 초기화
    func reset() {
        state = .idle
        signal = .unknown
        remainingSeconds = 600
        taggerDistance = nil
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
    // 현재 상태에서 술래 신호/거리 업데이트를 무시해야 하는지 알려주는 계산 속성
    var shouldIgnoreTaggerUpdates: Bool {
        switch self {
        case .taggedCheck, .taggedConfirm, .tagged:
            return true
            
        case .idle, .hiding, .taggerNearby, .recording:
            return false
        }
    }
}
