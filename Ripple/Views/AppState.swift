import SwiftUI
import RippleCore

/// Central observable state for the iOS app. Drives the root view's
/// picker / session / outro routing and exposes the current SessionConfig.
@Observable
final class AppState {
    enum Screen: Equatable {
        case picker
        case session(SessionConfig)
        case outro(SessionConfig, affirmation: String)
    }

    var screen: Screen = .picker

    /// Pulse trigger counter — SessionView increments, RootView's water view observes.
    /// Using an integer counter (rather than a Bool) lets repeated triggers fire
    /// even when consecutive values would otherwise be equal.
    var pulseTrigger: Int = 0
    var pulseIntensity: Float = 1.0

    /// Curtain opacity for the fade-to-black-and-return cycle.
    /// Range 0...1. AffirmationView animates this up; RootView animates it down.
    var curtainOpacity: Double = 0.0

    /// Pick an exercise and transition into a session.
    func startSession(_ exercise: BreathExercise) {
        screen = .session(SessionConfig(exercise))
    }

    /// Called when the session completes; transitions into outro.
    func finishSession(_ config: SessionConfig) {
        let affirmation = AffirmationPool.random()
        screen = .outro(config, affirmation: affirmation)
    }

    /// Reset back to picker (slow fade-to-black + return handled by the view).
    func returnToPicker() {
        screen = .picker
    }
}
