//
//  HintSuccessView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import SwiftUI

struct HintSuccessView: View {
    let camera: CameraModel
    let isHiderNearby: Bool
    let isUsingHint: Bool

    @State var rotation: Double = 30.0

    var body: some View {
        ZStack {
            GameCameraBackground(
                camera: camera,
                isRevealed: isHiderNearby && isUsingHint,
                isRecording: isHiderNearby
            )
            Color.appSuccess
                .ignoresSafeArea()
                .opacity(0.75)
            ZStack {
                VStack {
                    GameTimer(timeLeft: 300)
                    Spacer()
                    Image(systemName: "arrow.up")
                        .font(.system(size: 200))
                        .rotationEffect(Angle(degrees: rotation))

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
                                Text("이 있어요")
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
            .padding(.horizontal, 36)
        }
    }
}

#Preview {
    HintSuccessView(camera: CameraModel(), isHiderNearby: false, isUsingHint: false)
}
