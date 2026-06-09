//
//  GameEngine.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation

// MARK: - Engine

actor GameEngine {
    var state: GameState
    var appliedEventIDs: Set<GameEventID>
    var nextSequenceBySource: [PlayerID: Int]

    init(initialState: GameState) {
        self.state = initialState
        self.appliedEventIDs = []
        self.nextSequenceBySource = [:]
    }

    func snapshot() -> GameState {
        state
    }

    func apply(_ command: GameCommand, as sourcePlayerID: PlayerID) -> GameMutation {
        let events = makeEvents(for: command, sourcePlayerID: sourcePlayerID)
        apply(envelopes: events)
        return GameMutation(sharedState: state, newEvents: events)
    }

    func merge(_ remoteEvents: [GameEventEnvelope]) -> GameMutation {
        let acceptedEvents = remoteEvents
            .sorted(by: eventOrder(lhs:rhs:))
            .filter(isAuthorizedRemoteEvent(_:))

        apply(envelopes: acceptedEvents)
        return GameMutation(sharedState: state, newEvents: acceptedEvents)
    }
}
