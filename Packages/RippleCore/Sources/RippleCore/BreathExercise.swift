import Foundation

/// A single phase of a breathing exercise — what to do, how long, what to call it.
/// Mirrors the JS phase objects in web ripple's EXERCISES registry.
public struct BreathPhase: Sendable, Equatable {
    public enum Kind: String, Sendable, CaseIterable {
        case inhale
        case inhaleTop   // second inhale on top of first (physiological sigh)
        case holdFull    // hold at top of breath
        case holdEmpty   // rest phase (box breathing's fourth beat)
        case exhale
    }

    public let kind: Kind
    public let duration: TimeInterval
    public let label: String

    public init(kind: Kind, duration: TimeInterval, label: String) {
        self.kind = kind
        self.duration = duration
        self.label = label
    }
}

/// The four breathing exercises ripple supports.
/// Each exercise is a sequence of phases that repeats for N cycles.
public enum BreathExercise: String, Sendable, CaseIterable, Identifiable {
    case fourSevenEight = "478"
    case box
    case coherent
    case sigh

    public var id: String { rawValue }

    /// Display name shown on the splash and picker card.
    public var displayName: String {
        switch self {
        case .fourSevenEight: return "4-7-8"
        case .box:            return "Box"
        case .coherent:       return "Coherent"
        case .sigh:           return "Sigh"
        }
    }

    /// One-line pattern shown on picker cards (e.g. "4 · 7 · 8").
    public var patternLine: String {
        switch self {
        case .fourSevenEight: return "4 · 7 · 8"
        case .box:            return "4 · 4 · 4 · 4"
        case .coherent:       return "5.5 · 5.5"
        case .sigh:           return "Double inhale"
        }
    }

    /// What the exercise is good for — used on picker cards.
    public var purpose: String {
        switch self {
        case .fourSevenEight: return "Stress relief"
        case .box:            return "Focus"
        case .coherent:       return "HRV training"
        case .sigh:           return "Quick reset"
        }
    }

    /// Human-readable description for VoiceOver — spelled out so screen readers
    /// don't stumble over the punctuation in "4-7-8" or "5.5 · 5.5".
    public var accessibilityDescription: String {
        switch self {
        case .fourSevenEight: return "Four seven eight breathing. Four-second inhale, seven-second hold, eight-second exhale."
        case .box:            return "Box breathing. Four-second inhale, hold, exhale, and rest."
        case .coherent:       return "Coherent breathing. Five and a half second inhale and exhale."
        case .sigh:           return "Physiological sigh. Double inhale and long exhale."
        }
    }

    /// Default cycle count. Tuned per exercise so a default session feels right.
    public var defaultCycles: Int {
        switch self {
        case .fourSevenEight: return 4
        case .box:            return 4
        case .coherent:       return 6
        case .sigh:           return 3
        }
    }

    /// The phase sequence that constitutes one cycle.
    public var phases: [BreathPhase] {
        switch self {
        case .fourSevenEight:
            return [
                .init(kind: .inhale,   duration: 4, label: "Breathe in"),
                .init(kind: .holdFull, duration: 7, label: "Hold"),
                .init(kind: .exhale,   duration: 8, label: "Breathe out"),
            ]
        case .box:
            return [
                .init(kind: .inhale,    duration: 4, label: "Breathe in"),
                .init(kind: .holdFull,  duration: 4, label: "Hold"),
                .init(kind: .exhale,    duration: 4, label: "Breathe out"),
                .init(kind: .holdEmpty, duration: 4, label: "Rest"),
            ]
        case .coherent:
            return [
                .init(kind: .inhale, duration: 5.5, label: "Breathe in"),
                .init(kind: .exhale, duration: 5.5, label: "Breathe out"),
            ]
        case .sigh:
            return [
                .init(kind: .inhale,    duration: 1.5, label: "Breathe in"),
                .init(kind: .inhaleTop, duration: 1.0, label: "A little more"),
                .init(kind: .exhale,    duration: 5.0, label: "Long exhale"),
            ]
        }
    }

    /// Total duration of one cycle in seconds.
    public var cycleDuration: TimeInterval {
        phases.reduce(0) { $0 + $1.duration }
    }

    /// Total duration of a session with N cycles.
    public func sessionDuration(cycles: Int) -> TimeInterval {
        cycleDuration * Double(cycles)
    }

    /// Friendly name → canonical exercise. Matches the JS `EXERCISE_ALIASES` table.
    public static func resolve(_ raw: String) -> BreathExercise? {
        switch raw.lowercased() {
        case "478", "4-7-8", "four-seven-eight":              return .fourSevenEight
        case "box", "square", "tactical":                     return .box
        case "coherent", "resonance", "hrv", "5.5":           return .coherent
        case "sigh", "physiological", "physsigh", "reset":    return .sigh
        default:                                              return nil
        }
    }
}
