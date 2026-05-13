import SwiftUI
import RippleCore

@main
struct RippleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.020, green: 0.035, blue: 0.072)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("ripple")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text("v\(Ripple.version)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
    }
}

#Preview {
    ContentView()
}
