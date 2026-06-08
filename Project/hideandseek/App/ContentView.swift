//
//  ContentView.swift
//  hideandseek
//
//  Created by Lanakee on 5/28/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var roomFlow = RoomFlowViewModel()
    @State private var showingCreateRoom = false

    var body: some View {
        NavigationStack {
            Group {
                if let activeRoom = roomFlow.activeRoom {
                    RoomDetailView(
                        model: roomFlow,
                        room: activeRoom
                    )
                } else {
                    RoomListView(
                        model: roomFlow,
                        showingCreateRoom: $showingCreateRoom
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingCreateRoom) {
            NavigationStack {
                RoomCreateView(model: roomFlow)
            }
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    ContentView()
}
