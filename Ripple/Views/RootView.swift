import SwiftUI
import RippleCore

/// Top-level container that owns the persistent water canvas and routes
/// between picker / session / outro screens. Curtain overlay sits on top
/// so we can fade-to-black between session and picker without a snap.
struct RootView: View {
    @State private var state = AppState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // 1. The water — persistent across all screens. Pure decoration:
            //    the actual phase state is conveyed via HUD + announcements.
            MetalWaterView(pulseTrigger: state.pulseTrigger, pulseIntensity: state.pulseIntensity)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // 2. The current screen
            currentScreen
                .id(screenIdentity)
                .transition(.opacity)

            // 3. Curtain overlay — decorative; the outro view handles its own
            //    accessibility announcement before the curtain falls.
            Color.black
                .ignoresSafeArea()
                .opacity(state.curtainOpacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(Color(red: 0.020, green: 0.035, blue: 0.072))
        .environment(state)
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch state.screen {
        case .picker:
            ExercisePicker { exercise in
                state.startSession(exercise)
            }
        case .session(let config):
            SessionView(config: config) {
                state.finishSession(config)
            } onExit: {
                // Straight back to the picker — no outro, no HealthKit log
                state.returnToPicker()
            }
        case .outro(_, let affirmation):
            AffirmationView(affirmation: affirmation) {
                completeOutro()
            }
        }
    }

    private var screenIdentity: String {
        switch state.screen {
        case .picker:                       return "picker"
        case .session:                      return "session"
        case .outro(_, let affirmation):    return "outro-\(affirmation)"
        }
    }

    /// Outro completion handler — orchestrates the fade-to-black, state
    /// swap, and curtain retraction. Mirrors web ripple v4.2.
    private func completeOutro() {
        // Step 1: snap to picker UNDER the now-opaque black curtain
        state.returnToPicker()
        // Step 2: retract the curtain. Reduce Motion: instant.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 5.0)) {
                state.curtainOpacity = 0.0
            }
            // Announce that we're back on the picker so VoiceOver focus
            // moves to the new screen content.
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
}
