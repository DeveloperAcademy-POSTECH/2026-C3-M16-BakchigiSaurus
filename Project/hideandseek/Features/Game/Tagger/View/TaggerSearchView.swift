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
                .fixedSize()
                .padding(.top, 12)
                .ignoresSafeArea()
                .zIndex(10)
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
            CameraFrameOverlay()
            CameraBottomGradient()

            VStack {
                GameTimer(timeLeft: timeLeft)
                Spacer()
                bottomSearchLabel
                    .padding(.leading, 36)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            cameraActions
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 176)
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
    }

    private var bottomSearchLabel: some View {
        VStack(alignment: .leading) {
            Text("주변에")
                .foregroundStyle(.secondary)

            Text("\(Text("숨은 사람").foregroundStyle(.primary))을 찾는 중")
                .foregroundStyle(.secondary)
        }
        .font(.largeTitle.bold())
    }

    private var cameraActions: some View {
        ZStack {
            HStack {
                hintButton
                    .padding(.leading, 30)

                Spacer()
            }
            // 촬영 버튼: 아일랜드 확장(촬영 가능) + 카메라 세션 실행 중일 때만.
            CaptureButton(isEnabled: viewModel.canCapturePhoto && camera.isSessionRunning) {
                Task {
                    let localParticipant = viewModel.gameModel.localParticipant
                    if let photo = await camera.capturePhoto(
                        photographerID: localParticipant?.id ?? viewModel.gameModel.localPlayerID,
                        photographerName: localParticipant?.name,
                        photographerRole: localParticipant?.role ?? .tagger
                    ) {
                        photoStore.add(photo)
                    }
                }
            }
        }
    }

    private var hintButton: some View {
        Button {
            showHintAlert = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(.black.opacity(0.36))
                    .frame(width: 62, height: 62)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.5), lineWidth: 1)
                    }
                    .overlay {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }

                Text("\(viewModel.hintCountRemaining)")
                    .font(.caption2.bold())
                    .foregroundStyle(.black)
                    .frame(width: 20, height: 20)
                    .background(.white, in: Circle())
                    .offset(x: 2, y: -2)
            }
            .frame(width: 62, height: 62)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canUseHint || isMeasuringHint)
        .opacity((viewModel.canUseHint && !isMeasuringHint) ? 1 : 0.45)
        .accessibilityLabel("힌트 \(viewModel.hintCountRemaining)개 남음")
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

    private func logRenderState(_ message: String) {}

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

#Preview("아일랜드 확장(촬영 가능)") {
    let localID = PlayerID()
    let hiderID = PlayerID()

    let initialState = GameState(
        session: GameSessionDefinition(hostID: localID, settings: .default),
        phase: .playing,
        participants: [
            localID: GameParticipant(
                id: localID,
                peerID: nil,
                name: "술래",
                isHost: true,
                role: .tagger,
                status: .seeking
            ),
            hiderID: GameParticipant(
                id: hiderID,
                peerID: nil,
                name: "숨은 사람",
                isHost: false,
                role: .hider,
                status: .hiding
            )
        ],
        participantOrder: [localID, hiderID],
        taggerID: localID,
        hintCountRemaining: 3
    )

    let gameModel = GameModel(initialState: initialState, localPlayerID: localID)
    let viewModel = TaggerSearchViewModel(
        gameModel: gameModel,
        mcSession: MultipeerGameSession(displayName: "술래", isHost: true),
        niManager: NearbyInteractionManager()
    )

    // 아일랜드 확장 4조건 중 VM 측 2개를 강제 충족.
    viewModel.didReceiveLocalReading = true
    viewModel.latestObservedDistance = 2.4
    viewModel.isHiderWithinWarningRadius = true
    viewModel.localTaggerConfirmationSentAt = Date()

    return TaggerSearchView(
        camera: CameraModel(),
        viewModel: viewModel,
        photoStore: CapturedPhotoStore(),
        timeLeft: 180
    )
}
