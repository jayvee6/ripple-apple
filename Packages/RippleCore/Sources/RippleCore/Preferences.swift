import Foundation

/// Lightweight preference store backed by UserDefaults. Lives in a shared
/// suite so the iOS app + watchOS app + (later) a widget extension can all
/// read/write the same values.
public actor Preferences {
    public static let shared = Preferences()

    private let defaults: UserDefaults
    private let suiteName: String?

    public init(suiteName: String? = "group.dev.studiojoe.ripple") {
        self.suiteName = suiteName
        // Fall back to .standard if the App Group isn't available yet (e.g., dev simulator)
        self.defaults = (suiteName.flatMap { UserDefaults(suiteName: $0) }) ?? .standard
    }

    // MARK: - Last-picked exercise

    public func lastExercise() -> BreathExercise {
        let raw = defaults.string(forKey: Keys.lastExercise) ?? BreathExercise.fourSevenEight.rawValue
        return BreathExercise(rawValue: raw) ?? .fourSevenEight
    }

    public func setLastExercise(_ exercise: BreathExercise) {
        defaults.set(exercise.rawValue, forKey: Keys.lastExercise)
    }

    // MARK: - Total session count (lifetime)

    public func sessionsCompleted() -> Int {
        defaults.integer(forKey: Keys.sessionsCompleted)
    }

    public func incrementSessions() {
        defaults.set(sessionsCompleted() + 1, forKey: Keys.sessionsCompleted)
    }

    // MARK: - Reactions log (rolling, capped)

    /// A short rolling log of reactions per exercise.
    /// `BreathExercise.rawValue → [reaction strings, newest last]`.
    public func reactions() -> [String: [String]] {
        (defaults.dictionary(forKey: Keys.reactions) as? [String: [String]]) ?? [:]
    }

    public func appendReaction(_ reaction: String, for exercise: BreathExercise, maxPer: Int = 20) {
        var map = reactions()
        var list = map[exercise.rawValue] ?? []
        list.append(reaction)
        if list.count > maxPer { list.removeFirst(list.count - maxPer) }
        map[exercise.rawValue] = list
        defaults.set(map, forKey: Keys.reactions)
    }

    // MARK: - Custom breath pattern

    /// The user's saved custom rhythm. Defaults to BreathPattern.default
    /// (4-4-6, attainable hold) the first time the editor is opened.
    public func customPattern() -> BreathPattern {
        guard let data = defaults.data(forKey: Keys.customPattern),
              let pattern = try? JSONDecoder().decode(BreathPattern.self, from: data)
        else { return .default }
        return pattern
    }

    public func setCustomPattern(_ pattern: BreathPattern) {
        guard let data = try? JSONEncoder().encode(pattern) else { return }
        defaults.set(data, forKey: Keys.customPattern)
    }

    public func customCycles() -> Int {
        let v = defaults.integer(forKey: Keys.customCycles)
        return v > 0 ? v : 4
    }

    public func setCustomCycles(_ n: Int) {
        defaults.set(min(max(n, 1), 10), forKey: Keys.customCycles)
    }

    private enum Keys {
        static let lastExercise = "ripple.lastExercise"
        static let sessionsCompleted = "ripple.sessionsCompleted"
        static let reactions = "ripple.reactions"
        static let customPattern = "ripple.customPattern"
        static let customCycles = "ripple.customCycles"
    }
}
