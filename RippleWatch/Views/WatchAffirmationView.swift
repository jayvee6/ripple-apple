import SwiftUI
import RippleCore

struct WatchAffirmationView: View {
    let affirmation: String
    let onReturn: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity: Double = 0.0

    var body: some View {
        VStack {
            Spacer()
            Text(affirmation)
                .font(.system(.body, design: .default, weight: .light))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.horizontal, 16)
                .opacity(opacity)
            Spacer()
        }
        // The affirmation IS the accessibility surface. The label change at
        // view onAppear triggers VoiceOver to read this immediately when the
        // outro replaces the session view. No UIAccessibility.post on
        // watchOS — that API is iOS-only.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session complete. \(affirmation)")
        .accessibilityAddTraits(.isHeader)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) { opacity = 1.0 }
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { opacity = 0.0 }
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
                await MainActor.run { onReturn() }
            }
        }
    }
}
