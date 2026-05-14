import SwiftUI
import RippleCore

/// Outro screen — shows the affirmation, holds for a beat, then drives the
/// shared curtain opacity to full black. Once black, calls `onReturn`, which
/// (in RootView) snaps state back to .picker and retracts the curtain.
struct AffirmationView: View {
    let affirmation: String
    let onReturn: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var messageOpacity: Double = 0.0

    var body: some View {
        VStack {
            Spacer()
            Text(affirmation)
                .font(.system(.title2, design: .default, weight: .light))
                .foregroundStyle(Color.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .opacity(messageOpacity)
        // The outro is the climax of the session — give it heading weight
        // and announce immediately on appear.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session complete. \(affirmation)")
        .accessibilityAddTraits(.isHeader)
        .onAppear { runOutro() }
    }

    private func runOutro() {
        // Announce the completion + affirmation explicitly for VoiceOver
        UIAccessibility.post(
            notification: .screenChanged,
            argument: "Session complete. \(affirmation)"
        )

        // Fade in affirmation
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.0)) {
            messageOpacity = 1.0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_200_000_000)  // 4.2s
            withAnimation(reduceMotion ? nil : .easeIn(duration: 1.6)) {
                appState.curtainOpacity = 1.0
            }
            // Hold black for the silent reset moment
            try? await Task.sleep(nanoseconds: reduceMotion ? 600_000_000 : 2_400_000_000)
            onReturn()
        }
    }
}
