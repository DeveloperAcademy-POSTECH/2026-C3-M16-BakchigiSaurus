//
//  TransferStatusView.swift
//  hideandseek
//
//  Created by Gosan on 6/5/26.
//

import SwiftUI
 
/// 게임 종료 후 참가자별 영상 전송 현황을 보여주는 화면.
struct TransferStatusView: View {
    let viewModel: TransferStatusViewModel
    /// "이대로 영상 만들기"/"다시시도" 탭 시 실제 전송을 시작하는 트리거.
    let onStart: () -> Void
 
    var body: some View {
        VStack(spacing: 0) {
            header
            list
            Spacer()
            footer
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
    }
 
    private var header: some View {
        Text(viewModel.title)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }
 
    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.rows) { row in
                    TransferRowView(row: row)
                }
            }
            .padding(.horizontal, 20)
        }
    }
 
    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 16) {
            if !viewModel.isHostReachable {
                Label("호스트와 연결이 끊겼어요", systemImage: "wifi.slash")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            // ✅ 버튼 / 프로그레스바를 동시에 띄우지 않고 phase로 하나만 노출
            switch viewModel.phase {
            case .idle:
                startButton
            case .transferring:
                transferringIndicator
            case .completed:
                Label("영상 전송이 완료되었어요", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                failedSection
            }
        }
        .padding(20)
    }
 
    private var startButton: some View {
        Button {
            viewModel.start() // ✅ 탭하는 순간부터 전송 시작 → 프로그레스바로 전환
            onStart()
        } label: {
            Text("이대로 영상 만들기")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
    }
 
    private var transferringIndicator: some View {
        VStack(spacing: 6) {
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
            .tint(.orange)
        }
    }
}
 
/// 참가자 한 명의 전송 상태 행.
private struct TransferRowView: View {
    let row: TransferStatusViewModel.Row
 
    var body: some View {
        HStack(spacing: 12) {
            Text(row.peer.displayName)
                .font(.body)
            Spacer()
            if row.isSeeker {
                Text("술래")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15), in: Capsule())
            }
            statusIcon
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
 
    @ViewBuilder
    private var statusIcon: some View {
        switch row.status {
        case .waiting:
            Text("대기중") // ✅ 시작 전 상태
                .font(.caption)
                .foregroundStyle(.secondary)
        case .transferring:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}

#Preview("시작 전") {
    let mock = MockGameSession(asHost: true)
    let session = CollectorSession(session: mock)
    let transfer = ClipTransferService(transport: mock)
    let viewModel = TransferStatusViewModel(
        title: "박치기 사우루스 숨바꼭질",
        session: session,
        transfer: transfer,
        seekerIDs: ["p1"]
    )
    return TransferStatusView(viewModel: viewModel, onStart: {})
}
 
#Preview("전송 중") {
    let mock = MockGameSession(asHost: true)
    let session = CollectorSession(session: mock)
    let transfer = ClipTransferService(transport: mock)
    let viewModel = TransferStatusViewModel(
        title: "박치기 사우루스 숨바꼭질",
        session: session,
        transfer: transfer,
        seekerIDs: ["p1"]
    )
    viewModel.start()
    return TransferStatusView(viewModel: viewModel, onStart: {})
}
