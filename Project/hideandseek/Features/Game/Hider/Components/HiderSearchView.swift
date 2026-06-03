//
//  HiderSearchView.swift
//  hideandseek
//
//  Created by KDHA on 6/2/26.
//

import SwiftUI

/// 숨는 사람이 처음 보는 기본 화면
struct HiderSearchView: View {
    let remainingSeconds: Int // 남은 게임 시간. 초단위

    var body: some View {
        ZStack {
            searchBackground // 배경

            VStack {
                GameTimer(timeLeft: remainingSeconds)
                    .padding(.top, 75)

                Spacer()

                bottomMessage
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .ignoresSafeArea()
    }

    private var searchBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.13, blue: 0.09),
                Color(red: 0.10, green: 0.13, blue: 0.14),
                Color(red: 0.32, green: 0.24, blue: 0.18)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 2)
    }

    private var bottomMessage: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("주변에")
                .foregroundStyle(.white.opacity(0.55))

            Text("\(Text("술래").foregroundStyle(.white))를 찾는중")
                .foregroundStyle(.white.opacity(0.55))
        }
        .font(.system(size: 32, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
        .padding(.bottom, 60)
    }
}

#Preview {
    HiderSearchView(remainingSeconds: 180)
}
