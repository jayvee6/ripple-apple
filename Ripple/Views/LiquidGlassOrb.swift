import SwiftUI

/// A Liquid Glass orb — the iOS 26 `.glassEffect(_:in:)` material applied to
/// a Circle shape. The Liquid Glass material does the heavy lifting for
/// refraction and natural specular response; on top of that we lay just a
/// pair of *thin elongated specular pills* mimicking softbox slat lights
/// (the studiojoesavers/Mercury aesthetic) plus a hairline rim line.
///
/// Specular philosophy borrowed from `StudioJoeSavers/.../Mercury.metal`:
/// real shiny glass mostly shows refracted background, with elongated
/// highlight pills wrapping the curves. The "chrome marble" look is the
/// failure mode; this aims for "polished crystal."
struct LiquidGlassOrb: View {
    /// Tint color for the glass. Aqua/cyan to match ripple's accent palette.
    var tint: Color = Color(red: 0.471, green: 0.765, blue: 0.843)

    var body: some View {
        ZStack {
            // 1. Liquid Glass — the core material that refracts the water
            Circle()
                .fill(Color.clear)
                .glassEffect(
                    .regular.tint(tint.opacity(0.18)),
                    in: Circle()
                )

            // 2. Primary highlight pill — narrow elongated reflection of an
            //    imagined upper-left softbox. Thin Gaussian capsule, soft.
            Capsule()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.0),  location: 0.0),
                            .init(color: Color.white.opacity(0.32), location: 0.5),
                            .init(color: Color.white.opacity(0.0),  location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 56)
                .rotationEffect(.degrees(-20))
                .blur(radius: 3)
                .offset(x: -36, y: -42)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // 3. Secondary tiny highlight — a smaller second pill for a
            //    multi-light-source feel, lower right of the orb's upper.
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 3, height: 22)
                .rotationEffect(.degrees(-12))
                .blur(radius: 2)
                .offset(x: -8, y: -36)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // 4. Rim — hairline border for definition against bright wave crests
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.04),
                            Color.black.opacity(0.20),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.50), radius: 22, x: 0, y: 16)
        .shadow(color: tint.opacity(0.22), radius: 24, x: 0, y: 0)
    }
}

#Preview {
    ZStack {
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
