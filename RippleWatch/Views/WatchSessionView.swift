import SwiftUI
import RippleCore
#if canImport(WatchKit)
import WatchKit
#endif

/// Watch session — animated circle representing breath + haptic cues +
/// bowl audio. No Metal here; SwiftUI is enough on a 41–46mm screen and
/// way cheaper on battery.
struct WatchSessionView: View {
    let config: SessionConfig
    let onComplete: () -> Void
    /// Early bail — wrong exercise, etc. No outro, no HealthKit log.
    let onExit: () -> Void

    @Environment(WatchAppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPhase: BreathPhase?
    @State private var cycleIndex: Int = 0
    @State private var circleScale: CGFloat = 0.55
    @State private var glowOpacity: Double = 0.25
    @State private var countdown: Int = 0
    @State private var sessionTask: Task<Void, Never>?
    @State private var countdownTask: Task<Void, Never>?
    @State private var sessionStartedAt: Date?

    private let bowls = BowlAudioEngine()
    private let haptics = HapticsManager()
    private let runtime = ExtendedRuntime()

    private static let scaleEmpty: CGFloat = 0.55
    private static let scaleFull: CGFloat = 1.0

    var body: some View {
        ZStack {
            // The breathing circle — purely decorative on watch; phase + count
            // are read out via the central HUD label.
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.85), location: 0.0),
                            .init(color: Color(red: 0.196, green: 0.392, blue: 0.510).opacity(0.85), location: 0.55),
                            .init(color: Color(red: 0.031, green: 0.118, blue: 0.216).opacity(0.0), location: 1.0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.6 * glowOpacity), lineWidth: 1)
                )
                .frame(width: 140, height: 140)
                .scaleEffect(circleScale)
                .accessibilityHidden(true)

            VStack(spacing: 2) {
                Text(currentPhase?.label ?? "")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .tracking(2.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.78))
                Text("\(countdown)")
                    .font(.system(.title, design: .default, weight: .thin).monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(hudAccessibilityLabel)
            .accessibilityAddTraits(.updatesFrequently)

            VStack {
                HStack {
                    Button {
                        exitEarly()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 2)
                    .accessibilityLabel("Exit breathing session")
                    .accessibilityHint("Returns to the exercise picker.")

                    Spacer()

                    Text("\(cycleIndex + 1)/\(config.cycles)")
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.trailing, 6)
                        .padding(.top, 4)
                        .accessibilityLabel("Cycle \(cycleIndex + 1) of \(config.cycles)")
                }
                Spacer()
            }
        }
        .onAppear {
            startSession()
            // Keep the watch awake through wrist-down for the whole session.
            runtime.start()
        }
        .onDisappear {
            sessionTask?.cancel()
            countdownTask?.cancel()
            bowls.stop()
            haptics.stop()
            runtime.stop()
        }
    }

    /// User bailed — tear down without outro or HealthKit log.
    private func exitEarly() {
        sessionTask?.cancel()
        countdownTask?.cancel()
        bowls.stop()
        haptics.stop()
        runtime.stop()
        onExit()
    }

    /// VoiceOver label for the central HUD on watch — same pattern as iOS.
    private var hudAccessibilityLabel: String {
        guard let phase = currentPhase else { return "Breathing session starting." }
        return "\(phase.label). Cycle \(cycleIndex + 1) of \(config.cycles)."
    }

    private func startSession() {
        try? bowls.prepare()
        haptics.prepare()
        sessionStartedAt = Date()
        Task { try? await MindfulnessLogger.shared.requestAuthorization() }

        let runner = PhaseRunner(config: config)
        sessionTask = Task { @MainActor in
            for await event in runner.events {
                if Task.isCancelled { break }
                handle(event)
            }
        }
    }

    @MainActor
    private func handle(_ event: PhaseEvent) {
        switch event.kind {
        case .sessionBegan:
            break
        case .cycleBegan:
            cycleIndex = event.cycleIndex
        case .phaseBegan:
            guard let phase = event.phase else { return }
            startPhase(phase)
        case .cycleEnded:
            break
        case .sessionEnded:
            // Log to HealthKit
            if let start = sessionStartedAt {
                Task {
                    await MindfulnessLogger.shared.logSession(
                        start: start,
                        duration: config.totalSeconds
                    )
                }
            }
            // Quick fade-out — watch session is short, no curtain ceremony
            withAnimation(.easeInOut(duration: 0.6)) {
                circleScale = Self.scaleEmpty
                glowOpacity = 0
            }
            Task {
                try? await Task.sleep(nanoseconds: 700_000_000)
                onComplete()
            }
        }
    }

    @MainActor
    private func startPhase(_ phase: BreathPhase) {
        currentPhase = phase
        // Bowl (unless muted), haptic (always)
        if !appState.audioMuted {
            switch phase.kind {
            case .inhale:    bowls.inhale(strength: 0.7)
            case .inhaleTop: bowls.inhale(strength: 0.5)
            case .holdFull:  bowls.holdFull(strength: 0.55)
            case .holdEmpty: bowls.holdEmpty(strength: 0.4)
            case .exhale:    bowls.exhale(strength: 0.75)
            }
        }
        haptics.fire(phase.kind)
        // Backup WKHaptic for cases where CHHapticEngine isn't available
        #if canImport(WatchKit)
        let wkType: WKHapticType
        switch phase.kind {
        case .inhale:     wkType = .start
        case .inhaleTop:  wkType = .click
        case .holdFull:   wkType = .notification
        case .holdEmpty:  wkType = .stop
        case .exhale:     wkType = .directionDown
        }
        WKInterfaceDevice.current().play(wkType)
        #endif

        // Drive the circle scale per phase. Reduce Motion: skip scale tween;
        // the haptic + bowl still convey the phase change.
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) {
                circleScale = Self.scaleEmpty
                glowOpacity = (phase.kind == .holdEmpty || phase.kind == .exhale) ? 0.30 : 1.0
            }
        } else {
            switch phase.kind {
            case .inhale:
                withAnimation(.easeInOut(duration: phase.duration)) {
                    circleScale = Self.scaleFull
                    glowOpacity = 1.0
                }
            case .inhaleTop:
                withAnimation(.easeOut(duration: phase.duration)) {
                    circleScale = Self.scaleFull * 1.04
                    glowOpacity = 1.0
                }
            case .holdFull:
                withAnimation(.easeInOut(duration: 0.6)) {
                    circleScale = Self.scaleFull
                    glowOpacity = 0.95
                }
            case .holdEmpty:
                withAnimation(.easeOut(duration: 0.3)) {
                    circleScale = Self.scaleEmpty
                    glowOpacity = 0.30
                }
            case .exhale:
                withAnimation(.easeInOut(duration: phase.duration)) {
                    circleScale = Self.scaleEmpty
                    glowOpacity = 0.30
                }
            }
        }

        runCountdown(seconds: max(1, Int(phase.duration.rounded())))
    }

    private func runCountdown(seconds: Int) {
        countdownTask?.cancel()
        countdown = seconds
        countdownTask = Task { @MainActor in
            var remaining = seconds
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remaining -= 1
                countdown = max(0, remaining)
            }
        }
    }
}
