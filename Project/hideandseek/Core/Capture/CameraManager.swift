//
//  CameraManager.swift
//  hideandseek
//
//  Created by Gosan on 5/29/26.
//

//  게임 중 항상 켜져 있는 카메라 위에, 외부에서 주입한 Bool로
//  녹화(저장)와 블러 표시를 제어하는 재사용 카메라 스택.
//
//  ┌─ 구성 (3 레이어) ────────────────────────────────────────────┐
//  │ View      GameCameraBackground   preview + 블러 오버레이      │
//  │ Model     CameraModel            세션 수명 + 녹화 의도 관리     │
//  │ Capture   CaptureService(actor)  AVCaptureSession 접근 직렬화│
//  │           RecorderDelegate       녹화 완료 콜백 → async 변환   │
//  └───────────────────────────────────────────────────────────┘
//
//  빠른 시작
//  ---------
//  1) 게임 루트에서 CameraModel을 1개 만들고 bootstrap()을 1회 호출
//  2) 각 페이지 배경에 GameCameraBackground를 깔고 그 camera를 주입
//  3) isRevealed / isRecording 두 Bool로 블러·녹화를 제어
//
//      @State private var camera = CameraModel()
//      ...
//      GameCameraBackground(camera: camera,
//                           isRevealed: isNearby,
//                           isRecording: isNearby)
//          .task { await camera.bootstrap() }   // 루트에서 단 한 번
//
//  ⚠️ Info.plist 필수 키:
//     - NSCameraUsageDescription
//     - NSMicrophoneUsageDescription
//     (앨범 저장까지 하면 NSPhotoLibraryAddUsageDescription도)
//

import AVFoundation
import SwiftUI

// =====================================================================
// MARK: - RecorderDelegate

// =====================================================================

/// `AVCaptureMovieFileOutput`의 녹화 완료 delegate 콜백을 `async`/`await`로 바꿔주는 어댑터.
///
/// `AVCaptureFileOutputRecordingDelegate`는 `@objc` 프로토콜이라 `actor`가 직접 conform할 수 없다.
/// 그래서 이 클래스로 분리하고, delegate 콜백을 `CheckedContinuation`으로 연결해
/// ``stopAndWait()`` 한 번의 `await`로 결과 URL을 받을 수 있게 한다.
///
/// `continuation` 접근은 `NSLock`으로 직접 보호하므로 `@unchecked Sendable`로 표시한다.
///
/// - Important: 직접 쓰지 말고 ``CaptureService``를 통해서만 사용한다.
final nonisolated class RecorderDelegate: NSObject,
    AVCaptureFileOutputRecordingDelegate,
    @unchecked Sendable
{
    private let output: AVCaptureMovieFileOutput
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?

    /// - Parameter output: 이 delegate가 제어할 동영상 파일 출력.
    init(output: AVCaptureMovieFileOutput) {
        self.output = output
    }

    /// 지정한 경로로 녹화를 시작한다.
    /// - Parameter url: 결과 클립이 저장될 임시 파일 경로.
    func start(to url: URL) {
        output.startRecording(to: url, recordingDelegate: self)
    }

    /// 녹화를 멈추고, 파일 기록이 끝날 때까지 기다린 뒤 결과 URL을 돌려준다.
    /// - Returns: 녹화된 `.mov` 파일의 URL.
    /// - Throws: 녹화 중 발생한 오류.
    func stopAndWait() async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            // continuation을 먼저 arm한 "직후" stop을 호출해야
            // 완료 콜백이 빨리 들어와도 놓치지 않는다 (race 방지).
            lock.lock()
            continuation = cont
            lock.unlock()
            output.stopRecording()
        }
    }

    // AVCaptureFileOutputRecordingDelegate: AVFoundation이 자체 스레드에서 호출한다.
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()

        if let error {
            cont?.resume(throwing: error)
        } else {
            cont?.resume(returning: outputFileURL)
        }
    }
}

// =====================================================================
// MARK: - CaptureService

// =====================================================================

/// `AVCaptureSession`에 대한 모든 접근을 직렬화하는 actor.
///
/// 세션은 thread-safe하지 않으므로 구성/시작/정지/녹화를 actor로 감싸 동시 접근을 막는다.
/// 녹화 완료 처리는 ``RecorderDelegate``에 위임한다.
///
/// - Note: 보통 직접 쓰지 않고 ``CameraModel``을 통해 사용한다.
actor CaptureService {
    /// 미리보기 레이어에 연결할 캡처 세션.
    ///
    /// 미리보기(메인 액터)에서 읽어야 하는데 `AVCaptureSession`은 non-Sendable이라
    /// actor 밖으로 꺼낼 수 없다. setup 시 1회만 전달되는 안전한 케이스이므로
    /// `nonisolated(unsafe)`로 격리 검사를 해제한다.
    nonisolated(unsafe) let session = AVCaptureSession()

    private let output = AVCaptureMovieFileOutput()
    private lazy var recorder = RecorderDelegate(output: output)

    private var recordingStartedAt: Date?

    /// 후면 카메라 + 마이크 입력과 동영상 파일 출력을 세션에 구성한다.
    /// - Throws: 입력 디바이스(`AVCaptureDeviceInput`) 생성에 실패한 경우.
    func configure() throws {
        session.beginConfiguration()
        session.sessionPreset = .high

        if let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoInput) { session.addInput(videoInput) }
        }

        if let mic = AVCaptureDevice.default(for: .audio) { // 빠지면 무음 영상
            let audioInput = try AVCaptureDeviceInput(device: mic)
            if session.canAddInput(audioInput) { session.addInput(audioInput) }
        }

        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()
    }

    /// 세션을 시작한다. (이미 실행 중이면 무시)
    /// - Note: `startRunning()`은 blocking 호출이지만 시동 시 1회뿐이라 그대로 둔다.
    func start() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    /// 세션을 정지한다. (게임 종료 등 완전 정리 시점에 사용)
    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    /// 새 클립 녹화를 시작한다. 결과는 임시 디렉터리에 `.mov`로 저장된다.
    func startRecording() {
        guard !output.isRecording else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).mov")

        recordingStartedAt = Date()
        recorder.start(to: url)
    }

    /// 녹화를 멈추고 저장이 끝난 클립의 URL을 돌려준다.
    /// - Returns: 저장된 `.mov` 파일 URL.
    /// - Throws: 녹화 중 발생한 오류.
    func stopRecording() async throws -> RecordedClip {
        let url = try await recorder.stopAndWait()
        let started = recordingStartedAt ?? Date()
        recordingStartedAt = nil
        return RecordedClip(url: url, startedAt: started)
    }
}

