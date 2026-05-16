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
    var audioMuted: Bool {
        didSet {
            UserDefaults.standard.set(audioMuted, forKey: Self.audioMutedKey)
            if !applyingRemoteContext { pushSync() }
        }
    }
    /// Custom rhythm + cycles, synced bidirectionally with the phone.
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
    private static let audioMutedKey = "ripple.audioMuted"
    private static let customPatternKey = "ripple.customPattern"
    private static let customCyclesKey = "ripple.customCycles"
    private var applyingRemoteContext = false

    init() {
        let stored = UserDefaults.standard.bool(forKey: Self.audioMutedKey)
        self.audioMuted = stored

        if let data = UserDefaults.standard.data(forKey: Self.customPatternKey),
           let p = try? JSONDecoder().decode(BreathPattern.self, from: data) {
            self.customPattern = p
        } else {
            self.customPattern = .default
        }
        let cc = UserDefaults.standard.integer(forKey: Self.customCyclesKey)
        self.customCycles = cc > 0 ? cc : 4

        let initial = RippleConnectivity.shared.latestReceivedContext
        if let remoteMute = initial[RippleSyncKey.audioMuted] as? Bool, remoteMute != stored {
            applyingRemoteContext = true
            self.audioMuted = remoteMute
            applyingRemoteContext = false
        }
        applyCustom(from: initial)

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

    func startSession(_ exercise: BreathExercise) {
        screen = .session(SessionConfig(exercise))
    }

    func startCustomSession() {
        screen = .session(SessionConfig(custom: customPattern, cycles: customCycles))
    }

    func finishSession() {
        screen = .outro(affirmation: AffirmationPool.random())
    }

    func returnToPicker() {
        screen = .picker
    }
}
