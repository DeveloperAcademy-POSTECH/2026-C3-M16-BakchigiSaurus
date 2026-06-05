//
//  TaggerWarningView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 술래가 가까울때 보여주는 경고 화면
struct TaggerWarningView: View {
    let timeLeft: Int

    var body: some View {
        ZStack {
            backgroundView

            VStack {
                topWarningBar

                Text("!")
                    .font(.system(size: 200, weight: .bold))
                    .foregroundStyle(.appDanger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                bottomMessage
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(red: 0.35, green: 0.05, blue: 0.05),
                Color(red: 0.62, green: 0.18, blue: 0.14),
                Color(red: 0.78, green: 0.42, blue: 0.36),
                Color(red: 0.45, green: 0.03, blue: 0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var topWarningBar: some View {
        VStack {
            GameTimer(timeLeft: timeLeft)

            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title.bold())

                Text("주변에 술래가 있어요")
                    .font(.title.bold())
            }
            .foregroundStyle(.appDanger)
        }
        .padding(.top, 30)
        .padding(.bottom, 28)
        .padding(.horizontal, 50)
        .background(Color.appBackground)
        .clipShape(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
    }

    private var bottomMessage: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("주변에")
                .foregroundStyle(.secondary)

            Text("\(Text("술래").foregroundStyle(.primary))가 있어요!")
                .foregroundStyle(.secondary)
        }
        .font(.largeTitle.bold())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 36)
        .padding(.bottom, 121)
    }
}

#Preview {
    TaggerWarningView(timeLeft: 180)
}
