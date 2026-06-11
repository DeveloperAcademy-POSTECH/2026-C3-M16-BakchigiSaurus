//
//  CapturedPhotoStore.swift
//  hideandseek
//
//  버튼 클릭으로 촬영한 사진을 촬영 시각과 촬영자 정보와 함께 모아두는 로컬 저장소.
//
//  게임 종료 후에는 MC로 들어온 다른 참여자의 사진을 같은 저장소에 머지하고,
//  스토리 뷰어가 이 저장소를 시간순으로 재생한다.
//

import Foundation
import UIKit

/// 한 장의 촬영 결과. `capturedAt` 기준으로 정렬해 "촬영 시간 순" 노출에 사용한다.
struct CapturedPhoto: Codable, Identifiable, Hashable {
    let id: UUID
    /// JPEG/HEIC 등 인코딩된 원본 이미지 데이터.
    let imageData: Data
    /// 촬영 시각. 갤러리 정렬 키.
    let capturedAt: Date
    /// 촬영자의 안정적인 게임 참가자 ID. 표시/필터/중복 판단에 사용한다.
    let photographerID: PlayerID?
    /// 촬영 시점의 표시 이름. 게임 종료 후에도 그대로 보여주기 위해 사진에 박아둔다.
    let photographerName: String?
    /// 촬영자 역할. 스토리 칩의 배지에 사용한다.
    let photographerRole: PlayerRole?

    init(
        id: UUID = UUID(),
        imageData: Data,
        capturedAt: Date = .now,
        photographerID: PlayerID? = nil,
        photographerName: String? = nil,
        photographerRole: PlayerRole? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.capturedAt = capturedAt
        self.photographerID = photographerID
        self.photographerName = photographerName
        self.photographerRole = photographerRole
    }

    /// SwiftUI 표시용 이미지. 디코딩 실패 시 nil.
    var uiImage: UIImage? {
        UIImage(data: imageData)
    }

    var displayName: String {
        let trimmed = photographerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "익명" : trimmed
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
        guard !photos.contains(where: { $0.id == photo.id }) else {
            debugLog("skip duplicate id=\(photo.id) bytes=\(photo.imageData.count)")
            return
        }

        photos.append(photo)
        photos.sort { $0.capturedAt < $1.capturedAt }
        debugLog(
            "add id=\(photo.id) bytes=\(photo.imageData.count) " +
                "photographer=\(photo.displayName) role=\(String(describing: photo.photographerRole)) total=\(photos.count)"
        )
    }

    /// 외부 피어에서 받은 사진 묶음을 머지한다. 중복 사진은 ID 기준으로 무시한다.
    func mergeRemote(_ remotePhotos: [CapturedPhoto]) {
        let bytes = remotePhotos.reduce(0) { $0 + $1.imageData.count }
        debugLog("mergeRemote count=\(remotePhotos.count) bytes=\(bytes) currentTotal=\(photos.count)")
        for photo in remotePhotos {
            add(photo)
        }
    }

    /// 전체 비우기(새 게임 시작 등).
    func reset() {
        photos.removeAll()
    }

    var isEmpty: Bool {
        photos.isEmpty
    }

    var count: Int {
        photos.count
    }

    private func debugLog(_ message: String) {
        #if DEBUG
            print("[CapturedPhotoStore] \(message)")
        #endif
    }
}
