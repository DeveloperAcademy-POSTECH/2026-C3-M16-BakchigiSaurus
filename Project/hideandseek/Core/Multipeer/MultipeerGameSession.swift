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
@preconcurrency import MultipeerConnectivity
import NearbyInteraction
import UIKit

/// MC를 통해 수신한 NI DiscoveryToken 이벤트.
/// 어떤 peer에게서 받은 token인지 함께 전달한다.
struct NIDiscoveryTokenEvent {
    let peer: PeerID
    let token: NIDiscoveryToken
}

/// MC를 통해 수신한 게임 진행 메시지 이벤트.
/// 어떤 peer에게서 받은 메시지인지 함께 전달한다.
struct GameFlowMessageEvent {
    let peer: PeerID
    let message: GameFlowMessage
}

/// 게임 종료 후 각 기기가 자신의 촬영본을 묶어 보낼 때 사용하는 payload.
struct CapturedPhotoBatch: Codable {
    let gameID: UUID
    let sender: PeerID
    let photos: [CapturedPhoto]
    let sentAt: Date
}

/// MC를 통해 수신한 사진 배치 이벤트.
struct CapturedPhotoBatchEvent {
    let peer: PeerID
    let batch: CapturedPhotoBatch
}

/// 사진 수신 실패 시 상대에게 재전송을 요청하는 payload.
struct CapturedPhotoShareRequest: Codable {
    let gameID: UUID
    let requester: PeerID
    let requestedAt: Date
}

/// MC를 통해 수신한 사진 재전송 요청 이벤트.
struct CapturedPhotoShareRequestEvent {
    let peer: PeerID
    let request: CapturedPhotoShareRequest
}

/// 방 목록과 대기실 UI에서 사용하는 광고 스냅샷.
struct RoomLobbySnapshot: Identifiable, Hashable {
    let id: String
    let host: PeerID
    let name: String
    let currentCount: Int
    let maxCount: Int
    let hintCount: Int
    let hideTimeSeconds: Int
    let gameMinutes: Int

