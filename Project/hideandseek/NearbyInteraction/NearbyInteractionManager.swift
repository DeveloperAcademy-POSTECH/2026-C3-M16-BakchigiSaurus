//
//  NearbyInteractionManager.swift
//  hideandseek
//
//  Created by 허지우 on 5/29/26.
//

import SwiftUI
import NearbyInteraction


final class NearbyInteractionManager: NSObject, NISessionDelegate {
    private var session: NISession?
    
    func start() {
        session = NISession()
        session?.delegate = self
    }
    
    func getMyDiscoveryToken() -> NIDiscoveryToken? {
        return session?.discoveryToken
    }
    
    func run(with peerToken: NIDiscoveryToken) {
        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        session?.run(config)
    }
    
    
}



// #Preview {
//    NearbyInteractionManager()
// }
