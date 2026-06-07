//
//  ContentView.swift
//  hideandseek
//
//  Created by Lanakee on 5/28/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        StoryPlayerView(story: Story(scenes: [StoryScene]())) {
            print("")
        }
    }
}

#Preview {
    ContentView()
}
