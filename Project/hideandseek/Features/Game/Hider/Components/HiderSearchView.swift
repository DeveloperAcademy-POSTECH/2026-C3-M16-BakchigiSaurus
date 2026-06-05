//
//  HiderSearchView.swift
//  hideandseek
//
//  Created by KDHA on 6/2/26.
//

import SwiftUI

/// 숨는 사람이 처음 보는 기본 화면
struct HiderSearchView: View {
    let timeLeft: Int // 남은 게임 시간. 초단위

    var body: some View {
        ZStack {
            searchBackground // 배경
            
            GameTimer(timeLeft: timeLeft)
                .frame(width: 171, height: 67)
                .padding(.top, 84)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            bottomMessage
                .padding(.leading, 36)
                .padding(.bottom, 121)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
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
        VStack(alignment: .leading) {
            Text("주변에")
                .foregroundStyle(.secondary)

            Text("\(Text("술래").foregroundStyle(.primary))를 탐지중")
                .foregroundStyle(.secondary)
        }
        .font(.largeTitle.bold())

    }
}

#Preview {
    HiderSearchView(timeLeft: 180)
}
