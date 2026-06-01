//
//  HiderModeViewModel.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import Combine
import Foundation

// ObservableObject, @Published 사용하기 위해 사용

final class HiderModeViewModel: ObservableObject {
    @Published var state: HiderModeState = .idle // 숨는 사람 화면 상태
    @Published var signal: TaggerSignal = .unknown // 술래가 얼마나 가까운지 나타내는 신호
    @Published var remainingSeconds: Int = 600 // 남은 게임 시간(게임 설정시 내용과 연동 필요!)
    @Published var taggerDistance: Float? // 술래와의 거리

    private var timer: Timer? // 1초마다 시간 줄임
    private let taggedDistanceThreshold: Float = 0.5

    var remainingTimeText: String {
        let minutes = remainingSeconds / 60 // 초를 분으로 변환
        let seconds = remainingSeconds % 60 // 분으로 나누고 남은 초를 구함
        return String(format: "%d:%02d", minutes, seconds)
    }

    func startHiding() {
        state = .hiding
        signal = .unknown
        remainingSeconds = 600
        startTimer()
    }

    /// 술래에 대한 신호 호출 - 가까운지 먼지 여부
    func receiveTaggerSignal(_ newSignal: TaggerSignal) {
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
        taggerDistance = distance

        guard let distance else {
            return
        }

        if distance <= taggedDistanceThreshold {
            showTaggedCheck()
        }
    }

    /// 잡힘 확인 화면으로 이동
    func showTaggedCheck() {
        state = .taggedCheck
    }

    /// 네/아니오 선택
    func selectTaggedAnswer(_ answer: TaggedAnswer) {
        state = .taggedConfirm(answer: answer)
    }

    /// 한번 더 확인
    func confirmTaggedAnswer(_ answer: TaggedAnswer) {
        switch answer {
        case .yes:
            markTagged()

        case .no:
            state = .hiding
        }
    }

    func cancelTaggedConfirm() {
        state = .taggedCheck
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
