//
//  TransferStatusViewModel.swift
//  hideandseek
//
//  Created by Gosan on 6/4/26.
//

import Foundation

/// 전송 현황 화면용 ViewModel.
/// CollectorSession(참가자 목록)과 ClipTransferService(수집 현황)에서
/// 참가자별 상태와 전체 진행률을 파생한다.
@MainActor
@Observable
final class TransferStatusViewModel {
    /// 참가자별 전송 상태.
    enum Status {
        case transferring
        case done
        case failed
    }

    /// 리스트 한 행.
    struct Row: Identifiable {
        let peer: PeerID
        let isSeeker: Bool
        let status: Status
        var id: String { peer.rawID }
    }

    let title: String
    private let session: CollectorSession
    private let transfer: ClipTransferService
    private let seekerIDs: Set<String>

    init(
        title: String,
        session: CollectorSession,
        transfer: ClipTransferService,
        seekerIDs: Set<String> = []
    ) {
        self.title = title
        self.session = session
        self.transfer = transfer
        self.seekerIDs = seekerIDs
    }

    /// 참가자별 행. 수집 완료면 done, 아직이면 transferring.
    /// 실시간 "전송중 %"·per-참가자 "실패"는 transport progress 이벤트 연결 후 정교화(후속).
    var rows: [Row] {
        session.connectedPeers.map { peer in
            let done = transfer.collected[peer] != nil
            return Row(
                peer: peer,
                isSeeker: seekerIDs.contains(peer.rawID),
                status: done ? .done : .transferring
            )
        }
    }

    /// 전체 진행률 (수집 완료 인원 / 전체).
    var overallProgress: Double {
        let total = session.connectedPeers.count
        guard total > 0 else { return 0 }
        let done = session.connectedPeers.filter { transfer.collected[$0] != nil }.count
        return Double(done) / Double(total)
    }

    /// 전원 수신 완료 여부.
    var isComplete: Bool {
        let peers = session.connectedPeers
        return !peers.isEmpty && peers.allSatisfy { transfer.collected[$0] != nil }
    }

    /// 호스트(수집자) 연결 상태. 끊기면 화면에 노출.
    var isHostReachable: Bool { session.isHostReachable }
}
