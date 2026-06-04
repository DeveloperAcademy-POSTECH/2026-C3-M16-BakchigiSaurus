//
//  ActivityAttributes.swift
//  hideandseek
//
//  Created by 캄초 on 6/3/26.
//

import Foundation
import ActivityKit

struct HideAndSeekLiveActivityAttributes: ActivityAttributes {
    
    //고정되어 절대 안바뀌는 데이터
    var roomName: String
    var totalPlayers: Int
    
    //변동 데이터
    struct ContentState: Codable, Hashable {
        var currentStatusMessage: String
        var remainingTime: Int
        var caughtCount: Int
        var isTagger: Bool
        var isHiderNearby: Bool
    }
}
