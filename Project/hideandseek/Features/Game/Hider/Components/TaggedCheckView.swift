//
//  TaggedCheckView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 숨는 사람이 술래에게 잡혔는지 직접 확인하는 화면
struct TaggedCheckView: View {
    let remainingSeconds: Int
    let onYes: () -> Void // '네' 버튼 눌렀을 때
    let onNo: () -> Void // '아니요' 버튼 눌렀을 때

    var body: some View {
        ZStack {
            blurredBackground

            VStack {
                GameTimer(timeLeft: remainingSeconds)
                    .padding(.top, 76)

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
                            .buttonStyle(
                                AnswerButtonStyle(
                                    color: Color(red: 1.000, green: 0.259, blue: 0.271)
                                )
                            )

                        Button("네", action: onYes)
                            .buttonStyle(
                                AnswerButtonStyle(
                                    color: Color(red: 0.427, green: 0.486, blue: 1.000)
                                )
                            )
                    }
                }
                .padding(.bottom, 120)
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
}

/// 버튼 디자인
struct AnswerButtonStyle: ButtonStyle {
    let color: Color

    /// 버튼이 실제로 어떻게 보일지
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
        remainingSeconds: 180,
        onYes: {},
        onNo: {}
    )
}
