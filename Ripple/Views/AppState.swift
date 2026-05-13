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

    /// Silent mode — when true, the bowl chimes are muted. Haptics still
    /// fire. Persisted to UserDefaults and synced to the paired watch.
    var audioMuted: Bool {
        didSet {
            UserDefaults.standard.set(audioMuted, forKey: Self.audioMutedKey)
            if !applyingRemoteContext {
                pushSync()
            }
        }
    }
    private static let audioMutedKey = "ripple.audioMuted"

    /// Guards the didSet hooks from pushing back to the peer when *we* are
    /// the one applying an incoming context change — avoids feedback loops.
    private var applyingRemoteContext = false

    /// Pulse trigger counter — SessionView increments, RootView's water view observes.
    var pulseTrigger: Int = 0
    var pulseIntensity: Float = 1.0

    /// Curtain opacity for the fade-to-black-and-return cycle.
    var curtainOpacity: Double = 0.0

    init() {
        let stored = UserDefaults.standard.bool(forKey: Self.audioMutedKey)
        self.audioMuted = stored

        // Hydrate from any context the watch already pushed before we
        // attached our handler.
        let initial = RippleConnectivity.shared.latestReceivedContext
        if let remoteMute = initial[RippleSyncKey.audioMuted] as? Bool, remoteMute != stored {
            applyingRemoteContext = true
            self.audioMuted = remoteMute
            applyingRemoteContext = false
        }

        // Subscribe to live updates from the watch.
        RippleConnectivity.shared.onContextReceived = { [weak self] ctx in
            self?.apply(remoteContext: ctx)
        }
    }

    private func apply(remoteContext: [String: Any]) {
        applyingRemoteContext = true
        defer { applyingRemoteContext = false }
        if let m = remoteContext[RippleSyncKey.audioMuted] as? Bool, m != audioMuted {
            audioMuted = m
        }
    }

    private func pushSync() {
        RippleConnectivity.shared.sync([
            RippleSyncKey.audioMuted: audioMuted,
        ])
    }

    /// Pick an exercise and transition into a session.
    func startSession(_ exercise: BreathExercise) {
        screen = .session(SessionConfig(exercise))
    }

    /// Called when the session completes; transitions into outro.
    func finishSession(_ config: SessionConfig) {
        let affirmation = AffirmationPool.random()
        screen = .outro(config, affirmation: affirmation)
    }

    /// Reset back to picker.
    func returnToPicker() {
        screen = .picker
    }
}
