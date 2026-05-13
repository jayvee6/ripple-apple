import SwiftUI
import RippleCore

/// Outro screen — shows the affirmation, holds for a beat, then drives the
/// shared curtain opacity to full black. Once black, calls `onReturn`, which
/// (in RootView) snaps state back to .picker and retracts the curtain.
struct AffirmationView: View {
    let affirmation: String
    let onReturn: () -> Void

    @Environment(AppState.self) private var appState
    @State private var messageOpacity: Double = 0.0

    var body: some View {
        VStack {
            Spacer()
            Text(affirmation)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .opacity(messageOpacity)
        .onAppear { runOutro() }
    }

    private func runOutro() {
        // Fade in affirmation
        withAnimation(.easeInOut(duration: 1.0)) {
            messageOpacity = 1.0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_200_000_000)  // 4.2s — match web flow
            // Fade to black via shared curtain
            withAnimation(.easeIn(duration: 1.6)) {
                appState.curtainOpacity = 1.0
            }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            // Tell parent to swap to picker UNDER the curtain, then retract
            onReturn()
        }
    }
}
