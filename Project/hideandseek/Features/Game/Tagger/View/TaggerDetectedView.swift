//
//  TaggerDetectedView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import SwiftUI

struct TaggerDetectedView: View {
    let camera: CameraModel
    let isHiderNearby: Bool
    let isUsingHint: Bool
    let timeLeft: Int
    @State private var isHiderDetected: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            GameCameraBackground(
                camera: camera,
                isRevealed: isHiderNearby && isUsingHint,
                isRecording: isHiderNearby
            )
            .ignoresSafeArea()

            VStack {
                GameTimer(timeLeft: timeLeft)
                Spacer()
                Text("녹화중이에요")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 7)
            }
            .padding(.horizontal, 36)

            if isHiderDetected {
                FakeDynamicIslandView(isExpanded: true) {
                    IslandCompactContent()
                } expanded: {
                    IslandExpandedContent(timeLeft: 180, type: .hiderNearby)
                }
                .padding(.top, 12)
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    TaggerDetectedView(camera: CameraModel(), isHiderNearby: true, isUsingHint: false, timeLeft: 300)
}
