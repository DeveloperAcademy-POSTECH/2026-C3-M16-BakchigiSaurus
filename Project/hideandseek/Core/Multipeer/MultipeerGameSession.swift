//
//  MultipeerGameSession.swift
//  hideandseek
//
//  Created by 카야 on 6/3/26.
//
//  MultipeerGameSession.swift
//  hideandseek
//

import Foundation
import MultipeerConnectivity
import UIKit

final class MultipeerGameSession: NSObject, GameSession, @unchecked Sendable {
    private let serviceType = "hide-seek"

    private let localMCPeerID: MCPeerID
    private let session: MCSession

    private let stateQueue = DispatchQueue(label: "hideandseek.multipeer.session.state")

    private var connectedMCPeers: [MCPeerID] = []
    private var eventContinuation: AsyncStream<SessionEvent>.Continuation?

    let localPeer: PeerID
    private(set) var hostPeer: PeerID

    var currentPeers: [PeerID] {
        stateQueue.sync {
            let connectedPeers = connectedMCPeers.map { PeerID(mcPeerID: $0) }
            return uniquePeers([localPeer] + connectedPeers)
        }
    }

    init(displayName: String = UIDevice.current.name, isHost: Bool = true) {
        let mcPeerID = MCPeerID(displayName: displayName)

        self.localMCPeerID = mcPeerID
        self.session = MCSession(
            peer: mcPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )

        let peer = PeerID(
            rawID: displayName,
            displayName: displayName
        )

        self.localPeer = peer
        self.hostPeer = peer

        super.init()

        if isHost {
            self.hostPeer = self.localPeer
        }
    }

    func makeEventStream() -> AsyncStream<SessionEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }
}
private extension MultipeerGameSession {
    func uniquePeers(_ peers: [PeerID]) -> [PeerID] {
        var seen = Set<PeerID>()

        return peers.filter { peer in
            if seen.contains(peer) {
                return false
            } else {
                seen.insert(peer)
                return true
            }
        }
    }
}

private extension PeerID {
    init(mcPeerID: MCPeerID) {
        self.rawID = mcPeerID.displayName
        self.displayName = mcPeerID.displayName
    }
}
