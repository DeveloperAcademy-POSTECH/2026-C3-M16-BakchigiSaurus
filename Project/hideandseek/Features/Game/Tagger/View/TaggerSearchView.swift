//
//  TaggerSearchView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import SwiftUI

struct TaggerSearchView: View {
    @State private var showHintAlert: Bool = false
    @State private var activeHintResult: HintDisplayResult?
    let camera: CameraModel
    var viewModel: TaggerSearchViewModel
    let timeLeft: Int

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
}
