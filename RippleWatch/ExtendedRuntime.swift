import Foundation
#if canImport(WatchKit)
import WatchKit

/// Owns a single WKExtendedRuntimeSession for the duration of a breathing
/// session. The `.mindAndBody` session type is sanctioned by Apple for
/// breathing/meditation experiences specifically — it keeps the watch app
/// running through wrist-down for several minutes, instead of getting
/// suspended after ~70 seconds when the wrist drops.
///
/// Pattern: start() when the session begins; stop() when it ends or the
/// view disappears. The class is its own delegate so the session can clean
/// up if the system ends it (e.g., user manually switches apps).
final class ExtendedRuntime: NSObject, WKExtendedRuntimeSessionDelegate, @unchecked Sendable {
    private var session: WKExtendedRuntimeSession?

    func start() {
        // Don't start a second session if one is already running.
        if let s = session, s.state == .running || s.state == .scheduled { return }
        let s = WKExtendedRuntimeSession()
        s.delegate = self
        s.start()
        session = s
    }

    func stop() {
        session?.invalidate()
        session = nil
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // System gave us a heads-up that the session is about to time out.
        // Could surface a "session ending" haptic here. For now, no-op.
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                error: Error?) {
        session = nil
    }
}
#endif
