//
//  GameTimer.swift
//  hideandseek
//
//  Created by Lanakee on 5/29/26.
//

import SwiftUI

struct GameTimer: View {
    var body: some View {
      ZStack {
        Rectangle()
          .foregroundStyle(.black)
          .frame(maxWidth: 180, maxHeight: 67)
          .cornerRadius(33)
        Text("10:00")
          .font(Font.largeTitle.bold())
      }
    }
}

#Preview {
  VStack {
    GameTimer()
  }
  .padding(24)
  .background(.white)
}
