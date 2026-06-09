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
/// displayName은 앱 전용 랜덤 이름으로 생성해 유지한다.
struct LocalPeerIdentityStore {
    private enum Key {
        static let rawID = "hideandseek.localPeer.rawID"
        static let displayName = "hideandseek.localPeer.displayName"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadOrCreatePeerID(displayName: String? = nil) -> PeerID {
        let rawID = loadOrCreateRawID()
        let resolvedDisplayName = loadOrCreateDisplayName(
            preferredDisplayName: displayName
        )

        return PeerID(
            rawID: rawID,
            displayName: resolvedDisplayName
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

    private func loadOrCreateDisplayName(
        preferredDisplayName: String?
    ) -> String {
        if let preferredDisplayName {
            let trimmedName = preferredDisplayName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if !trimmedName.isEmpty {
                userDefaults.set(trimmedName, forKey: Key.displayName)
                return trimmedName
            }
        }

        if let storedDisplayName = userDefaults.string(forKey: Key.displayName),
           !storedDisplayName.isEmpty
        {
            return storedDisplayName
        }

        let randomDisplayName = makeRandomDisplayName()
        userDefaults.set(randomDisplayName, forKey: Key.displayName)
        return randomDisplayName
    }

    private func makeRandomDisplayName() -> String {
        let prefixes = [
            "반차쓴", "용감한", "재빠른", "반짝이는", "든든한", "휴가중인",
            "은밀한", "명랑한", "도도한", "연차쓴", "배고픈", "호기심많은",
            "친절한", "멋진", "귀여운", "행복한", "슬픈", "출근하기싫은",
            "코딩하기싫은", "게임하기싫은", "잠자기싫은", "디자인하기싫은"
        ]
        let suffixs = [
            "하워드", "MK", "곰민", "프라이데이", "루미", "지쿠", "리이오", "사야", "세니",
            "아이작", "수", "그웬", "스칼리", "제트", "링고", "제이슨", "주디", "도라", "재성"
        ]

        return "\(prefixes.randomElement() ?? "배고픈") \(suffixs.randomElement() ?? "하워드")"
    }
}
