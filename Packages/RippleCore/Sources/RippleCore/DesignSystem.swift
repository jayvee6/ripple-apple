#if canImport(SwiftUI)
import SwiftUI

/// Design tokens for ripple — colors, type, materials. Mirrors the web app's
/// palette and spacing so the iOS and watchOS apps feel like the same product.
///
/// Glass panel pattern is adapted from StudioJoeSavers' `panelBackground`:
/// `.ultraThinMaterial` + LinearGradient overlay + hairline border + shadow.
public enum DesignSystem {
    // MARK: - Colors

    public enum Palette {
        /// Outer void color used as the safe-area background.
        public static let voidBlack = Color(red: 0.020, green: 0.035, blue: 0.072)
        /// Deep water at the edges (used in the radial gradient field).
        public static let deepWater = Color(red: 0.024, green: 0.078, blue: 0.157)
        /// Mid-water color (center of the radial gradient).
        public static let midWater  = Color(red: 0.078, green: 0.224, blue: 0.376)
        /// The cool cyan accent that drives the orb's glow + button highlights.
        public static let aquaAccent = Color(red: 0.471, green: 0.765, blue: 0.843)
        /// Primary text color — slightly off-white for warmth on dark.
        public static let primaryText = Color(red: 0.918, green: 0.941, blue: 0.980)
        /// Secondary text color — lower-contrast for tagline / pattern strings.
        public static let secondaryText = Color(red: 0.918, green: 0.941, blue: 0.980).opacity(0.5)
    }

    // MARK: - Typography

    public enum Typography {
        public static let display: Font = .system(size: 34, weight: .ultraLight)
        public static let heroNumber: Font = .system(size: 64, weight: .thin).monospacedDigit()
        public static let title: Font = .system(size: 22, weight: .light)
        public static let body: Font = .system(size: 16, weight: .regular)
        public static let caption: Font = .system(size: 11, weight: .semibold)
        public static let phaseLabel: Font = .system(size: 14, weight: .medium)
    }

    // MARK: - Materials

    /// Glass panel background — adapted from StudioJoeSavers ContentView.
    /// Stack: ultraThinMaterial → linear gradient depth overlay → hairline border → outer shadow.
    public struct GlassPanel: ViewModifier {
        public let cornerRadius: CGFloat
        public init(cornerRadius: CGFloat = 18) {
            self.cornerRadius = cornerRadius
        }
        public func body(content: Content) -> some View {
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.04), location: 0.0),
                                .init(color: .clear,               location: 0.45),
                                .init(color: .black.opacity(0.10), location: 1.0),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.30), radius: 24, x: 0, y: 10)
        }
    }
}

public extension View {
    /// Apply the ripple glass-panel aesthetic to a view.
    func glassPanel(cornerRadius: CGFloat = 18) -> some View {
        modifier(DesignSystem.GlassPanel(cornerRadius: cornerRadius))
    }
}
#endif
