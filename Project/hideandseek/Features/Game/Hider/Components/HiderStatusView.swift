//
//  HiderStatusView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 현재 숨는 사람 상태 보여주는 컴포넌트
struct HiderStatusView: View {
    let state: HiderModeState // 외부에서 현재 상태 전달받음

    var body: some View {
        VStack(spacing: 8) {
            Text(eyebrowText)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(titleText)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
    }

    private var eyebrowText: String {
        switch state {
        case .idle:
            "게임 대기"

        case .hiding:
            "주변에"

        case .taggerNearby:
            "주의"

        case .recording:
            "자동 녹화"

        case .taggedCheck:
            "확인 필요"

        case .taggedConfirm:
            "한 번 더 확인"

        case .tagged:
            "잡힘"

        case .gameEnded:
            "라운드 종료"
        }
    }

    private var titleText: String {
        switch state {
        case .idle:
            "숨는 중"

        case .hiding:
            "술래를 찾는중"

        case .taggerNearby:
            "술래가 가까이 있어요"

        case .recording:
            "녹화중이에요"

        case .taggedCheck:
            "술래에게 잡혔나요?"

        case let .taggedConfirm(answer):
            switch answer {
            case .yes:
                "정말로 잡혔나요?"
            case .no:
                "정말로 잡히지 않았나요?"
            }

        case .tagged:
            "술래에게 잡혔습니다"

        case .gameEnded:
            "게임이 종료되었습니다"
        }
    }

    private var titleColor: Color {
        switch state {
        case .taggerNearby, .recording, .tagged:
            .secondary

        case .idle, .hiding, .taggedCheck, .taggedConfirm, .gameEnded:
            .primary
        }
    }
}

#Preview("대기 중") {
    HiderStatusView(state: .idle)
        .padding()
        .background(.appBackground)
}

#Preview("술래 위치 파악") {
    HiderStatusView(state: .hiding)
        .padding()
        .background(.appBackground)
}

#Preview("술래 가까움") {
    HiderStatusView(state: .taggerNearby)
        .padding()
        .background(.appBackground)
}

#Preview("녹화 중") {
    HiderStatusView(state: .recording)
        .padding()
        .background(.appBackground)
}

#Preview("잡힘 확인") {
    HiderStatusView(state: .taggedCheck)
        .padding()
        .background(.appBackground)
}

#Preview("잡힘 재확인 - 네") {
    HiderStatusView(state: .taggedConfirm(answer: .yes))
        .padding()
        .background(.appBackground)
}

#Preview("잡힘 재확인 - 아니요") {
    HiderStatusView(state: .taggedConfirm(answer: .no))
        .padding()
        .background(.appBackground)
}

#Preview("최종 잡힘") {
    HiderStatusView(state: .tagged)
        .padding()
        .background(.appBackground)
}

#Preview("게임 종료") {
    HiderStatusView(state: .gameEnded)
        .padding()
        .background(.appBackground)
}
