//
//  GameRootView.swift
//  hideandseek
//
//  Created by KDHA on 6/3/26.
//

import SwiftUI

struct GameRootView: View {
    @State private var camera = CameraModel()
    // 게임 중 같은 카메라 객체 공유

    var body: some View {
        HiderModeView(camera: camera)
            .task {
                await camera.bootstrap()
            }
    }
}

#Preview {
    GameRootView()
}
