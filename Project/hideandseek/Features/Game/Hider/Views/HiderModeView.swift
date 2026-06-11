//
//  HiderModeView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 숨는 사람이 보는 전체  화면 흐름 관리하는 메인 화면
struct HiderModeView: View {
    let camera: CameraModel
    let photoStore: CapturedPhotoStore
    var timeLeft: Int?
    let photographerID: PlayerID
    let photographerName: String?
    let photographerRole: PlayerRole
    var onCaptureConfirmed: () -> Void = {}
    // 상위 View에서 만든 camera를 받아서 사용

    /// HiderModeViewModel을 생성
    @State private var viewModel = HiderModeViewModel()
    @State private var isCapturingPhoto = false

    var body: some View {
        ZStack {
            if shouldShowCamera {
                GameCameraBackground(camera: camera, isRevealed: true)
                    .ignoresSafeArea()
                CameraFrameOverlay()
                CameraBottomGradient()
            }

            screenContent // 현재 상태에 따라 보여줄 화면 결정

            if shouldShowCaptureButton {
                CaptureButton(isEnabled: camera.isSessionRunning && !isCapturingPhoto) {
                    capturePhoto()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 176)
            }
        }
        .onAppear {
            viewModel.startHiding() // 처음 화면
            debugLog("appear")
        }
        .onChange(of: viewModel.state, initial: true) { _, state in
            debugLog("state changed -> \(state)")
        }
        .onChange(of: camera.isSessionRunning, initial: true) { _, isRunning in
            debugLog("camera.isSessionRunning changed -> \(isRunning)")
        }
    }

    @ViewBuilder // 여러 종류 View를 조건에 따라 반환
    private var screenContent: some View {
        switch viewModel.state {
        // view 모델이 가지고 있는 현재 상태 확인
        case .hiding:
            HiderSearchView(
                camera: camera,
                timeLeft: displayedTimeLeft
            )

        case .taggerNearby:
            TaggerWarningView(
                timeLeft: displayedTimeLeft
            )

        case .taggedCheck:
            TaggedCheckView(
                timeLeft: displayedTimeLeft,
                onConfirmAnswer: { answer in
                    if viewModel.confirmTaggedAnswer(answer) {
                        onCaptureConfirmed()
                    }
                }
            )

        case .captured:
            capturedContent
        }
    }

    private var displayedTimeLeft: Int {
        timeLeft ?? viewModel.timeLeft
    }

    private var shouldShowCamera: Bool {
        switch viewModel.state {
        case .hiding, .taggerNearby:
            true
        case .taggedCheck, .captured:
            false
        }
    }

    private var shouldShowCaptureButton: Bool {
        switch viewModel.state {
        case .hiding, .taggerNearby:
            true
        case .taggedCheck, .captured:
            false
        }
    }

    private func capturePhoto() {
        guard !isCapturingPhoto else { return }
        isCapturingPhoto = true
        debugLog("capture tapped")

        Task {
            defer {
                Task { @MainActor in
                    isCapturingPhoto = false
                }
            }

            guard let photo = await camera.capturePhoto(
                photographerID: photographerID,
                photographerName: photographerName,
                photographerRole: photographerRole
            ) else {
                debugLog("capture failed: camera returned nil")
                return
            }

            photoStore.add(photo)
            debugLog("capture stored id=\(photo.id) bytes=\(photo.imageData.count) total=\(photoStore.count)")
        }
    }

    private var capturedContent: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("잡혔습니다")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                Text("게임 결과를 확인하는 중입니다")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
            print(
                "[HiderModeView] \(message)",
                "state=\(viewModel.state)",
                "sessionRunning=\(camera.isSessionRunning)",
                "isCapturing=\(isCapturingPhoto)",
                "photoCount=\(photoStore.count)",
                "photographer=\(photographerName ?? "nil")",
                "role=\(photographerRole)"
            )
        #endif
    }
}

#Preview {
    HiderModeView(
        camera: CameraModel(),
        photoStore: CapturedPhotoStore(),
        photographerID: PlayerID(),
        photographerName: "플레이어",
        photographerRole: .hider
    )
}
