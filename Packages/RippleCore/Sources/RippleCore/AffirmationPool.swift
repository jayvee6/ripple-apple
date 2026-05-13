import Foundation

/// The ten quiet affirmations shown at the end of a session.
/// Voice: second-person, present-tense, observation over motivation.
/// Source: web ripple v4 (AFFIRMATIONS const).
public enum AffirmationPool {
    public static let all: [String] = [
        "You're doing great.",
        "Welcome back to now.",
        "That breath was yours.",
        "Carry this calm with you.",
        "Nothing else needed right now.",
        "You showed up.",
        "Steadier than a minute ago.",
        "Whatever it was, smaller now.",
        "You can come back here anytime.",
        "A little quieter.",
    ]

    /// Pick a random affirmation. Uses the system random source by default;
    /// inject a custom one for deterministic tests.
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> String {
        all.randomElement(using: &generator) ?? all[0]
    }

    public static func random() -> String {
        var rng = SystemRandomNumberGenerator()
        return random(using: &rng)
    }
}
