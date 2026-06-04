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

/// GameSession 프로토콜을 실제 MultipeerConnectivity로 구현하는 클래스.
/// Feature 쪽은 이 구현체가 아니라 GameSession 인터페이스에 의존한다.
final class MultipeerGameSession: NSObject, GameSession, @unchecked Sendable {
    /// 주변 기기 탐색에 사용할 MC 서비스 이름.
    /// Info.plist의 Bonjour 서비스 이름과 맞아야 한다.
    private let serviceType = "hide-seek"

    /// MC 내부에서 사용하는 내 기기 식별자.
    private let localMCPeerID: MCPeerID

    /// 기기 간 연결과 추후 데이터 송수신을 담당하는 MC 세션.
    private let session: MCSession

    /// 연결 상태 변경을 순서대로 처리하기 위한 큐.
    private let stateQueue = DispatchQueue(label: "hideandseek.multipeer.session.state")

    /// 현재 MCSession에 연결된 peer 목록.
    private var connectedMCPeers: [MCPeerID] = []

    /// 연결/끊김 이벤트를 Feature로 전달하기 위한 AsyncStream continuation.
    private var eventContinuation: AsyncStream<SessionEvent>.Continuation?

    /// 호스트 광고를 담당하는 advertiser.
    private var advertiser: MCNearbyServiceAdvertiser?

    /// 주변에서 광고 중인 호스트를 탐색하는 브라우저.
    private var browser: MCNearbyServiceBrowser?

    /// 발견된 호스트를 Feature용 PeerID와 실제 MC용 MCPeerID로 매핑한다.
    private var discoveredMCPeers: [PeerID: MCPeerID] = [:]

    /// displayName 기준으로 이미 확인한 PeerID를 저장한다.
    /// 연결 이후에도 discoveryInfo에서 얻은 안정적인 rawID를 재사용하기 위해 사용한다.
    private var knownPeerIDsByDisplayName: [String: PeerID] = [:]

    /// GameSession 요구사항: 이 기기의 추상화된 식별자.
    let localPeer: PeerID

    /// GameSession 요구사항: 게임을 만든 호스트.
    private(set) var hostPeer: PeerID

    /// GameSession 요구사항: 현재 연결된 피어 목록.
    /// Feature에는 MCPeerID 대신 PeerID로 변환해서 제공한다.
    var currentPeers: [PeerID] {
        stateQueue.sync {
            let connectedPeers = connectedMCPeers.map { makeKnownPeerID(from: $0) }
            return uniquePeers([localPeer] + connectedPeers)
        }
    }

    /// 주변에서 발견된 호스트 목록.
    /// 현재 GameSession 프로토콜에는 포함되어 있지 않은 구현체 전용 상태다.
    var discoveredPeers: [PeerID] {
        stateQueue.sync {
            discoveredMCPeers.keys.sorted { $0.displayName < $1.displayName }
        }
    }

    /// MultipeerGameSession 생성자.
    /// - Parameters:
    ///   - displayName: 주변 기기에 표시될 이름.
    ///   - isHost: 현재 기기가 호스트인지 여부.
    init(
        displayName: String = UIDevice.current.name,
        isHost: Bool = true,
        peerIdentityStore: LocalPeerIdentityStore = LocalPeerIdentityStore()
    ) {
        let peer = peerIdentityStore.loadOrCreatePeerID(displayName: displayName)
        let mcPeerID = MCPeerID(displayName: peer.displayName)

        self.localMCPeerID = mcPeerID
        self.session = MCSession(
            peer: mcPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )

        self.localPeer = peer
        self.hostPeer = peer

        super.init()

        self.knownPeerIDsByDisplayName[mcPeerID.displayName] = peer

        // MCSession 연결 상태 변화를 이 클래스에서 받을 수 있게 설정한다.
        self.session.delegate = self

        if isHost {
            self.hostPeer = self.localPeer
        }
    }

    /// GameSession 요구사항: 연결 변화 이벤트 스트림 생성.
    func makeEventStream() -> AsyncStream<SessionEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }
}

private extension MultipeerGameSession {
    /// currentPeers에 같은 PeerID가 중복으로 들어가지 않도록 정리한다.
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

    /// stateQueue 안에서만 호출되는 호스트 광고 정리 함수.
    func stopHostingOnStateQueue() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
    }

    /// stateQueue 안에서만 호출되는 주변 호스트 탐색 정리 함수.
    func stopBrowsingOnStateQueue() {
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
        discoveredMCPeers.removeAll()
    }

    func makeKnownPeerID(from mcPeerID: MCPeerID) -> PeerID {
        knownPeerIDsByDisplayName[mcPeerID.displayName] ?? PeerID(mcPeerID: mcPeerID)
    }

    func makeDiscoveredPeerID(
        from peerID: MCPeerID,
        discoveryInfo: [String: String]?
    ) -> PeerID {
        PeerID(
            rawID: discoveryInfo?["hostRawID"] ?? peerID.displayName,
            displayName: discoveryInfo?["hostDisplayName"] ?? peerID.displayName
        )
    }
}

