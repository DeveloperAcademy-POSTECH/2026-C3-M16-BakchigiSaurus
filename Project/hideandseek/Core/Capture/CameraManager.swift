//
//  CameraManager.swift
//  hideandseek
//
//  Created by Gosan on 5/29/26.
//

import AVFoundation
import SwiftUI

final class RecorderDelegate: NSObject,
                              AVCaptureFileOutputRecordingDelegate,
                              @unchecked Sendable {
    
    private let output: AVCaptureMovieFileOutput
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    
    init(output: AVCaptureMovieFileOutput) {
        self.output = output
    }
    
    func start(to url: URL) {
        output.startRecording(to: url, recordingDelegate: self)
    }
    
    func stopAndWait() async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            lock.lock()
            continuation = cont
            lock.unlock()
            output.stopRecording()
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
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

actor CaptureService {
    
    nonisolated(unsafe) let session = AVCaptureSession()
    
    private let output = AVCaptureMovieFileOutput()
    private lazy var recorder = RecorderDelegate(output: output)
    
    func configure() throws {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video, position: .back) {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoInput) { session.addInput(videoInput) }
        }
        
        if let mic = AVCaptureDevice.default(for: .audio) {
            let audioInput = try AVCaptureDeviceInput(device: mic)
            if session.canAddInput(audioInput) { session.addInput(audioInput) }
        }
        
        if session.canAddOutput(output) { session.addOutput(output) }
        
        session.commitConfiguration()
    }
    
    func start() {
        guard !session.isRunning else { return }
        session.startRunning()
    }
    
    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }
    
    func startRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).mov")
        recorder.start(to: url)
    }
    
    func stopRecording() async throws -> URL {
        try await recorder.stopAndWait()
    }
}

@MainActor
@Observable
final class CameraModel {
    
    var isRecording = false
    var lastSavedURL: URL?
    
    let service = CaptureService()
    
    func bootstrap() async {
        guard await requestPermissions() else { return }
        do {
            try await service.configure()
            await service.start()
        } catch {
            print("setup error:", error)
        }
    }
    
    private func requestPermissions() async -> Bool {
        let video = await AVCaptureDevice.requestAccess(for: .video)
        let audio = await AVCaptureDevice.requestAccess(for: .audio)
        return video && audio
    }
    
    func toggleRecording() async {
        if isRecording {
            do {
                lastSavedURL = try await service.stopRecording()
            } catch {
                print("record error:", error)
            }
            isRecording = false
        } else {
            await service.startRecording()
            isRecording = true
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

struct RecordingView: View {
    @State private var model = CameraModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // ✅ model.service.session: nonisolated(unsafe)라 await 없이 main에서 접근 가능
            CameraPreview(session: model.service.session)
                .ignoresSafeArea()
            
            Button {
                Task { await model.toggleRecording() }
            } label: {
                Circle()
                    .fill(model.isRecording ? .red : .white)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(.white, lineWidth: 4).padding(4))
            }
            .padding(.bottom, 40)
        }
        .task { await model.bootstrap() }
    }
}
