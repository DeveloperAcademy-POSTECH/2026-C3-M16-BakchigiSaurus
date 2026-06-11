//
//  PhotoStoryViewModel.swift
//  hideandseek
//

import Foundation
import Observation

@MainActor
@Observable
final class PhotoStoryViewModel {
    let photos: [CapturedPhoto]
    let perPhotoDuration: TimeInterval

    private(set) var currentIndex = 0
    private(set) var progress: Double = 0
    private(set) var isPaused = false
    private(set) var isFinished = false

    private var tickTask: Task<Void, Never>?
    private let frameInterval: TimeInterval = 1.0 / 30.0

    init(photos: [CapturedPhoto], perPhotoDuration: TimeInterval = 4) {
        self.photos = photos
        self.perPhotoDuration = perPhotoDuration
    }

    var currentPhoto: CapturedPhoto? {
        guard photos.indices.contains(currentIndex) else { return nil }
        return photos[currentIndex]
    }

    func start() {
        currentIndex = 0
        progress = 0
        isPaused = false
        isFinished = photos.isEmpty

        guard !photos.isEmpty else {
            tickTask?.cancel()
            tickTask = nil
            return
        }

        startTicking()
    }

    func pause() {
        guard !isFinished else { return }
        isPaused = true
    }

    func resume() {
        guard !isFinished else { return }
        isPaused = false
    }

    func next() {
        guard !photos.isEmpty, !isFinished else { return }

        if currentIndex >= photos.count - 1 {
            finish()
            return
        }

        currentIndex += 1
        progress = 0
    }

    func previous() {
        guard !photos.isEmpty, !isFinished else { return }

        if progress > 0.18 || currentIndex == 0 {
            progress = 0
            return
        }

        currentIndex -= 1
        progress = 0
    }

    func restart() {
        start()
    }

    func finish() {
        tickTask?.cancel()
        tickTask = nil
        progress = 1
        isPaused = false
        isFinished = true
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(frameInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self?.tick()
                }
            }
        }
    }

    private func tick() {
        guard !isPaused, !isFinished, !photos.isEmpty else { return }

        let delta = frameInterval / max(perPhotoDuration, 0.1)
        progress = min(1, progress + delta)
        if progress >= 1 {
            next()
        }
    }
}