private extension PeerID {
    /// MC 내부 타입인 MCPeerID를 Feature용 PeerID로 변환한다.
    init(mcPeerID: MCPeerID) {
        self.rawID = mcPeerID.displayName
        self.displayName = mcPeerID.displayName
    }
}

extension MultipeerGameSession: MCSessionDelegate {
    /// MCSession의 연결 상태가 바뀔 때 호출된다.
    /// 연결되면 peerConnected, 끊기면 peerDisconnected 이벤트를 전달한다.
    func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        let peer = PeerID(mcPeerID: peerID)

        stateQueue.async {
            self.connectedMCPeers = session.connectedPeers

            switch state {
            case .connected:
                self.eventContinuation?.yield(.peerConnected(peer))

            case .notConnected:
                self.eventContinuation?.yield(.peerDisconnected(peer))

            case .connecting:
                break

            @unknown default:
                break
            }
        }
    }

    /// 현재 브랜치에서는 데이터 수신을 구현하지 않는다.
    /// 실제 클립/영상 송수신은 후속 브랜치에서 확장한다.
    func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {}

    /// 스트림 수신 콜백. 현재 브랜치에서는 사용하지 않는다.
    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    /// 리소스 수신 시작 콜백. 현재 브랜치에서는 사용하지 않는다.
    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    /// 리소스 수신 완료 콜백. 추후 파일/클립 전송에서 사용할 수 있다.
    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

extension MultipeerGameSession {
    /// 호스트가 주변 기기에 자신의 세션을 광고하기 시작한다.
    /// 방 만들기 플로우에서 호출되는 함수다.
    func startHosting() {
        stateQueue.async {
            self.stopHostingOnStateQueue()

            let discoveryInfo = [
                "hostRawID": self.localPeer.rawID,
                "hostDisplayName": self.localPeer.displayName
            ]

            let advertiser = MCNearbyServiceAdvertiser(
                peer: self.localMCPeerID,
                discoveryInfo: discoveryInfo,
                serviceType: self.serviceType
            )

            advertiser.delegate = self
            self.advertiser = advertiser
            advertiser.startAdvertisingPeer()
        }
    }

    /// 호스트 광고를 중지한다.
    /// 방 나가기, 게임 종료, 세션 초기화 시 호출할 수 있다.
    func stopHosting() {
        stateQueue.async {
            self.stopHostingOnStateQueue()
        }
    }

    /// 주변에서 광고 중인 호스트 탐색을 시작한다.
    /// 방 찾기 플로우에서 호출되는 함수다.
    func startBrowsing() {
        stateQueue.async {
            self.stopBrowsingOnStateQueue()

            let browser = MCNearbyServiceBrowser(
                peer: self.localMCPeerID,
                serviceType: self.serviceType
            )
            browser.delegate = self
            self.browser = browser
            browser.startBrowsingForPeers()
        }
    }

    /// 주변 호스트 탐색을 중지한다.
    /// 방 찾기 화면 이탈, 연결 완료, 세션 초기화 시 호출할 수 있다.
    func stopBrowsing() {
        stateQueue.async {
            self.stopBrowsingOnStateQueue()
        }
    }
}

extension MultipeerGameSession: MCNearbyServiceAdvertiserDelegate {
    /// 다른 peer가 이 호스트에게 참가 요청을 보냈을 때 호출된다.
    /// MVP에서는 별도 승인 UI 없이 자동 수락한다.
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(true, session)
    }

    /// 호스트 광고 시작에 실패했을 때 호출된다.
    /// 권한 설정이나 Bonjour serviceType 문제를 확인할 때 사용한다.
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        print("Failed to start advertising peer:", error.localizedDescription)
    }
}
extension MultipeerGameSession: MCNearbyServiceBrowserDelegate {
    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        let peer = makeDiscoveredPeerID(
            from: peerID,
            discoveryInfo: info
        )

        stateQueue.async {
            guard peer.rawID != self.localPeer.rawID else { return }

            self.discoveredMCPeers[peer] = peerID
            self.knownPeerIDsByDisplayName[peerID.displayName] = peer
        }
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {
        stateQueue.async {
            self.discoveredMCPeers = self.discoveredMCPeers.filter { _, storedPeerID in
                storedPeerID.displayName != peerID.displayName
            }
        }
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
        print("Failed to start browsing peers:", error.localizedDescription)
    }
}
