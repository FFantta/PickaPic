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
                    VStack {
                        Image("bottom1_d")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                        // Text("今日")
                    }
                }
            
            HistoryView()
                .tabItem {
                    VStack {
                        Image("bottom2_d")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                        // Text("记录")
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
