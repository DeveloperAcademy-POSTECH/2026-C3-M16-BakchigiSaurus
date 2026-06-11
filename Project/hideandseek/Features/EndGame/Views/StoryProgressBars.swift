//
//  StoryProgressBars.swift
//  hideandseek
//

import SwiftUI

struct StoryProgressBars: View {
    let count: Int
    let currentIndex: Int
    let progress: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< max(count, 0), id: \.self) { index in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.32))

                        Capsule()
                            .fill(.white)
                            .frame(width: proxy.size.width * fillAmount(for: index))
                    }
                }
                .frame(height: 3)
            }
        }
        .frame(height: 3)
    }

    private func fillAmount(for index: Int) -> Double {
        if index < currentIndex { return 1 }
        if index == currentIndex { return min(max(progress, 0), 1) }
        return 0
    }
}
