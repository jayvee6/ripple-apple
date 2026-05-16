import SwiftUI
import RippleCore

/// The active breathing session: Metal water in the back, the polished stone
/// in the middle, HUD overlay. Drives the bowl audio, haptics, and water
/// pulses off the PhaseRunner event stream.
struct SessionView: View {
    let config: SessionConfig
    let onComplete: () -> Void
    /// Called when the user bails out early (wrong exercise, etc.). Skips
    /// the affirmation outro and the HealthKit log — they didn't finish.
    let onExit: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentPhase: BreathPhase?
    @State private var cycleIndex: Int = 0
    @State private var stoneScale: CGFloat = 1.0
    @State private var stoneOpacity: Double = 1.0
    @State private var haloOpacity: Double = 0.0
    @State private var countdown: Int = 0
    @State private var phaseLabelOpacity: Double = 0.0
    @State private var hudOpacity: Double = 0.0
    @State private var sessionTask: Task<Void, Never>?
    @State private var countdownTask: Task<Void, Never>?
    @State private var sessionStartedAt: Date?

    private let bowls = BowlAudioEngine()
    private let haptics = HapticsManager()

    private static let stoneBase: CGFloat = 1.0
    private static let stoneFull: CGFloat = 1.04
    private static let stoneOverFull: CGFloat = 1.055

