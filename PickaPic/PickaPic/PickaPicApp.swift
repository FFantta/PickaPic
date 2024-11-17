//
//  PickaPicApp.swift
//  PickaPic
//
//  Created by Junrun Chen on 2024/11/16.
//

import SwiftUI

@main
struct PickaPicApp: App {
    @StateObject private var photoManager = PhotoManager()
    
    init() {
        // 设置支持的方向
        if #available(iOS 16.0, *) {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.forEach { windowScene in
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoManager)
        }
    }
}
