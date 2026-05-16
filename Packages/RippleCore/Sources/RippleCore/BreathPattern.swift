import Foundation

/// A user-defined breathing rhythm. Each value is a phase duration in
/// seconds. A phase set to 0 is skipped entirely — so hold = 0 turns a
/// 4-hold-6 into a simple 4-in / 6-out, and rest = 0 drops the box-style
/// fourth beat. This is the escape hatch for people who can't hold for
/// the preset 7 seconds (or want a longer exhale, shorter everything, etc).
public struct BreathPattern: Codable, Sendable, Equatable {
    public var inhale: Double
    public var holdFull: Double
    public var exhale: Double
    public var holdEmpty: Double

    /// Per-phase bounds. Inhale/exhale must be > 0 (a breath needs both);
    /// holds may be 0 (skipped). Cap keeps the UI steppers sane.
    public static let minActive: Double = 1
    public static let minHold: Double = 0
    public static let maxPhase: Double = 20

    public init(inhale: Double, holdFull: Double, exhale: Double, holdEmpty: Double) {
        self.inhale    = Self.clampActive(inhale)
        self.holdFull  = Self.clampHold(holdFull)
        self.exhale    = Self.clampActive(exhale)
        self.holdEmpty = Self.clampHold(holdEmpty)
    }

    /// A sensible starting point the first time someone opens the editor:
    /// 4-7-8 but with the hold dialed back to a more attainable 4s.
    public static let `default` = BreathPattern(inhale: 4, holdFull: 4, exhale: 6, holdEmpty: 0)

    private static func clampActive(_ v: Double) -> Double {
        min(max(v.rounded(), minActive), maxPhase)
    }
    private static func clampHold(_ v: Double) -> Double {
        min(max(v.rounded(), minHold), maxPhase)
    }

    /// The phase sequence for one cycle. Zero-duration holds are omitted so
    /// the runner never sleeps for 0 seconds or shows an empty "Hold 0".
    public var phases: [BreathPhase] {
        var result: [BreathPhase] = [
            .init(kind: .inhale, duration: inhale, label: "Breathe in"),
        ]
        if holdFull > 0 {
            result.append(.init(kind: .holdFull, duration: holdFull, label: "Hold"))
        }
        result.append(.init(kind: .exhale, duration: exhale, label: "Breathe out"))
        if holdEmpty > 0 {
            result.append(.init(kind: .holdEmpty, duration: holdEmpty, label: "Rest"))
        }
        return result
    }

    public var cycleDuration: TimeInterval {
        phases.reduce(0) { $0 + $1.duration }
    }

    /// Compact "4 · 4 · 6" style line for the picker card. Skipped phases
    /// are dropped so it matches what actually runs.
    public var patternLine: String {
        phases.map { Self.trim($0.duration) }.joined(separator: " · ")
    }

    /// Spelled-out description for VoiceOver.
    public var accessibilityDescription: String {
        var parts = ["\(Self.trim(inhale)) second inhale"]
        if holdFull > 0 { parts.append("\(Self.trim(holdFull)) second hold") }
        parts.append("\(Self.trim(exhale)) second exhale")
        if holdEmpty > 0 { parts.append("\(Self.trim(holdEmpty)) second rest") }
        return "Custom pattern. " + parts.joined(separator: ", ") + "."
    }

    private static func trim(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }
}
