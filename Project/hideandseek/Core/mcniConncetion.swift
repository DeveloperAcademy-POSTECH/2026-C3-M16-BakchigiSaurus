//
//  mcniConncetion.swift
//  hideandseek
//
//  Created by 허지우 on 6/5/26.
//

import Foundation
import NearbyInteraction

final class mcniConnection {
    private let mcSession: MultipeerGameSession
    private let niManager: NearbyInteractionManager
    
    private var sessionEventTask: Task<Void, Error>?
    private var niTokenEventTask: Task<Void, Error>?
    
    init(mcManager: MultipeerGameSession, niManager: NearbyInteractionManager) {
        self.mcSession = mcManager
        self.niManager = niManager
        
        observeSessionEvents()
        observeNITokenEvents()
    }
    
    /// MC 연결 이벤트 구독 예정
    private func observeSessionEvents() {
        niTokenEventTask = Task { [weak self] in
            guard let self else { return}
            // 아직 브랜치 머지를 못해서 못 불러옴
            //for await event in mcSession.makeNIDiscoveryTokenStream() {
            //    niManager.run(with: event.token)
            //}
        }
    }
    
    /// NI token 이벤트 구독 예정
    private func observeNITokenEvents() {
        
    }
    
    deinit {
        sessionEventTask?.cancel()
        niTokenEventTask?.cancel()
    }
}

