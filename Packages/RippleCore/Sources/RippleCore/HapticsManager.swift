import Foundation
#if canImport(CoreHaptics) && (os(iOS) || os(watchOS))
import CoreHaptics

/// Fires breath-cue haptics synchronized with bowl strikes.
///
/// Each phase gets its own pattern:
/// - inhale: rising-intensity continuous + final transient (the "rise into")
/// - inhaleTop: short crisp transient (the second-inhale top-off)
/// - holdFull: double-tap transient (hold marker)
/// - holdEmpty: single soft tap
/// - exhale: long descending continuous + final transient (the "release")
public final class HapticsManager: @unchecked Sendable {
    private var engine: CHHapticEngine?
    private var isPrepared = false

    public init() {}

    public func prepare() {
        guard !isPrepared else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { _ in /* engine may stop on app background; restart on next strike */ }
            try engine?.start()
            isPrepared = true
        } catch {
            engine = nil
        }
    }

    public func fire(_ kind: BreathPhase.Kind) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if !isPrepared { prepare() }
        guard let engine else { return }

        do {
            let pattern = try Self.pattern(for: kind)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // If the engine got into a bad state, recover lazily
            try? engine.start()
        }
    }

    public func stop() {
        engine?.stop()
        isPrepared = false
    }

    // MARK: - Pattern factory

    private static func pattern(for kind: BreathPhase.Kind) throws -> CHHapticPattern {
        switch kind {
        case .inhale:
            // 1.2s continuous rising from soft → moderate, then a punctuating tap
            let cont = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.5),
                    .init(parameterID: .hapticSharpness, value: 0.4),
                ],
                relativeTime: 0,
                duration: 1.2
            )
            let intensityCurve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0.0, value: 0.0),
                    .init(relativeTime: 1.2, value: 0.55),
                ],
                relativeTime: 0
            )
            let tap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.5),
                    .init(parameterID: .hapticSharpness, value: 0.5),
                ],
                relativeTime: 0.0
            )
            return try CHHapticPattern(events: [tap, cont], parameterCurves: [intensityCurve])

        case .inhaleTop:
            let crisp = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.45),
                    .init(parameterID: .hapticSharpness, value: 0.75),
                ],
                relativeTime: 0
            )
            return try CHHapticPattern(events: [crisp], parameters: [])

        case .holdFull:
            // Double-tap marker
            let tap1 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.6),
                    .init(parameterID: .hapticSharpness, value: 0.6),
                ],
                relativeTime: 0
            )
            let tap2 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.45),
                    .init(parameterID: .hapticSharpness, value: 0.55),
                ],
                relativeTime: 0.12
            )
            return try CHHapticPattern(events: [tap1, tap2], parameters: [])

        case .holdEmpty:
            // Single soft tap
            let tap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.35),
                    .init(parameterID: .hapticSharpness, value: 0.4),
                ],
                relativeTime: 0
            )
            return try CHHapticPattern(events: [tap], parameters: [])

        case .exhale:
            // Long descending continuous + transient on the strike
            let tap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.6),
                    .init(parameterID: .hapticSharpness, value: 0.45),
                ],
                relativeTime: 0
            )
            let cont = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.45),
                    .init(parameterID: .hapticSharpness, value: 0.3),
                ],
                relativeTime: 0,
                duration: 2.0
            )
            let intensityCurve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0.0, value: 0.45),
                    .init(relativeTime: 2.0, value: 0.0),
                ],
                relativeTime: 0
            )
            return try CHHapticPattern(events: [tap, cont], parameterCurves: [intensityCurve])
        }
    }
}

#else
/// No-op fallback for platforms without CoreHaptics (macOS, tvOS).
public final class HapticsManager: @unchecked Sendable {
    public init() {}
    public func prepare() {}
    public func fire(_ kind: BreathPhase.Kind) {}
    public func stop() {}
}
#endif
