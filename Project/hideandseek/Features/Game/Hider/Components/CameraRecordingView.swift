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

    var body: some View {
        ZStack {
            GameCameraBackground(
                camera: camera, // 상위에서 받은 카메라 객체 넘김
                isRevealed: isTaggerNearby, // 카메라 화면 공개
                isRecording: isTaggerNearby // 녹화 시작
            )
            
            GameTimer(timeLeft: timeLeft)
                .frame(width: 171, height: 67)
                .padding(.top, 84)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            Text("녹화중이에요")
                .font(.largeTitle.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 36)
                .padding(.bottom, 54)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .ignoresSafeArea()
        // 화면이 나타나면 .task 실행
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            guard !Task.isCancelled else {
                            return
                        }
            
            await camera.setRecording(false)
            onRecordingFinished()
        }
        .onDisappear {
            Task {
                await camera.setRecording(false)
                // 2초 후 녹화를 멈춤
            }
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
