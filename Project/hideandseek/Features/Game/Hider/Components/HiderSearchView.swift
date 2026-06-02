//
//  HiderSearchView.swift
//  hideandseek
//
//  Created by KDHA on 6/2/26.
//

import SwiftUI

struct HiderSearchView: View {
    let remainingSeconds: Int

    var body: some View {
        ZStack {
            searchBackground

            VStack {
                GameTimer(timeLeft: remainingSeconds)
                    .padding(.top, 58)

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

            Text("술래를 찾는중")
                .foregroundStyle(.white)
        }
        .font(.system(size: 28, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HiderSearchView(remainingSeconds: 180)
}
