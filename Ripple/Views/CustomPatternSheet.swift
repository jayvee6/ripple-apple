import SwiftUI
import RippleCore

/// The fifth picker tile — opens the custom-rhythm editor. Shows the saved
/// pattern as its subtitle so returning users see their numbers at a glance.
struct CustomCard: View {
    let pattern: BreathPattern
    let action: () -> Void
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.85))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom")
                        .font(.system(.title2, design: .default, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.95))
                    Text(pattern.patternLine.uppercased())
                        .font(.system(.caption, design: .default, weight: .medium))
                        .tracking(2.4)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
            .padding(.horizontal, 22)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isPressed ? 0.10 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isPressed
                          ? Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.40)
                          : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            )
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.985 : 1.0))
            .animation(.easeOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Custom rhythm. Currently \(pattern.accessibilityDescription)")
        .accessibilityHint("Opens the editor to set your own inhale, hold, exhale, and rest times.")
        .accessibilityAddTraits(.isButton)
    }
}

/// The editor. Steppers for each phase + cycles, a live total-duration
/// readout, and Begin. Hold/Rest can go to 0 (skipped). Persisting +
/// starting the session is the caller's job via `onBegin`.
struct CustomPatternSheet: View {
    @State private var inhale: Double
    @State private var holdFull: Double
    @State private var exhale: Double
    @State private var holdEmpty: Double
    @State private var cycles: Int

    let onBegin: (BreathPattern, Int) -> Void
    let onCancel: () -> Void

    init(pattern: BreathPattern, cycles: Int,
         onBegin: @escaping (BreathPattern, Int) -> Void,
         onCancel: @escaping () -> Void) {
        _inhale = State(initialValue: pattern.inhale)
        _holdFull = State(initialValue: pattern.holdFull)
        _exhale = State(initialValue: pattern.exhale)
        _holdEmpty = State(initialValue: pattern.holdEmpty)
        _cycles = State(initialValue: cycles)
        self.onBegin = onBegin
        self.onCancel = onCancel
    }

    private var built: BreathPattern {
        BreathPattern(inhale: inhale, holdFull: holdFull, exhale: exhale, holdEmpty: holdEmpty)
    }

    private var totalSeconds: Int {
        Int(built.cycleDuration) * cycles
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    phaseStepper("Inhale", value: $inhale, min: BreathPattern.minActive)
                    phaseStepper("Hold", value: $holdFull, min: 0, allowsZero: true)
                    phaseStepper("Exhale", value: $exhale, min: BreathPattern.minActive)
                    phaseStepper("Rest", value: $holdEmpty, min: 0, allowsZero: true)
                } footer: {
                    Text("Set Hold or Rest to 0 to skip that phase. Range is 1–20 seconds.")
                }

                Section {
                    Stepper(value: $cycles, in: 1...10) {
                        HStack {
                            Text("Cycles")
                            Spacer()
                            Text("\(cycles)").foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityValue("\(cycles) cycles")
                } footer: {
                    Text("Total: about \(totalSeconds) seconds (\(timeString(totalSeconds))).")
                        .accessibilityLabel("Total session length, about \(totalSeconds) seconds.")
                }
            }
            .navigationTitle("Custom Rhythm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Begin") { onBegin(built, cycles) }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func phaseStepper(_ title: String, value: Binding<Double>,
                              min: Double, allowsZero: Bool = false) -> some View {
        Stepper(value: value, in: min...BreathPattern.maxPhase, step: 1) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue == 0 ? "Off" : "\(Int(value.wrappedValue))s")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityValue(value.wrappedValue == 0 ? "Off" : "\(Int(value.wrappedValue)) seconds")
    }

    private func timeString(_ s: Int) -> String {
        let m = s / 60, sec = s % 60
        return m > 0 ? "\(m)m \(sec)s" : "\(sec)s"
    }
}

#Preview {
    CustomPatternSheet(pattern: .default, cycles: 4) { _, _ in } onCancel: { }
}
