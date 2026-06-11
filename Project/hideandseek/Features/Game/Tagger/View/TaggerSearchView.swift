//
//  TaggerSearchView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import Foundation
import SwiftUI

struct TaggerSearchView: View {
    @State private var showHintAlert: Bool = false
    @State private var activeHintResult: HintDisplayResult?
    @State private var isMeasuringHint: Bool = false
    let camera: CameraModel
    var viewModel: TaggerSearchViewModel
    let photoStore: CapturedPhotoStore
    let timeLeft: Int

    var body: some View {
        ZStack(alignment: .top) {
            // 촬영 가능(=아일랜드 확장) 상태에서만 블러 해제. 그 외엔 블러로 가림.
            GameCameraBackground(
                camera: camera,
                isRevealed: viewModel.isIslandExpanded
            )
            .ignoresSafeArea()

            if let activeHintResult {
                HintResultView(
                    result: activeHintResult,
                    timeLeft: timeLeft,
                    angleRadians: viewModel.currentHintAngleRadians
                ) {
                    self.activeHintResult = nil
                    // 힌트 화면이 사라지는 시점에 NI 거리 모드 + 카메라 복구.
                    Task { await viewModel.endHintDirectionMode(camera: camera) }
                }
                .transition(.opacity)
            } else if isMeasuringHint {
                hintMeasuringContent
                    .transition(.opacity)
            } else {
                searchContent
                    .transition(.opacity)
            }

            if activeHintResult == nil, !isMeasuringHint {
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
        .onChange(of: camera.isSessionRunning, initial: true) { _, isRunning in
            logRenderState("camera.isSessionRunning changed -> \(isRunning)")
        }
        .onChange(of: activeHintResult, initial: true) { _, result in
            logRenderState("activeHintResult changed -> \(String(describing: result))")
        }
        .onChange(of: isMeasuringHint, initial: true) { _, isMeasuringHint in
            logRenderState("isMeasuringHint changed -> \(isMeasuringHint)")
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
                        .disabled(!viewModel.canUseHint || isMeasuringHint)
                    }
                    Spacer()
                }
            }

            // 촬영 버튼: 아일랜드 확장(촬영 가능) + 카메라 세션 실행 중일 때만.
            CaptureButton(isEnabled: viewModel.canCapturePhoto && camera.isSessionRunning) {
                Task {
                    if let photo = await camera.capturePhoto(ownerRole: .tagger) {
                        photoStore.add(photo)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 24)
        }
        .alert("힌트를 사용할까요?", isPresented: $showHintAlert) {
            Button("네", role: .none) {
                showHintAlert = false
                Task {
                    // 방향 지원 기기에서는 NI 방향 모드, 미지원 기기에서는 거리 기반 힌트로 처리.
                    await MainActor.run {
                        activeHintResult = nil
                        isMeasuringHint = viewModel.supportsDirectionalHint
                    }
                    let result = await viewModel.beginHintWithDirection(camera: camera)

                    await MainActor.run {
                        isMeasuringHint = false
                        if let result {
                            activeHintResult = result
                        }
                    }
                }
            }
            Button("아니요", role: .cancel) {}
        } message: {
            Text(hintAlertMessage)
        }
        .padding(.horizontal, 36)
    }

    private var hintMeasuringContent: some View {
        ZStack {
            Color.appBackground
                .opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                GameTimer(timeLeft: timeLeft)

                Spacer()

                ProgressView()
                    .controlSize(.large)
                    .tint(.primary)

                VStack(spacing: 10) {
                    Text("방향을 측정 중이에요")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                    Text(hintMeasuringMessage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(.horizontal, 36)
        }
    }

    private var hintMeasuringMessage: String {
        guard let distance = viewModel.latestObservedDistance else {
            return "상대 방향을 향한 채 좌우로 천천히 움직여 주세요"
        }

        if distance < 1 {
            return "1~2m 정도 떨어진 뒤 좌우로 천천히 움직여 주세요"
        }

        return "상대 방향을 향한 채 좌우로 천천히 움직여 주세요"
    }

    private var hintAlertMessage: String {
        viewModel.supportsDirectionalHint
            ? "가장 가까운 사람의 방향이 잠시동안 표시됩니다"
            : "가까운 숨은 사람이 있는지 잠시동안 표시됩니다"
    }

    private func logRenderState(_ message: String) {
        #if DEBUG
            print(
                "[TaggerSearchView] \(message)",
                "isIslandExpanded=\(viewModel.isIslandExpanded)",
                "canCapturePhoto=\(viewModel.canCapturePhoto)",
                "sessionRunning=\(camera.isSessionRunning)",
                "activeHintResult=\(String(describing: activeHintResult))",
                "isMeasuringHint=\(isMeasuringHint)",
                "distance=\(format(distance: viewModel.latestObservedDistance))",
                "angle=\(format(angle: viewModel.latestObservedHorizontalAngle))",
                "hintAngle=\(format(angleRadians: viewModel.currentHintAngleRadians))",
                "within5m=\(viewModel.isHiderWithinWarningRadius)",
                "confirmedAt=\(format(date: viewModel.localTaggerConfirmationSentAt))"
            )
        #endif
    }

    private func format(distance: Float?) -> String {
        guard let distance else { return "nil" }
        return String(format: "%.2fm", distance)
    }

    private func format(angle: Float?) -> String {
        guard let angle else { return "nil" }
        return String(format: "%.2frad", angle)
    }

    private func format(angleRadians: Double?) -> String {
        guard let angleRadians else { return "nil" }
        return String(format: "%.2frad", angleRadians)
    }

    private func format(date: Date?) -> String {
        guard let date else { return "nil" }
        return String(format: "%.3f", date.timeIntervalSince1970)
    }
}
