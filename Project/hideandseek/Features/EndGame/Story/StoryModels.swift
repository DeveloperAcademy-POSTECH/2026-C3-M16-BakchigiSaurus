//
//  StoryModels.swift
//  hideandseek
//
//  Created by Gosan on 6/7/26.
//

import Foundation

/// 녹화된 클립 하나. startedAt은 스토리 정렬의 기준, encounterID는 인카운터 그룹핑의 기준.
struct StoryClip: Identifiable {
    let id: UUID
    let owner: PeerID
    let startedAt: Date
    let url: URL
    let encounterID: String?

    init(
        id: UUID = UUID(),
        owner: PeerID,
        startedAt: Date,
        url: URL,
        encounterID: String? = nil
    ) {
        self.id = id
        self.owner = owner
        self.startedAt = startedAt
        self.url = url
        self.encounterID = encounterID
    }
}

/// Scene 한 칸. 클립이 있거나, 미수신이면 검은 화면.
enum SceneTile: Identifiable {
    case clip(StoryClip)
    case missing(PeerID)

    var id: String {
        switch self {
        case let .clip(clip): clip.id.uuidString
        case let .missing(peer): "missing-\(peer.rawID)"
        }
    }
}

/// 타일 수에 따른 레이아웃. (2분할은 N=2인 특수 케이스)
enum SceneLayout {
    case full // 1
    case split // 2
    case grid // 3명 이상 (적응형 NxM)
}

/// 스토리 한 장면. 동시에 보여줄 타일 묶음.
struct StoryScene: Identifiable {
    let id = UUID()
    let tiles: [SceneTile]
    let startedAt: Date

    var layout: SceneLayout {
        switch tiles.count {
        case 0, 1: .full
        case 2: .split
        default: .grid
        }
    }
}

/// 전체 스토리 = Scene 순서열. Player/Export 공용 단일 진실원.
struct Story {
    let scenes: [StoryScene]
    var isEmpty: Bool {
        scenes.isEmpty
    }
}
