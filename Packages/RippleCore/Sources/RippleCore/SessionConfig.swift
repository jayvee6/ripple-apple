import Foundation

/// Configuration for a single session — exercise + cycle count.
public struct SessionConfig: Sendable, Equatable {
    public let exercise: BreathExercise
    public let cycles: Int

    public init(exercise: BreathExercise, cycles: Int) {
        self.exercise = exercise
        self.cycles = Self.clamped(cycles, exercise: exercise)
    }

    /// Convenience: use the exercise's default cycle count.
    public init(_ exercise: BreathExercise) {
        self.exercise = exercise
        self.cycles = exercise.defaultCycles
    }

    /// Total session duration in seconds.
    public var totalSeconds: TimeInterval {
        exercise.sessionDuration(cycles: cycles)
    }

    /// Clamp cycle count to the supported range. 1–10 matches web ripple.
    private static func clamped(_ n: Int, exercise: BreathExercise) -> Int {
        guard n > 0 else { return exercise.defaultCycles }
        return min(max(n, 1), 10)
    }
}
