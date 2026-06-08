//
//  RoomDetailView.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import SwiftUI

struct RoomDetailView: View {
    @ObservedObject var model: RoomFlowViewModel
    let room: RoomLobbySnapshot

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(model.sortedParticipants, id: \.rawID) { participant in
                        ParticipantCard(
                            name: participant.displayName,
                            isTagger: model.selectedTaggerRawID == participant.rawID
                        ) {
                            model.toggleTagger(for: participant)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            footer
        }
        .background(.appBackground)
        .navigationTitle(room.name)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: model.leaveActiveRoom) {
                    Label("goback", systemImage: "chevron.left")
                }
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Label("\(room.currentCount)/\(room.maxCount)", systemImage: "person.2")
                    .labelStyle(.titleAndIcon)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if model.canStartGame {
                Text("참여자를 선택해 술래로 지정하세요. 선택하지 않으면 시작 시 랜덤으로 정해집니다")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Button {
                    model.startGame()
                } label: {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .tint(.accent)
                .buttonStyle(.glassProminent)
                .disabled(!model.canStartGame || model.gameStarted || !model.isHostInActiveRoom)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                ProgressView()
                Text("방장이 게임을 시작하길 기다리는중")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    private var buttonTitle: String {
        if model.gameStarted {
            return "게임 시작됨"
        }

        return model.isHostInActiveRoom ? "게임 시작" : "대기 중"
    }
}

#Preview {
    NavigationStack {
        RoomDetailView(
            model: RoomFlowViewModel(),
            room: RoomLobbySnapshot(
                id: "preview",
                host: PeerID(rawID: "preview-host", displayName: "미리보기 호스트"),
                name: "박치기 사우루스 숨바꼭질",
                currentCount: 2,
                maxCount: 6,
                hintCount: 3,
                hideTimeSeconds: 10,
                gameMinutes: 10
            )
        )
    }
    .preferredColorScheme(.dark)
}
