//
//  HintSuccessView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import SwiftUI

struct HintResultView: View {
    let result: HintDisplayResult
    let timeLeft: Int
    let angleRadians: Double?
    var onFinished: @MainActor () -> Void = {}

    var body: some View {
        ZStack {
            result.overlayColor
                .ignoresSafeArea()
                .opacity(0.75)
            ZStack {
                VStack {
                    GameTimer(timeLeft: timeLeft)
                    Spacer()
                    Image(systemName: iconName)
                        .font(.system(size: 200))
                        .rotationEffect(isDirectionalSuccess ? Angle(radians: activeAngleRadians ?? 0) : .zero)
                        .animation(.easeInOut(duration: 0.15), value: activeAngleRadians)

                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text(leadingText)
                                .font(.largeTitle.bold())
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("숨은 사람")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.primary)
                                Text(result.trailingText)
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.bottom)
                }
            }
            .padding(.horizontal, 36)
        }
        .task(id: result) {
            try? await Task.sleep(nanoseconds: result.displayDuration)
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }

    private var activeAngleRadians: Double? {
        angleRadians ?? result.angleRadians
    }

    private var isDirectionalSuccess: Bool {
        result.isSuccess && activeAngleRadians != nil
    }

    private var iconName: String {
        switch result {
        case .success:
            isDirectionalSuccess ? "arrow.up.circle.fill" : "location.circle.fill"
        case .failure:
            "xmark.circle.fill"
        }
    }

    private var leadingText: String {
        switch result {
        case .success:
            isDirectionalSuccess ? "화살표 방향에" : "근처에"
        case .failure:
            "주변에"
        }
    }
}

private extension HintDisplayResult {
    var overlayColor: Color {
        switch self {
        case .success:
            .appSuccess
        case .failure:
            .red
        }
    }

    var trailingText: String {
        switch self {
        case .success:
            "이 있어요"
        case .failure:
            "이 없어요"
        }
    }

    var displayDuration: UInt64 {
        switch self {
        case .success:
            7_000_000_000
        case .failure:
            2_000_000_000
        }
    }
}

struct HintSuccessView: View {
    let camera: CameraModel
    let isHiderNearby: Bool
    let isUsingHint: Bool
    let timeLeft: Int

    var body: some View {
        HintResultView(
            result: .success(angleRadians: nil),
            timeLeft: timeLeft,
            angleRadians: nil
        )
    }
}

#Preview {
    HintSuccessView(camera: CameraModel(), isHiderNearby: false, isUsingHint: false, timeLeft: 300)
}
