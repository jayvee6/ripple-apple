import SwiftUI
import RippleCore

struct WatchRootView: View {
    @State private var state = WatchAppState()

    var body: some View {
        ZStack {
            // Background — deep water gradient (no Metal on watch for perf/battery)
            RadialGradient(
                colors: [
                    Color(red: 0.059, green: 0.137, blue: 0.235),
                    Color(red: 0.020, green: 0.078, blue: 0.157),
                    Color(red: 0.012, green: 0.035, blue: 0.078),
                ],
                center: .center,
                startRadius: 20,
                endRadius: 220
            )
            .ignoresSafeArea()

            switch state.screen {
            case .picker:
                WatchExercisePicker { exercise in
                    state.startSession(exercise)
                }
            case .session(let config):
                WatchSessionView(config: config) {
                    state.finishSession()
                }
            case .outro(let affirmation):
                WatchAffirmationView(affirmation: affirmation) {
                    state.returnToPicker()
                }
            }
        }
        .environment(state)
    }
}
