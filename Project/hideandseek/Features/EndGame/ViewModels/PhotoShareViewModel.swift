//
//  PhotoShareViewModel.swift
//  hideandseek
//
//  게임 종료 후 각 참여자가 촬영한 사진 묶음을 서로 공유하고,
//  스토리 재생 전 수집 상태를 관리한다.
//

import Foundation
import Observation

@MainActor
@Observable
final class PhotoShareViewModel {
    enum Status {
        case waiting
        case received
        case noPhotos
        case failed
    }

    struct Row: Identifiable {
        let peer: PeerID
        let role: PlayerRole
        let status: Status
        let photoCount: Int

        var id: String {
            peer.rawID
        }
    }

    private struct ParticipantSnapshot: Hashable {
        let peer: PeerID
        let role: PlayerRole
    }

    private let session: MultipeerGameSession
    private let photoStore: CapturedPhotoStore
    private let gameID: UUID
    private let participants: [ParticipantSnapshot]
    private let timeoutSeconds: TimeInterval
    private let collectionStartedAt = Date()
    private let acceptedBatchAgeBeforeCollection: TimeInterval = 120

    private var receivedPeerRawIDs: Set<String> = []
    private var failedPeerRawIDs: Set<String> = []
    private var photoCountByPeerRawID: [String: Int] = [:]
    private var receivedPhotoIDsByPeerRawID: [String: Set<UUID>] = [:]
    private var receiveTask: Task<Void, Never>?
    private var requestTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var didStartSharing = false

    init(
        gameModel: GameModel,
        session: MultipeerGameSession,
        photoStore: CapturedPhotoStore,
        timeoutSeconds: TimeInterval = 12
    ) {
        self.session = session
        self.photoStore = photoStore
        self.gameID = gameModel.sharedState.session.id
        self.timeoutSeconds = timeoutSeconds

        let localPeer = session.localPeer
        let snapshots = gameModel.participants.compactMap { participant -> ParticipantSnapshot? in
            let peer = participant.peerID ?? (participant.id == gameModel.localPlayerID ? localPeer : nil)
            guard let peer else { return nil }
            return ParticipantSnapshot(peer: peer, role: participant.role)
        }

        var seenRawIDs = Set<String>()
        self.participants = snapshots.filter { snapshot in
            seenRawIDs.insert(snapshot.peer.rawID).inserted
        }

    }

    var rows: [Row] {
        participants.map { participant in
            let rawID = participant.peer.rawID
            let status: Status = if failedPeerRawIDs.contains(rawID) {
                .failed
            } else if receivedPeerRawIDs.contains(rawID) {
                (photoCountByPeerRawID[rawID] ?? 0) > 0 ? .received : .noPhotos
            } else {
                .waiting
            }

            return Row(
                peer: participant.peer,
                role: participant.role,
                status: status,
                photoCount: photoCountByPeerRawID[rawID] ?? 0
            )
        }
    }

    var progress: Double {
        guard !participants.isEmpty else { return 1 }
        let completedCount = receivedPeerRawIDs.count + failedPeerRawIDs.count
        return min(1, Double(completedCount) / Double(participants.count))
    }

    var isFinishedCollecting: Bool {
        guard !participants.isEmpty else { return true }
        return receivedPeerRawIDs.count + failedPeerRawIDs.count >= participants.count
    }

    var hasFailures: Bool {
        !failedPeerRawIDs.isEmpty
    }

    var canRetry: Bool {
        hasFailures
    }

    var hasPhotos: Bool {
        !photoStore.isEmpty
    }

    func startSharingIfNeeded() {
        guard !didStartSharing else {
            return
        }
        didStartSharing = true

        let localPeer = session.localPeer
        markReceived(peer: localPeer, photoCount: photoStore.photos.count)
        observeIncomingBatches()
        observeIncomingRequests()
        session.sendCapturedPhotos(photoStore.photos, gameID: gameID)
        scheduleTimeout()
    }

    func retryFailedTransfers() {
        let retryTargets = participants.filter { participant in
            participant.peer.rawID != session.localPeer.rawID &&
                (failedPeerRawIDs.isEmpty || failedPeerRawIDs.contains(participant.peer.rawID))
        }

        guard !retryTargets.isEmpty else {
            return
        }


        for participant in retryTargets {
            failedPeerRawIDs.remove(participant.peer.rawID)
            session.sendCapturedPhotoShareRequest(gameID: gameID, to: participant.peer)
            session.sendCapturedPhotos(photoStore.photos, gameID: gameID, to: participant.peer)
        }

        scheduleTimeout()
    }

    func cancel() {
        receiveTask?.cancel()
        receiveTask = nil
        requestTask?.cancel()
        requestTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    private func observeIncomingBatches() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self, session] in
            for await event in session.makeCapturedPhotoBatchStream() {
                await self?.handle(event)
            }
        }
    }

    private func observeIncomingRequests() {
        requestTask?.cancel()
        requestTask = Task { [weak self, session] in
            for await event in session.makeCapturedPhotoShareRequestStream() {
                await self?.handle(event)
            }
        }
    }

    private func handle(_ event: CapturedPhotoBatchEvent) {
        guard isExpectedParticipant(event.batch.sender) else {
            return
        }
        guard isRecentEnough(event.batch.sentAt) else {
            return
        }
        if event.batch.gameID != gameID {
        }

        photoStore.mergeRemote(event.batch.photos)
        let peerRawID = event.batch.sender.rawID
        var receivedPhotoIDs = receivedPhotoIDsByPeerRawID[peerRawID] ?? []
        for photo in event.batch.photos {
            receivedPhotoIDs.insert(photo.id)
        }
        receivedPhotoIDsByPeerRawID[peerRawID] = receivedPhotoIDs

        markReceived(
            peer: event.batch.sender,
            photoCount: receivedPhotoIDs.count
        )
    }

    private func handle(_ event: CapturedPhotoShareRequestEvent) {
        guard isExpectedParticipant(event.request.requester) else {
            return
        }
        guard isRecentEnough(event.request.requestedAt) else {
            return
        }
        if event.request.gameID != gameID {
        }

        session.sendCapturedPhotos(photoStore.photos, gameID: gameID, to: event.request.requester)
    }

    private func markReceived(peer: PeerID, photoCount: Int) {
        receivedPeerRawIDs.insert(peer.rawID)
        failedPeerRawIDs.remove(peer.rawID)
        photoCountByPeerRawID[peer.rawID] = photoCount
    }

    private func scheduleTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.markMissingPeersFailed()
            }
        }
    }

    private func markMissingPeersFailed() {
        for participant in participants {
            let rawID = participant.peer.rawID
            guard !receivedPeerRawIDs.contains(rawID) else { continue }
            failedPeerRawIDs.insert(rawID)
        }
    }

    private func isExpectedParticipant(_ peer: PeerID) -> Bool {
        participants.contains { $0.peer.rawID == peer.rawID }
    }

    private func isRecentEnough(_ date: Date) -> Bool {
        date >= collectionStartedAt.addingTimeInterval(-acceptedBatchAgeBeforeCollection)
    }

}

private extension [CapturedPhoto] {
    var totalImageBytes: Int {
        reduce(0) { $0 + $1.imageData.count }
    }
}
