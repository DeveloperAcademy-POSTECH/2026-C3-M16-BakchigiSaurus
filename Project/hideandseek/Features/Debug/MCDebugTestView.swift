//
//  MCDebugTestView.swift
//  hideandseek
//
//  Created by 서혜린 on 6/5/26.
//
//  MCDebugTestView.swift
//  hideandseek
//

import SwiftUI

struct MCDebugTestView: View {
    @StateObject private var viewModel = MCDebugViewModel()

    var body: some View {
        NavigationStack {
            List {
                localSection
                actionSection
                discoveredPeersSection
                connectedPeersSection
                logSection
            }
            .navigationTitle("MC Debug")
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
                        VStack(alignment: .leading) {
                            Text(peer.displayName)
                            Text(peer.rawID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                    VStack(alignment: .leading) {
                        Text(peer.displayName)
                        Text(peer.rawID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                ForEach(viewModel.logs, id: \.self) { log in
                    Text(log)
                        .font(.caption)
                }
            }
        }
    }
}

#Preview {
    MCDebugTestView()
}
