//
//  TaggerRevealView.swift
//  hideandseek
//
//  Created by Lanakee on 6/10/26.
//

import SwiftUI

struct TaggerRevealView: View {
    let gameModel: GameModel
    var onComplete: (() -> Void)?

    var body: some View {
        if let taggerName = gameModel.sharedState.tagger?.name {
            SlotMachineTaggerView(
                playerNames: gameModel.participants.map(\.name),
                taggerName: taggerName,
                onComplete: onComplete
            )
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            }
        }
    }
}

#Preview {
    let sample: GameModel = {
        let host = PlayerID()
        let p2 = PlayerID()
        let p3 = PlayerID()
        let p4 = PlayerID()
        let p5 = PlayerID()

        let participants: [PlayerID: GameParticipant] = [
            host: GameParticipant(id: host, name: "캄초의 iPhone", isHost: true, role: .tagger),
            p2: GameParticipant(id: p2, name: "플레이어 1"),
            p3: GameParticipant(id: p3, name: "플레이어 2"),
            p4: GameParticipant(id: p4, name: "플레이어 3"),
            p5: GameParticipant(id: p5, name: "플레이어 4")
        ]

        let session = GameSessionDefinition(hostID: host, settings: .default)
        var state = GameState(
            session: session,
            participants: participants,
            participantOrder: [host, p2, p3, p4, p5],
            taggerID: host
        )
        state.phase = .lobby

        return GameModel(initialState: state, localPlayerID: host)
    }()

    return TaggerRevealView(gameModel: sample)
}
