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
        VStack(spacing: 12) {
            Text(signalText)
                .font(.headline)

            Circle()
                .fill(signalColor)
                .frame(width: 80, height: 80)
        }
    }

    private var signalText: String {
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
            .red
        }
    }
}

#Preview("위치 모름") {
    TaggerSignalView(signal: .unknown)
        .padding()
}

#Preview("술래 멀리 있음") {
    TaggerSignalView(signal: .far)
        .padding()
}

#Preview("술래 가까움") {
    TaggerSignalView(signal: .near)
        .padding()
}

#Preview("술래 매우 가까움") {
    TaggerSignalView(signal: .veryNear)
        .padding()
}