    var isFull: Bool {
        currentCount >= maxCount
    }
}

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

    /// 연결/끊김 이벤트를 여러 consumer가 동시에 구독할 수 있도록 continuation을 저장한다.
    private var eventContinuations: [UUID: AsyncStream<SessionEvent>.Continuation] = [:]

    /// MC로 수신한 NI DiscoveryToken 이벤트 구독자들.
    private var niTokenContinuations: [UUID: AsyncStream<NIDiscoveryTokenEvent>.Continuation] = [:]

    /// MC로 수신한 게임 진행 메시지 이벤트 구독자들.
    private var gameFlowMessageContinuations: [UUID: AsyncStream<GameFlowMessageEvent>.Continuation] = [:]

    /// MC로 수신한 촬영 사진 배치 이벤트 구독자들.
    private var photoBatchContinuations: [UUID: AsyncStream<CapturedPhotoBatchEvent>.Continuation] = [:]

    /// MC로 수신한 사진 재전송 요청 구독자들.
    private var photoShareRequestContinuations: [UUID: AsyncStream<CapturedPhotoShareRequestEvent>.Continuation] = [:]

    /// 종료 화면이 구독하기 전에 도착한 사진 배치를 잃지 않기 위한 최근 수신 버퍼.
    private var photoBatchEventsByGameAndSender: [String: CapturedPhotoBatchEvent] = [:]

    /// 호스트 광고를 담당하는 advertiser.
    private var advertiser: MCNearbyServiceAdvertiser?

    /// 주변에서 광고 중인 호스트를 탐색하는 브라우저.
    private var browser: MCNearbyServiceBrowser?

    /// 발견된 호스트를 rawID 기준으로 저장한다.
    private var discoveredPeersByRawID: [String: PeerID] = [:]

    /// 발견된 호스트의 rawID와 실제 MC용 MCPeerID를 매핑한다.
    private var discoveredMCPeersByRawID: [String: MCPeerID] = [:]

    /// 발견된 방 광고를 rawID 기준으로 저장한다.
    private var discoveredRoomsByID: [String: RoomLobbySnapshot] = [:]

    /// displayName 기준으로 이미 확인한 PeerID를 저장한다.
    /// 연결 이후에도 discoveryInfo에서 얻은 안정적인 rawID를 재사용하기 위해 사용한다.
    private var knownPeerIDsByDisplayName: [String: PeerID] = [:]

    /// 현재 기기가 호스트일 때 외부에 광고할 방 설정이다.
    private var hostedRoomSettings: RoomSettings?

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
            discoveredPeersByRawID.values.sorted { $0.displayName < $1.displayName }
        }
    }

    /// 주변에서 발견된 방 목록이다.
    var discoveredRooms: [RoomLobbySnapshot] {
        stateQueue.sync {
            discoveredRoomsByID.values.sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.host.displayName < rhs.host.displayName
                }

                return lhs.name < rhs.name
            }
        }
    }

    /// 현재 기기가 호스트일 때의 방 스냅샷이다.
    var hostedRoom: RoomLobbySnapshot {
        stateQueue.sync {
            makeHostedRoomSnapshot()
        }
    }

    /// MultipeerGameSession 생성자.
    /// - Parameters:
    ///   - displayName: 주변 기기에 표시될 이름.
    ///   - isHost: 현재 기기가 호스트인지 여부.
    init(
        displayName: String? = nil,
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

    func makeEventStream() -> AsyncStream<SessionEvent> {
        AsyncStream { continuation in
            let subscriberID = UUID()

            stateQueue.async {
                self.eventContinuations[subscriberID] = continuation
            }

            continuation.onTermination = { [weak self] _ in
                self?.stateQueue.async {
                    self?.eventContinuations.removeValue(forKey: subscriberID)
                }
            }
        }
    }

    /// MCSession을 통해 수신한 상대방의 NIDiscoveryToken 이벤트 스트림을 생성한다.
    /// NI 담당 객체는 이 스트림을 구독해 NINearbyPeerConfiguration에 사용할 token을 받을 수 있다.
    func makeNIDiscoveryTokenStream() -> AsyncStream<NIDiscoveryTokenEvent> {
        AsyncStream { continuation in
            let subscriberID = UUID()

            stateQueue.async {
                self.niTokenContinuations[subscriberID] = continuation
            }

            continuation.onTermination = { [weak self] _ in
                self?.stateQueue.async {
                    self?.niTokenContinuations.removeValue(forKey: subscriberID)
                }
            }
        }
    }

    /// MCSession을 통해 수신한 게임 진행 메시지 이벤트 스트림을 생성한다.
    /// Feature는 이 스트림을 구독해 게임 시작, 역할 배정, 탐색 시작 등의 이벤트를 받을 수 있다.
    func makeGameFlowMessageStream() -> AsyncStream<GameFlowMessageEvent> {
        AsyncStream { continuation in
            let subscriberID = UUID()

            stateQueue.async {
                self.gameFlowMessageContinuations[subscriberID] = continuation
            }

            continuation.onTermination = { [weak self] _ in
                self?.stateQueue.async {
                    self?.gameFlowMessageContinuations.removeValue(forKey: subscriberID)
                }
            }
        }
    }

    /// MCSession을 통해 수신한 사진 배치 이벤트 스트림을 생성한다.
    func makeCapturedPhotoBatchStream() -> AsyncStream<CapturedPhotoBatchEvent> {
        AsyncStream { continuation in
            let subscriberID = UUID()

            stateQueue.async {
                self.photoBatchContinuations[subscriberID] = continuation
                self.debugLog(
                    "photoBatchStream subscribed id=\(subscriberID) " +
                        "bufferedEvents=\(self.photoBatchEventsByGameAndSender.count)"
                )
                for event in self.photoBatchEventsByGameAndSender.values {
                    continuation.yield(event)
                }
            }

            continuation.onTermination = { [weak self] _ in
                self?.stateQueue.async {
                    self?.debugLog("photoBatchStream terminated id=\(subscriberID)")
                    self?.photoBatchContinuations.removeValue(forKey: subscriberID)
                }
            }
        }
    }

    /// MCSession을 통해 수신한 사진 재전송 요청 이벤트 스트림을 생성한다.
    func makeCapturedPhotoShareRequestStream() -> AsyncStream<CapturedPhotoShareRequestEvent> {
        AsyncStream { continuation in
            let subscriberID = UUID()

            stateQueue.async {
                self.photoShareRequestContinuations[subscriberID] = continuation
                self.debugLog("photoShareRequestStream subscribed id=\(subscriberID)")
            }

            continuation.onTermination = { [weak self] _ in
                self?.stateQueue.async {
                    self?.debugLog("photoShareRequestStream terminated id=\(subscriberID)")
                    self?.photoShareRequestContinuations.removeValue(forKey: subscriberID)
                }
            }
        }
    }
}

