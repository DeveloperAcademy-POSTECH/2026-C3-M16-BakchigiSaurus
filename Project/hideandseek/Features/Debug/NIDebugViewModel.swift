//
//  NIDebugViewModel.swift
//  hideandseek
//
//  Created by 허지우 on 6/7/26.
//

import Combine
import Foundation

@MainActor
final class NIDebugViewModel: ObservableObject {
    private let session: MultipeerGameSession
    private let niManager: NearbyInteractionManager
    private let connection: McniConnection

    @Published private(set) var localPeer: PeerID
    @Published private(set) var hostPeer: PeerID
    @Published private(set) var currentPeers: [PeerID] = []
    @Published private(set) var discoveredPeers: [PeerID] = []
    @Published private(set) var logs: [String] = []

    @Published private(set) var distanceText = "-"
    @Published private(set) var directionText = "-"
    @Published var horizontalAngle: Float?

    init() {
        let session = MultipeerGameSession()
        let niManager = NearbyInteractionManager()

        self.session = session
        self.niManager = niManager
        self.connection = McniConnection(
            mcManager: session,
            niManager: niManager
        )

        self.localPeer = session.localPeer
        self.hostPeer = session.hostPeer

        refreshPeers()
        observeNIReadings()
    }

    func startHosting() {
        session.startHosting()
        appendLog("호스트 광고 시작")
        refreshPeers()
    }

    func stopHosting() {
        session.stopHosting()
        appendLog("호스트 광고 중지")
        refreshPeers()
    }

    func startBrowsing() {
        session.startBrowsing()
        appendLog("주변 호스트 탐색 시작")
        refreshPeers()
    }

    func stopBrowsing() {
        session.stopBrowsing()
        appendLog("주변 호스트 탐색 중지")
        refreshPeers()
    }

    func invite(_ peer: PeerID) {
        session.invite(peer)
        appendLog("초대 요청 전송: \(peer.displayName)")
        refreshPeers()
    }

    func refreshPeers() {
        localPeer = session.localPeer
        hostPeer = session.hostPeer
        currentPeers = session.currentPeers
        discoveredPeers = session.discoveredPeers
    }

    func stop() {
        session.stopHosting()
        session.stopBrowsing()
        niManager.invalidateSession()

        appendLog("MC 및 NI 세션 종료")
        refreshPeers()
    }

    private func observeNIReadings() {
        niManager.onReadingUpdated = { [weak self] reading in
            Task { @MainActor in
                self?.distanceText = reading.distance.map {
                    String(format: "%.2f m", $0)
                } ?? "-"

//                self?.directionText = reading.direction.map {
//                    "x: \($0.x), y: \($0.y), z: \($0.z)"
//                } ?? "-"
                if let angle = reading.horizontalAngle {
                    let degrees = angle * 180 / .pi
                    self?.directionText = String(
                        format: "%.1f°",
                        degrees
                    )
                    self?.horizontalAngle = angle
                } else {
                    self?.directionText = "-"
                    self?.horizontalAngle = nil
                }

                self?.appendLog("NI 거리/방향 업데이트")
            }
        }
    }

    private func appendLog(_ message: String) {
        logs.insert(message, at: 0)
    }
}
