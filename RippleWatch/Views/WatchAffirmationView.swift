import SwiftUI
import RippleCore

struct WatchAffirmationView: View {
    let affirmation: String
    let onReturn: () -> Void

    @State private var opacity: Double = 0.0

    var body: some View {
        VStack {
            Spacer()
            Text(affirmation)
                .font(.system(size: 15, weight: .light))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.horizontal, 16)
                .opacity(opacity)
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) { opacity = 1.0 }
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.6)) { opacity = 0.0 }
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
                await MainActor.run { onReturn() }
            }
        }
    }
}
