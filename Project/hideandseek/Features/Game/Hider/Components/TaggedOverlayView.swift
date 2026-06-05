//
//  TaggedOverlayView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 게임이 끝났을 때 보여주는 화면
struct TaggedOverlayView: View {
    let onConfirm: () -> Void // 확인 버튼 눌렀을때.. 아직 미정

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 11) {
                    Text("게임이 종료되었습니다")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)

                    Text("처음 장소로 모여주세요")
                        .font(.title.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onConfirm) {
                    Text("확인")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    TaggedOverlayView(
        onConfirm: {}
    )
}
