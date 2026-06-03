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
                // 타이머와 경고 문구만 하단에 집중 배치
                DynamicIslandExpandedRegion(.bottom) {
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
                
                // 나머지 영역(Leading, Trailing, Center)은 비워둠으로써 삭제 효과
                DynamicIslandExpandedRegion(.leading) { }
                DynamicIslandExpandedRegion(.trailing) { }
                DynamicIslandExpandedRegion(.center) { }
                
            } compactLeading: {
                // 3) Compact Leading: 기본 상태의 왼쪽 (역할 아이콘)
                Text(context.state.isTagger ? "👹" : "🏃‍♂️")
            } compactTrailing: {
                // 4) Compact Trailing: 기본 상태의 오른쪽
                if context.state.isTargetNear {
                    Text("🚨")
                } else {
                    Text("\(context.state.remainingTime)초")
                }
            } minimal: {
                // 5) Minimal: 다른 앱과 겹쳤을 때
                Text(context.state.isTargetNear ? "⚠️" : (context.state.isTagger ? "👹" : "🏃‍♂️"))
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.cyan)
        }
    }
}

// MARK: - Previews
// 3️⃣ Xcode 오른쪽에 미리보기(Preview) 설정

extension HideAndSeekLiveActivityAttributes {
    fileprivate static var preview: HideAndSeekLiveActivityAttributes {
        HideAndSeekLiveActivityAttributes(roomName: "A동 숨바꼭질", totalPlayers: 5)
    }
}

extension HideAndSeekLiveActivityAttributes.ContentState {
    fileprivate static var taggerNormal: HideAndSeekLiveActivityAttributes.ContentState {
        HideAndSeekLiveActivityAttributes.ContentState(
            currentStatusMessage: "숨은 사람들을 찾으세요!",
            remainingTime: 180,
            caughtCount: 0,
            isTagger: true,
            isTargetNear: false
        )
    }
    
    fileprivate static var hiderDanger: HideAndSeekLiveActivityAttributes.ContentState {
        HideAndSeekLiveActivityAttributes.ContentState(
            currentStatusMessage: "심장이 두근거립니다...",
            remainingTime: 120,
            caughtCount: 2,
            isTagger: false,
            isTargetNear: true
        )
    }
}

// 1. 잠금화면/알림센터용 프리뷰
#Preview("Notification", as: .content, using: HideAndSeekLiveActivityAttributes.preview) {
    HideAndSeekLiveActivityLiveActivity()
} contentStates: {
    HideAndSeekLiveActivityAttributes.ContentState.taggerNormal
    HideAndSeekLiveActivityAttributes.ContentState.hiderDanger
}

// 2. 다이나믹 아일랜드 - 확장형 (Expanded) 프리뷰
#Preview("Island Expanded", as: .dynamicIsland(.expanded), using: HideAndSeekLiveActivityAttributes.preview) {
    HideAndSeekLiveActivityLiveActivity()
} contentStates: {
    HideAndSeekLiveActivityAttributes.ContentState.taggerNormal
    HideAndSeekLiveActivityAttributes.ContentState.hiderDanger
}

// 3. 다이나믹 아일랜드 - 컴팩트 (Compact) 프리뷰
#Preview("Island Compact", as: .dynamicIsland(.compact), using: HideAndSeekLiveActivityAttributes.preview) {
    HideAndSeekLiveActivityLiveActivity()
} contentStates: {
    HideAndSeekLiveActivityAttributes.ContentState.hiderDanger
}
