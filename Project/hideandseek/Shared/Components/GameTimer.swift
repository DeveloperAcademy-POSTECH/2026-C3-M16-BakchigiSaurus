//
//  GameTimer.swift
//  hideandseek
//
//  Created by Lanakee on 5/29/26.
//

import SwiftUI

struct GameTimer: View {
    /// TimeLeft in seconds
    let timeLeft: Int

    /// format seconds to MM:SS
    private var formattedTime: String {
        let minutes = timeLeft / 60
        let seconds = timeLeft % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.black)
                .frame(maxWidth: 180, maxHeight: 67)
                .cornerRadius(33)
            Text(formattedTime)
                .font(Font.largeTitle.bold())
        }
    }
}

#Preview {
    VStack {
        GameTimer(timeLeft: 600) // 10:00
        GameTimer(timeLeft: 65) // 01:05
        GameTimer(timeLeft: 9) // 00:09
    }
    .padding(24)
    .background(.white)
}
