//
//  LocalPeerIdentityStore.swift
//  hideandseek
//
//  Created by 서혜린 on 6/4/26.
//
//  LocalPeerIdentityStore.swift
//  hideandseek
//

import Foundation

/// 이 기기의 고유 PeerID를 로컬에 저장하고 불러오는 저장소.
/// rawID는 앱 최초 실행 시 UUID로 생성해 유지하고,
/// displayName은 화면 표시용 이름으로 외부에서 주입받는다.
struct LocalPeerIdentityStore {
    private enum Key {
        static let rawID = "hideandseek.localPeer.rawID"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadOrCreatePeerID(displayName: String) -> PeerID {
        let rawID = loadOrCreateRawID()

        return PeerID(
            rawID: rawID,
            displayName: displayName
        )
    }

    private func loadOrCreateRawID() -> String {
        if let storedRawID = userDefaults.string(forKey: Key.rawID) {
            return storedRawID
        }

        let newRawID = UUID().uuidString
        userDefaults.set(newRawID, forKey: Key.rawID)
        return newRawID
    }
}
