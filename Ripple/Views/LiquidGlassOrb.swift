import SwiftUI

/// A Liquid Glass orb — the iOS 26 `.glassEffect(_:in:)` material applied to
/// a Circle shape. Refracts the rippling water behind it for that
/// "glass marble dropped in a pool" feel. Layers a subtle highlight on top
/// so the orb reads as a sphere, not a flat circle.
struct LiquidGlassOrb: View {
    /// Tint color for the glass. Aqua/cyan to match ripple's accent palette.
    var tint: Color = Color(red: 0.471, green: 0.765, blue: 0.843)

    var body: some View {
        ZStack {
            // 1. Liquid Glass — the core material that refracts the water
            Circle()
                .fill(Color.clear)
                .glassEffect(
                    .regular.tint(tint.opacity(0.22)),
                    in: Circle()
                )

            // 2. Soft inner highlight — gives the orb spherical depth
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.32), location: 0.0),
                            .init(color: Color.white.opacity(0.0),  location: 0.55),
                        ],
                        center: UnitPoint(x: 0.36, y: 0.30),
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // 3. Crisp meniscus highlight — top-left, like overhead light
            //    catching the top of a wet sphere
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.65), Color.white.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 70, height: 42)
                .blur(radius: 4)
                .offset(x: -34, y: -50)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // 4. Rim — subtle white border so the sphere has definition
            //    against the bright wave crests
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.42),
                            Color.white.opacity(0.06),
                            Color.black.opacity(0.18),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
        .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 16)
        .shadow(color: tint.opacity(0.30), radius: 24, x: 0, y: 0)
    }
}

#Preview {
    ZStack {
        // Fake water for the preview
        LinearGradient(
            colors: [
                Color(red: 0.024, green: 0.078, blue: 0.157),
                Color(red: 0.078, green: 0.224, blue: 0.376),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        LiquidGlassOrb()
            .frame(width: 220, height: 220)
    }
}
