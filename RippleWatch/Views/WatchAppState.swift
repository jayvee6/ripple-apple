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

    /// Silent mode — mutes the bowl chimes; haptics still fire.
    var audioMuted: Bool {
        didSet { UserDefaults.standard.set(audioMuted, forKey: Self.audioMutedKey) }
    }
    private static let audioMutedKey = "ripple.audioMuted"

    init() {
        self.audioMuted = UserDefaults.standard.bool(forKey: Self.audioMutedKey)
    }

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
