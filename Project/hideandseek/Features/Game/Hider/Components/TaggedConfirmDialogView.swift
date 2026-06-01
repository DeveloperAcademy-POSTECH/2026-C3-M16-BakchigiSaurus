//
//  TaggedConfirmDialogView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 술래에게 잡힘 여부를 한번 더 확인하는 팝업
struct TaggedConfirmDialogView: View {
    let answer: TaggedAnswer
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineSpacing(4)

                HStack(spacing: 10) {
                    Button("아니요", action: onCancel)
                        .buttonStyle(DialogButtonStyle(color: .gray))

                    Button("네", action: onConfirm)
                        .buttonStyle(DialogButtonStyle(color: .red))
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

    private var title: String {
        switch answer {
        case .yes:
            "정말로 잡혔나요?"
        case .no:
            "정말로 잡히지 않았나요?"
        }
    }

    private var message: String {
        switch answer {
        case .yes:
            "술래에게 들켰을 경우에만 '네'를 눌러주세요"
        case .no:
            "술래에게 들키지 않은 경우에만 '네'를 눌러주세요"
        }
    }
}

struct DialogButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(color.opacity(configuration.isPressed ? 0.6 : 0.9))
            .clipShape(Capsule())
    }
}

#Preview {
    TaggedConfirmDialogView(
        answer: .yes,
        onCancel: {},
        onConfirm: {}
    )
}
