//
//  TransferStatusView.swift
//  hideandseek
//
//  Created by Gosan on 6/5/26.
//

import SwiftUI

/// 게임 종료 후 참가자별 영상 전송 현황을 보여주는 화면.
///
/// 수집은 화면 진입과 함께 자동으로 진행되고, 전원 수신되면 자동으로 다음 화면으로 넘어간다.
/// "이대로 영상 만들기"는 오류 등으로 진행이 막혔을 때 건너뛰는 용도라 확인 다이얼로그를 거친다.
struct TransferStatusView: View {
    let viewModel: TransferStatusViewModel
    /// 뒤로가기. nil이면 버튼을 숨긴다.
    var onBack: (() -> Void)?
    /// 건너뛰기 확인(네) 시 실제 영상 만들기를 시작하는 트리거.
    var onStart: () -> Void = {}
    /// 전원 수신 완료 시 다음 화면 전환.
    var onAllReceived: (() -> Void)?

    @State private var showsSkipConfirm = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                list
                Spacer(minLength: 0)
                footer
            }

            if showsSkipConfirm {
                skipConfirmDialog
            }

            if viewModel.phase == .completed {
                completionToast
            }
        }
        .foregroundStyle(.white)
        .animation(.easeInOut(duration: 0.2), value: showsSkipConfirm)
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete {
                onAllReceived?()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(viewModel.title)
                .font(.headline)

            if let onBack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.rows) { row in
                    TransferRowView(row: row)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 16) {
            if !viewModel.isHostReachable {
                Label("호스트와 연결이 끊겼어요", systemImage: "wifi.slash")
                    .font(.subheadline)
                    .foregroundStyle(.appWarning)
            }

            switch viewModel.phase {
            case .idle:
                idleFooter
            case .transferring:
                transferringIndicator
            case .completed:
                EmptyView() // 완료는 중앙 토스트로 표시
            case .failed:
                failedSection
            }
        }
        .padding(20)
    }

    private var idleFooter: some View {
        VStack(spacing: 14) {
            Text("영상이 모두 수신되면 다음화면으로 자동으로 넘어갑니다\n오류 등으로 계속 진행할 수 없는경우 아래 버튼을 눌러주세요")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showsSkipConfirm = true
            } label: {
                Text("이대로 영상 만들기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
    }

    private var transferringIndicator: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.overallProgress)
                .tint(.accentColor)

            Text("영상을 전송중이에요")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var failedSection: some View {
        VStack(spacing: 12) {
            Text("영상 전송을 실패했어요")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                viewModel.retry()
                onStart()
            } label: {
                Label("다시시도", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.appWarning)
        }
    }

    // MARK: - Overlays

    private var skipConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    showsSkipConfirm = false
                }

            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("정말로 건너뛸까요?")
                        .font(.headline.bold())

                    Text("영상을 수신하지 못한 참가자는 검은\n화면으로 표시됩니다")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button {
                        showsSkipConfirm = false
                    } label: {
                        Text("아니오")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.white)

                    Button {
                        showsSkipConfirm = false
                        viewModel.start()
                        onStart()
                    } label: {
                        Text("네")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.appDanger)
                }
            }
            .padding(24)
            .background(.appCard, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 44)
        }
    }

    private var completionToast: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.appSuccess)

            Text("영상 전송이 완료되었어요")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .background(.appCard, in: RoundedRectangle(cornerRadius: 24))
        .transition(.opacity)
    }
}

/// 참가자 한 명의 전송 상태 행.
private struct TransferRowView: View {
    let row: TransferStatusViewModel.Row

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.peer.displayName)
                    .font(.headline.bold())

                if let detail = row.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            trailingStatus
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.accentColor, lineWidth: row.isSeeker ? 2 : 0)
        )
    }

    private var rowBackground: Color {
        switch row.status {
        case .done:
            Color.appSuccess.opacity(0.35)
        case .failed:
            Color.appWarning.opacity(0.35)
        case .waiting, .transferring:
            Color.appCard
        }
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if row.isSeeker {
            Text("술래")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        } else {
            switch row.status {
            case .waiting:
                Text("대기중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .transferring:
                ProgressView()
                    .controlSize(.small)
            case .done:
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.appSuccess)
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.appWarning)
            }
        }
    }
}
