//
//  CameraRecordingView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 술래가 매우 가까이 왔을 때 카메라 화면을 보여주고 녹화 중임을 표시하는 화면
struct CameraRecordingView: View {
    let camera: CameraModel // 카메라 기능을 관리하는 객체. 상위View에서 받은 카메라 사용
    let timeLeft: Int // 남은 게임 시간. 초단위
    let isTaggerNearby: Bool // 술래가 가까운지 여부
    let onRecordingFinished: () -> Void // 녹화가 끝난 뒤 상위View에 알려주기 위한 클로저

    /// NOTE: 숨는 사람 촬영 UX는 다음 단계로 미룸. 이 화면은 녹화 제거 이후 컴파일만
    /// 맞춰둔 임시 상태다. (실제 사진 촬영은 추후 HiderModeView에 CaptureButton으로 붙임)
    var body: some View {
        ZStack {
            GameCameraBackground(
                camera: camera, // 상위에서 받은 카메라 객체 넘김
                isRevealed: isTaggerNearby // 촬영 가능 여부=블러
            )

            GameTimer(timeLeft: timeLeft)
                .frame(width: 171, height: 67)
                .padding(.top, 84)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            onRecordingFinished()
        }
    }
}

#Preview {
    CameraRecordingView(
        camera: CameraModel(),
        timeLeft: 180,
        isTaggerNearby: true,
        onRecordingFinished: {}
    )
}
