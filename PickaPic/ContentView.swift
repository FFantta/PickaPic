import SwiftUI

struct ContentView: View {
    @StateObject private var photoManager = PhotoManager()
    
    var body: some View {
        TabView {
            CalendarView()
                .environmentObject(photoManager)
                .tabItem {
                    Label("日历", systemImage: "calendar")
                }
            
            CameraView()
                .environmentObject(photoManager)
                .tabItem {
                    Label("拍照", systemImage: "camera")
                }
        }
    }
} 