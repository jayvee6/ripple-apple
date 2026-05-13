import SwiftUI
import RippleCore

@Observable
final class WatchAppState {
    enum Screen: Equatable {
        case picker
        case session(SessionConfig)
        case outro(affirmation: String)
    }

    var screen: Screen = .picker

    func startSession(_ exercise: BreathExercise) {
        screen = .session(SessionConfig(exercise))
    }

    func finishSession() {
        screen = .outro(affirmation: AffirmationPool.random())
    }

    func returnToPicker() {
        screen = .picker
    }
}
