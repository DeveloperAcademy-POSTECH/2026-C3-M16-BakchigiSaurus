//
//  HintFailureView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import SwiftUI

struct HintFailureView: View {
    
    let camera: CameraModel
    let isHiderNearby: Bool
    let isUsingHint: Bool
    
    var body: some View {
        ZStack {
            GameCameraBackground(camera: camera,
                                isRevealed: isHiderNearby && isUsingHint,
                                isRecording: isHiderNearby)
            Color.appDanger
                .ignoresSafeArea()
                .opacity(0.75)
            ZStack {
                VStack {
                    GameTimer(timeLeft: 300)
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 200))
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("화살표 방향에")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("숨은 사람")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.primary)
                                Text("이 없어요")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Button {} label: {
                                Label("힌트 (n개 남음)", systemImage: "magnifyingglass")
                                    .padding(.vertical, 10)
                                    .font(.title3)
                            }
                            .buttonStyle(.glass)
                            .cornerRadius(20)
                            .padding(.bottom, 7)
                            .opacity(0)
                            .disabled(true)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    HintFailureView(camera: CameraModel(), isHiderNearby: false, isUsingHint: false)
}
