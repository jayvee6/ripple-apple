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

    /// User's saved custom breathing rhythm. Persisted as JSON; synced to
    /// the watch so a pattern built on the phone is available on the wrist.
    var customPattern: BreathPattern {
        didSet {
            if let data = try? JSONEncoder().encode(customPattern) {
                UserDefaults.standard.set(data, forKey: Self.customPatternKey)
            }
            if !applyingRemoteContext { pushSync() }
        }
    }
    var customCycles: Int {
        didSet {
            UserDefaults.standard.set(customCycles, forKey: Self.customCyclesKey)
            if !applyingRemoteContext { pushSync() }
        }
    }
    private static let customPatternKey = "ripple.customPattern"
    private static let customCyclesKey = "ripple.customCycles"

    /// Pulse trigger counter — SessionView increments, RootView's water view observes.
    var pulseTrigger: Int = 0
    var pulseIntensity: Float = 1.0

    /// Curtain opacity for the fade-to-black-and-return cycle.
    var curtainOpacity: Double = 0.0

    init() {
        let stored = UserDefaults.standard.bool(forKey: Self.audioMutedKey)
        self.audioMuted = stored

        // Hydrate custom pattern + cycles from disk
        if let data = UserDefaults.standard.data(forKey: Self.customPatternKey),
           let p = try? JSONDecoder().decode(BreathPattern.self, from: data) {
            self.customPattern = p
        } else {
            self.customPattern = .default
        }
        let cc = UserDefaults.standard.integer(forKey: Self.customCyclesKey)
        self.customCycles = cc > 0 ? cc : 4

        // Hydrate from any context the watch already pushed before we
        // attached our handler.
        let initial = RippleConnectivity.shared.latestReceivedContext
        if let remoteMute = initial[RippleSyncKey.audioMuted] as? Bool, remoteMute != stored {
            applyingRemoteContext = true
            self.audioMuted = remoteMute
            applyingRemoteContext = false
        }
        applyCustom(from: initial)

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
        applyCustom(from: remoteContext)
    }

    /// Decode a custom pattern + cycles out of a WatchConnectivity context.
    private func applyCustom(from ctx: [String: Any]) {
        if let data = ctx[RippleSyncKey.customPattern] as? Data,
           let p = try? JSONDecoder().decode(BreathPattern.self, from: data),
           p != customPattern {
            customPattern = p
        }
        if let cyc = ctx[RippleSyncKey.customCycles] as? Int, cyc != customCycles {
            customCycles = cyc
        }
    }

    private func pushSync() {
        var ctx: [String: Any] = [RippleSyncKey.audioMuted: audioMuted]
        if let data = try? JSONEncoder().encode(customPattern) {
            ctx[RippleSyncKey.customPattern] = data
        }
        ctx[RippleSyncKey.customCycles] = customCycles
        RippleConnectivity.shared.sync(ctx)
    }

    /// Pick an exercise and transition into a session.
    func startSession(_ exercise: BreathExercise) {
        screen = .session(SessionConfig(exercise))
    }

    /// Start a session from the custom rhythm editor.
    func startCustomSession(_ pattern: BreathPattern, cycles: Int) {
        screen = .session(SessionConfig(custom: pattern, cycles: cycles))
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
