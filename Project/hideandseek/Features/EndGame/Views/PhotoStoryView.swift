//
//  PhotoStoryView.swift
//  hideandseek
//

import SwiftUI

struct PhotoStoryView: View {
    let onClose: () -> Void

    @State private var viewModel: PhotoStoryViewModel
    @State private var pressStartedAt: Date?

    init(
        photos: [CapturedPhoto],
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        let sortedPhotos = photos.sorted { $0.capturedAt < $1.capturedAt }
        self._viewModel = State(initialValue: PhotoStoryViewModel(photos: sortedPhotos))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                currentImage(size: proxy.size)

                gradientOverlays

                VStack(spacing: 12) {
                    StoryProgressBars(
                        count: viewModel.photos.count,
                        currentIndex: viewModel.currentIndex,
                        progress: viewModel.progress
                    )
                    .padding(.horizontal, 10)

                    HStack(spacing: 10) {
                        if let photo = viewModel.currentPhoto {
                            PhotographerChip(photo: photo)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(.black.opacity(0.34), in: Circle())
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer()
                }
                .padding(.top, topControlsPadding(proxy))

                if viewModel.isFinished {
                    finishedOverlay
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(storyGesture(width: proxy.size.width))
        }
        .ignoresSafeArea()
        .task {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private func topControlsPadding(_ proxy: GeometryProxy) -> CGFloat {
        max(proxy.safeAreaInsets.top, 24) + 60
    }

    @ViewBuilder
    private func currentImage(size: CGSize) -> some View {
        if let image = viewModel.currentPhoto?.uiImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo")
                    .font(.system(size: 44))
                Text("사진을 불러올 수 없어요")
                    .font(.headline)
            }
            .foregroundStyle(.white.opacity(0.72))
            .frame(width: size.width, height: size.height)
        }
    }

    private var gradientOverlays: some View {
        VStack {
            LinearGradient(
                colors: [.black.opacity(0.72), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)

            Spacer()

            LinearGradient(
                colors: [.clear, .black.opacity(0.54)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
        }
        .ignoresSafeArea()
    }

    private var finishedOverlay: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.green)

                Text("모든 사진을 봤어요")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Button {
                        viewModel.restart()
                    } label: {
                        Label("다시 보기", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        onClose()
                    } label: {
                        Text("닫기")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .frame(maxWidth: 320)
            }
            .padding(24)
        }
    }

    private func storyGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if pressStartedAt == nil {
                    pressStartedAt = Date()
                    viewModel.pause()
                }
            }
            .onEnded { value in
                let elapsed = pressStartedAt.map { Date().timeIntervalSince($0) } ?? 0
                pressStartedAt = nil
                viewModel.resume()

                guard elapsed < 0.25, !viewModel.isFinished else { return }
                if value.location.x < width / 3 {
                    viewModel.previous()
                } else {
                    viewModel.next()
                }
            }
    }
}
