//
//  TaggedCheckView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 숨는 사람이 술래에게 잡혔는지 직접 확인하는 화면
struct TaggedCheckView: View {
    let timeLeft: Int
    let onConfirmAnswer: (TaggedAnswer) -> Void

    @State private var pendingAnswer: TaggedAnswer?
    @State private var isShowingConfirmAlert = false

    var body: some View {
        ZStack {
            blurredBackground

            GameTimer(timeLeft: timeLeft)
                .frame(width: 171, height: 67)
                .padding(.top, 84)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Text("!")
                .font(.system(size: 200, weight: .bold))
                .foregroundStyle(.appDanger)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            answerArea
                .padding(.bottom, 141)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
        .alert(
            confirmTitle,
            isPresented: $isShowingConfirmAlert
        ) {
            Button("아니요", role: .cancel) {
                pendingAnswer = nil
            }

            Button("네", role: .destructive) {
                guard let pendingAnswer else {
                    return
                }

                onConfirmAnswer(pendingAnswer)
                self.pendingAnswer = nil
            }
        } message: {
            Text(confirmMessage)
        }
    }

    private var answerArea: some View {
        VStack(spacing: 18) {
            Text("술래에게 잡혔나요?")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                Button("아니요") {
                    pendingAnswer = .no
                    isShowingConfirmAlert = true
                }
                .buttonStyle(
                    AnswerButtonStyle(color: .appDanger)
                )

                Button("네") {
                    pendingAnswer = .yes
                    isShowingConfirmAlert = true
                }
                .buttonStyle(
                    AnswerButtonStyle(color: .accentColor)
                )
            }
        }
    }

    private var confirmTitle: String {
        switch pendingAnswer {
        case .yes:
            "정말로 잡혔나요?"
        case .no:
            "정말로 잡히지 않았나요?"
        case nil:
            ""
        }
    }

    private var confirmMessage: String {
        switch pendingAnswer {
        case .yes:
            "술래에게 들켰을 경우에만 '네'를 눌러주세요"
        case .no:
            "술래에게 들키지 않은 경우에만 '네'를 눌러주세요"
        case nil:
            ""
        }
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
            .font(.title3.bold())
            .foregroundStyle(.primary)
            .frame(width: 122, height: 48)
            .background(color.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(Capsule())
    }
}

#Preview {
    TaggedCheckView(
        timeLeft: 180,
        onConfirmAnswer: { _ in }
    )
}
