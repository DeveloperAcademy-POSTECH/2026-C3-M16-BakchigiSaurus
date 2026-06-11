//
//  EndGamePhotoShareView.swift
//  hideandseek
//

import SwiftUI

struct EndGamePhotoShareView: View {
    let photoStore: CapturedPhotoStore

    @State private var viewModel: PhotoShareViewModel
    @State private var isShowingStory = false

    init(
        gameModel: GameModel,
        mcSession: MultipeerGameSession,
        photoStore: CapturedPhotoStore
    ) {
        self.photoStore = photoStore
        self._viewModel = State(
            initialValue: PhotoShareViewModel(
                gameModel: gameModel,
                session: mcSession,
                photoStore: photoStore
            )
        )
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            if isShowingStory {
                PhotoStoryView(photos: photoStore.photos) {
                    isShowingStory = false
                }
                .transition(.opacity)
            } else {
                shareStatusContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isShowingStory)
        .task {
            viewModel.startSharingIfNeeded()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }

    private var shareStatusContent: some View {
        VStack(spacing: 0) {
            header

            if viewModel.rows.isEmpty {
                emptyParticipantsContent
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.rows) { row in
                            PhotoShareParticipantRow(row: row)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                }
            }

            footer
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("박치기 사우루스 숨바꼭질")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("게임이 종료됐어요")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.horizontal, 24)
    }

    private var emptyParticipantsContent: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "person.2.slash")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("사진을 받을 참여자가 없어요")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            if !viewModel.isFinishedCollecting {
                ProgressView(value: viewModel.progress)
                    .tint(.accentColor)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.progress)

                Text("촬영한 사진을 주고받는 중이에요")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if viewModel.hasPhotos {
                Text(viewModel.hasFailures ? "일부 사진 수신을 완료하지 못했어요" : "사진을 모두 모았어요")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(viewModel.hasFailures ? .orange : .secondary)
            } else {
                Text("촬영된 사진이 없어요")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if viewModel.canRetry {
                Button {
                    viewModel.retryFailedTransfers()
                } label: {
                    Label("다시 요청", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.glass)
                .tint(.orange)
            }

            Button {
                isShowingStory = true
            } label: {
                Label(
                    storyButtonTitle,
                    systemImage: viewModel.hasPhotos ? "play.fill" : "photo"
                )
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.glassProminent)
            .tint(.accent)
            .disabled(!viewModel.hasPhotos)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private var storyButtonTitle: String {
        guard viewModel.hasPhotos else { return "사진 없음" }
        return viewModel.hasFailures ? "받은 사진만 보기" : "스토리 보기"
    }
}

private struct PhotoShareParticipantRow: View {
    let row: PhotoShareViewModel.Row

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(row.peer.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(roleText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(roleColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(roleColor.opacity(0.15), in: Capsule())
                }

                Text(detailText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusIcon
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(rowBorder, lineWidth: 1)
        }
    }

    private var detailText: String {
        switch row.status {
        case .waiting:
            "대기중"
        case .received:
            "\(row.photoCount)장 수신"
        case .noPhotos:
            "보낸 사진 없음"
        case .failed:
            "수신 실패"
        }
    }

    private var roleText: String {
        switch row.role {
        case .tagger:
            "술래"
        case .hider:
            "숨는 사람"
        case .unassigned:
            "참여자"
        }
    }

    private var roleColor: Color {
        switch row.role {
        case .tagger:
            .orange
        case .hider:
            .green
        case .unassigned:
            .secondary
        }
    }

    private var rowBackground: Color {
        switch row.status {
        case .waiting:
            Color.white.opacity(0.07)
        case .received:
            Color.green.opacity(0.16)
        case .noPhotos:
            Color.white.opacity(0.08)
        case .failed:
            Color.orange.opacity(0.18)
        }
    }

    private var rowBorder: Color {
        switch row.status {
        case .waiting:
            Color.white.opacity(0.12)
        case .received:
            Color.green.opacity(0.34)
        case .noPhotos:
            Color.white.opacity(0.18)
        case .failed:
            Color.orange.opacity(0.34)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch row.status {
        case .waiting:
            ProgressView()
                .controlSize(.small)
                .tint(.accentColor)
        case .received:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        case .noPhotos:
            Image(systemName: "minus.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
        }
    }
}
