//
//  TaggerWarningView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 술래가 가까울때 보여주는 경고 화면
struct TaggerWarningView: View {
    let remainingSeconds: Int

    var body: some View {
        ZStack {
            backgroundView

            VStack {
                topWarningBar

                Spacer()

                Text("!")
                    .font(.system(size: 150, weight: .bold))
                    .foregroundStyle(.red)

                Spacer()

                bottomMessage
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 70)
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
        VStack(spacing: 10) {
            GameTimer(timeLeft: remainingSeconds)

            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .bold))

                Text("주변에 술래가 있어요")
                    .font(.system(size: 27, weight: .bold))
            }
            .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 28)
        .background(Color.black)
        .clipShape(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .padding(.top, 8)
    }

    private var bottomMessage: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("주변에")
                .foregroundStyle(.white.opacity(0.65))

            Text("\(Text("술래").foregroundStyle(.white))가 있어요!")
                .foregroundStyle(.white.opacity(0.65))
        }
        .font(.system(size: 32, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
        .padding(.bottom, 60)
    }
}

#Preview {
    TaggerWarningView(remainingSeconds: 180)
}
