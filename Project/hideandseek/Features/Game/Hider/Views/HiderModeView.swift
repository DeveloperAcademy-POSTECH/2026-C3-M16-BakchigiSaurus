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
    // 상위 View에서 만든 camera를 받아서 사용

    /// HiderModeViewModel을 생성
    @StateObject private var viewModel = HiderModeViewModel()

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
        case .idle, .hiding:
            HiderSearchView(
                remainingSeconds: viewModel.remainingSeconds
            )

        case .taggerNearby:
            TaggerWarningView(
                remainingSeconds: viewModel.remainingSeconds
            )

        case .recording:
            CameraRecordingView(
                camera: camera,
                // 상위 View에서 받은 카메라 객체를 CameraRecordingView에 넘김
                remainingSeconds: viewModel.remainingSeconds,
                isTaggerNearby: true,// 술래가 가까운 상태라고 알려줌
                onRecordingFinished: {
                    viewModel.receiveTaggerSignal(.near)
                }
            )

        case .taggedCheck:
            // 술래에게 잡혔는지 묻는 화면
            TaggedCheckView(
                remainingSeconds: viewModel.remainingSeconds,
                onYes: {
                    viewModel.selectTaggedAnswer(.yes)
                },
                onNo: {
                    viewModel.selectTaggedAnswer(.no)
                }
            )

        case let .taggedConfirm(answer):
            // 1차 선택 답변 한번 더 확인
            TaggedCheckView(
                remainingSeconds: viewModel.remainingSeconds,
                onYes: {
                    viewModel.selectTaggedAnswer(.yes)
                },
                onNo: {
                    viewModel.selectTaggedAnswer(.no)
                }
            )
            // 팝업
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
            TaggedOverlayView(
                onConfirm: {
                    viewModel.reset()
                }
            )
        }
    }
}

#Preview {
    HiderModeView(
        camera: CameraModel()
    )
}
