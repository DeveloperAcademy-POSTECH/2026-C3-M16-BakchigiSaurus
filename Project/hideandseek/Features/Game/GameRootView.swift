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
    @State private var camera = CameraModel()
    @State private var currentDate = Date()
    @State private var taggerViewModel: TaggerSearchViewModel

    init(
        gameModel: GameModel,
        mcSession: MultipeerGameSession,
        niManager: NearbyInteractionManager
    ) {
        self.gameModel = gameModel
        _taggerViewModel = State(
            initialValue: TaggerSearchViewModel(
                gameModel: gameModel,
                mcSession: mcSession,
                niManager: niManager
            )
        )
    }

    var body: some View {
        content
            .task {
                await camera.bootstrap()
            }
            .task {
                await runGameClock()
            }
            .onChange(of: gameModel.sharedState.phase, initial: true) { _, _ in
                taggerViewModel.resetProximityTracking()
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
                TaggerSearchView(
                    camera: camera,
                    viewModel: taggerViewModel,
                    timeLeft: timeLeft
                )
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
}