    var body: some View {
        ZStack {
            // Water is rendered by RootView — we just write to its shared
            // pulse trigger when the bowls strike.

            // The stone — Liquid Glass orb centered to the FULL screen (not
            // safe area) so it lines up with the water pulse origin. The
            // .ignoresSafeArea() on this wrapper ensures the geometric
            // center matches the MTKView's pulse center exactly.
            ZStack {
                // Caustic — concentrated focus of light on the water under
                // the orb. Drawn behind the orb so it appears the orb is
                // floating above it. Offset slightly down for the
                // "sitting just above the water" depth cue.
                OrbCaustic(intensity: haloOpacity)
                    .offset(y: 16)

                // The orb — glass sphere refracting the rippling water
                LiquidGlassOrb()
                    .frame(width: 220, height: 220)
            }
            .accessibilityHidden(true) // decorative; HUD text + announcements convey state
            .scaleEffect(stoneScale)
            .opacity(stoneOpacity)
            .animation(.easeInOut(duration: 0.6), value: stoneOpacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // HUD — also the accessibility surface for the session. The
            // central element is announced as a live region whenever the
            // phase or countdown changes, so VoiceOver users hear the cue.
            VStack {
                Spacer().frame(height: 80)
                VStack(spacing: 18) {
                    Text(currentPhase?.label.uppercased() ?? "")
                        .font(.system(.subheadline, design: .default, weight: .medium))
                        .tracking(4.5)
                        .foregroundStyle(Color.white.opacity(0.78))
                        .opacity(phaseLabelOpacity)
                        .animation(.easeInOut(duration: 0.3), value: phaseLabelOpacity)
                    Text("\(countdown)")
                        .font(.system(.largeTitle, design: .default, weight: .thin).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.85))
                        .shadow(color: Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.45), radius: 12)
                }
                Spacer()
            }
            .opacity(hudOpacity)
            .animation(.easeInOut(duration: 0.4), value: hudOpacity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(hudAccessibilityLabel)
            .accessibilityAddTraits(.updatesFrequently)

            // Top bar — back affordance (left) + cycle indicator (right)
            VStack {
                HStack(alignment: .top) {
                    // Exit early. Subtle until you look for it.
                    Button {
                        exitEarly()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 21)
                    .padding(.leading, 26)
                    .accessibilityLabel("Exit breathing session")
                    .accessibilityHint("Returns to the exercise picker without finishing.")
                    .accessibilityAddTraits(.isButton)

                    Spacer()

                    Text("CYCLE \(cycleIndex + 1) OF \(config.cycles)")
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .tracking(3.1)
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        .padding(.top, 24)
                        .padding(.trailing, 32)
                        .accessibilityLabel("Cycle \(cycleIndex + 1) of \(config.cycles)")
                }
                Spacer()
            }
            .opacity(hudOpacity)
        }
        .onAppear {
            startSession()
            // Keep the device awake for the duration of the session so the
            // phone doesn't auto-lock mid-exhale. Restored on disappear AND
            // when the app backgrounds, so we never leave it disabled.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            sessionTask?.cancel()
            countdownTask?.cancel()
            bowls.stop()
            haptics.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Defensive — if the user backgrounds the app mid-session, drop
            // the idle-timer override so we're not still locked out the next
            // time iOS evaluates auto-lock.
            if newPhase != .active {
                UIApplication.shared.isIdleTimerDisabled = false
            } else {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }

    // MARK: - Early exit

    /// User bailed (wrong exercise, changed their mind). Cancel everything,
    /// release the wake lock, and hand control back without logging a
    /// mindful session or running the affirmation outro.
    private func exitEarly() {
        sessionTask?.cancel()
        countdownTask?.cancel()
        bowls.stop()
        haptics.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        onExit()
    }

    // MARK: - Accessibility

    /// Constructed label for the central HUD; updates whenever currentPhase
    /// or cycleIndex changes. VoiceOver re-reads it on update because the
    /// element has the `.updatesFrequently` trait.
    private var hudAccessibilityLabel: String {
        guard let phase = currentPhase else {
            return "Breathing session starting."
        }
        return "\(phase.label). Cycle \(cycleIndex + 1) of \(config.cycles)."
    }

    // MARK: - Pulse intensity per phase

    private var pulseIntensity: Float {
        switch currentPhase?.kind {
        case .inhale:     return 1.4
        case .inhaleTop:  return 0.7
        case .holdFull:   return 1.0
        case .holdEmpty:  return 0.5
        case .exhale:     return 1.6
        case .none:       return 1.0
        }
    }

    // MARK: - Session driver

    private func startSession() {
        try? bowls.prepare()
        haptics.prepare()
        sessionStartedAt = Date()
        // Request HealthKit auth on first session; subsequent calls are cheap no-ops
        Task { try? await MindfulnessLogger.shared.requestAuthorization() }

        // Soft fade-in of HUD after a beat
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            await MainActor.run { hudOpacity = 1.0 }
        }

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
            // Log to HealthKit as a mindful session
            if let start = sessionStartedAt {
                Task {
                    await MindfulnessLogger.shared.logSession(
                        start: start,
                        duration: config.totalSeconds
                    )
                }
            }
            // Fade stone + HUD, then defer to parent
            withAnimation(.easeInOut(duration: 0.8)) {
                stoneOpacity = 0
                haloOpacity = 0
                hudOpacity = 0
            }
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                onComplete()
            }
        }
    }

    @MainActor
    private func startPhase(_ phase: BreathPhase) {
        currentPhase = phase
        // Fire the bowl (unless muted), haptic (always — silent mode only
        // mutes audio, haptics stay so phase cues remain available), water pulse.
        if !appState.audioMuted {
            switch phase.kind {
            case .inhale:    bowls.inhale()
            case .inhaleTop: bowls.inhale(strength: 0.6)
            case .holdFull:  bowls.holdFull()
            case .holdEmpty: bowls.holdEmpty()
            case .exhale:    bowls.exhale()
            }
        }
        haptics.fire(phase.kind)
        appState.pulseTrigger += 1
        appState.pulseIntensity = pulseIntensity

        // VoiceOver announcement — call out the new phase explicitly. The
        // .updatesFrequently HUD will also re-read its label, but a direct
        // announcement gives the most reliable cue at the moment of strike.
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(phase.label) for \(Int(phase.duration.rounded())) seconds"
        )

        // Phase label flash
        phaseLabelOpacity = 0
        withAnimation(.easeInOut(duration: 0.3)) { phaseLabelOpacity = 0 }
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) { phaseLabelOpacity = 1.0 }
            }
        }

        // Drive the stone/halo per phase. Reduce Motion: skip the scale
        // tween entirely (stay at stoneBase) and just crossfade the halo —
        // the chime, haptic, and announcement still convey the phase.
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) {
                stoneScale = Self.stoneBase
                haloOpacity = (phase.kind == .holdEmpty || phase.kind == .exhale) ? 0 : 0.85
            }
        } else {
            switch phase.kind {
            case .inhale:
                withAnimation(.easeInOut(duration: phase.duration)) {
                    stoneScale = Self.stoneFull
                    haloOpacity = 0.85
                }
            case .inhaleTop:
                withAnimation(.easeOut(duration: phase.duration)) {
                    stoneScale = Self.stoneOverFull
                    haloOpacity = 1.0
                }
            case .holdFull:
                // Subtle jitter — sequence of small scale changes via Task
                jitter(around: Self.stoneFull, duration: phase.duration)
            case .holdEmpty:
                withAnimation(.easeOut(duration: 0.4)) {
                    stoneScale = Self.stoneBase
                    haloOpacity = 0
                }
            case .exhale:
                withAnimation(.easeInOut(duration: phase.duration)) {
                    stoneScale = Self.stoneBase
                    haloOpacity = 0
                }
            }
        }

        // Drive the countdown
        runCountdown(seconds: max(1, Int(phase.duration.rounded())))
    }

    private func jitter(around base: CGFloat, duration: TimeInterval) {
        let steps: [(CGFloat, Double)] = [
            (base + 0.005, 0.22),
            (base - 0.010, 0.26),
            (base + 0.005, 0.22),
            (base,         0.30),
        ]
        Task { @MainActor in
            for (target, frac) in steps {
                let stepDuration = duration * frac
                withAnimation(.easeInOut(duration: stepDuration)) {
                    stoneScale = target
                }
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
        }
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

#Preview {
    SessionView(config: SessionConfig(.sigh), onComplete: { }, onExit: { })
        .environment(AppState())
}
