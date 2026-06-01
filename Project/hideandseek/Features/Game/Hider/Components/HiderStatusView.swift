//
//  HiderStatusView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 현재 숨는 사람 상태 보여주는 컴포넌트
struct HiderStatusView: View {
    let state: HiderModeState

    var body: some View {
        switch state {
        case .idle:
            statusText(
                title: "대기 중",
                color: .secondary
            )

        case .hiding:
            statusText(
                title: "숨는 중",
                color: .primary
            )

        case .taggerNearby:
            statusText(
                title: "술래가 가까워요",
                color: .orange
            )

        case .recording:
            statusText(
                title: "녹화중이에요",
                color: .red
            )

        case .taggedCheck:
            statusText(
                title: "잡혔는지 확인해주세요",
                color: .white
            )

        case .taggedConfirm:
            statusText(
                title: "한 번 더 확인해주세요",
                color: .white
            )

        case .tagged:
            statusText(
                title: "잡혔어요",
                color: .red
            )
        }
    }

    private func statusText(title: String, color: Color) -> some View {
        Text(title)
            .font(.title)
            .fontWeight(.bold)
            .foregroundStyle(color)
    }
}

#Preview {
    HiderStatusView(state: .idle)
        .padding()
}

#Preview {
    HiderStatusView(state: .hiding)
        .padding()
}

#Preview {
    HiderStatusView(state: .taggerNearby)
        .padding()
}

#Preview {
    HiderStatusView(state: .recording)
        .padding()
}

#Preview {
    HiderStatusView(state: .taggedCheck)
        .padding()
}

#Preview {
    HiderStatusView(state: .taggedConfirm(answer: .yes))
        .padding()
}

#Preview {
    HiderStatusView(state: .taggedConfirm(answer: .no))
        .padding()
}

#Preview {
    HiderStatusView(state: .tagged)
        .padding()
}
