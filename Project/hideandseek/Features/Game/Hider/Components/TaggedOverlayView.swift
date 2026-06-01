//
//  TaggedOverlayView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 잡혔을 때 보여주는 화면
struct TaggedOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("잡혔습니다")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.white)

                Text("라운드가 종료될 때까지 기다려주세요")
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

#Preview {
    TaggedOverlayView()
}
