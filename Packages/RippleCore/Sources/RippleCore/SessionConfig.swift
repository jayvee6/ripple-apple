import Foundation

/// Configuration for a single session. Either a preset exercise OR a
/// user-defined custom pattern, plus a cycle count. The runner only ever
/// asks for `phases` and `cycles`, so the rest of the app is agnostic to
/// which kind it is.
public struct SessionConfig: Sendable, Equatable {
    public let exercise: BreathExercise
    public let cycles: Int
    /// When non-nil, overrides the preset's phases. The `exercise` field is
    /// still carried (set to a sentinel) so existing call sites compile, but
    /// `phases` / `displayName` / `accessibilityDescription` all defer to the
    /// custom pattern.
    public let customPattern: BreathPattern?

    // MARK: - Preset init

    public init(exercise: BreathExercise, cycles: Int) {
        self.exercise = exercise
        self.cycles = Self.clamped(cycles, fallback: exercise.defaultCycles)
        self.customPattern = nil
    }

    /// Convenience: preset with its default cycle count.
    public init(_ exercise: BreathExercise) {
        self.exercise = exercise
        self.cycles = exercise.defaultCycles
        self.customPattern = nil
    }

    // MARK: - Custom init

    public init(custom pattern: BreathPattern, cycles: Int) {
        self.exercise = .fourSevenEight // sentinel; never read when custom
        self.cycles = Self.clamped(cycles, fallback: 4)
        self.customPattern = pattern
    }

    // MARK: - Resolved values (preset or custom)

    public var isCustom: Bool { customPattern != nil }

    public var phases: [BreathPhase] {
        customPattern?.phases ?? exercise.phases
    }

    public var displayName: String {
        customPattern != nil ? "Custom" : exercise.displayName
    }

    public var accessibilityDescription: String {
        customPattern?.accessibilityDescription ?? exercise.accessibilityDescription
    }

    /// Total session duration in seconds — always derived from the actual
    /// phases so custom and preset compute the same way.
    public var totalSeconds: TimeInterval {
        phases.reduce(0) { $0 + $1.duration } * Double(cycles)
    }

    /// Clamp cycle count to the supported range. 1–10 matches web ripple.
    private static func clamped(_ n: Int, fallback: Int) -> Int {
        guard n > 0 else { return fallback }
        return min(max(n, 1), 10)
    }
}
