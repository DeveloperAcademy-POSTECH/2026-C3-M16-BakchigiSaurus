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
            Image("btn")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .opacity(isEnabled ? 1 : 0.45)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("사진 촬영")
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
