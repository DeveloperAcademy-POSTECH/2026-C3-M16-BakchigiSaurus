//
//  TaggerSearchView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import Foundation
import SwiftUI

struct TaggerSearchView: View {
    // 💡 1. 뷰모델을 관찰 가능한 상태로 소유합니다.
    @State private var viewModel: TaggerSearchViewModel
    @State private var showHintAlert: Bool = false
    @State private var activeHintResult: HintDisplayResult?
    let camera: CameraModel
    var viewModel: TaggerSearchViewModel
    let timeLeft: Int

    let camera: CameraModel
    let timeLeft: Int

    /// 💡 2. 이니셜라이저를 통해 의존성을 외부에서 주입받아 뷰모델을 초기화합니다.
    init(
        gameModel: GameModel,
        mcSession: MultipeerGameSession,
        niManager: NearbyInteractionManager,
        camera: CameraModel,
        timeLeft: Int
    ) {
        self.camera = camera
        self.timeLeft = timeLeft

        _viewModel = State(initialValue: TaggerSearchViewModel(
            gameModel: gameModel,
            mcSession: mcSession,
            niManager: niManager
        ))
    }

    var body: some View {
        ZStack(alignment: .top) {
            GameCameraBackground(
                camera: camera,
                isRevealed: true,
                isRecording: viewModel.isRecording
            )
            .ignoresSafeArea()

            if let activeHintResult {
                HintResultView(
                    result: activeHintResult,
                    timeLeft: timeLeft
                ) {
                    self.activeHintResult = nil
                }
                .transition(.opacity)
            } else {
                searchContent
                    .transition(.opacity)
            }

            if activeHintResult == nil {
                FakeDynamicIslandView(isExpanded: viewModel.isIslandExpanded) {
                    IslandCompactContent()
                } expanded: {
                    IslandExpandedContent(
                        timeLeft: timeLeft,
                        type: .hiderNearby
                    )
                }
                .padding(.top, 12)
                .ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activeHintResult)
        .onAppear {
            viewModel.activateProximityTracking(reason: "TaggerSearchView appear")
            logRenderState("appear")
        }
        .onDisappear {
            viewModel.deactivateProximityTracking(reason: "TaggerSearchView disappear")
        }
        .onChange(of: viewModel.isIslandExpanded, initial: true) { _, isExpanded in
            logRenderState("isIslandExpanded changed -> \(isExpanded)")
        }
        .onChange(of: viewModel.isRecording, initial: true) { _, isRecording in
            logRenderState("isRecording changed -> \(isRecording)")
        }
        .onChange(of: viewModel.latestObservedDistance, initial: true) { _, distance in
            logRenderState("latestObservedDistance changed -> \(format(distance: distance))")
        }
        .onChange(of: activeHintResult, initial: true) { _, result in
            logRenderState("activeHintResult changed -> \(String(describing: result))")
        }
    }

    private var searchContent: some View {
        ZStack {
            VStack {
                GameTimer(timeLeft: timeLeft)
                Spacer()
                HStack {
                    VStack(alignment: .leading) {
                        Text("주변에")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("숨은 사람")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.primary)
                            Text("을 찾는 중")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            showHintAlert = true
                        } label: {
                            Label("힌트 \(viewModel.hintCountRemaining)개 남음", systemImage: "magnifyingglass")
                                .padding(.vertical, 10)
                                .font(.title3)
                        }
                        .buttonStyle(.glass)
                        .cornerRadius(20)
                        .padding(.bottom, 7)
                        .disabled(!viewModel.canUseHint)
                    }
                    Spacer()
                }
            }
        }
        .alert("힌트를 사용할까요?", isPresented: $showHintAlert) {
            Button("네", role: .none) {
                showHintAlert = false
                Task {
                    guard let result = await viewModel.tapHintButton() else { return }

                    try? await Task.sleep(nanoseconds: 300_000_000)
                    // TODO: 데이터 레이싱 해결하기
                    await MainActor.run {
                        activeHintResult = result
                    }
                }
            }
            Button("아니요", role: .cancel) {}
        } message: {
            Text("가장 가까운 사람의 방향이 잠시동안 표시됩니다")
        }
        .padding(.horizontal, 36)
    }

    private func logRenderState(_ message: String) {
        #if DEBUG
        print(
            "[TaggerSearchView] \(message)",
            "isIslandExpanded=\(viewModel.isIslandExpanded)",
            "isRecording=\(viewModel.isRecording)",
            "activeHintResult=\(String(describing: activeHintResult))",
            "distance=\(format(distance: viewModel.latestObservedDistance))",
            "within5m=\(viewModel.isHiderWithinWarningRadius)",
            "confirmedAt=\(format(date: viewModel.localTaggerConfirmationSentAt))"
        )
        #endif
    }

    private func format(distance: Float?) -> String {
        guard let distance else { return "nil" }
        return String(format: "%.2fm", distance)
    }

    private func format(date: Date?) -> String {
        guard let date else { return "nil" }
        return String(format: "%.3f", date.timeIntervalSince1970)
    }
}
