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
    
    
    
    
}



// #Preview {
//    NearbyInteractionManager()
// }
