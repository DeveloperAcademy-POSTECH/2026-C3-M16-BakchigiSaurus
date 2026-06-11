//
//  CapturedPhotoStore.swift
//  hideandseek
//
//  버튼 클릭으로 촬영한 사진을 촬영 시각과 함께 모아두는 로컬 저장소.
//
//  이번 단계 범위: "촬영 → 로컬 저장(시간순)"까지만 담당한다.
//  종료 후 갤러리 화면/피어 간 전송(MC)은 다음 단계에서 이 저장소를 소비하면 된다.
//

import Foundation
import UIKit

/// 한 장의 촬영 결과. `capturedAt` 기준으로 정렬해 "촬영 시간 순" 노출에 사용한다.
struct CapturedPhoto: Identifiable, Hashable {
    let id: UUID
    /// JPEG/HEIC 등 인코딩된 원본 이미지 데이터.
    let imageData: Data
    /// 촬영 시각. 갤러리 정렬 키.
    let capturedAt: Date
    /// 누가 찍었는지(술래/숨는 사람) 표시·필터링용. 필요 없으면 무시 가능.
    let ownerRole: PlayerRole?

    init(
        id: UUID = UUID(),
        imageData: Data,
        capturedAt: Date = .now,
        ownerRole: PlayerRole? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.capturedAt = capturedAt
        self.ownerRole = ownerRole
    }

    /// SwiftUI 표시용 이미지. 디코딩 실패 시 nil.
    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}

/// 촬영본을 시간순으로 보관하는 메인 액터 저장소.
///
/// 게임 루트에서 1개 만들어 술래/숨는 사람 화면에 공유 주입한다.
/// (`@State private var photoStore = CapturedPhotoStore()`)
@MainActor
@Observable
final class CapturedPhotoStore {
    /// 항상 `capturedAt` 오름차순으로 정렬된 상태를 유지한다.
    private(set) var photos: [CapturedPhoto] = []

    /// 촬영본 1장을 추가한다. 삽입 후 시간순 정렬을 보장한다.
    func add(_ photo: CapturedPhoto) {
        photos.append(photo)
        photos.sort { $0.capturedAt < $1.capturedAt }
    }

    /// 전체 비우기(새 게임 시작 등).
    func reset() {
        photos.removeAll()
    }

    var count: Int { photos.count }
}
