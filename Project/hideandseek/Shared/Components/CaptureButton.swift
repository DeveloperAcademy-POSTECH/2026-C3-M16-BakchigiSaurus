//
//  CaptureButton.swift
//  hideandseek
//
//  촬영 버튼. 촬영 가능 여부(isEnabled)에 따라 활성/비활성 표시한다.
//  · 술래: 다이내믹 아일랜드 확장 + 카메라 세션 실행 중일 때만 활성
//  · 숨는 사람: 카메라 세션 실행 중이면 항상 활성
//

import SwiftUI

struct CaptureButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(.white.opacity(isEnabled ? 0.25 : 0.08)))
                .overlay(Circle().stroke(.white, lineWidth: 3))
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

#Preview {
    ZStack {
        Color.black
        VStack(spacing: 24) {
            CaptureButton(isEnabled: true) {}
            CaptureButton(isEnabled: false) {}
        }
    }
}
