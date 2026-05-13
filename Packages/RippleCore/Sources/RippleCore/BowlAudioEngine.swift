import Foundation
#if canImport(AVFoundation)
import AVFoundation

/// Synthesizes a Tibetan-bowl strike via four detuned sine partials at
/// inharmonic ratios (1.0, 2.76, 5.4, 8.93), each with its own exponential
/// decay envelope. Mirrors the web app's `singingBowl(...)` JS function.
///
/// The fundamental sustains for ~6s while higher partials fade progressively
/// faster (0.55× / 0.28× / 0.16× of the base decay) — that's what gives a
/// real bowl its "shimmer fades, hum sustains" character.
public final class BowlAudioEngine: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let sampleRate: Double = 44_100
    private var isStarted = false

    public init() {}

    /// Spin up the engine on first use. Safe to call repeatedly.
    public func prepare() throws {
        guard !isStarted else { return }
        configureSession()
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        mixer.outputVolume = 0.22  // ≈ -13dB master
        try engine.start()
        isStarted = true
    }

    /// Trigger a bowl strike with the given fundamental frequency, base decay,
    /// and strike strength multiplier. Each partial gets its own oscillator
    /// node with a custom render block applying ADSR + sine synthesis.
    public func strike(fundamental: Double, baseDecay: TimeInterval = 6.0, strength: Double = 1.0) {
        if !isStarted { try? prepare() }
        guard isStarted else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        for partial in Self.partials {
            let freq = fundamental * partial.ratio * pow(2.0, partial.detune / 1200.0)
            let decay = baseDecay * partial.decayScale
            let peak = Float(partial.gain * strength)
            let attack = partial.attack

            // Per-strike state — captured by the render block.
            let state = StrikeVoice(
                freq: freq,
                sampleRate: sampleRate,
                peak: peak,
                attack: attack,
                decay: decay
            )

            let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
                state.render(frameCount: Int(frameCount), bufferList: UnsafeMutableAudioBufferListPointer(audioBufferList))
                return noErr
            }

            engine.attach(node)
            engine.connect(node, to: mixer, format: format)

            // Schedule node teardown once the decay fully completes.
            let lifetime = attack + decay + 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) { [weak self] in
                guard let self else { return }
                self.engine.disconnectNodeInput(node)
                self.engine.detach(node)
            }
        }
    }

    // MARK: - Convenience phase-strikes (frequencies match web's bowlInhale/Hold/Exhale)

    public func inhale(strength: Double = 0.9)    { strike(fundamental: 220, baseDecay: 6.0, strength: strength) }
    public func holdFull(strength: Double = 0.75) { strike(fundamental: 294, baseDecay: 5.0, strength: strength) }
    public func holdEmpty(strength: Double = 0.55) { strike(fundamental: 165, baseDecay: 4.0, strength: strength) }
    public func exhale(strength: Double = 1.0)    { strike(fundamental: 196, baseDecay: 7.0, strength: strength) }

    public func stop() {
        engine.stop()
        isStarted = false
    }

    // MARK: - Internals

    private struct Partial {
        let ratio: Double
        let gain: Double
        let detune: Double      // cents
        let decayScale: Double  // multiplied by baseDecay
        let attack: TimeInterval
    }
    private static let partials: [Partial] = [
        .init(ratio: 1.00, gain: 0.65, detune:  0, decayScale: 1.00, attack: 0.05),
        .init(ratio: 2.76, gain: 0.32, detune: -4, decayScale: 0.55, attack: 0.035),
        .init(ratio: 5.40, gain: 0.15, detune:  6, decayScale: 0.28, attack: 0.025),
        .init(ratio: 8.93, gain: 0.06, detune: -2, decayScale: 0.16, attack: 0.02),
    ]

    /// Holds per-strike rendering state. A new instance is created per partial
    /// at the moment of the strike. `framesElapsed` advances monotonically
    /// across render callbacks so phase and envelope stay continuous.
    private final class StrikeVoice {
        let freq: Double
        let sampleRate: Double
        let peak: Float
        let attack: TimeInterval
        let decay: TimeInterval
        let alpha: Double  // precomputed exponential decay coefficient
        var framesElapsed: UInt64 = 0

        init(freq: Double, sampleRate: Double, peak: Float, attack: TimeInterval, decay: TimeInterval) {
            self.freq = freq
            self.sampleRate = sampleRate
            self.peak = peak
            self.attack = attack
            self.decay = max(decay, 0.001)
            // exponentialRampToValueAtTime(0.0008, t + decay) → α = ln(0.0008 / peak) / decay
            let p = max(Double(peak), 1e-9)
            let endValue = 0.0008
            self.alpha = log(endValue / p) / self.decay
        }

        func render(frameCount: Int, bufferList: UnsafeMutableAudioBufferListPointer) {
            let twoPiF = 2.0 * Double.pi * freq
            for buffer in bufferList {
                guard let dst = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<frameCount {
                    let globalFrame = framesElapsed + UInt64(i)
                    let t = Double(globalFrame) / sampleRate
                    let env: Float
                    if t < attack {
                        env = peak * Float(t / attack)
                    } else {
                        env = peak * Float(exp(alpha * (t - attack)))
                    }
                    dst[i] = env * Float(sin(twoPiF * t))
                }
            }
            framesElapsed += UInt64(frameCount)
        }
    }

    private func configureSession() {
        #if os(iOS) || os(watchOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
        #endif
    }
}
#endif
