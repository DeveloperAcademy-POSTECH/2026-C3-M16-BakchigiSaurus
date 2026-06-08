//
//  TaggerSearchViewModel.swift
//  hideandseek
//
//  Created by 캄초 on 6/8/26.
//

import Foundation
import Observation
import NearbyInteraction
import MultipeerConnectivity

@Observable
@MainActor
final class TaggerSearchViewModel {
    // 1. 외부에서 주입받을 의존성 (GameModel 및 기존 세션)
    private let gameModel: GameModel
    private let mcSession: MultipeerGameSession
    private let niManager: NearbyInteractionManager
    
    // 2. UI에서 바인딩해서 사용할 상태값들
    var isHintActive: Bool = false
    var nearestHiderDirection: DirectionVector? = nil
    var nearestHiderDistance: Float? = nil
    
    // 타이머 (5m 이내 5초 체크용)
    private var proximityTimer: Timer?
    private var trackingTargetID: PlayerID?
    private var secondsInProximity: Int = 0

    // 3. 이니셜라이저 수정: 클래스 타입 대신 주입받은 인스턴스(소문자) 대입
    init(gameModel: GameModel, mcSession: MultipeerGameSession, niManager: NearbyInteractionManager) {
        self.gameModel = gameModel
        self.mcSession = mcSession
        self.niManager = niManager
        
        setupNearbyInteractionCallbacks()
    }
    
    // 4. NI 읽기값 콜백 설정
        private func setupNearbyInteractionCallbacks() {
            // 💡 중요: Swift가 타입을 헷갈려하지 않도록 (reading: NearbyInteractionReading) 명시합니다.
            // 만약 매니저가 peerID도 같이 던져주는 스펙이 확실하다면 { [weak self] reading, peerID in ... } 으로 유지하되,
            // 에러가 지속된다면 아래처럼 reading 하나만 받아와서 내부에서 처리하는 것이 안전합니다.
            self.niManager.onReadingUpdated = { [weak self] (reading: NearbyInteractionReading) in
                guard let self = self else { return }
                
                // 💡 1. 방향 벡터 타입 변환 (SIMD3<Float>? -> DirectionVector?)
                // 리드 개발자님이 만들어둔 DirectionVector에 SIMD3를 넣어서 변환하는 이니셜라이저가 있다고 가정합니다.
                // 만약 변환 생성자가 없다면 우선 컴파일을 위해 nil을 넣어두고 구조를 확인해야 합니다.
                let convertedDirection: DirectionVector? = {
                    if let simdDir = reading.direction {
                        return DirectionVector(simdDir) // 혹은 프로젝트 구조에 맞는 변환 방식 적용
                    }
                    return nil
                }()
                
                // 💡 2. reading 내부에 식별자가 없으므로, 현재 추적 중인 타겟 ID를 기반으로 이벤트를 보냅니다.
                // (술래가 찾고 있는 플레이어 ID가 이미 결정되어 있다고 가정)
                guard let hiderID = self.trackingTargetID else { return }
                
                Task { @MainActor in
                    // 실시간 읽기값을 GameModel 엔진으로 전송
                    await self.gameModel.send(.observeProximity(
                        hiderID: hiderID,
                        distance: reading.distance,
                        direction: convertedDirection, // 변환된 타입 전달
                        observedAt: reading.timestamp
                    ))
                    
                    // 힌트가 활성화되어 있다면 UI에 방향/거리 표시
                    if self.isHintActive {
                        self.nearestHiderDistance = reading.distance
                        self.nearestHiderDirection = convertedDirection // 타입 일치 완료
                    }
                    
                    // 5m 이내 5초 감시 로직 실행
                    self.checkProximityAlert(hiderID: hiderID, distance: reading.distance)
                }
            }
        }
    
    // 5. 5m 이내에 5초 동안 머물렀는지 체크하는 로직 (MainActor 격리 해결)
    private func checkProximityAlert(hiderID: PlayerID, distance: Float?) {
        guard let distance = distance else { return }
        
        if distance <= 5.0 {
            if trackingTargetID == hiderID {
                return
            }
            
            trackingTargetID = hiderID
            secondsInProximity = 0
            
            proximityTimer?.invalidate()
            
            // @MainActor 내부에서 타이머를 안전하게 돌리기 위해 메인 큐에서 실행되도록 지정합니다.
            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                // 타이머 내부 클로저가 메인 액터 영역으로 안전하게 진입하도록 Task 배치
                Task { @MainActor in
                    self.secondsInProximity += 1
                    if self.secondsInProximity >= 5 {
                        self.triggerProximityNotification(for: hiderID)
                        self.clearProximityTimer()
                    }
                }
            }
            // 메인 런루프에 타이머 등록 (MainActor 격리 에러 방지)
            RunLoop.main.add(timer, forMode: .common)
            self.proximityTimer = timer
            
        } else {
            if trackingTargetID == hiderID {
                clearProximityTimer()
            }
        }
    }
    
    private func clearProximityTimer() {
        proximityTimer?.invalidate()
        proximityTimer = nil
        trackingTargetID = nil
        secondsInProximity = 0
    }
    
    private func triggerProximityNotification(for hiderID: PlayerID) {
        print("🚨 알림: 숨은 사람(\(hiderID))이 5m 이내에 5초 동안 있었습니다!")
    }
    
    // 6. 힌트 버튼 클릭 시 Action (HintCandidate 타입 변환 에러 해결)
    func tapHintButton() async {
        guard gameModel.sharedState.hintCountRemaining > 0 else { return }
        
        // 💡 변경된 부분: [PlayerID]를 [HintCandidate]로 바꿀 때,
        // 찾으신 구조체 정의대로 hiderID, direction, distance를 모두 넣어줍니다.
        let candidates: [HintCandidate] = gameModel.participants
            .filter { $0.id != gameModel.localPlayerID }
            .map { participant in
                // 힌트를 쓰는 시점에는 아직 정확한 방향과 거리를 모르거나
                // NearbyInteraction 읽기값에서 가져와야 하므로, 초기값은 nil로 채워줍니다.
                return HintCandidate(
                    hiderID: participant.id,
                    direction: nil,
                    distance: nil
                )
            }
        
        // 서버/엔진에 힌트 사용 명령 전송
        await gameModel.send(.useHint(candidates: candidates))
        
        isHintActive = true
        
        try? await Task.sleep(nanoseconds: 7 * 1_000_000_000)
        isHintActive = false
        nearestHiderDirection = nil
        nearestHiderDistance = nil
    }
    
    // Helper 수정: PeerID 비교 시 타입을 프로젝트 내 PeerID 타입에 일치시킵니다.
    private func findPlayerID(by peerID: PeerID) -> PlayerID? {
        return gameModel.participants.first(where: { $0.peerID == peerID })?.id
    }
    
    deinit {
        // 타이머 해제는 메인 스레드에서 안전하게 실행되도록 처리하거나 기기 소멸 시 큐 관리
        // @MainActor class의 deinit은 nonisolated이므로 주의가 필요합니다.
    }
}