// =====================================================================
// MARK: - CameraModel

// =====================================================================

/// 카메라 세션의 수명과 "녹화 의도"를 관리하는 메인 액터 모델.
///
/// 게임 룰(술래/숨는 사람)이나 블러를 전혀 모른다. 외부에서 주입하는 Bool에만 반응하므로
/// 여러 화면에서 **하나의 인스턴스를 공유**해 재사용하도록 설계됐다.
///
/// ## 사용 패턴
/// - 세션은 ``bootstrap()``으로 게임 시작 시 **한 번만** 켜고 게임 내내 유지한다.
/// - 녹화는 ``setRecording(_:)``에 Bool을 주입해 제어한다. (`true`=시작, `false`=정지+저장)
/// - 내부적으로 "원하는 상태(desired)"와 "실제 상태(``isRecording``)"를 수렴시켜
///   호출 순서/타이밍에 강하다. 예를 들어 세션 기동 전에 녹화 요청이 와도 누락되지 않는다.
///
/// ```swift
/// @State private var camera = CameraModel()
/// // ...
/// .task { await camera.bootstrap() }            // 게임 루트에서 1회
///
/// // 근접 감지 등으로 외부에서:
/// await camera.setRecording(true)   // 녹화 시작
/// await camera.setRecording(false)  // 정지 → lastSavedURL 갱신
/// ```
///
/// - Note: 모든 메서드가 `async`인 이유는, 메인 액터에서 돌면서 내부 ``service``(actor)를
///   건드릴 때마다 `await`로 경계를 넘기 때문이다.
@MainActor
@Observable
final class CameraModel {
    /// 세션이 구성·시작되어 녹화 가능한 상태인지 여부.
    var isReady = false

    /// 현재 녹화 중인지 여부.
    var isRecording = false

    /// 가장 최근에 저장된 클립의 파일 URL. ``setRecording(_:)``에 `false`를 준 뒤 갱신된다.
    var lastSaved: RecordedClip?

    /// 미리보기 연결 등에 쓰이는 캡처 서비스. (보통 직접 만질 필요 없음)
    let service = CaptureService()

    /// 외부에서 주입한 "원하는 녹화 상태". 실제 적용은 ``reconcile()``이 담당한다.
    private var desiredRecording = false

    /// 권한 요청 → 세션 구성 → 시작까지 한 번에 수행한다. 게임 루트에서 **1회만** 호출한다.
    ///
    /// 마지막에 ``reconcile()``을 호출해, 세션 기동 전에 들어온 녹화 요청이 있으면 반영한다.
    /// 중복 호출은 무시되므로(`isReady` 가드) `.task` 재실행 등에도 안전하다.
    func bootstrap() async {
        guard !isReady else { return }
        guard await requestPermissions() else { return }
        do {
            try await service.configure()
            await service.start()
            isReady = true
            await reconcile() // 기동 전 들어온 녹화 의도 반영
        } catch {
            print("setup error:", error)
        }
    }

    /// 세션을 정지하고 준비 상태를 해제한다. 게임을 완전히 떠날 때 호출한다.
    func stop() async {
        await service.stop()
        isReady = false
    }

    /// 녹화 여부를 외부 Bool로 제어하는 진입점.
    ///
    /// 직접 녹화를 켜고 끄지 않고 "원하는 상태"만 기록한 뒤 ``reconcile()``에 위임한다.
    /// 같은 값을 여러 번 주입해도 안전하다(중복 동작 없음).
    /// - Parameter shouldRecord: `true`면 녹화 시작, `false`면 정지하며 결과를 ``lastSavedURL``에 저장.
    func setRecording(_ shouldRecord: Bool) async {
        desiredRecording = shouldRecord
        await reconcile()
    }

    /// 원하는 상태(``desiredRecording``)와 실제 상태(``isRecording``)의 차이를 메운다.
    ///
    /// 차이가 있을 때만 동작하므로 반복 호출에 안전하고, 세션이 아직 안 켜졌으면 아무것도 하지 않는다.
    /// (선언형 reconciliation 패턴)
    private func reconcile() async {
        guard isReady else { return }

        if desiredRecording, !isRecording {
            await service.startRecording()
            isRecording = true
        } else if !desiredRecording, isRecording {
            do {
                lastSaved = try await service.stopRecording()
            } catch {
                print("record error:", error)
            }
            isRecording = false
        }
    }

    /// 카메라·마이크 권한을 요청한다.
    /// - Returns: 둘 다 허용되면 `true`, 하나라도 거부되면 `false`.
    private func requestPermissions() async -> Bool {
        let video = await AVCaptureDevice.requestAccess(for: .video)
        let audio = await AVCaptureDevice.requestAccess(for: .audio)
        return video && audio
    }
}

struct RecordedClip {
    let url: URL
    let startedAt: Date
}
