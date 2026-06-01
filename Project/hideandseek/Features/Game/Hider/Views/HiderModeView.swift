//
//  HiderModeView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 숨는 사람이 보는 메인 화면
struct HiderModeView: View {
    @StateObject private var viewModel = HiderModeViewModel()

    var body: some View {
        screenContent
            .onAppear {
                viewModel.startHiding()
            }
    }

    @ViewBuilder
    private var screenContent: some View {
        // ViewModel의 현재 상태 확인. state 값에 따라 화면 변경
        switch viewModel.state {
        case .idle, .hiding:
            normalHiderContent

        case .taggerNearby:
            TaggerWarningView(
                remainingTime: viewModel.remainingTimeText
            )

        case .recording:
            CameraRecordingView(
                remainingTime: viewModel.remainingTimeText
            )

        case .taggedCheck:
            TaggedCheckView(
                remainingTime: viewModel.remainingTimeText,
                onYes: {
                    viewModel.selectTaggedAnswer(.yes)
                },
                onNo: {
                    viewModel.selectTaggedAnswer(.no)
                }
            )

        case let .taggedConfirm(answer):
            TaggedCheckView(
                remainingTime: viewModel.remainingTimeText,
                onYes: {
                    viewModel.selectTaggedAnswer(.yes)
                },
                onNo: {
                    viewModel.selectTaggedAnswer(.no)
                }
            )
            .overlay {
                TaggedConfirmDialogView(
                    answer: answer,
                    onCancel: {
                        viewModel.cancelTaggedConfirm()
                    },
                    onConfirm: {
                        viewModel.confirmTaggedAnswer(answer)
                    }
                )
            }

        case .tagged:
            TaggedOverlayView()
        }
    }

    private var normalHiderContent: some View {
        VStack(spacing: 32) {
            HiderStatusView(state: viewModel.state)
            TaggerSignalView(signal: viewModel.signal)
            testButtons
        }
        .padding()
    }

    private var testButtons: some View {
        VStack(spacing: 12) {
            Button("테스트: 술래 가까움") {
                viewModel.receiveTaggerSignal(.near)
            }

            Button("테스트: 녹화 시작") {
                viewModel.receiveTaggerSignal(.veryNear)
            }

            Button("테스트: 50cm 이내") {
                viewModel.updateTaggerDistance(0.5)
            }

            Button("테스트: 초기화") {
                viewModel.reset()
            }
        }
    }
}

#Preview {
    HiderModeView()
}
