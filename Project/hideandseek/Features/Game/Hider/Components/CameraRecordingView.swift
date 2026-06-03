//
//  CameraRecordingView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

// 술래가 매우 가까이 왔을 때 카메라 화면을 보여주고 녹화 중임을 표시하는 화면
struct CameraRecordingView: View {
    let camera: CameraModel // 카메라 기능을 관리하는 객체. 상위View에서 받은 카메라 사용
    let remainingSeconds: Int // 남은 게임 시간. 초단위
    let isTaggerNearby: Bool // 술래가 가까운지 여부
    
    var body: some View {
        ZStack {
            GameCameraBackground(
                camera: camera, // 상위에서 받은 카메라 객체 넘김
                isRevealed: isTaggerNearby, // 카메라 화면 공개
                isRecording: isTaggerNearby // 녹화 시작
            )
            
            VStack {
                GameTimer(timeLeft: remainingSeconds)
                    .padding(.top, 58)
                
                Spacer()
                
                Text("녹화중이에요")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    CameraRecordingView(
        camera: CameraModel(),
        remainingSeconds: 180,
        isTaggerNearby: true // 카메라 공개되고 녹화테스트
    )
}
