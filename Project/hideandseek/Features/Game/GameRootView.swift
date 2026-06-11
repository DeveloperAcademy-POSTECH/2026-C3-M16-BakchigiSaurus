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
            waitingView(title: gameModel.isLocalTagger ? "숨는 시간을 기다리는 중" : "숨을 시간이에요")

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
                    timeLeft: timeLeft
                ) {
                    Task {
                        await gameModel.send(.confirmCapture(hiderID: gameModel.localPlayerID))
                    }
                }
            }

        case .ended:
            waitingView(title: "게임이 종료됐어요")
        }
    }

    private var timeLeft: Int {
        gameModel.sharedState.remainingSeconds(at: currentDate)
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
