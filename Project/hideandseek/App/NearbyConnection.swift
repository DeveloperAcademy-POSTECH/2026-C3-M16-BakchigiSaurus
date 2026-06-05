//
//  NearbyConnection.swift
//  hideandseek
//
//  Created by 허지우 on 6/5/26.
//

import Foundation

final class NearbyConnection {
    private let mcManager: MultipeerGameSession
    private let niManager: NearbyInteractionManager

    private var peerTokenTask: Task<Void, Never>?

    init(mcManager: MultipeerGameSession, niManager: NearbyInteractionManager) {
        self.mcManager = mcManager
        self.niManager = niManager

        /// MC가 제공하는 peerTokenDataStream을 구독해서, Data가 들어올 때마다 NIManager로 넘기도록 연결하는 함수
        func observePeerTokenData() {
            peerTokenTask = Task { [weak self] in
                guard let self else { return }

                // for await peerTokenData in mcManager// Async{
                //         niManager.run(with: peerTokenData)
            }
        }
    }
}
