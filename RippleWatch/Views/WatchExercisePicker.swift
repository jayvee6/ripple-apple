import SwiftUI
import RippleCore

/// Vertical list of breathing exercises. Crown scrolls; tap to start.
struct WatchExercisePicker: View {
    let onPick: (BreathExercise) -> Void
    @Environment(WatchAppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text("BREATHE")
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
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundStyle(
                        isMuted
                          ? Color.white.opacity(0.50)
                          : Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.85)
                    )
            }
            // Watch tap targets: keep visual at 26pt but extend the hit area
            .frame(minWidth: 32, minHeight: 32)
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

#Preview {
    WatchExercisePicker { _ in }
        .environment(WatchAppState())
}
