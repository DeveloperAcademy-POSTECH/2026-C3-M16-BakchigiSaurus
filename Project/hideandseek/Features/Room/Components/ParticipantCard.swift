//
//  ParticipantCard.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import SwiftUI

struct ParticipantCard: View {
    let name: String
    let isTagger: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            Text(name)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Spacer()
            if isTagger {
                Text("술래")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.accentColor, lineWidth: isTagger ? 2 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: onTap)
        .animation(.easeInOut(duration: 0.15), value: isTagger)
    }
}
