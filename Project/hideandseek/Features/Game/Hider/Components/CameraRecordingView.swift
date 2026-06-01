//
//  CameraRecordingView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 술래가 매우 가까이 왔을 때 녹화 중임을 보여주는 화면
struct CameraRecordingView: View {
    let remainingTime: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                topWarningBar

                Spacer()

                Text("녹화중이에요")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
    }

    private var topWarningBar: some View {
        VStack(spacing: 8) {
            Text(remainingTime)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("주변에 술래가 있어요")
            }
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.red)
        }
        .padding(.top, 56)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }
}

#Preview {
    CameraRecordingView(
        remainingTime: "3:00"
    )
}
