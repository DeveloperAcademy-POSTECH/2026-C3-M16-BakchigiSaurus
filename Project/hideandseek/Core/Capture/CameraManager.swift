//
//  CameraManager.swift
//  hideandseek
//
//  Created by Gosan on 5/29/26.
//

//  게임 중 항상 켜져 있는 카메라 위에서 "버튼 클릭 → 사진 촬영"을 담당하는 재사용 스택.
//  (이전의 영상 녹화 방식은 제거됨)
//
//  ┌─ 구성 (3 레이어) ────────────────────────────────────────────┐
//  │ View      GameCameraBackground   preview + 블러 오버레이      │
//  │ Model     CameraModel            세션 수명 + 사진 촬영 제어     │
//  │ Capture   CaptureService(actor)  AVCaptureSession 접근 직렬화 │
//  │           PhotoCaptureProcessor  촬영 완료 콜백 → async 변환   │
//  └───────────────────────────────────────────────────────────┘
//
//  빠른 시작
//  ---------
//  1) 게임 루트에서 CameraModel을 1개 만들고 bootstrap()을 1회 호출
//  2) 각 페이지 배경에 GameCameraBackground를 깔고 그 camera를 주입
//  3) 촬영 가능 여부(블러)는 GameCameraBackground(isRevealed:)로 표현
//  4) 촬영 버튼에서 `await camera.capturePhoto()` 호출 → CapturedPhotoStore에 저장
//
//  힌트(NI 방향) 토글
//  ------------------
//  · 술래가 힌트를 쓰면 카메라 세션을 잠깐 닫고(closeSession) NI를 방향 모드로 돌린다.
//  · 힌트가 끝나면 다시 openSession()으로 카메라를 재개한다. (재구성 불필요, start만)
//
//  ⚠️ Info.plist 필수 키: NSCameraUsageDescription
//

import AVFoundation
import SwiftUI
import UIKit

// =====================================================================
// MARK: - PhotoCaptureProcessor

// =====================================================================

/// `AVCapturePhotoOutput`의 촬영 완료 delegate 콜백을 `async`/`await`로 바꿔주는 어댑터.
///
/// `AVCapturePhotoCaptureDelegate`는 `@objc` 프로토콜이라 `actor`가 직접 conform할 수 없다.
/// 그래서 이 클래스로 분리하고, 콜백을 `CheckedContinuation`으로 연결해
/// ``capture(using:settings:)`` 한 번의 `await`로 이미지 데이터를 받는다.
///
/// `continuation` 접근은 `NSLock`으로 보호하므로 `@unchecked Sendable`로 표시한다.
final nonisolated class PhotoCaptureProcessor: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?

    /// 한 장 촬영을 시작하고 이미지 데이터가 나올 때까지 기다린다.
    /// - Important: 한 번에 한 장만(직렬). 동시 호출은 ``CaptureService`` actor가 막는다.
    func capture(
        using output: AVCapturePhotoOutput,
        settings: AVCapturePhotoSettings
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            // continuation을 먼저 arm한 "직후" 촬영을 시작해야
            // 완료 콜백이 빨리 들어와도 놓치지 않는다.
            lock.lock()
            continuation = cont
            lock.unlock()
            output.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension PhotoCaptureProcessor: @preconcurrency AVCapturePhotoCaptureDelegate {
    /// AVFoundation이 자체 스레드에서 호출한다.
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()

        if let error {
            cont?.resume(throwing: error)
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            cont?.resume(throwing: CameraError.photoEncodingFailed)
            return
        }

        cont?.resume(returning: data)
    }
}

// =====================================================================
// MARK: - CaptureService

// =====================================================================

