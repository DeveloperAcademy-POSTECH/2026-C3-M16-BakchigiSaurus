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
    // 💡 1. 뷰모델을 관찰 가능한 상태로 소유합니다.
    @State private var viewModel: TaggerSearchViewModel
    @State private var showHintAlert: Bool = false
    @State private var activeHintView: HintViewType?
    
    let camera: CameraModel
    let timeLeft: Int

    // 💡 2. 이니셜라이저를 통해 의존성을 외부에서 주입받아 뷰모델을 초기화합니다.
    init(gameModel: GameModel, mcSession: MultipeerGameSession, niManager: NearbyInteractionManager, camera: CameraModel, timeLeft: Int) {
        self.camera = camera
        self.timeLeft = timeLeft
        
        _viewModel = State(initialValue: TaggerSearchViewModel(
            gameModel: gameModel,
            mcSession: mcSession,
            niManager: niManager
        ))
    }

    var body: some View {
        ZStack {
            // 센서 실시간 판정 연동
            // 거리가 감지되고 있으면(nil이 아니면) 주변에 숨은 사람이 있는 것으로 판단
            let isHiderNearby = viewModel.nearestHiderDistance != nil
            
            GameCameraBackground(
                camera: camera,
                isRevealed: isHiderNearby && viewModel.isHintActive,
                isRecording: isHiderNearby
            )
            
            ZStack {
                VStack {
                    GameTimer(timeLeft: timeLeft)
                    
                    // 실시간 거리 측정 UI 추가부
                    if let distance = viewModel.nearestHiderDistance {
                        VStack(spacing: 4) {
                            Text("상대방과의 거리")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f m", distance))
                                .font(.system(.title, design: .rounded).bold())
                                .foregroundStyle(distance <= 5.0 ? .red : .green)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        .padding(.top, 10)
                    }
                    
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
                            
                            // 💡 4. 엔진 내부의 힌트 개수 잔여량과 동기화
                            let hintCount = viewModel.gameModel.sharedState.hintCountRemaining
                            
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
                            .disabled(hintCount == 0 || viewModel.isHintActive) // 힌트 사용 중일 때도 중복 클릭 방지
                        }
                        Spacer()
                    }
                }
            }
            .alert("힌트를 사용할까요?", isPresented: $showHintAlert) {
                Button("네", role: .none) {
                    // 💡 5. 비동기로 뷰모델의 힌트 아이템 사용 로직 구동
                    Task {
                        await viewModel.tapHintButton()
                        
                        // 힌트 사용 직후 성공/실패 화면 분기 판정
                        if viewModel.nearestHiderDistance != nil {
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
                let isHiderNearby = viewModel.nearestHiderDistance != nil
                switch hintType {
                case .success:
                    HintSuccessView(camera: camera, isHiderNearby: isHiderNearby, isUsingHint: viewModel.isHintActive, timeLeft: timeLeft)
                case .failure:
                    HintFailureView(camera: camera, isHiderNearby: isHiderNearby, isUsingHint: viewModel.isHintActive, timeLeft: timeLeft)
                }
            }
            .padding(.horizontal, 36)
        }
    }
}
