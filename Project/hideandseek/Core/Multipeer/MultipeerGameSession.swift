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

final class MultipeerGameSession: NSObject {
    private let serviceType = "hide-seek"

    private let localMCPeerID: MCPeerID
    private let session: MCSession

    init(displayName: String = UIDevice.current.name) {
        let mcPeerID = MCPeerID(displayName: displayName)

        self.localMCPeerID = mcPeerID
        self.session = MCSession(
            peer: mcPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )

        super.init()
    }
}
