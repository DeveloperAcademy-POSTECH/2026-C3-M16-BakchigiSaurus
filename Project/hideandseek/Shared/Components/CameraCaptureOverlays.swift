//
//  CameraCaptureOverlays.swift
//  hideandseek
//

import SwiftUI

struct CameraFrameOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.88, proxy.size.height * 0.52)

            Image("frame")
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .position(
                    x: proxy.size.width / 2,
                    y: proxy.size.height / 2
                )
        }
        .allowsHitTesting(false)
    }
}

struct CameraBottomGradient: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            LinearGradient(
                colors: [
                    .black.opacity(0.0),
                    .black.opacity(0.45),
                    .black.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.horizontal, -20)
            .frame(height: 260)
            .blur(radius: 10)
            .offset(y: 8)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
