import SwiftUI
import RippleCore

/// The active breathing session: Metal water in the back, the polished stone
/// in the middle, HUD overlay. Drives the bowl audio, haptics, and water
/// pulses off the PhaseRunner event stream.
struct SessionView: View {
    let config: SessionConfig
    let onComplete: () -> Void

    @Environment(AppState.self) private var appState
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
                // Soft halo behind the orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.45),
                                Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.0),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 220
                        )
                    )
                    .frame(width: 340, height: 340)
                    .blur(radius: 24)
                    .opacity(haloOpacity)

                // The orb — Liquid Glass refracting the rippling water behind it
                LiquidGlassOrb()
                    .frame(width: 220, height: 220)
            }
            .scaleEffect(stoneScale)
            .opacity(stoneOpacity)
            .animation(.easeInOut(duration: 0.6), value: stoneOpacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // HUD
            VStack {
                Spacer().frame(height: 80)
                VStack(spacing: 18) {
                    Text(currentPhase?.label.uppercased() ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .tracking(4.5)
                        .foregroundStyle(Color.white.opacity(0.78))
                        .opacity(phaseLabelOpacity)
                        .animation(.easeInOut(duration: 0.3), value: phaseLabelOpacity)
                    Text("\(countdown)")
                        .font(.system(size: 64, weight: .thin).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.85))
                        .shadow(color: Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.45), radius: 12)
                }
                Spacer()
            }
            .opacity(hudOpacity)
            .animation(.easeInOut(duration: 0.4), value: hudOpacity)

            // Cycle indicator
            VStack {
                HStack {
                    Spacer()
                    Text("CYCLE \(cycleIndex + 1) OF \(config.cycles)")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(3.1)
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        .padding(.top, 24)
                        .padding(.trailing, 32)
                }
                Spacer()
            }
            .opacity(hudOpacity)
        }
        .onAppear { startSession() }
        .onDisappear {
            sessionTask?.cancel()
            countdownTask?.cancel()
            bowls.stop()
            haptics.stop()
        }
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
        // Fire the bowl + haptic + water pulse
        switch phase.kind {
        case .inhale:    bowls.inhale()
        case .inhaleTop: bowls.inhale(strength: 0.6)
        case .holdFull:  bowls.holdFull()
        case .holdEmpty: bowls.holdEmpty()
        case .exhale:    bowls.exhale()
        }
        haptics.fire(phase.kind)
        appState.pulseTrigger += 1
        appState.pulseIntensity = pulseIntensity

        // Phase label flash
        phaseLabelOpacity = 0
        withAnimation(.easeInOut(duration: 0.3)) { phaseLabelOpacity = 0 }
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) { phaseLabelOpacity = 1.0 }
            }
        }

        // Drive the stone/halo per phase
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
    SessionView(config: SessionConfig(.sigh)) { }
}
