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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // 锁定竖屏方向
        OrientationManager.shared.lockOrientation()
        
        // 强制使用浅色模式
        UIWindow.appearance().overrideUserInterfaceStyle = .light
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoManager)
                .preferredColorScheme(.light)
        }
    }
}
