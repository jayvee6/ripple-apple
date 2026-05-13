import Foundation
#if canImport(HealthKit)
import HealthKit

/// Logs completed ripple sessions as Mindful Minutes in Apple Health.
/// HealthKit auto-deduplicates samples across paired devices, so logging
/// from both iOS and watchOS independently is safe — Health surfaces a
/// single session.
public final class MindfulnessLogger: @unchecked Sendable {
    public static let shared = MindfulnessLogger()
    private let healthStore = HKHealthStore()
    private let mindfulType = HKCategoryType(.mindfulSession)

    private init() {}

    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Request write authorization for mindful sessions. Safe to call multiple
    /// times — the system only prompts on the first call.
    public func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await healthStore.requestAuthorization(toShare: [mindfulType], read: [])
    }

    /// Log a completed session. `start` should be when the user began
    /// the first inhale; `duration` is the full session length in seconds.
    /// Silently no-ops if HealthKit isn't available or auth was denied.
    public func logSession(start: Date, duration: TimeInterval) async {
        guard isAvailable, duration > 0 else { return }
        let end = start.addingTimeInterval(duration)
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )
        do {
            try await healthStore.save(sample)
        } catch {
            // Auth denied or save failed — swallow. Logging is opportunistic.
        }
    }
}
#else
/// No-op fallback for platforms without HealthKit (visionOS / tvOS / Mac Catalyst).
public final class MindfulnessLogger: @unchecked Sendable {
    public static let shared = MindfulnessLogger()
    private init() {}
    public var isAvailable: Bool { false }
    public func requestAuthorization() async throws {}
    public func logSession(start: Date, duration: TimeInterval) async {}
}
#endif
