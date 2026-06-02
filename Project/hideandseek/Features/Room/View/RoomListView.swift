//
//  RoomListView.swift
//  hideandseek
//
//  Created by Lanakee on 6/2/26.
//

import SwiftUI

// MARK: - Model

struct Room: Identifiable {
    let id = UUID()
    let title: String
    let currentCount: Int
    let maxCount: Int

    var isFull: Bool {
        currentCount >= maxCount
    }
}

// MARK: - RoomListView

struct RoomListView: View {
    @State private var rooms: [Room] = [
        Room(title: "루미랑 놀사람", currentCount: 1, maxCount: 6),
        Room(title: "루미랑 놀사람", currentCount: 4, maxCount: 6),
        Room(title: "루미랑 놀사람", currentCount: 6, maxCount: 6)
    ]

    @State private var showingCreateRoom = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    // MARK: Header

                    VStack(alignment: .leading, spacing: 4) {
                        Text("방 목록")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)

                        Text("같이 플레이할 방을 만들거나 참여해보세요")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                    // MARK: Room List

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(rooms) { room in
                                RoomCard(
                                    title: room.title,
                                    capacity: (current: room.currentCount, max: room.maxCount)
                                ) {}
                                    .padding(.horizontal, 20)
                            }
                        }
                    }

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateRoom = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .tint(.accent)
                    .buttonStyle(.glassProminent)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    RoomListView()
}
