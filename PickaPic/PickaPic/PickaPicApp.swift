import SwiftUI

@main
struct PickaPicApp: App {
    @StateObject private var store = JournalStore()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(store).preferredColorScheme(.light).tint(Paper.ink) }
    }
}