/// `AVCaptureSession`에 대한 모든 접근을 직렬화하는 actor.
///
/// 세션은 thread-safe하지 않으므로 구성/시작/정지/촬영을 actor로 감싸 동시 접근을 막는다.
/// 촬영 완료 처리는 ``PhotoCaptureProcessor``에 위임한다.
actor CaptureService {
    /// 미리보기 레이어에 연결할 캡처 세션.
    ///
    /// 미리보기(메인 액터)에서 읽어야 하는데 `AVCaptureSession`은 non-Sendable이라
    /// actor 밖으로 꺼낼 수 없다. setup 시 1회만 전달되는 안전한 케이스이므로
    /// `nonisolated(unsafe)`로 격리 검사를 해제한다.
    nonisolated(unsafe) let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private lazy var processor = PhotoCaptureProcessor()
    private var isConfigured = false

    /// 후면 카메라 입력과 사진 출력을 세션에 구성한다. (오디오 입력 없음)
    /// - Throws: 입력 디바이스(`AVCaptureDeviceInput`) 생성에 실패한 경우.
    func configure() throws {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        if let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoInput) { session.addInput(videoInput) }
        }

        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        session.commitConfiguration()
        isConfigured = true
    }

    /// 세션을 시작한다. (이미 실행 중이면 무시)
    func start() {
        debugLog("start requested isRunningBefore=\(session.isRunning)")
        guard !session.isRunning else {
            debugLog("start skipped: already running")
            return
        }

        session.startRunning()
        debugLog("start finished isRunningAfter=\(session.isRunning)")
    }

    /// 세션을 정지한다. (힌트 NI 토글, 게임 종료 등)
    func stop() {
        debugLog("stop requested isRunningBefore=\(session.isRunning)")
        guard session.isRunning else {
            debugLog("stop skipped: already stopped")
            return
        }

        session.stopRunning()
        debugLog("stop finished isRunningAfter=\(session.isRunning)")
    }

    var isRunning: Bool {
        session.isRunning
    }

    /// 한 장 촬영하고 인코딩된 이미지 데이터를 돌려준다.
    /// - Throws: 세션 미실행(``CameraError/sessionNotRunning``) 또는 촬영/인코딩 실패.
    func capturePhoto() async throws -> Data {
        guard session.isRunning else { throw CameraError.sessionNotRunning }
        let settings = AVCapturePhotoSettings()
        return try await processor.capture(using: photoOutput, settings: settings)
    }

    private func debugLog(_ message: String) {
        #if DEBUG
            print("[CaptureService] \(message)")
        #endif
    }
}

// =====================================================================
// MARK: - CameraModel

// =====================================================================

/// 카메라 세션의 수명과 "사진 촬영"을 관리하는 메인 액터 모델.
///
/// 게임 룰(술래/숨는 사람)이나 블러를 전혀 모른다. 외부에서 호출만 받으므로
/// 여러 화면에서 **하나의 인스턴스를 공유**해 재사용하도록 설계됐다.
///
/// ## 사용 패턴
/// - 세션은 ``bootstrap()``으로 게임 시작 시 **한 번만** 켜고 게임 내내 유지한다.
/// - 촬영은 ``capturePhoto()``로 한 장씩 찍는다.
/// - 힌트(NI 방향)를 위해 잠깐 카메라를 비울 땐 ``closeSession()`` / ``openSession()``.
@MainActor
@Observable
final class CameraModel {
    /// 세션이 구성·시작되어 촬영 가능한 상태가 된 적이 있는지.
    var isReady = false

    /// 현재 세션이 실행(프리뷰/촬영 가능) 중인지. 힌트 토글 시 false로 내려간다.
    var isSessionRunning = false

    /// 미리보기 연결 등에 쓰이는 캡처 서비스. (보통 직접 만질 필요 없음)
    let service = CaptureService()

    private var didConfigure = false

    /// 권한 요청 → 세션 구성 → 시작까지 한 번에 수행한다. 게임 루트에서 **1회만** 호출한다.
    /// 중복 호출은 무시되므로(`isReady` 가드) `.task` 재실행 등에도 안전하다.
    func bootstrap() async {
        debugLog("bootstrap requested isReady=\(isReady) isSessionRunning=\(isSessionRunning)")
        guard !isReady else { return }
        guard await requestCameraPermission() else { return }

        do {
            try await service.configure()
            await service.start()
            didConfigure = true
            isReady = true
            isSessionRunning = await service.isRunning
            debugLog("bootstrap finished isReady=\(isReady) isSessionRunning=\(isSessionRunning)")
        } catch {
            print("camera setup error:", error)
        }
    }

