//
//  TaggerSignalView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 술래 접근 정도를 보여주는 컴포넌트
struct TaggerSignalView: View {
    let signal: TaggerSignal

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(signalColor.opacity(0.18))
                    .frame(width: 96, height: 96)

                Circle()
                    .stroke(signalColor.opacity(0.45), lineWidth: 2)
                    .frame(width: 84, height: 84)

                Image(systemName: signalIcon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(signalColor)
            }

            VStack(spacing: 4) {
                Text(signalTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Text(signalDescription)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
    }

    private var signalIcon: String {
        switch signal {
        case .unknown:
            "questionmark"

        case .far:
            "checkmark"

        case .near:
            "exclamationmark"

        case .veryNear:
            "exclamationmark.triangle.fill"
        }
    }

    private var signalTitle: String {
        switch signal {
        case .unknown:
            "탐색 중"

        case .far:
            "안전"

        case .near:
            "주의"

        case .veryNear:
            "위험"
        }
    }

    private var signalDescription: String {
        switch signal {
        case .unknown:
            "술래 위치를 알 수 없음"

        case .far:
            "술래가 멀리 있어요"

        case .near:
            "술래가 가까워지고 있어요"

        case .veryNear:
            "술래가 매우 가까워요"
        }
    }

    private var signalColor: Color {
        switch signal {
        case .unknown:
                .gray

        case .far:
                .green

        case .near:
                .orange

        case .veryNear:
                .appDanger
        }
    }
}

#Preview("위치 모름") {
    TaggerSignalView(signal: .unknown)
        .padding()
        .background(.appBackground)
}

#Preview("안전") {
    TaggerSignalView(signal: .far)
        .padding()
        .background(.appBackground)
}

#Preview("주의") {
    TaggerSignalView(signal: .near)
        .padding()
        .background(.appBackground)
}

#Preview("위험") {
    TaggerSignalView(signal: .veryNear)
        .padding()
        .background(.appBackground)
}
