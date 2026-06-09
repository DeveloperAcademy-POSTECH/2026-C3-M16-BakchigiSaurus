//
//  HiderGameViewModel.swift
//  hideandseek
//
//  Created by Codex on 6/9/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class HiderGameViewModel {
    let gameModel: GameModel

    init(gameModel: GameModel) {
        self.gameModel = gameModel
    }

    var mode: HiderModeState {
        guard gameModel.localParticipant?.role == .hider else {
            return .hiding
        }

        if gameModel.localParticipant?.status == .captured {
            return .captured
        }

        if gameModel.activeLocalCaptureRequest != nil {
            return .taggedCheck
        }

        guard let proximity = gameModel.proximityState(for: gameModel.localPlayerID) else {
            return .hiding
        }

        if proximity.hiderWarningSentAt != nil {
            return .recording
        }

        if let distance = proximity.lastDistance, distance <= 5 {
            return .taggerNearby
        }

        return .hiding
    }

    var timeLeft: Int {
        gameModel.remainingSeconds
    }

    var isTaggerNearby: Bool {
        guard let distance = gameModel.proximityState(for: gameModel.localPlayerID)?.lastDistance else {
            return false
        }

        return distance <= 5
    }

    func confirmCapture() async {
        await gameModel.send(
            .confirmCapture(hiderID: gameModel.localPlayerID),
            as: gameModel.localPlayerID
        )
    }

    func rejectCapture() async {
        await gameModel.send(
            .rejectCapture(hiderID: gameModel.localPlayerID),
            as: gameModel.localPlayerID
        )
    }
}
