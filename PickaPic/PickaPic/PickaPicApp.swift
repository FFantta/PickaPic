//
//  PickaPicApp.swift
//  PickaPic
//
//  Created by Junrun Chen on 2024/11/16.
//

import SwiftUI

@main
struct PickaPicApp: App {
    // 添加环境对象来管理照片数据
    @StateObject private var photoManager = PhotoManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoManager)
        }
    }
}
