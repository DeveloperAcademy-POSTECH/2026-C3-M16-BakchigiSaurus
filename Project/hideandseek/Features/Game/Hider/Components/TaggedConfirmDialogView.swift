//
//  TaggedConfirmDialogView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 술래에게 잡힘 여부를 한번 더 확인하는 팝업
struct TaggedConfirmDialogView: View {
    let answer: TaggedAnswer // 1차 질문
    let onCancel: () -> Void // '아니오' 버튼 눌렀을 때 실행
    let onConfirm: () -> Void // '네' 버튼 눌렀을 때 실행

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea() // 화면전체 : 반투명 검정

            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)

                HStack(spacing: 10) {
                    Button("아니요", action: onCancel)
                        .buttonStyle(
                            DialogButtonStyle(textColor: .primary)
                        )

                    Button("네", action: onConfirm)
                        .buttonStyle(
                            DialogButtonStyle(
                                textColor: .appDanger)
                        )
                }
            }
            .padding(22)
            .frame(width: 300)
            .background(.black.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
        }
    }

    /// 해당 뷰 안에서만 팝업 제목
    private var title: String {
        switch answer {
        case .yes:
            "정말로 잡혔나요?"
        case .no:
            "정말로 잡히지 않았나요?"
        }
    }

    /// 해당 뷰 안에서는 팝업 문구
    private var message: String {
        switch answer {
        case .yes:
            "술래에게 잡혔을 경우에만 '네'를 눌러주세요"
        case .no:
            "술래에게 잡히지 않은 경우에만 '네'를 눌러주세요"
        }
    }
}

struct DialogButtonStyle: ButtonStyle {
    let textColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(textColor.opacity(configuration.isPressed ? 0.6 : 1))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    TaggedConfirmDialogView(
        answer: .yes, // 해당 상태 미리 보기
        onCancel: {},
        onConfirm: {}
    )
}
