//
//  LiveActivityManager.swift
//  hideandseek
//
//  Created by 캄초 on 6/4/26.
//

import ActivityKit
import Foundation

class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<HideAndSeekLiveActivityAttributes>?

    /// 다이나믹 아일랜드 시작하는 함수
    func startLiveActivity(roomName: String, isTagger: Bool) {
        // currentActivity가 비어있는가? 그렇지 않다면 나가라
        guard currentActivity == nil else { return }
        // 고정데이터를 설정해줌
        let attributes = HideAndSeekLiveActivityAttributes(roomName: roomName, totalPlayers: 5)
        // 실시간으로 변할 데이터의 초기 데이터도 설정해줌
        let initialState = HideAndSeekLiveActivityAttributes.ContentState(
            currentStatusMessage: isTagger ? "근처에 숨은 사람이 있어요" : "주변에 술래가 있어요!!",
            remainingTime: 300,
            caughtCount: 0,
            isTagger: isTagger,
            isTargetNear: true
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            print("다이나믹 아일랜드 켜짐")
        } catch {
            print("다이나믹 아일랜드 켜기 실패")
        }
    }

    func stopLiveActivity() {
        Task {
            await currentActivity?.end(dismissalPolicy: .immediate)
            currentActivity = nil
            print("다이나믹 아일랜드 꺼짐")
        }
    }
}
