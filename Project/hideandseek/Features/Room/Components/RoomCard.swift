//
//  RoomCard.swift
//  hideandseek
//
//  Created by Lanakee on 6/2/26.
//

import SwiftUI

struct RoomCard: View {
  let title:String
  let capacity: (current: Int, max: Int)
  let onTap: () -> Void
  
  private var isDisabled: Bool {
      capacity.current >= capacity.max
  }
  
  var body: some View {
    ZStack {
      Rectangle()
        .foregroundStyle(.appCard)
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .cornerRadius(16)
      HStack {
        Text(title)
          .font(.title3.bold())
        Spacer()
        Label("\(capacity.current)/\(capacity.max)", systemImage: "person.2")
          .labelStyle(.titleAndIcon)
          .font(.headline)
          .foregroundStyle(isDisabled ? .appDanger : .primary)
        if !isDisabled {
          Image(systemName: "chevron.right")
            .font(.headline)
        }
      }.padding(.horizontal,16)
    }
    .onTapGesture {
        guard !isDisabled else { return }
        onTap()
    }
  }
}

#Preview {
  RoomCard(title: "루미랑 놀사람", capacity: (current: 3, max: 6), onTap: {})
    .background(.appBackground)
    .padding(20)
  RoomCard(title: "루미랑 놀사람", capacity: (current: 6, max: 6), onTap: {})
    .background(.appBackground)
    .padding(20)
}

