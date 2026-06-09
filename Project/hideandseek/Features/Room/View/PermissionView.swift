//
//  PermissionView.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import SwiftUI

struct PermissionItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
}

struct PermissionView: View {
    let permissionItems: [PermissionItem] = [
        .init(
            icon: "network",
            title: "Local Network",
            description: "서로의 앱을 찾기위해 사용되어요",
            status: .granted
        ),
        .init(
            icon: "arrow.up.right",
            title: "Nearby Interaction",
            description: "서로의 방향과 거리를 측정하기 위해 사용되어요",
            status: .granted
        ),
        .init(
            icon: "camera",
            title: "Camera",
            description: "생동감 넘치는 게임 기록을 위해 사용되어요",
            status: .denied
        ),
        .init(
            icon: "microphone",
            title: "Microphone",
            description: "생동감 넘치는 게임 기록을 위해 사용되어요",
            status: .granted
        )
    ]

    var body: some View {
        VStack {
            Spacer()
            Text("앱 사용을 위해 권한이 필요해요")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Spacer()
            ForEach(permissionItems) { item in
                PermissionCard(
                    icon: item.icon,
                    title: item.title,
                    description: item.description,
                    status: item.status
                )
            }
            Spacer()
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("권한 허용하기")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .tint(.accent)
            .buttonStyle(.glassProminent)
            .padding(.bottom, 20)
        }.padding(.horizontal, 20)
    }
}

#Preview {
    PermissionView()
}
