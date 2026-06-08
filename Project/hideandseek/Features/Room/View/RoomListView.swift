//
//  RoomListView.swift
//  hideandseek
//
//  Created by Lanakee on 6/2/26.
//

import SwiftUI

struct RoomListView: View {
    @ObservedObject var model: RoomFlowViewModel
    @Binding var showingCreateRoom: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let statusMessage = model.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            if model.discoveredRooms.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.discoveredRooms) { room in
                            RoomCard(
                                title: room.name,
                                capacity: (
                                    current: room.currentCount,
                                    max: room.maxCount
                                )
                            ) {
                                model.joinRoom(room)
                            }
                            .opacity(
                                model.joiningRoomID == nil || model.joiningRoomID == room.id ? 1 : 0.55
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }
            }

            Spacer(minLength: 0)
        }
        .background(.appBackground)
        .navigationBarTitleDisplayMode(.inline)
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
        .onAppear {
            model.activateLobby()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("방 목록")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("같이 플레이할 방을 만들거나 참여해보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 44))
                .padding(.bottom, 10)

            Text("아직 방이 없어요")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("새로운 방을 만들어 친구들과 함께 플레이해보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateRoom = true
            } label: {
                Label("방 만들기", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .tint(.accent)
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Button {
                model.activateLobby()
            } label: {
                Label("새로 고침", systemImage: "arrow.trianglehead.2.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glass)
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

#Preview {
    NavigationStack {
        RoomListView(
            model: RoomFlowViewModel(),
            showingCreateRoom: .constant(false)
        )
    }
    .preferredColorScheme(.dark)
}
