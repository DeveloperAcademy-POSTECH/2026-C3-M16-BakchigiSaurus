//
//  StoryComposer.swift
//  hideandseek
//
//  Created by Gosan on 6/7/26.
//

import AVFoundation
import CoreGraphics

/// Story를 단일 영상으로 합성(export). 각 Scene을 레이아웃대로 배치해 순차 연결한다.
/// 미수신/빈 칸은 트랙을 안 깔아 배경(검정)이 그대로 노출된다.
///
/// ⚠️ 이 파일은 #6의 long-pole — 실기기 검증 필수. 아래 caveat 참고.
enum StoryComposer {
    static let renderSize = CGSize(width: 1080, height: 1920)   // portrait

    enum ComposeError: Error {
        case exportInitFailed
    }

    static func export(_ story: Story, to outputURL: URL) async throws {
        let composition = AVMutableComposition()
        var configuration = AVVideoComposition.Configuration()
        configuration.renderSize = renderSize
        configuration.frameDuration = CMTime(value: 1, timescale: 30)

        var cursor = CMTime.zero
        var instructions: [AVMutableVideoCompositionInstruction] = []

        for scene in story.scenes {
            var sceneDuration = CMTime(seconds: 3, preferredTimescale: 600)
            var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
            let frames = cellFrames(for: scene.layout, count: scene.tiles.count)

            for (tileIndex, tile) in scene.tiles.enumerated() {
                guard case let .clip(clip) = tile else { continue }   // 미수신=검정
                let asset = AVURLAsset(url: clip.url)
                guard let source = try await asset.loadTracks(withMediaType: .video).first else { continue }
                let duration = try await asset.load(.duration)
                sceneDuration = max(sceneDuration, duration)

                guard let track = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else { continue }
                try track.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: source,
                    at: cursor
                )

                guard tileIndex < frames.count else { continue }
                let frame = frames[tileIndex]
                let naturalSize = try await source.load(.naturalSize)
                let preferred = try await source.load(.preferredTransform)
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
                // preferredTransform(회전 보정) 먼저 → 셀 배치 transform
                layer.setTransform(
                    preferred.concatenating(transform(from: naturalSize, to: frame)),
                    at: cursor
                )
                layer.setCropRectangle(frame, at: cursor)   // 셀 밖으로 안 넘치게
                layerInstructions.append(layer)
            }

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: cursor, duration: sceneDuration)
            instruction.layerInstructions = layerInstructions
            instruction.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            instructions.append(instruction)

            cursor = cursor + sceneDuration
        }

        configuration.instructions = instructions
        let videoComposition = AVVideoComposition(configuration: configuration)

        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ComposeError.exportInitFailed
        }
        export.videoComposition = videoComposition
        try await export.export(to: outputURL, as: .mp4)
    }

    /// 레이아웃·타일 수에 맞춰 셀 프레임을 만든다 (renderSize 기준).
    private static func cellFrames(for layout: SceneLayout, count: Int) -> [CGRect] {
        let w = renderSize.width
        let h = renderSize.height
        switch layout {
        case .full:
            return [CGRect(x: 0, y: 0, width: w, height: h)]
        case .split:
            return [
                CGRect(x: 0, y: 0, width: w, height: h / 2),
                CGRect(x: 0, y: h / 2, width: w, height: h / 2),
            ]
        case .grid:
            // ✅ 거의 정사각형 그리드: 3·4→2열, 5·6→3열, 7~9→3열
            let columns = Int(Double(count).squareRoot().rounded(.up))
            let rows = Int((Double(count) / Double(columns)).rounded(.up))
            let cellWidth = w / CGFloat(columns)
            let cellHeight = h / CGFloat(rows)
            return (0 ..< count).map { i in
                let row = i / columns
                let col = i % columns
                return CGRect(
                    x: CGFloat(col) * cellWidth,
                    y: CGFloat(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
            }
        }
    }

    /// 소스 영상을 셀에 aspect-fill로 맞추는 transform.
    private static func transform(from natural: CGSize, to frame: CGRect) -> CGAffineTransform {
        let scale = max(frame.width / natural.width, frame.height / natural.height)
        let scaled = CGSize(width: natural.width * scale, height: natural.height * scale)
        let tx = frame.midX - scaled.width / 2
        let ty = frame.midY - scaled.height / 2
        return CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: tx, y: ty))
    }
}
