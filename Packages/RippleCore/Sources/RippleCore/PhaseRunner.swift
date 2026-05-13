import Foundation

/// Drives a breathing session as an async sequence of phase events.
///
/// Usage:
/// ```
/// let runner = PhaseRunner(config: SessionConfig(.fourSevenEight))
/// for await event in runner.events {
///     // event.kind tells you what happened (start, phaseBegan, cycleEnded, sessionEnded)
/// }
/// ```
public struct PhaseRunner {
    public let config: SessionConfig

    public init(config: SessionConfig) {
        self.config = config
    }

    /// Stream of phase events. Each phase yields a `phaseBegan` at start; the
    /// task sleeps for the phase duration; the next phase begins. After all
    /// cycles complete, a `sessionEnded` event closes the stream.
    public var events: AsyncStream<PhaseEvent> {
        AsyncStream { continuation in
            let task = Task {
                continuation.yield(PhaseEvent(kind: .sessionBegan, cycleIndex: 0, phase: nil))
                for cycleIdx in 0..<config.cycles {
                    if Task.isCancelled { break }
                    continuation.yield(PhaseEvent(kind: .cycleBegan, cycleIndex: cycleIdx, phase: nil))
                    for phase in config.exercise.phases {
                        if Task.isCancelled { break }
                        continuation.yield(PhaseEvent(kind: .phaseBegan, cycleIndex: cycleIdx, phase: phase))
                        try? await Task.sleep(nanoseconds: UInt64(phase.duration * 1_000_000_000))
                    }
                    continuation.yield(PhaseEvent(kind: .cycleEnded, cycleIndex: cycleIdx, phase: nil))
                }
                continuation.yield(PhaseEvent(kind: .sessionEnded, cycleIndex: config.cycles - 1, phase: nil))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

public struct PhaseEvent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case sessionBegan
        case cycleBegan
        case phaseBegan
        case cycleEnded
        case sessionEnded
    }

    public let kind: Kind
    public let cycleIndex: Int
    public let phase: BreathPhase?
}
