//
//  HiderModeView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 숨는 사람이 보는 전체  화면 흐름 관리하는 메인 화면
struct HiderModeView: View {
    let camera: CameraModel
    var timeLeft: Int?
    var onCaptureConfirmed: () -> Void = {}
    // 상위 View에서 만든 camera를 받아서 사용

    /// HiderModeViewModel을 생성
    @State private var viewModel = HiderModeViewModel()

    var body: some View {
        screenContent // 현재 상태에 따라 보여줄 화면 결정
            .onAppear {
                viewModel.startHiding() // 처음 화면
            }
    }

    @ViewBuilder // 여러 종류 View를 조건에 따라 반환
    private var screenContent: some View {
        switch viewModel.state {
        // view 모델이 가지고 있는 현재 상태 확인
        case .hiding:
            HiderSearchView(
                timeLeft: displayedTimeLeft
            )

        case .taggerNearby:
            TaggerWarningView(
                timeLeft: displayedTimeLeft
            )

        case .recording:
            CameraRecordingView(
                camera: camera,
                // 상위 View에서 받은 카메라 객체를 CameraRecordingView에 넘김
                timeLeft: displayedTimeLeft,
                isTaggerNearby: true, // 술래가 가까운 상태라고 알려줌
                onRecordingFinished: {
                    viewModel.finishRecording()
                }
            )

        case .taggedCheck:
            TaggedCheckView(
                timeLeft: displayedTimeLeft,
                onConfirmAnswer: { answer in
                    if viewModel.confirmTaggedAnswer(answer) {
                        onCaptureConfirmed()
                    }
                }
            )

        case .captured:
            capturedContent
        }
    }

    private var displayedTimeLeft: Int {
        timeLeft ?? viewModel.timeLeft
    }

    private var capturedContent: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("잡혔습니다")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                Text("게임 결과를 확인하는 중입니다")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HiderModeView(
        camera: CameraModel()
    )
}
