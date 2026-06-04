//
//  PermissionCard.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import SwiftUI

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus

    var body: some View {
        HStack(spacing: 16) {
            iconView

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PermissionChip(status: status)
                .padding(.bottom)
        }
        .padding(.horizontal, 18)
        .frame(height: 82)
        .background(.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.tint.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    PermissionCard(
        icon: "camera",
        title: "Camera",
        description: "생동감 넘치는 게임 기록을 위해 사용돼요",
        status: .denied
    )
    .padding()
    .background(.black)
}
