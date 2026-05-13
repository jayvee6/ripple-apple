import SwiftUI
import RippleCore

@main
struct RippleWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

struct WatchContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.020, green: 0.035, blue: 0.072)
                .ignoresSafeArea()
            VStack(spacing: 4) {
                Text("ripple")
                    .font(.system(size: 22, weight: .ultraLight))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text("v\(Ripple.version)")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
    }
}

#Preview {
    WatchContentView()
}
