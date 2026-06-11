//
//  HidingTimerView.swift
//  hideandseek
//
//  Created by Lanakee on 6/10/26.
//

import SwiftUI

struct HidingTimerView: View {
    let time: (remaining: Double, total: Double)

    private var progress: Double {
        max(0, min(time.remaining / time.total, 1))
    }

    private var backgroundColor: Color {
        Color(
            hue: progress * 0.33,
            saturation: 0.65,
            brightness: 0.9
        )
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            CircularTimer(
                current: time.remaining,
                total: time.total
            )
        }
        .animation(.linear(duration: 0.3), value: progress)
    }
}

#Preview {
    HidingTimerView(time: (remaining: 30, total: 60))
}
