import SwiftUI
import RippleCore

/// Vertical list of breathing exercises. Crown scrolls; tap to start.
struct WatchExercisePicker: View {
    let onPick: (BreathExercise) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("BREATHE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(3.2)
                    .foregroundStyle(Color.white.opacity(0.45))
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

private struct WatchExerciseRow: View {
    let exercise: BreathExercise

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.displayName)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.95))
                Text(exercise.patternLine)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.75))
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
    }
}

#Preview {
    WatchExercisePicker { _ in }
}
