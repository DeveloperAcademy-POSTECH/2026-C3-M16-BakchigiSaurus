//
//  GameRootView.swift
//  hideandseek
//
//  Created by KDHA on 6/3/26.
//

import SwiftUI

@MainActor
struct GameRootView: View {
    let gameModel: GameModel
    private let mcSession: MultipeerGameSession
    private let niManager: NearbyInteractionManager
    @State private var camera = CameraModel()
    @State private var photoStore = CapturedPhotoStore()
    @State private var currentDate = Date()
    @State private var taggerViewModel: TaggerSearchViewModel?
    @State private var hasConfirmedGameEnd = false
    @State private var collectorSession: CollectorSession?
    @State private var clipTransferService: ClipTransferService?
    @State private var transferViewModel: TransferStatusViewModel?

    init(
        gameModel: GameModel,
        mcSession: MultipeerGameSession,
        niManager: NearbyInteractionManager
    ) {
        self.gameModel = gameModel
        self.mcSession = mcSession
        self.niManager = niManager
        debugLog("init")
    }

    var body: some View {
        content
            .task {
                if gameModel.isLocalTagger {
                    ensureTaggerViewModelIfNeeded()
                }
                await camera.bootstrap()
            }
            .task {
                await runGameClock()
            }
            .onChange(of: gameModel.sharedState.phase) { _, newPhase in
                // 재경기 등으로 ended를 벗어나면 전송 화면 상태를 초기화한다.
                if newPhase != .ended {
                    hasConfirmedGameEnd = false
                    transferViewModel = nil
                    collectorSession = nil
                    clipTransferService = nil
                }
            }
            .onChange(of: gameModel.sharedState.phase, initial: true) { oldPhase, newPhase in
                debugLog(
                    "phase changed old=\(oldPhase) new=\(newPhase) " +
                        "isLocalTagger=\(gameModel.isLocalTagger) -> reset tagger proximity tracking"
                )
                guard gameModel.isLocalTagger || taggerViewModel != nil else { return }
                let taggerViewModel = ensureTaggerViewModelIfNeeded()
                taggerViewModel.resetProximityTracking(reason: "GameRootView phase change \(oldPhase)->\(newPhase)")

                if newPhase == .playing, gameModel.isLocalTagger {
                    taggerViewModel.activateProximityTracking(reason: "GameRootView playing phase")
                } else {
                    taggerViewModel.deactivateProximityTracking(reason: "GameRootView phase \(newPhase)")
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch gameModel.sharedState.phase {
        case .lobby:
            waitingView(title: "게임을 준비중이에요")

        case .hiding:
            if isInTaggerReveal {
                TaggerRevealView(gameModel: gameModel)
            } else {
                HidingTimerView(
                    time: (
                        remaining: Double(timeLeft),
                        total: Double(gameModel.sharedState.session.settings.hideTimeSeconds)
                    )
                )
            }

        case .playing:
            if gameModel.isLocalTagger {
                if let taggerViewModel {
                    TaggerSearchView(
                        camera: camera,
                        viewModel: taggerViewModel,
                        photoStore: photoStore,
                        timeLeft: timeLeft
                    )
                } else {
                    waitingView(title: "게임을 준비중이에요")
                }
            } else {
                HiderModeView(
                    camera: camera,
                    photoStore: photoStore,
                    timeLeft: timeLeft,
                    photographerID: gameModel.localParticipant?.id ?? gameModel.localPlayerID,
                    photographerName: gameModel.localParticipant?.name,
                    photographerRole: gameModel.localParticipant?.role ?? .hider
                ) {
                    Task {
                        await gameModel.send(.confirmCapture(hiderID: gameModel.localPlayerID))
                    }
                }
            }

        case .ended:
            EndGamePhotoShareView(
                gameModel: gameModel,
                mcSession: mcSession,
                photoStore: photoStore
            )
        }
    }

    private var timeLeft: Int {
        gameModel.sharedState.remainingSeconds(at: currentDate)
    }

    /// hiding 단계 도입부(룰렛 노출 구간)인지 여부. hideDeadline도 같은 시간만큼 늦춰져 있다.
    private var isInTaggerReveal: Bool {
        guard let startedAt = gameModel.sharedState.phaseStartedAt else { return false }
        return currentDate.timeIntervalSince(startedAt) < TimeInterval(RoomSettings.taggerRevealSeconds)
    }

    private func waitingView(title: String) -> some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                GameTimer(timeLeft: timeLeft)

                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
            }
        }
    }

    private func runGameClock() async {
        while !Task.isCancelled {
            let now = Date()
            currentDate = now
            await gameModel.send(.evaluateDeadlines(evaluatedAt: now))

            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    /// 전송 화면용 세션/서비스/뷰모델을 한 번만 만든다.
    private func ensureTransferViewModelIfNeeded() {
        guard transferViewModel == nil else { return }

        let collector = CollectorSession(session: mcSession)
        let transfer = ClipTransferService(transport: PendingClipTransport())
        let sharedState = gameModel.sharedState

        let seekerIDs = Set(
            sharedState.participants.values
                .filter { $0.role == .tagger }
                .compactMap { $0.peerID?.rawID }
        )

        collectorSession = collector
        clipTransferService = transfer
        transferViewModel = TransferStatusViewModel(
            title: "박치기 사우루스 숨바꼭질",
            session: collector,
            transfer: transfer,
            seekerIDs: seekerIDs,
            detailProvider: { [gameModel] peer in
                Self.captureDetail(for: peer, in: gameModel.sharedState)
            }
        )
    }

    /// "1:30 검거" 형태의 보조 텍스트. 검거되지 않았거나 시간을 알 수 없으면 nil.
    private static func captureDetail(for peer: PeerID, in state: GameState) -> String? {
        guard
            let participant = state.participants.values.first(where: { $0.peerID?.rawID == peer.rawID }),
            let capturedAt = participant.capturedAt,
            let playingStartedAt = state.playingStartedAt
        else { return nil }

        let elapsed = max(0, Int(capturedAt.timeIntervalSince(playingStartedAt)))
        return String(format: "%d:%02d 검거", elapsed / 60, elapsed % 60)
    }

    @discardableResult
    private func ensureTaggerViewModelIfNeeded() -> TaggerSearchViewModel {
        if let taggerViewModel {
            return taggerViewModel
        }

        let viewModel = TaggerSearchViewModel(
            gameModel: gameModel,
            mcSession: mcSession,
            niManager: niManager
        )
        taggerViewModel = viewModel

        if gameModel.sharedState.phase == .playing, gameModel.isLocalTagger {
            viewModel.activateProximityTracking(reason: "GameRootView created tagger view model")
        }

        return viewModel
    }

    private func debugLog(_ message: String) {
        #if DEBUG
            print("[GameRootView] \(message) phase=\(gameModel.sharedState.phase)")
        #endif
    }
}
