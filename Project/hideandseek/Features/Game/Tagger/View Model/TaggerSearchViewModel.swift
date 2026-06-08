//
//  TaggerSearchViewModel.swift
//  hideandseek
//
//  Created by 캄초 on 6/8/26.
//

import Foundation
import MultipeerConnectivity
import NearbyInteraction
import Combine

@MainActor
final class TaggerSearchViewModel: ObservableObject {
    
    // ni 문서에서 설계한 인프라 세트
    private let mcSession: MultipeerGameSession
    private let niManager: NearbyInteractionManager
    private let mcniConnection: McniConnection
    
    // 힌트 화면에서 실시간으로 가져갈 데이터
    @Published var distanceToHider: Float?
    @Published var directionToHider: SIMD3<Float>?
    @Published var horizontalAngle: Float?
    
    // 숨은 사람이 가까워졌는가?
    @Published var isHiderNearby: Bool = false
    
    init() {
        let mc = MultipeerGameSession(displayName: "술래")
        let ni = NearbyInteractionManager()
        
        self.mcSession = mc
        self.niManager = ni
        self.mcniConnection = McniConnection(mcManager: mc, niManager: ni)
        setupNICallback()
    }
    
    private func setupNICallback() {
        niManager.onReadingUpdated = { [weak self] reading in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.distanceToHider = reading.distance
                self.directionToHider = reading.direction
                self.horizontalAngle = reading.horizontalAngle
                
                if let distance = reading.distance, distance <= 0.5 {
                    if !self.isHiderNearby {
                        self.isHiderNearby = true
                        print("[발견] 숨은 사람의 위치를 확보했습니다!")
                    }
                }
            }
        } // 👈 여기서 niManager.onReadingUpdated 클로저가 깔끔하게 닫혀야 합니다!
    }
    
    // MARK: - View에서 호출하는 인터페이스 (Action)
    
    /// 술래 게임 화면이 켜질 때 호출 (`.onAppear`)
    /// 타이머 없이 백그라운드에서 McniConnection이 자동으로 상대방을 찾아 악수(연결)합니다.
    func startGameSession() {
        mcSession.startHosting()
        mcSession.startBrowsing()
    }
    
    /// 술래가 화면의 '힌트 사용' 버튼을 탭했을 때 호출되는 함수
    func useHint() {
        if let distance = distanceToHider {
            // UI 단에서 이 함수가 성공하면 distanceToHider, directionToHider를 기반으로
            // 나침반 화살표나 거리 미터(m)를 팝업 애니메이션으로 보여주면 됩니다.
            print("🎯 [힌트 성공] 현재 숨은 사람과의 거리: \(String(format: "%.2f", distance))m")
        } else {
            // 아직 상대방 기기와 UWB 연결 통로가 완전히 붙지 않았거나 신호 거리를 벗어났을 때 (nil일 때)
            // 뷰단에 "아직 신호가 잡히지 않습니다" 같은 실패 알림 유도
            print("⚠️ [힌트 실패] 주변에 숨은 사람의 신호가 감지되지 않습니다.")
        }
    }
    
    /// 게임 화면을 나가거나 매치가 완전히 끝났을 때 세션 정리 (`.onDisappear`)
    func stopGameSession() {
        mcSession.stopHosting()
        mcSession.stopBrowsing()
        niManager.invalidateSession()
        
        // 상태 초기화
        distanceToHider = nil
        directionToHider = nil
        horizontalAngle = nil
        isHiderNearby = false
        print("🛑 술래 게임 세션이 안전하게 종료되었습니다.")
    }
}
