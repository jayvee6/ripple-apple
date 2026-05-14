import SwiftUI
import RippleCore

/// The bare-URL entry screen: one big frosted-glass plane covering the
/// viewport, 2×2 grid of exercise cards. Mirrors the web app's selector.
struct ExercisePicker: View {
    let onPick: (BreathExercise) -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        ZStack {
            // The single glass plane covering the viewport. backdrop blur
            // does the work; the stone behind it reads as a soft glow.
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.06), location: 0.0),
                            .init(color: .clear,               location: 0.45),
                            .init(color: .black.opacity(0.18), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(alignment: .top) {
                    // Hairline meniscus at the top edge of the glass
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.18), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(height: 1)
                }
                .ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("breathe")
                        .font(.system(.largeTitle, design: .default, weight: .ultraLight))
                        .tracking(2)
                        .foregroundStyle(Color.white.opacity(0.95))
                        .accessibilityAddTraits(.isHeader)
                    Text("CHOOSE YOUR BREATH")
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .tracking(5.4)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .accessibilityHidden(true) // decorative tagline; heading already announced
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 140, maximum: 240), spacing: 14),
                        GridItem(.flexible(minimum: 140, maximum: 240), spacing: 14),
                    ],
                    spacing: 14
                ) {
                    ForEach(BreathExercise.allCases) { exercise in
                        ExerciseCard(exercise: exercise) {
                            onPick(exercise)
                        }
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)
            }

            // Mute toggle — top-right corner. Subtle, persists across sessions.
            VStack {
                HStack {
                    Spacer()
                    MuteToggle(isMuted: $appState.audioMuted)
                        .padding(.top, 12)
                        .padding(.trailing, 18)
                }
                Spacer()
            }
        }
    }
}

private struct MuteToggle: View {
    @Binding var isMuted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                isMuted.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(.callout, design: .default, weight: .medium))
                    .foregroundStyle(
                        isMuted
                          ? Color.white.opacity(0.45)
                          : Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.85)
                    )
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMuted ? "Bowl chimes muted" : "Bowl chimes on")
        .accessibilityHint("Double tap to \(isMuted ? "unmute" : "mute") the breathing session audio. Haptics remain on either way.")
        .accessibilityAddTraits(.isButton)
    }
}

private struct ExerciseCard: View {
    let exercise: BreathExercise
    let action: () -> Void
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.displayName)
                    .font(.system(.title2, design: .default, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.95))
                Text(exercise.patternLine.uppercased())
                    .font(.system(.caption, design: .default, weight: .medium))
                    .tracking(2.4)
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer().frame(height: 8)
                Text(exercise.purpose.uppercased())
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(Color(red: 0.471, green: 0.765, blue: 0.843).opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 22)
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
            .shadow(color: .black.opacity(isPressed ? 0.10 : 0.18), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.985 : 1.0))
            .animation(.easeOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        // VoiceOver: combine the three text rows into one element with a
        // human-readable label + hint about what tap does.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.displayName). \(exercise.accessibilityDescription) Best for \(exercise.purpose.lowercased()).")
        .accessibilityHint("Starts the breathing session.")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    ZStack {
        Color(red: 0.020, green: 0.035, blue: 0.072).ignoresSafeArea()
        ExercisePicker { _ in }
            .environment(AppState())
    }
}
