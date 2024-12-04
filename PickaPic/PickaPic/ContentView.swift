//
//  ContentView.swift
//  PickaPic
//
//  Created by Junrun Chen on 2024/11/16.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    VStack {
                        Image(selectedTab == 0 ? "icon1_l" : "bottom1_d")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                        // Text("今日")
                    }
                }
                .tag(0)
            
            HistoryView()
                .tabItem {
                    VStack {
                        Image(selectedTab == 1 ? "icon2_l" : "bottom2_d")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                        // Text("记录")
                    }
                }
                .tag(1)
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