private extension MultipeerGameSession {
    enum DiscoveryKey {
        static let hostRawID = "hostRawID"
        static let hostDisplayName = "hostDisplayName"
        static let roomName = "roomName"
        static let currentCount = "roomCurrentCount"
        static let maxCount = "roomMaxCount"
        static let hintCount = "roomHintCount"
        static let hideTimeSeconds = "roomHideTimeSeconds"
        static let gameMinutes = "roomGameMinutes"
    }

    struct PeerIdentityContext: Codable {
        let peer: PeerID
    }

    /// currentPeers에 같은 PeerID가 중복으로 들어가지 않도록 정리한다.
    func uniquePeers(_ peers: [PeerID]) -> [PeerID] {
        var seenRawIDs = Set<String>()

        return peers.filter { peer in
            seenRawIDs.insert(peer.rawID).inserted
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
        discoveredPeersByRawID.removeAll()
        discoveredMCPeersByRawID.removeAll()
        discoveredRoomsByID.removeAll()
        yieldSessionEvent(.discoveredRoomsChanged)
    }

    func makeHostedRoomSnapshot() -> RoomLobbySnapshot {
        let fallbackName = "\(localPeer.displayName)의 방"
        let settings = hostedRoomSettings ?? RoomSettings(
            name: fallbackName,
            maxCount: RoomSettings.default.maxCount,
            hintCount: RoomSettings.default.hintCount,
            hideTimeSeconds: RoomSettings.default.hideTimeSeconds,
            gameMinutes: RoomSettings.default.gameMinutes,
            taggerSelectionPolicy: RoomSettings.default.taggerSelectionPolicy
        )
        let roomName = settings.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = roomName.isEmpty ? fallbackName : roomName

        return RoomLobbySnapshot(
            id: localPeer.rawID,
            host: localPeer,
            name: normalizedName,
            currentCount: min(settings.maxCount, max(1, connectedMCPeers.count + 1)),
            maxCount: settings.maxCount,
            hintCount: settings.hintCount,
            hideTimeSeconds: settings.hideTimeSeconds,
            gameMinutes: settings.gameMinutes
        )
    }

    func makeDiscoveryInfo(for room: RoomLobbySnapshot) -> [String: String] {
        [
            DiscoveryKey.hostRawID: room.host.rawID,
            DiscoveryKey.hostDisplayName: room.host.displayName,
            DiscoveryKey.roomName: room.name,
            DiscoveryKey.currentCount: String(room.currentCount),
            DiscoveryKey.maxCount: String(room.maxCount),
            DiscoveryKey.hintCount: String(room.hintCount),
            DiscoveryKey.hideTimeSeconds: String(room.hideTimeSeconds),
            DiscoveryKey.gameMinutes: String(room.gameMinutes)
        ]
    }

    func makeInvitationContext() -> Data? {
        try? JSONEncoder().encode(PeerIdentityContext(peer: localPeer))
    }

    func peerIdentity(from context: Data?) -> PeerID? {
        guard let context else { return nil }
        return try? JSONDecoder().decode(PeerIdentityContext.self, from: context).peer
    }

    /// 이미 discoveryInfo를 통해 알고 있는 PeerID가 있으면 해당 값을 사용한다.
    /// 없으면 MCPeerID의 displayName을 기반으로 fallback PeerID를 만든다.
    func makeKnownPeerID(from mcPeerID: MCPeerID) -> PeerID {
        knownPeerIDsByDisplayName[mcPeerID.displayName] ?? PeerID(mcPeerID: mcPeerID)
    }

    /// 연결된 peer 목록에서 Feature용 PeerID와 매칭되는 MCPeerID를 찾는다.
    /// MCSession.send는 MCPeerID를 요구하므로, PeerID를 내부 MC 타입으로 다시 매핑한다.
    func connectedMCPeer(for peer: PeerID) -> MCPeerID? {
        connectedMCPeers.first { mcPeerID in
            makeKnownPeerID(from: mcPeerID).rawID == peer.rawID
        }
    }

    /// 호스트가 광고한 discoveryInfo를 기반으로 Feature용 PeerID를 만든다.
    /// discoveryInfo가 없으면 MCPeerID의 displayName을 fallback으로 사용한다.
    func makeDiscoveredPeerID(
        from peerID: MCPeerID,
        discoveryInfo: [String: String]?
    ) -> PeerID {
        PeerID(
            rawID: discoveryInfo?[DiscoveryKey.hostRawID] ?? peerID.displayName,
            displayName: discoveryInfo?[DiscoveryKey.hostDisplayName] ?? peerID.displayName
        )
    }

    func makeDiscoveredRoom(
        from peerID: MCPeerID,
        discoveryInfo: [String: String]?
    ) -> RoomLobbySnapshot {
        let host = makeDiscoveredPeerID(
            from: peerID,
            discoveryInfo: discoveryInfo
        )
        let fallbackName = "\(host.displayName)의 방"

        return RoomLobbySnapshot(
            id: host.rawID,
            host: host,
            name: discoveryInfo?[DiscoveryKey.roomName] ?? fallbackName,
            currentCount: Int(
                discoveryInfo?[DiscoveryKey.currentCount] ?? ""
            ) ?? 1,
            maxCount: Int(
                discoveryInfo?[DiscoveryKey.maxCount] ?? ""
            ) ?? RoomSettings.default.maxCount,
            hintCount: Int(
                discoveryInfo?[DiscoveryKey.hintCount] ?? ""
            ) ?? RoomSettings.default.hintCount,
            hideTimeSeconds: Int(
                discoveryInfo?[DiscoveryKey.hideTimeSeconds] ?? ""
            ) ?? RoomSettings.default.hideTimeSeconds,
            gameMinutes: Int(
                discoveryInfo?[DiscoveryKey.gameMinutes] ?? ""
            ) ?? RoomSettings.default.gameMinutes
        )
    }

    func yieldSessionEvent(_ event: SessionEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    func yieldNITokenEvent(_ event: NIDiscoveryTokenEvent) {
        for continuation in niTokenContinuations.values {
            continuation.yield(event)
        }
    }

    func yieldGameFlowMessageEvent(_ event: GameFlowMessageEvent) {
        for continuation in gameFlowMessageContinuations.values {
            continuation.yield(event)
        }
    }

    func yieldCapturedPhotoBatchEvent(_ event: CapturedPhotoBatchEvent) {
        photoBatchEventsByGameAndSender[photoBatchKey(gameID: event.batch.gameID, sender: event.batch.sender)] = event
        debugLog(
            "yield photo batch sender=\(event.batch.sender.displayName)(\(event.batch.sender.rawID)) " +
                "gameID=\(event.batch.gameID) photos=\(event.batch.photos.count) " +
                "bytes=\(photoByteCount(event.batch.photos)) subscribers=\(photoBatchContinuations.count)"
        )

        for continuation in photoBatchContinuations.values {
            continuation.yield(event)
        }
    }

    func yieldCapturedPhotoShareRequestEvent(_ event: CapturedPhotoShareRequestEvent) {
        debugLog(
            "yield photo share request requester=\(event.request.requester.displayName)(\(event.request.requester.rawID)) " +
                "gameID=\(event.request.gameID) subscribers=\(photoShareRequestContinuations.count)"
        )

        for continuation in photoShareRequestContinuations.values {
            continuation.yield(event)
        }
    }

    func photoBatchKey(gameID: UUID, sender: PeerID) -> String {
        "\(gameID.uuidString)|\(sender.rawID)"
    }

    func photoByteCount(_ photos: [CapturedPhoto]) -> Int {
        photos.reduce(0) { $0 + $1.imageData.count }
    }

    func debugLog(_ message: String) {
        #if DEBUG
            print("[MultipeerGameSession] \(message)")
        #endif
    }

    func sendLocalPeerIdentityOnStateQueue(to targetPeers: [MCPeerID]) {
        guard !targetPeers.isEmpty else { return }

        do {
            let payload = try JSONEncoder().encode(localPeer)
            let message = MultipeerMessage(
                kind: .peerIdentity,
                payload: payload
            )
            let messageData = try JSONEncoder().encode(message)

            try session.send(
                messageData,
                toPeers: targetPeers,
                with: .reliable
            )
        } catch {
            print("Failed to send local peer identity:", error.localizedDescription)
        }
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
        stateQueue.async {
            let peer = self.makeKnownPeerID(from: peerID)
            self.connectedMCPeers = session.connectedPeers

            switch state {
            case .connected:
                self.knownPeerIDsByDisplayName[peerID.displayName] = peer
                self.stopBrowsingOnStateQueue()
                self.sendLocalPeerIdentityOnStateQueue(to: session.connectedPeers)
                self.yieldSessionEvent(.peerConnected(peer))
                Task { @MainActor in
                    self.refreshHostingAdvertisementIfNeeded()
                }

            case .notConnected:
                self.yieldSessionEvent(.peerDisconnected(peer))
                Task { @MainActor in
                    self.refreshHostingAdvertisementIfNeeded()
                }

            case .connecting:
                break

            @unknown default:
                break
            }
        }
    }

    /// MCSession으로 수신한 data를 앱 내부 메시지로 해석한다.
    /// 현재는 NI DiscoveryToken 메시지와 게임 플로우 메시지를 복원해 각각의 수신 스트림으로 전달한다.
    func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        stateQueue.async {
            do {
                let message = try JSONDecoder().decode(
                    MultipeerMessage.self,
                    from: data
                )

                switch message.kind {
                case .peerIdentity:
                    let peerIdentity = try JSONDecoder().decode(
                        PeerID.self,
                        from: message.payload
                    )
                    let previousPeer = self.makeKnownPeerID(from: peerID)

                    self.knownPeerIDsByDisplayName[peerID.displayName] = peerIdentity
                    if previousPeer.rawID != peerIdentity.rawID {
                        self.yieldSessionEvent(.peerConnected(peerIdentity))
                    } else {
                        self.yieldSessionEvent(.discoveredRoomsChanged)
                    }

                case .niDiscoveryToken:
                    let token = try NIDiscoveryTokenCoding.decode(
                        from: message.payload
                    )
                    let peer = self.makeKnownPeerID(from: peerID)

                    self.yieldNITokenEvent(
                        NIDiscoveryTokenEvent(
                            peer: peer,
                            token: token
                        )
                    )

                case .gameFlowMessage:
                    let gameFlowMessage = try JSONDecoder().decode(
                        GameFlowMessage.self,
                        from: message.payload
                    )
                    let peer = self.makeKnownPeerID(from: peerID)

                    self.yieldGameFlowMessageEvent(
                        GameFlowMessageEvent(
                            peer: peer,
                            message: gameFlowMessage
                        )
                    )

                case .capturedPhotoBatch:
                    let batch = try JSONDecoder().decode(
                        CapturedPhotoBatch.self,
                        from: message.payload
                    )
                    self.knownPeerIDsByDisplayName[peerID.displayName] = batch.sender
                    self.debugLog(
                        "received photo batch mcPeer=\(peerID.displayName) " +
                            "sender=\(batch.sender.displayName)(\(batch.sender.rawID)) " +
                            "gameID=\(batch.gameID) photos=\(batch.photos.count) " +
                            "payloadBytes=\(message.payload.count) photoBytes=\(self.photoByteCount(batch.photos))"
                    )

                    self.yieldCapturedPhotoBatchEvent(
                        CapturedPhotoBatchEvent(
                            peer: batch.sender,
                            batch: batch
                        )
                    )

                case .capturedPhotoShareRequest:
                    let request = try JSONDecoder().decode(
                        CapturedPhotoShareRequest.self,
                        from: message.payload
                    )
                    self.knownPeerIDsByDisplayName[peerID.displayName] = request.requester
                    self.debugLog(
                        "received photo share request mcPeer=\(peerID.displayName) " +
                            "requester=\(request.requester.displayName)(\(request.requester.rawID)) " +
                            "gameID=\(request.gameID) payloadBytes=\(message.payload.count)"
                    )

                    self.yieldCapturedPhotoShareRequestEvent(
                        CapturedPhotoShareRequestEvent(
                            peer: request.requester,
                            request: request
                        )
                    )
                }
            } catch {
                print("Failed to handle received multipeer data:", error.localizedDescription)
            }
        }
    }

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
    func configureHostedRoom(with settings: RoomSettings) {
        stateQueue.sync {
            self.hostedRoomSettings = settings
        }

        refreshHostingAdvertisementIfNeeded()
    }

    func disconnect() {
        stateQueue.async {
            self.stopHostingOnStateQueue()
            self.stopBrowsingOnStateQueue()
            self.session.disconnect()
            self.connectedMCPeers.removeAll()
            self.hostPeer = self.localPeer
            self.hostedRoomSettings = nil
        }
    }

    private func refreshHostingAdvertisementIfNeeded(force: Bool = false) {
        let shouldRefresh = stateQueue.sync {
            force || self.advertiser != nil
        }

        guard shouldRefresh else { return }

        Task { @MainActor in
            let hostedRoom = self.stateQueue.sync {
                self.makeHostedRoomSnapshot()
            }
            let advertiser = MCNearbyServiceAdvertiser(
                peer: self.localMCPeerID,
                discoveryInfo: self.makeDiscoveryInfo(for: hostedRoom),
                serviceType: self.serviceType
            )

            advertiser.delegate = self

            self.stateQueue.async {
                self.stopHostingOnStateQueue()
                self.advertiser = advertiser
                advertiser.startAdvertisingPeer()
            }
        }
    }

    /// 호스트가 주변 기기에 자신의 세션을 광고하기 시작한다.
    /// 방 만들기 플로우에서 호출되는 함수다.
    func startHosting() {
        refreshHostingAdvertisementIfNeeded(force: true)
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
        Task { @MainActor in
            let browser = MCNearbyServiceBrowser(
                peer: self.localMCPeerID,
                serviceType: self.serviceType
            )

            browser.delegate = self

            self.stateQueue.async {
                self.stopBrowsingOnStateQueue()
                self.browser = browser
                browser.startBrowsingForPeers()
            }
        }
    }

    /// 주변 호스트 탐색을 중지한다.
    /// 방 찾기 화면 이탈, 연결 완료, 세션 초기화 시 호출할 수 있다.
    func stopBrowsing() {
        stateQueue.async {
            self.stopBrowsingOnStateQueue()
        }
    }

    /// 발견된 호스트에게 참가 요청을 보낸다.
    func invite(_ peer: PeerID, timeout: TimeInterval = 10) {
        stateQueue.async {
            guard let mcPeerID = self.discoveredMCPeersByRawID[peer.rawID] else {
                print("Failed to invite peer. MCPeerID not found:", peer.displayName)
                return
            }

            self.hostPeer = peer
            self.browser?.invitePeer(
                mcPeerID,
                to: self.session,
                withContext: self.makeInvitationContext(),
                timeout: timeout
            )
        }
    }

    /// NI 담당 코드에서 생성한 localDiscoveryToken을 연결된 peer에게 전송한다.
    /// peer를 지정하지 않으면 현재 연결된 모든 peer에게 전송한다.
    func sendNIDiscoveryToken(
        _ token: NIDiscoveryToken,
        to peer: PeerID? = nil
    ) {
        stateQueue.async {
            do {
                let tokenData = try NIDiscoveryTokenCoding.encode(token)
                let message = MultipeerMessage(
                    kind: .niDiscoveryToken,
                    payload: tokenData
                )
                let messageData = try JSONEncoder().encode(message)

                let targetPeers: [MCPeerID]
                if let peer {
                    guard let targetPeer = self.connectedMCPeer(for: peer) else {
                        print("Failed to send NI token. MCPeerID not found:", peer.displayName)
                        return
                    }

                    targetPeers = [targetPeer]
                } else {
                    targetPeers = self.session.connectedPeers
                }

                guard !targetPeers.isEmpty else {
                    print("Failed to send NI token. No connected peers.")
                    return
                }

                try self.session.send(
                    messageData,
                    toPeers: targetPeers,
                    with: .reliable
                )
            } catch {
                print("Failed to send NI token:", error.localizedDescription)
            }
        }
    }

    /// 게임 진행 메시지를 연결된 peer에게 전송한다.
    /// peer를 지정하지 않으면 현재 연결된 모든 peer에게 전송한다.
    func sendGameFlowMessage(
        _ gameFlowMessage: GameFlowMessage,
        to peer: PeerID? = nil
    ) {
        stateQueue.async {
            do {
                let payload = try JSONEncoder().encode(gameFlowMessage)
                let message = MultipeerMessage(
                    kind: .gameFlowMessage,
                    payload: payload
                )
                let messageData = try JSONEncoder().encode(message)

                let targetPeers: [MCPeerID]
                if let peer {
                    guard let targetPeer = self.connectedMCPeer(for: peer) else {
                        print("Failed to send game flow message. MCPeerID not found:", peer.displayName)
                        return
                    }

                    targetPeers = [targetPeer]
                } else {
                    targetPeers = self.session.connectedPeers
                }

                guard !targetPeers.isEmpty else {
                    print("Failed to send game flow message. No connected peers.")
                    return
                }

                try self.session.send(
                    messageData,
                    toPeers: targetPeers,
                    with: .reliable
                )
            } catch {
                print("Failed to send game flow message:", error.localizedDescription)
            }
        }
    }

    /// 게임 종료 후 촬영 사진 묶음을 연결된 peer에게 전송한다.
    /// 빈 사진 배열도 전송해서 수신 측이 "이 참여자는 보낼 사진이 없음"을 완료 상태로 알 수 있게 한다.
    func sendCapturedPhotos(
        _ photos: [CapturedPhoto],
        gameID: UUID,
        to peer: PeerID? = nil
    ) {
        stateQueue.async {
            let targetPeers: [MCPeerID]
            if let peer {
                guard let targetPeer = self.connectedMCPeer(for: peer) else {
                    self.debugLog("failed photo batch send: MCPeerID not found peer=\(peer.displayName)")
                    return
                }

                targetPeers = [targetPeer]
            } else {
                targetPeers = self.session.connectedPeers
            }

            guard !targetPeers.isEmpty else {
                self.debugLog(
                    "skipped photo batch send: no connected peers " +
                        "gameID=\(gameID) photos=\(photos.count) photoBytes=\(self.photoByteCount(photos))"
                )
                return
            }

            let photoChunks: [[CapturedPhoto]] = photos.isEmpty ? [[]] : photos.map { [$0] }
            for (index, chunk) in photoChunks.enumerated() {
                do {
                    let batch = CapturedPhotoBatch(
                        gameID: gameID,
                        sender: self.localPeer,
                        photos: chunk,
                        sentAt: Date()
                    )
                    let payload = try JSONEncoder().encode(batch)
                    let message = MultipeerMessage(
                        kind: .capturedPhotoBatch,
                        payload: payload
                    )
                    let messageData = try JSONEncoder().encode(message)

                    self.debugLog(
                        "send photo batch gameID=\(gameID) chunk=\(index + 1)/\(photoChunks.count) " +
                            "photos=\(chunk.count) totalPhotos=\(photos.count) " +
                            "photoBytes=\(self.photoByteCount(chunk)) payloadBytes=\(payload.count) " +
                            "messageBytes=\(messageData.count) targets=\(targetPeers.map(\.displayName))"
                    )
                    try self.session.send(
                        messageData,
                        toPeers: targetPeers,
                        with: .reliable
                    )
                    self.debugLog(
                        "send photo batch succeeded chunk=\(index + 1)/\(photoChunks.count) " +
                            "targets=\(targetPeers.map(\.displayName))"
                    )
                } catch {
                    self.debugLog(
                        "failed to send photo batch chunk=\(index + 1)/\(photoChunks.count): " +
                            error.localizedDescription
                    )
                }
            }
        }
    }

    /// 사진 수신 실패 시 상대에게 사진 재전송을 요청한다.
    func sendCapturedPhotoShareRequest(
        gameID: UUID,
        to peer: PeerID? = nil
    ) {
        stateQueue.async {
            do {
                let request = CapturedPhotoShareRequest(
                    gameID: gameID,
                    requester: self.localPeer,
                    requestedAt: Date()
                )
                let payload = try JSONEncoder().encode(request)
                let message = MultipeerMessage(
                    kind: .capturedPhotoShareRequest,
                    payload: payload
                )
                let messageData = try JSONEncoder().encode(message)

                let targetPeers: [MCPeerID]
                if let peer {
                    guard let targetPeer = self.connectedMCPeer(for: peer) else {
                        self.debugLog("failed photo share request: MCPeerID not found peer=\(peer.displayName)")
                        return
                    }

                    targetPeers = [targetPeer]
                } else {
                    targetPeers = self.session.connectedPeers
                }

                guard !targetPeers.isEmpty else {
                    self.debugLog("skipped photo share request: no connected peers gameID=\(gameID)")
                    return
                }

                self.debugLog(
                    "send photo share request gameID=\(gameID) payloadBytes=\(payload.count) " +
                        "messageBytes=\(messageData.count) targets=\(targetPeers.map(\.displayName))"
                )
                try self.session.send(
                    messageData,
                    toPeers: targetPeers,
                    with: .reliable
                )
                self.debugLog("send photo share request succeeded targets=\(targetPeers.map(\.displayName))")
            } catch {
                self.debugLog("failed to send photo share request: \(error.localizedDescription)")
            }
        }
    }

    /// 게임 시작 메시지를 전송한다.
    func sendGameStarted(
        participants: [PeerID]? = nil,
        taggerPeer: PeerID? = nil,
        to peer: PeerID? = nil
    ) {
        sendGameFlowMessage(
            .gameStarted(
                participants: participants,
                taggerPeer: taggerPeer
            ),
            to: peer
        )
    }

    /// 역할 배정 메시지를 전송한다.
    func sendRoleAssigned(
        _ role: GameFlowRole,
        taggerPeer: PeerID? = nil,
        to peer: PeerID? = nil
    ) {
        sendGameFlowMessage(
            .roleAssigned(role, taggerPeer: taggerPeer),
            to: peer
        )
    }

    /// 카운트다운 시작 메시지를 전송한다.
    func sendCountdownStarted(
        seconds: Int,
        to peer: PeerID? = nil
    ) {
        sendGameFlowMessage(
            .countdownStarted(seconds: seconds),
            to: peer
        )
    }

    /// 탐색 시작 메시지를 전송한다.
    func sendSearchStarted(to peer: PeerID? = nil) {
        sendGameFlowMessage(
            .searchStarted(),
            to: peer
        )
    }

    /// 특정 peer를 찾았다는 메시지를 전송한다.
    func sendPlayerFound(
        _ peer: PeerID,
        to targetPeer: PeerID? = nil
    ) {
        sendGameFlowMessage(
            .playerFound(peer),
            to: targetPeer
        )
    }

    /// 게임 종료 메시지를 전송한다.
    func sendGameEnded(
        winner: GameFlowWinner,
        to peer: PeerID? = nil
    ) {
        sendGameFlowMessage(
            .gameEnded(winner: winner),
            to: peer
        )
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
        stateQueue.async {
            let peer = self.peerIdentity(from: context) ?? PeerID(mcPeerID: peerID)
            self.knownPeerIDsByDisplayName[peerID.displayName] = peer

            let room = self.makeHostedRoomSnapshot()
            let isAlreadyConnected = self.connectedMCPeers.contains { connectedPeer in
                connectedPeer.displayName == peerID.displayName
            }
            let canAccept = isAlreadyConnected || room.currentCount < room.maxCount

            invitationHandler(canAccept, canAccept ? self.session : nil)
        }
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
    // 주변에서 호스트 peer를 발견했을 때 호출된다.
    // discoveryInfo를 기반으로 PeerID를 만들고, 실제 invite에 필요한 MCPeerID와 매핑한다.

    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        let peer = makeDiscoveredPeerID(
            from: peerID,
            discoveryInfo: info
        )
        let room = makeDiscoveredRoom(
            from: peerID,
            discoveryInfo: info
        )

        stateQueue.async {
            guard peer.rawID != self.localPeer.rawID else { return }

            self.discoveredPeersByRawID[peer.rawID] = peer
            self.discoveredMCPeersByRawID[peer.rawID] = peerID
            self.discoveredRoomsByID[room.id] = room
            self.knownPeerIDsByDisplayName[peerID.displayName] = peer
            self.yieldSessionEvent(.discoveredRoomsChanged)
        }
    }

    /// 탐색 중이던 호스트 peer가 사라졌을 때 호출된다.
    /// 저장된 rawID 기준 매핑에서 해당 peer를 제거한다.
    func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {
        stateQueue.async {
            if let knownPeer = self.knownPeerIDsByDisplayName[peerID.displayName] {
                self.discoveredPeersByRawID.removeValue(forKey: knownPeer.rawID)
                self.discoveredMCPeersByRawID.removeValue(forKey: knownPeer.rawID)
                self.discoveredRoomsByID.removeValue(forKey: knownPeer.rawID)
                self.yieldSessionEvent(.discoveredRoomsChanged)
                return
            }

            let rawIDs = self.discoveredMCPeersByRawID
                .filter { _, storedPeerID in
                    storedPeerID.displayName == peerID.displayName
                }
                .map { rawID, _ in
                    rawID
                }

            for rawID in rawIDs {
                self.discoveredPeersByRawID.removeValue(forKey: rawID)
                self.discoveredMCPeersByRawID.removeValue(forKey: rawID)
                self.discoveredRoomsByID.removeValue(forKey: rawID)
            }

            self.yieldSessionEvent(.discoveredRoomsChanged)
        }
    }

    /// 주변 호스트 탐색 시작에 실패했을 때 호출된다.
    func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
        print("Failed to start browsing peers:", error.localizedDescription)
    }
}
