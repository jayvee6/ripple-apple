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

    /// Silent mode — mutes bowl chimes; haptics still fire.
    /// Persisted locally and synced to the paired iPhone.
    var audioMuted: Bool {
        didSet {
            UserDefaults.standard.set(audioMuted, forKey: Self.audioMutedKey)
            if !applyingRemoteContext {
                pushSync()
            }
        }
    }
    private static let audioMutedKey = "ripple.audioMuted"
    private var applyingRemoteContext = false

    init() {
        let stored = UserDefaults.standard.bool(forKey: Self.audioMutedKey)
        self.audioMuted = stored

        // Hydrate from any context the phone already pushed.
        let initial = RippleConnectivity.shared.latestReceivedContext
        if let remoteMute = initial[RippleSyncKey.audioMuted] as? Bool, remoteMute != stored {
            applyingRemoteContext = true
            self.audioMuted = remoteMute
            applyingRemoteContext = false
        }

        // Live updates from the phone.
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
