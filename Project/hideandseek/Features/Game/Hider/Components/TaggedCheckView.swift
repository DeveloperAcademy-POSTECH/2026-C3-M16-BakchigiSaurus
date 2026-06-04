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
    let onConfirmAnswer: (TaggedAnswer) -> Void

    @State private var pendingAnswer: TaggedAnswer?

    var body: some View {
        ZStack {
            blurredBackground
            
            VStack {
                GameTimer(timeLeft: remainingSeconds)
                    .padding(.top, 76)
                
                Spacer()
                
                Text("!")
                    .font(.system(size: 200, weight: .bold))
                    .foregroundStyle(.appDanger)
                
                Spacer()
                
                VStack(spacing: 18) {
                    Text("술래에게 잡혔나요?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 16) {
                        Button("아니요") {
                            pendingAnswer = .no
                        }
                        .buttonStyle(
                            AnswerButtonStyle(color: .appDanger)
                        )
                        
                        Button("네") {
                            pendingAnswer = .yes
                        }
                        .buttonStyle(
                            AnswerButtonStyle(color: .accentColor)
                        )
                    }
                }
                .padding(.bottom, 120)
            }
            
            if let pendingAnswer {
                TaggedConfirmDialogView(
                    answer: pendingAnswer,
                    onCancel: {
                        self.pendingAnswer = nil
                    },
                    onConfirm: {
                        onConfirmAnswer(pendingAnswer)
                        self.pendingAnswer = nil
                    }
                )
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
            .foregroundStyle(.primary)
            .frame(width: 122, height: 48)
            .background(color.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(Capsule())
    }
}

#Preview {
    TaggedCheckView(
        remainingSeconds: 180,
        onConfirmAnswer: { _ in }
    )
}
