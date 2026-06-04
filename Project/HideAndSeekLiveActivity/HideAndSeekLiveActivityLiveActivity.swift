//
//  HideAndSeekLiveActivityLiveActivity.swift
//  HideAndSeekLiveActivity
//
//  Created by 캄초 on 6/3/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct HideAndSeekLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HideAndSeekLiveActivityAttributes.self) { context in
            // 1) 잠금화면 & 알림 센터 배너 UI (기존 유지)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(context.attributes.roomName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("남은 시간: \(context.state.remainingTime)초")
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                }
                
                Text(context.state.currentStatusMessage)
                    .font(.body)
                    .foregroundColor(.white)
            }
            .padding()
            .activityBackgroundTint(context.state.isTagger ? Color.red.opacity(0.6) : Color.blue.opacity(0.3))
            
        } dynamicIsland: { context in
            DynamicIsland {
                // 2) Expanded: 아일랜드를 꾹 눌러서 커졌을 때 화면
                DynamicIslandExpandedRegion(.bottom) {
//                    Text("hello")
//                        .foregroundStyle(Color.yellow)
                }
                // 나머지 영역(Leading, Trailing, Center)은 비워둠으로써 삭제 효과
                DynamicIslandExpandedRegion(.leading) {
//                    Text("hello")
//                        .foregroundStyle(Color.yellow)
                }
                DynamicIslandExpandedRegion(.trailing) {
//                    Text("hello")
//                        .foregroundStyle(Color.green)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 10) {
                        // 타이머 표시
                        let minutes = context.state.remainingTime / 60
                        let seconds = context.state.remainingTime % 60
                        let formattedTime = String(format: "%02d:%02d", minutes, seconds)
                        
                        Text(formattedTime)
                            .font(Font.largeTitle.bold())
                            .foregroundColor(.white)
                        
                        // 근처에 대상이 있을 때만 경고 워딩 표시
                        if context.state.isTargetNear {
                            Text(context.state.isTagger ? "근처에 숨은 사람이 있어요" : "주변에 술래가 있어요!!")
                                .font(.title)
                                .bold()
                                .foregroundColor(context.state.isTagger ? .orange : .red)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 10)
                }
                
            } compactLeading: {

            } compactTrailing: {
                // 4) Compact Trailing: 기본 상태의 오른쪽 - 안쓰므로 비워둠
            } minimal: {

            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.cyan)
        }
    }
}

// MARK: - Previews
// Xcode 오른쪽에 미리보기(Preview) 설정

extension HideAndSeekLiveActivityAttributes {
    // 1. 방 이름이랑 인원수 설정
    fileprivate static var preview = HideAndSeekLiveActivityAttributes(roomName: "테스트 방", totalPlayers: 5)
}

extension HideAndSeekLiveActivityAttributes.ContentState {
    // 2. 술래일 때 상황 딱 1개만 남기기 (나머지 한 개는 삭제!)
    fileprivate static var taggerTest = HideAndSeekLiveActivityAttributes.ContentState(
        currentStatusMessage: "게임 중...",
        remainingTime: 180, // 3분
        caughtCount: 0,
        isTagger: true,      // 술래라면 ture, 숨는사람이라면 false
        isTargetNear: true   // 근처에 타겟이 있다고 가정 (술래의 타겟은 숨은 사람 / 숨은 사람의 타겟은 술래)
    )
}

//다이나믹 아일랜드 - 확장형 (Expanded) 프리뷰
#Preview("Island Expanded", as: .dynamicIsland(.expanded), using: HideAndSeekLiveActivityAttributes.preview) {
    HideAndSeekLiveActivityLiveActivity()
} contentStates: {
    HideAndSeekLiveActivityAttributes.ContentState.taggerTest
}


#Preview("Island Expanded", as: .dynamicIsland(.compact), using: HideAndSeekLiveActivityAttributes.preview) {
    HideAndSeekLiveActivityLiveActivity()
} contentStates: {
    HideAndSeekLiveActivityAttributes.ContentState.taggerTest
}


#Preview("Island Expanded", as: .dynamicIsland(.minimal), using: HideAndSeekLiveActivityAttributes.preview) {
    HideAndSeekLiveActivityLiveActivity()
} contentStates: {
    HideAndSeekLiveActivityAttributes.ContentState.taggerTest
}
