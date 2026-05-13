import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

/// Thin two-way sync over WatchConnectivity. Both iOS and watchOS apps
/// activate the shared session on launch and call `sync(_:)` to push a
/// dictionary of preferences (mute flag, last picked exercise, etc.) to
/// the paired device. The peer's delegate callback fires `onContextReceived`
/// on the main thread so the receiving AppState can update.
///
/// Uses `updateApplicationContext` (not `sendMessage`): the system holds
/// only the latest dictionary and delivers it whenever the peer next
/// becomes reachable — perfect for "settings that should match across
/// devices" without needing real-time reachability.
public final class RippleConnectivity: NSObject, @unchecked Sendable {
    public static let shared = RippleConnectivity()

    /// Called whenever the peer device pushes new application context.
    /// Always invoked on the main thread.
    public var onContextReceived: (([String: Any]) -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Push a snapshot of preferences to the peer device. Subsequent calls
    /// fully replace the prior context — only the most recent state ships.
    public func sync(_ updates: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext(updates)
        } catch {
            // Silently swallow — Watch Connectivity errors are best-effort.
            // If the peer is unreachable now, the system will redeliver the
            // latest context the next time it activates.
        }
    }

    /// Snapshot of the most recently received context, if any. Useful for
    /// reading initial state at app launch before any new push arrives.
    public var latestReceivedContext: [String: Any] {
        guard WCSession.isSupported() else { return [:] }
        return WCSession.default.receivedApplicationContext
    }
}

extension RippleConnectivity: WCSessionDelegate {
    public func session(_ session: WCSession,
                        activationDidCompleteWith activationState: WCSessionActivationState,
                        error: Error?) {
        // No-op. We don't surface activation state to the rest of the app —
        // the sync(_:) call gates on activationState itself.
    }

    public func session(_ session: WCSession,
                        didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.onContextReceived?(applicationContext)
        }
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        // System tears down the session when the active paired watch
        // changes; re-activate so the new pairing gets our context.
        WCSession.default.activate()
    }
    #endif
}

/// Shared keys for the WatchConnectivity application context dictionary.
public enum RippleSyncKey {
    public static let audioMuted = "audioMuted"
    public static let lastExercise = "lastExercise"
}
#endif
