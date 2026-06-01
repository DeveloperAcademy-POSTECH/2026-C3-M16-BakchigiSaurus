//
//  TaggedCheckView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 술래에게 잡혔는지 묻는 화면
struct TaggedCheckView: View {
    let remainingTime: String
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        ZStack {
            blurredBackground

            VStack {
                timePill

                Spacer()

                Text("!")
                    .font(.system(size: 130, weight: .bold))
                    .foregroundStyle(.red)

                Spacer()

                VStack(spacing: 18) {
                    Text("술래에게 잡혔나요?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 16) {
                        Button("아니요", action: onNo)
                            .buttonStyle(AnswerButtonStyle(color: .red))

                        Button("네", action: onYes)
                            .buttonStyle(AnswerButtonStyle(color: .blue))
                    }
                }
                .padding(.bottom, 90)
            }
        }
        .ignoresSafeArea()
    }

    private var blurredBackground: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.9),
                Color(red: 0.30, green: 0.18, blue: 0.12),
                Color.black.opacity(0.9)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var timePill: some View {
        Text(remainingTime)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 42)
            .padding(.vertical, 18)
            .background(Color.black.opacity(0.65))
            .clipShape(Capsule())
            .padding(.top, 76)
    }
}

struct AnswerButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 122, height: 48)
            .background(color.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(Capsule())
    }
}

#Preview {
    TaggedCheckView(
        remainingTime: "3:00",
        onYes: {},
        onNo: {}
    )
}
