//
//  StoryPlayerView.swift
//  hideandseek
//
//  Created by Gosan on 6/7/26.
//

import AVFoundation
import SwiftUI

/// 인스타 스토리식 재생 화면. Scene 순서대로 재생, 탭으로 앞/뒤 이동, 끝나면 자동 전환.
struct StoryPlayerView: View {
    let story: Story
    var onClose: () -> Void = {}

    @State private var index = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let scene = currentScene {
                StorySceneView(scene: scene, onFinished: advance)
                    .id(scene.id)
                    .ignoresSafeArea()
            }

            // 탭 네비게이션: 왼쪽 1/3 뒤로, 오른쪽 2/3 다음
            HStack(spacing: 0) {
                tapZone { back() }.frame(width: 96)
                tapZone { advance() }
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                progressBar
                topBar
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
    }

    private var currentScene: StoryScene? {
        story.scenes.indices.contains(index) ? story.scenes[index] : nil
    }

    private func tapZone(_ action: @escaping () -> Void) -> some View {
        Color.clear.contentShape(Rectangle()).onTapGesture(perform: action)
    }

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(story.scenes.indices, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(i <= index ? 0.9 : 0.3))
                    .frame(height: 3)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                // 공유는 #8(export)에서 연결
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
        }
        .font(.title3)
    }

    private func advance() {
        if index < story.scenes.count - 1 {
            index += 1
        } else {
            onClose()
        }
    }

    private func back() {
        if index > 0 { index -= 1 }
    }
}

/// Scene 한 장면. 클립 타일은 동시에 재생, 첫 클립이 끝나면 다음 Scene으로.
private struct StorySceneView: View {
    let scene: StoryScene
    var onFinished: () -> Void

    @State private var players: [String: AVPlayer] = [:]
    @State private var leaderItem: AVPlayerItem?

    private var hasClips: Bool {
        scene.tiles.contains { if case .clip = $0 { true } else { false } }
    }

    var body: some View {
        layout
            .background(Color.black)
            .onAppear(perform: setup)
            .onDisappear { players.values.forEach { $0.pause() } }
            .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { note in
                if let item = note.object as? AVPlayerItem, item === leaderItem { onFinished() }
            }
            .task {
                guard !hasClips else { return }   // 전부 미수신이면 3초 후 자동 전환
                try? await Task.sleep(for: .seconds(3))
                onFinished()
            }
    }

    @ViewBuilder
    private var layout: some View {
        switch scene.layout {
        case .full:
            tileView(at: 0)
        case .split:
            VStack(spacing: 0) {
                tileView(at: 0)
                tileView(at: 1)
            }
        case .grid:
            gridLayout   // ✅ 타일 수에 맞춰 NxM 적응형 (3~7명+)
        }
    }

    /// 타일 수에 맞춰 거의 정사각형 그리드로 배치. 빈 칸은 검은 화면.
    private var gridLayout: some View {
        let count = max(scene.tiles.count, 1)
        let columns = Int(Double(count).squareRoot().rounded(.up))   // 3·4→2, 5·6→3, 7~9→3
        let rows = Int((Double(count) / Double(columns)).rounded(.up))
        return VStack(spacing: 0) {
            ForEach(0 ..< rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0 ..< columns, id: \.self) { col in
                        tileView(at: row * columns + col)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tileView(at i: Int) -> some View {
        let tile = scene.tiles.indices.contains(i) ? scene.tiles[i] : nil
        switch tile {
        case let .clip(clip):
            if let player = players[clip.id.uuidString] {
                PlayerLayerView(player: player)
            } else {
                Color.black
            }
        case let .missing(peer):
            MissingTileView(name: peer.displayName)
        case nil:
            Color.black   // grid 빈 칸 = 검은 화면
        }
    }

    private func setup() {
        guard players.isEmpty else { return }
        for tile in scene.tiles {
            guard case let .clip(clip) = tile else { continue }
            players[clip.id.uuidString] = AVPlayer(url: clip.url)
        }
        if case let .clip(first)? = scene.tiles.first(where: { if case .clip = $0 { true } else { false } }) {
            leaderItem = players[first.id.uuidString]?.currentItem
        }
        players.values.forEach { $0.play() }
    }
}

/// 미수신 타일. 검은 화면 + 이름.
private struct MissingTileView: View {
    let name: String

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                Image(systemName: "video.slash")
                Text(name).font(.footnote)
            }
            .foregroundStyle(.white.opacity(0.4))
        }
    }
}

/// 컨트롤 없는 AVPlayer 레이어 (스토리용).
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context _: Context) -> PlayerContainer {
        let view = PlayerContainer()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerContainer, context _: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerContainer: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
