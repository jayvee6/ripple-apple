import SwiftUI
import RippleCore

/// Vertical list of breathing exercises. Crown scrolls; tap to start.
struct WatchExercisePicker: View {
    let onPick: (BreathExercise) -> Void
    let onPickCustom: () -> Void
    @Environment(WatchAppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text("RIPPLE")
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .tracking(3.2)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    WatchMuteToggle(isMuted: $appState.audioMuted)
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 4)

                ForEach(BreathExercise.allCases) { ex in
                    Button { onPick(ex) } label: {
                        WatchExerciseRow(exercise: ex)
                    }
                    .buttonStyle(.plain)
                }

                // Custom — runs the rhythm synced from / saved on the phone.
                // (The full editor lives on iPhone; the watch just runs it.)
                Button { onPickCustom() } label: {
                    WatchCustomRow(pattern: appState.customPattern)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    WatchCustomEditor(
                        pattern: appState.customPattern,
                        cycles: appState.customCycles
                    ) { p, c in
                        appState.customPattern = p
                        appState.customCycles = c
                    }
                } label: {
                    Text("Edit custom rhythm")
                        .font(.system(.caption2, design: .default, weight: .medium))
                        .foregroundStyle(Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct WatchMuteToggle: View {
    @Binding var isMuted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { isMuted.toggle() }
        } label: {
            ZStack {
                Circle().fill(Color.white.opacity(0.06))
                // Fixed point size — icon chrome shouldn't scale with body text
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        isMuted
                          ? Color.white.opacity(0.50)
                          : Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.85)
                    )
            }
            // Visual 26pt, clips overflow, outer hit area 32pt.
            .frame(width: 26, height: 26)
            .clipShape(Circle())
            .frame(width: 32, height: 32)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMuted ? "Bowl chimes muted" : "Bowl chimes on")
        .accessibilityHint("Double tap to \(isMuted ? "unmute" : "mute").")
        .accessibilityAddTraits(.isButton)
    }
}

private struct WatchExerciseRow: View {
    let exercise: BreathExercise

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.displayName)
                    .font(.system(.headline, design: .default, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.95))
                Text(exercise.patternLine)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(.caption2, design: .default, weight: .semibold))
                .foregroundStyle(Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.75))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.displayName). \(exercise.accessibilityDescription)")
        .accessibilityHint("Starts the breathing session.")
    }
}

private struct WatchCustomRow: View {
    let pattern: BreathPattern

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Custom")
                    .font(.system(.headline, design: .default, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.95))
                Text(pattern.patternLine)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            Spacer()
            Image(systemName: "slider.horizontal.3")
                .font(.system(.caption2, design: .default, weight: .semibold))
                .foregroundStyle(Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.75))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Custom. \(pattern.accessibilityDescription)")
        .accessibilityHint("Starts your custom rhythm.")
    }
}

/// Compact on-watch editor — Digital Crown drives each stepper.
private struct WatchCustomEditor: View {
    @State private var inhale: Double
    @State private var holdFull: Double
    @State private var exhale: Double
    @State private var holdEmpty: Double
    @State private var cycles: Int
    let onSave: (BreathPattern, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    init(pattern: BreathPattern, cycles: Int,
         onSave: @escaping (BreathPattern, Int) -> Void) {
        _inhale = State(initialValue: pattern.inhale)
        _holdFull = State(initialValue: pattern.holdFull)
        _exhale = State(initialValue: pattern.exhale)
        _holdEmpty = State(initialValue: pattern.holdEmpty)
        _cycles = State(initialValue: cycles)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            stepper("Inhale", $inhale, min: BreathPattern.minActive)
            stepper("Hold", $holdFull, min: 0)
            stepper("Exhale", $exhale, min: BreathPattern.minActive)
            stepper("Rest", $holdEmpty, min: 0)
            Stepper("Cycles: \(cycles)", value: $cycles, in: 1...10)
            Button("Save") {
                onSave(
                    BreathPattern(inhale: inhale, holdFull: holdFull,
                                  exhale: exhale, holdEmpty: holdEmpty),
                    cycles
                )
                dismiss()
            }
        }
        .navigationTitle("Custom")
    }

    @ViewBuilder
    private func stepper(_ title: String, _ v: Binding<Double>, min: Double) -> some View {
        Stepper(value: v, in: min...BreathPattern.maxPhase, step: 1) {
            Text("\(title): \(v.wrappedValue == 0 ? "Off" : "\(Int(v.wrappedValue))s")")
        }
    }
}

#Preview {
    WatchExercisePicker(onPick: { _ in }, onPickCustom: { })
        .environment(WatchAppState())
}
