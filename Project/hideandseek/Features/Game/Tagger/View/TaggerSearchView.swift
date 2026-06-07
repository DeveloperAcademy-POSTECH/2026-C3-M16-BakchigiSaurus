//
//  TaggerSearchView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import SwiftUI

enum HintViewType: Identifiable {
    case success
    case failure
    var id: HintViewType {
        self
    }
}

struct TaggerSearchView: View {
    @State private var showHintAlert: Bool = false
    let camera: CameraModel
    let isHiderNearby: Bool
    let isUsingHint: Bool
    let timeLeft: Int
    @State var hintCount = 1
    @State private var activeHintView: HintViewType?

    var body: some View {
        ZStack {
            GameCameraBackground(
                camera: camera,
                isRevealed: isHiderNearby && isUsingHint,
                isRecording: isHiderNearby
            )
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
                                Label("힌트 \(hintCount)개 남음", systemImage: "magnifyingglass")
                                    .padding(.vertical, 10)
                                    .font(.title3)
                            }
                            .buttonStyle(.glass)
                            .cornerRadius(20)
                            .padding(.bottom, 7)
                            .disabled(hintCount == 0)
                        }
                        Spacer()
                    }
                }
            }
            .alert("힌트를 사용할까요?", isPresented: $showHintAlert) {
                Button("네", role: .none) {
                    if hintCount > 0 {
                        hintCount -= 1
                        if isHiderNearby {
                            activeHintView = .success
                        } else {
                            activeHintView = .failure
                        }
                    }
                }
                Button("아니요", role: .cancel) {}
            } message: {
                Text("가장 가까운 사람의 방향이 잠시동안 표시됩니다")
            }
            .fullScreenCover(item: $activeHintView) { hintType in
                switch hintType {
                case .success:
                    HintSuccessView(camera: camera, isHiderNearby: isHiderNearby, isUsingHint: true, timeLeft: timeLeft)
                case .failure:
                    HintFailureView(camera: camera, isHiderNearby: isHiderNearby, isUsingHint: true, timeLeft: timeLeft)
                }
            }
            .padding(.horizontal, 36)
        }
    }
}

#Preview {
    TaggerSearchView(camera: CameraModel(), isHiderNearby: true, isUsingHint: false, timeLeft: 300)
}
