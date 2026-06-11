//
//  GameEndedView.swift
//  hideandseek
//
//  Created by Lanakee on 6/11/26.
//

import SwiftUI

/// 게임 종료 직후 보여주는 안내 화면. 확인을 누르면 영상 전송 화면으로 넘어간다.
struct GameEndedView: View {
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("게임이 종료되었습니다")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("처음 장소로 모여주세요")
                    .font(.title3.weight(.semibold))
                    .underline()
                    .foregroundStyle(.secondary)
            }

            Button(action: onConfirm) {
                Text("확인")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

#Preview {
    GameEndedView(onConfirm: {})
}
