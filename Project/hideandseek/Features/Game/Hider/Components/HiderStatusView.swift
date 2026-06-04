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
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(titleText)
                .font(.system(size: 30, weight: .bold))
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

        case .taggedConfirm:
            "정말로 잡혔나요?"

        case .tagged:
            "술래에게 잡혔습니다"
        }
    }

    private var titleColor: Color {
        switch state {
        case .taggerNearby, .recording, .tagged:
            Color(red: 1.0, green: 0.24, blue: 0.27)

        default:
            .white
        }
    }
}

#Preview("대기 중") {
    HiderStatusView(state: .idle)
        .padding()
        .background(.black)
}

#Preview("술래 위치 파악") {
    HiderStatusView(state: .hiding)
        .padding()
        .background(.black)
}

#Preview("술래 가까움") {
    HiderStatusView(state: .taggerNearby)
        .padding()
        .background(.black)
}

#Preview("녹화 중") {
    HiderStatusView(state: .recording)
        .padding()
        .background(.black)
}

#Preview("잡힘 확인") {
    HiderStatusView(state: .taggedCheck)
        .padding()
        .background(.black)
}

#Preview("잡힘 재확인 - 네") {
    HiderStatusView(state: .taggedConfirm(answer: .yes))
        .padding()
        .background(.black)
}

#Preview("잡힘 재확인 - 아니요") {
    HiderStatusView(state: .taggedConfirm(answer: .no))
        .padding()
        .background(.black)
}

#Preview("최종 잡힘") {
    HiderStatusView(state: .tagged)
        .padding()
        .background(.black)
}
