//
//  McniConncetion.swift
//  hideandseek
//
//  Created by 허지우 on 6/5/26.
//

import Combine
import Foundation
import NearbyInteraction

final class McniConnection {
    private let mcSession: MultipeerGameSession
    private let trackerPool: NearbyTrackerPool

    private var sessionEventTask: Task<Void, Error>?
    private var niTokenEventTask: Task<Void, Error>?

    var onPeerReadingUpdated: ((PeerID, NearbyInteractionReading) -> Void)? {
        get { trackerPool.onPeerReadingUpdated }
        set { trackerPool.onPeerReadingUpdated = newValue }
    }

    init(
        mcManager: MultipeerGameSession,
        trackerPool: NearbyTrackerPool? = nil
    ) {
        self.mcSession = mcManager
        self.trackerPool = trackerPool ?? NearbyTrackerPool(session: mcManager)

        observeSessionEvents()
        observeNITokenEvents()
    }

    /// MC 연결 상태 지켜보는 함수
    private func observeSessionEvents() {
        sessionEventTask = Task { [weak self] in
            guard let self else { return }

            for await event in mcSession.makeEventStream() {
                switch event {
                case let .peerConnected(peer):
                    print("MC peer Connected:", peer)
                    await MainActor.run {
                        self.trackerPool.startTracking(peer)
                    }

                case let .peerDisconnected(peer):
                    await MainActor.run {
                        self.trackerPool.stopTracking(peer)
                    }

                case .discoveredRoomsChanged:
                    break
                }
            }
        }
    }

    private func observeNITokenEvents() {
        niTokenEventTask = Task { [weak self] in
            guard let self else { return }

            for await event in mcSession.makeNIDiscoveryTokenStream() {
                await MainActor.run {
                    self.trackerPool.receiveToken(event.token, from: event.peer)
                }
            }
        }
    }

    deinit {
        sessionEventTask?.cancel()
        niTokenEventTask?.cancel()
        Task { @MainActor [trackerPool] in
            trackerPool.stopAll()
        }
    }
}

final class McniConnectionHolder: ObservableObject {
    let connection: McniConnection

    init() {
        let mcSession = MultipeerGameSession()

        self.connection = McniConnection(mcManager: mcSession)
    }
}
