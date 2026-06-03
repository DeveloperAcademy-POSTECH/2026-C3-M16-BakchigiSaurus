//
//  HideAndSeekLiveActivityLiveActivity.swift
//  HideAndSeekLiveActivity
//
//  Created by 캄초 on 6/3/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct HideAndSeekLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct HideAndSeekLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HideAndSeekLiveActivityAttributes.self) { context in
            // 1️⃣ 잠금화면 & 알림 센터에 뜰 길쭉한 배너 디자인
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // 2️⃣ Expanded: 꾹 눌렀을 때 커지는 화면 (상/하/좌/우 영역 분할 가능)
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                //3️⃣ Compact Leading: 왼쪽 알약 모양
                Text("L")
            } compactTrailing: {
                // 4️⃣ Compact Trailing: 오른쪽 알약 모양
                Text("T \(context.state.emoji)")
            } minimal: {
                // 5️⃣ Minimal: 다른 앱과 겹쳤을 때 동그라미 모양
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension HideAndSeekLiveActivityAttributes {
    fileprivate static var preview: HideAndSeekLiveActivityAttributes {
        HideAndSeekLiveActivityAttributes(name: "World")
    }
}

extension HideAndSeekLiveActivityAttributes.ContentState {
    fileprivate static var smiley: HideAndSeekLiveActivityAttributes.ContentState {
        HideAndSeekLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: HideAndSeekLiveActivityAttributes.ContentState {
         HideAndSeekLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: HideAndSeekLiveActivityAttributes.preview) {
   HideAndSeekLiveActivityLiveActivity()
} contentStates: {
    HideAndSeekLiveActivityAttributes.ContentState.smiley
    HideAndSeekLiveActivityAttributes.ContentState.starEyes
}
