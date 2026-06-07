//
//  NIDebugTestView.swift
//  hideandseek
//
//  Created by 허지우 on 6/7/26.
//

import SwiftUI

struct NIDebugTestView: View {
    @StateObject private var viewModel = NIDebugViewModel()

    var body: some View {
        NavigationStack {
            List {
                localSection
                niMeasurementSection
                actionSection
                discoveredPeersSection
                connectedPeersSection
                logSection
            }
            .navigationTitle("MC / NI Debug")
            .toolbar {
                Button("새로고침") {
                    viewModel.refreshPeers()
                }
            }
        }
    }

    private var localSection: some View {
        Section("Local") {
            Text("Local: \(viewModel.localPeer.displayName)")
            Text("Host: \(viewModel.hostPeer.displayName)")
        }
    }

    private var niMeasurementSection: some View {
        Section("Nearby Interaction") {
//            LabeledContent("거리", value: viewModel.distanceText)
//            LabeledContent("방향", value: viewModel.directionText)

            VStack(spacing: 16) {
                Text("거리: \(viewModel.distanceText)")
                Text("방향: \(viewModel.directionText)")

                Image(systemName: "arrow.up")
                    .font(.system(size: 60))
                    .rotationEffect(
                        .radians(Double(viewModel.horizontalAngle ?? 0))
                    )
                    .foregroundStyle(
                        viewModel.horizontalAngle == nil ? .gray : .blue
                    )
            }
        }
    }

    private var actionSection: some View {
        Section("Actions") {
            Button("호스트 시작") {
                viewModel.startHosting()
            }

            Button("호스트 중지") {
                viewModel.stopHosting()
            }

            Button("주변 호스트 탐색 시작") {
                viewModel.startBrowsing()
            }

            Button("주변 호스트 탐색 중지") {
                viewModel.stopBrowsing()
            }

            Button("MC / NI 종료", role: .destructive) {
                viewModel.stop()
            }
        }
    }

    private var discoveredPeersSection: some View {
        Section("Discovered Peers") {
            if viewModel.discoveredPeers.isEmpty {
                Text("발견된 호스트 없음")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.discoveredPeers, id: \.rawID) { peer in
                    Button {
                        viewModel.invite(peer)
                    } label: {
                        peerLabel(peer)
                    }
                }
            }
        }
    }

    private var connectedPeersSection: some View {
        Section("Current Peers") {
            if viewModel.currentPeers.isEmpty {
                Text("연결된 peer 없음")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.currentPeers, id: \.rawID) { peer in
                    peerLabel(peer)
                }
            }
        }
    }

    private var logSection: some View {
        Section("Logs") {
            if viewModel.logs.isEmpty {
                Text("로그 없음")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(viewModel.logs.enumerated()),
                    id: \.offset
                ) { _, log in
                    Text(log)
                        .font(.caption)
                }
            }
        }
    }

    private func peerLabel(_ peer: PeerID) -> some View {
        VStack(alignment: .leading) {
            Text(peer.displayName)

            Text(peer.rawID)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NIDebugTestView()
}
