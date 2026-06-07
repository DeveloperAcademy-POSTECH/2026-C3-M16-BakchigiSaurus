//
//  StoryBuilder.swift
//  hideandseek
//
//  Created by Gosan on 6/7/26.
//

import Foundation

/// 클립 목록 + 기대 참가자에서 Story(Scene 순서열)를 만든다.
/// - 그룹핑: encounterID가 하나라도 있으면 인카운터별, 없으면 클립별 단독(가장 견고).
/// - 미수신(기대됐지만 클립 0개) 참가자는 검은 화면 Scene으로 채운다.
enum StoryBuilder {
    static func build(clips: [StoryClip], expected: [PeerID]) -> Story {
        var scenes: [StoryScene] = []
        
        if clips.contains(where: { $0.encounterID != nil }) {
            let groups = Dictionary(grouping: clips) { $0.encounterID ?? $0.id.uuidString }
            for group in groups.values {
                let sorted = group.sorted { $0.startedAt < $1.startedAt }
                let start = sorted.first?.startedAt ?? .distantPast
                scenes.append(StoryScene(tiles: sorted.map(SceneTile.clip), startedAt: start))
            }
        } else {
            for clip in clips {
                scenes.append(StoryScene(tiles: [.clip(clip)], startedAt: clip.startedAt))
            }
        }
        
        // 미수신 참가자 → 검은 화면 Scene (정렬상 끝으로 가도록 distantFuture)
        let contributed = Set(clips.map { $0.owner.rawID })
        for peer in expected where !contributed.contains(peer.rawID) {
            scenes.append(StoryScene(tiles: [.missing(peer)], startedAt: .distantFuture))
        }
        
        scenes.sort { $0.startedAt < $1.startedAt }
        return Story(scenes: scenes)
    }
}
