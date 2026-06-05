//
//  TaggerDetectedVeiw.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import SwiftUI

struct TaggerDetectedVeiw: View {
    let camera: CameraModel
    let isHiderNearby: Bool
    let isUsingHint: Bool

    func checkDetection(distance: Double, duration: Int) {
        if distance <= 5.0, duration >= 5 {
            LiveActivityManager.shared.startLiveActivity(roomName: "캄초의 숨바꼭질", isTagger: true)
        } else {
            LiveActivityManager.shared.stopLiveActivity()
        }
    }

    var body: some View {
        ZStack {
            GameCameraBackground(
                camera: camera,
                isRevealed: isHiderNearby && isUsingHint,
                isRecording: isHiderNearby
            )
            VStack {
                GameTimer(timeLeft: 300)
                Spacer()
                Text("녹화중이에요")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 7)
            }
            .padding(.horizontal, 36)
        }
    }
}

#Preview {
    TaggerDetectedVeiw(camera: CameraModel(), isHiderNearby: true, isUsingHint: false)
}
