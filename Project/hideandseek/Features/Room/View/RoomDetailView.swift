//
//  RoomDetailView.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import SwiftUI

struct Participant: Identifiable, Hashable {
    let id = UUID()
    let name: String
}

struct RoomDetailView: View {
    let roomTitle: String
    let maxCount: Int

    @State private var participants: [Participant] = [
        Participant(name: "캄초의 iPhone"),
        Participant(name: "캄초의 iPhone"),
        Participant(name: "캄초의 iPhone"),
        Participant(name: "캄초의 iPhone")
    ]
    @State private var taggerID: Participant.ID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Label("\(participants.count)/\(maxCount)", systemImage: "person.2")
                    .labelStyle(.titleAndIcon)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(participants) { participant in
                        ParticipantCard(
                            name: participant.name,
                            isTagger: participant.id == taggerID
                        ) {
                            toggleTagger(for: participant)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Text("참여자를 선택해 술래로 지정하세요\n술래를 지정하지 않을시 랜덤으로 선택됩니다")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            Button {} label: {
                Text("게임 시작")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .tint(.accent)
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(.appBackground)
        .navigationTitle(roomTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func toggleTagger(for participant: Participant) {
        taggerID = (taggerID == participant.id) ? nil : participant.id
    }
}

#Preview {
    NavigationStack {
        RoomDetailView(roomTitle: "박치기 사우루스 숨바꼭질", maxCount: 6)
    }
    .preferredColorScheme(.dark)
}
