import SwiftUI
import RippleCore

@main
struct RippleWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .preferredColorScheme(.dark)
        }
    }
}