    /// 카메라 세션을 잠깐 닫는다. (힌트 NI 방향 측정을 위해 카메라 자원을 양보할 때)
    func closeSession() async {
        let actualRunningBefore = await service.isRunning
        debugLog(
            "closeSession requested isReady=\(isReady) " +
                "modelRunning=\(isSessionRunning) actualRunning=\(actualRunningBefore)"
        )
        await service.stop()
        isSessionRunning = await service.isRunning
        debugLog(
            "closeSession finished isReady=\(isReady) " +
                "modelRunning=\(isSessionRunning)"
        )
    }

    /// 카메라 세션을 다시 연다. (힌트 종료 후) 재구성 없이 start만 한다.
    func openSession() async {
        let actualRunningBefore = await service.isRunning
        debugLog(
            "openSession requested didConfigure=\(didConfigure) isReady=\(isReady) " +
                "modelRunning=\(isSessionRunning) actualRunning=\(actualRunningBefore)"
        )
        guard didConfigure else {
            await bootstrap()
            return
        }

        await service.start()
        isSessionRunning = await service.isRunning
        debugLog(
            "openSession finished isReady=\(isReady) " +
                "modelRunning=\(isSessionRunning)"
        )
    }

    /// 세션을 정지하고 준비 상태를 해제한다. 게임을 완전히 떠날 때 호출한다.
    func stop() async {
        debugLog("stop requested isReady=\(isReady) isSessionRunning=\(isSessionRunning)")
        await service.stop()
        isReady = false
        isSessionRunning = false
        debugLog("stop finished isReady=\(isReady) isSessionRunning=\(isSessionRunning)")
    }

    /// 한 장 촬영한다. 세션이 안 켜져 있으면 nil. 성공 시 ``CapturedPhoto``를 돌려준다.
    /// - Parameters:
    ///   - photographerID: 촬영자의 안정적인 게임 참가자 ID.
    ///   - photographerName: 촬영 시점의 표시 이름.
    ///   - photographerRole: 촬영자 역할.
    /// - Returns: 촬영본. 호출 측에서 ``CapturedPhotoStore/add(_:)``로 저장한다.
    @discardableResult
    func capturePhoto(
        photographerID: PlayerID? = nil,
        photographerName: String? = nil,
        photographerRole: PlayerRole? = nil
    ) async -> CapturedPhoto? {
        guard isSessionRunning else { return nil }

        do {
            let rawData = try await service.capturePhoto()
            let data = normalizedPhotoDataForStory(from: rawData)
            debugLog(
                "capturePhoto succeeded rawBytes=\(rawData.count) storedBytes=\(data.count) " +
                    "photographer=\(photographerName ?? "nil") role=\(String(describing: photographerRole))"
            )
            return CapturedPhoto(
                imageData: data,
                capturedAt: Date(),
                photographerID: photographerID,
                photographerName: photographerName,
                photographerRole: photographerRole
            )
        } catch {
            print("photo capture error:", error)
            return nil
        }
    }

    /// MC data 메시지로도 안정적으로 보낼 수 있게 스토리용 크기로 정규화한다.
    private func normalizedPhotoDataForStory(
        from data: Data,
        maxPixel: CGFloat = 1440,
        compressionQuality: CGFloat = 0.72
    ) -> Data {
        guard let image = UIImage(data: data) else {
            debugLog("normalize skipped: UIImage decode failed bytes=\(data.count)")
            return data
        }

        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > 0 else {
            return data
        }

        let scale = min(1, maxPixel / longestSide)
        let targetSize = CGSize(
            width: max(1, floor(size.width * scale)),
            height: max(1, floor(size.height * scale))
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let jpegData = renderedImage.jpegData(compressionQuality: compressionQuality) else {
            debugLog("normalize skipped: JPEG encode failed bytes=\(data.count)")
            return data
        }

        debugLog(
            "normalize photo originalSize=\(Int(size.width))x\(Int(size.height)) " +
                "targetSize=\(Int(targetSize.width))x\(Int(targetSize.height)) " +
                "rawBytes=\(data.count) jpegBytes=\(jpegData.count)"
        )
        return jpegData
    }

    /// 카메라 권한을 요청한다. (마이크는 사용하지 않음)
    private func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    private func debugLog(_ message: String) {
        #if DEBUG
            print("[CameraModel] \(message)")
        #endif
    }
}
