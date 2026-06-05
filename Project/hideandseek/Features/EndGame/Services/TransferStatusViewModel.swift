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
        case waiting // 전송 시작 전
        case transferring // 전송 중
        case done // 수신 완료
        case failed // 실패
    }

    /// 푸터 표시 단계. 버튼 / 프로그레스바 / 완료 / 실패 중 "하나만" 노출하기 위함.
    enum Phase {
        case idle // 전송 시작 전 — "이대로 영상 만들기" 버튼
        case transferring // 전송 중 — 프로그레스바
        case completed // 전원 수신 완료
        case failed // 전송 실패 — "다시시도"
    }

    /// 리스트 한 행.
    struct Row: Identifiable {
        let peer: PeerID
        let isSeeker: Bool
        let status: Status
        var id: String {
            peer.rawID
        }
    }

    let title: String
    private let session: CollectorSession
    private let transfer: ClipTransferService
    private let seekerIDs: Set<String>
    private var hasStarted = false // ✅ 추가: 버튼 탭으로 전송이 시작됐는지
    private var didFail = false // ✅ 추가: 전송 실패 여부

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

    /// 참가자별 행. 수신되면 done, 시작 후 미수신이면 transferring, 시작 전이면 waiting.
    /// per-참가자 실시간 진행률·실패는 transport progress 이벤트 연결 후 정교화(후속).
    var rows: [Row] {
        session.connectedPeers.map { peer in
            let status: Status = if transfer.collected[peer] != nil {
                .done
            } else if hasStarted {
                .transferring // ✅ 시작 후에만 "전송중"
            } else {
                .waiting // ✅ 시작 전엔 "대기중" (스피너 X)
            }
            return Row(
                peer: peer,
                isSeeker: seekerIDs.contains(peer.rawID),
                status: status
            )
        }
    }

    /// 전체 진행률 (수집 완료 인원 / 전체).
    var overallProgress: Double {
        let total = session.connectedPeers.count
        guard total > 0 else { return 0 }
        let done = session.connectedPeers.count(where: { transfer.collected[$0] != nil })
        return Double(done) / Double(total)
    }

    /// 전원 수신 완료 여부.
    var isComplete: Bool {
        let peers = session.connectedPeers
        return !peers.isEmpty && peers.allSatisfy { transfer.collected[$0] != nil }
    }

    /// 호스트(수집자) 연결 상태. 끊기면 화면에 노출.
    var isHostReachable: Bool {
        session.isHostReachable
    }

    /// 푸터 단계. ✅ 버튼/프로그레스바가 동시에 안 뜨도록 단일 상태로 파생.
    var phase: Phase {
        if didFail { return .failed }
        if !hasStarted { return .idle } // ✅ 시작 전이면 버튼만
        if isComplete { return .completed }
        return .transferring // ✅ 시작 후에만 프로그레스바
    }

    /// "이대로 영상 만들기" — 전송 시작. ✅ 이 시점부터 프로그레스바가 노출된다.
    func start() {
        didFail = false
        hasStarted = true
    }

    /// "다시시도" — 실패 후 재시작.
    func retry() {
        didFail = false
        hasStarted = true
    }

    /// 전송 실패 처리 (transport 실패 이벤트 연결 후 호출).
    func markFailed() {
        didFail = true
    }
}
