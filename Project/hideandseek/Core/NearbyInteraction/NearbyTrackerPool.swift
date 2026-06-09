//
//  NearbyTrackerPool.swift
//  hideandseek
//
//  Created by Codex on 6/9/26.
//

import Foundation
import NearbyInteraction

@MainActor
final class NearbyPeerTracker {
    let peer: PeerID
    let manager: NearbyInteractionManager
    var onReadingUpdated: ((PeerID, NearbyInteractionReading) -> Void)?

    init(
        peer: PeerID,
        manager: NearbyInteractionManager = NearbyInteractionManager()
    ) {
        self.peer = peer
        self.manager = manager
        self.manager.onReadingUpdated = { [weak self] reading in
            guard let self else { return }
            self.onReadingUpdated?(self.peer, reading)
        }
    }

    func startTokenExchange(using session: MultipeerGameSession) {
        manager.startSession()

        guard let localToken = manager.getMyDiscoveryToken() else {
            return
        }

        session.sendNIDiscoveryToken(localToken, to: peer)
    }

    func run(with token: NIDiscoveryToken) {
        manager.run(with: token)
    }

    func invalidate() {
        manager.invalidateSession()
    }
}

@MainActor
final class NearbyTrackerPool {
    private let session: MultipeerGameSession
    private var trackersByPeerRawID: [String: NearbyPeerTracker] = [:]

    var onPeerReadingUpdated: ((PeerID, NearbyInteractionReading) -> Void)?

    init(session: MultipeerGameSession) {
        self.session = session
    }

    var trackedPeers: [PeerID] {
        trackersByPeerRawID.values
            .map(\.peer)
            .sorted { $0.displayName < $1.displayName }
    }

    func startTracking(_ peer: PeerID) {
        let tracker = ensureTracker(for: peer)
        tracker.startTokenExchange(using: session)
    }

    func receiveToken(_ token: NIDiscoveryToken, from peer: PeerID) {
        let tracker = ensureTracker(for: peer)
        tracker.run(with: token)
    }

    func stopTracking(_ peer: PeerID) {
        trackersByPeerRawID.removeValue(forKey: peer.rawID)?.invalidate()
    }

    func stopAll() {
        let trackers = trackersByPeerRawID.values
        trackersByPeerRawID.removeAll()
        trackers.forEach { $0.invalidate() }
    }

    private func ensureTracker(for peer: PeerID) -> NearbyPeerTracker {
        if let existingTracker = trackersByPeerRawID[peer.rawID] {
            return existingTracker
        }

        let tracker = NearbyPeerTracker(peer: peer)
        tracker.onReadingUpdated = { [weak self] peer, reading in
            self?.onPeerReadingUpdated?(peer, reading)
        }
        trackersByPeerRawID[peer.rawID] = tracker
        return tracker
    }
}
