//
//  CircularTimer.swift
//  hideandseek
//
//  Created by Lanakee on 6/10/26.
//

import SwiftUI

struct CircularTimer: View {
    let current: Double
    let total: Double

    var progress: Double {
        max(0, min(current / total, 1))
    }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.gray.opacity(0.25),
                    style: StrokeStyle(
                        lineWidth: 18,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            Text("\(Int(current))")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 260, height: 260)
    }
}
