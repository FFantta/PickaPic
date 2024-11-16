//
//  ContentView.swift
//  PickaPic
//
//  Created by Junrun Chen on 2024/11/16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "camera")
                }
            
            HistoryView()
                .tabItem {
                    Label("记录", systemImage: "photo.on.rectangle")
                }
        }
    }
}

#Preview {
    ContentView()
}
