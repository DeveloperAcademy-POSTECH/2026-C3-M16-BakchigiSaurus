//
//  CameraManager.swift
//  hideandseek
//
//  Created by Gosan on 5/29/26.
//

import AVFoundation
import SwiftUI

nonisolated final class RecorderDelegate: NSObject,
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
