//
//  TaggerSearchView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import SwiftUI

struct TaggerSearchView: View {
    @State private var showHintAlert: Bool = false
    let camera: CameraModel
    let isHiderNearby: Bool
    let isUsingHint: Bool
    
    var body: some View {
        ZStack {
            GameCameraBackground(camera: camera,
                                isRevealed: isHiderNearby && isUsingHint,
                                isRecording: isHiderNearby)
            ZStack {
                VStack {
                    GameTimer(timeLeft: 300)
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
                                // TODO: 힌트 갯수 연결
                                showHintAlert = true
                            } label: {
                                Label("힌트 (n개 남음)", systemImage: "magnifyingglass")
                                    .padding(.vertical, 10)
                                    .font(.title3)
                            }
                            .buttonStyle(.glass)
                            .cornerRadius(20)
                            .padding(.bottom, 7)
                        }
                        Spacer()
                    }
                }
            }
            .alert("힌트를 사용할까요?", isPresented: $showHintAlert) {
                Button("네", role: .none) {
                    // TODO: HintSuccessView Or HintFailureView 로 이동함
                }
                Button("아니요", role: .cancel) {}
            } message: {
                Text("가장 가까운 사람의 방향이 잠시동안 표시됩니다")
            }
            .padding(.horizontal, 36)
        }
    }
}

#Preview {
    TaggerSearchView(camera: CameraModel(), isHiderNearby: false, isUsingHint: false)
}
