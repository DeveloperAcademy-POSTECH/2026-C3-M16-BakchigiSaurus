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
    var onFinished: @MainActor () -> Void = {}

    @State var rotation: Double = 0

    var body: some View {
        ZStack {
            result.overlayColor
                .ignoresSafeArea()
                .opacity(0.75)
            ZStack {
                VStack {
                    GameTimer(timeLeft: timeLeft)
                    Spacer()
                    Image(systemName: result.iconName)
                        .font(.system(size: 200))
                        .rotationEffect(result == .success ? Angle(degrees: rotation) : .zero)

                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text(result.leadingText)
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
            await onFinished()
        }
    }
}

private extension HintDisplayResult {
    var overlayColor: Color {
        switch self {
        case .success:
            return .appSuccess
        case .failure:
            return .red
        }
    }

    var iconName: String {
        switch self {
        case .success:
            return "arrow.up.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        }
    }

    var leadingText: String {
        "화살표 방향에"
    }

    var trailingText: String {
        switch self {
        case .success:
            return "이 있어요"
        case .failure:
            return "이 없어요"
        }
    }

    var displayDuration: UInt64 {
        switch self {
        case .success:
            return 5_000_000_000
        case .failure:
            return 2_000_000_000
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
            result: .success,
            timeLeft: timeLeft
        )
    }
}

#Preview {
    HintSuccessView(camera: CameraModel(), isHiderNearby: false, isUsingHint: false, timeLeft: 300)
}
