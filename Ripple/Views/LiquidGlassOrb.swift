import SwiftUI

/// A glass orb sitting above the water. iOS 26 Liquid Glass (`.clear` variant
/// so refraction reads cleanly through it) for the lens body, plus a soft
/// refractive bezel that fades smoothly around the rim — no harsh dark ring.
struct LiquidGlassOrb: View {
    /// Tint color applied to the rim. Aqua matches ripple's accent.
    var tint: Color = Color(red: 0.471, green: 0.765, blue: 0.843)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let rimWidth = size * 0.055  // a bit thicker so the soft gradient has room to breathe

            ZStack {
                // 1. Lens body — clear Liquid Glass; water reads through
                Circle()
                    .fill(Color.clear)
                    .glassEffect(.clear, in: Circle())
                    .padding(rimWidth * 0.5)

                // 2. The bezel — soft refractive rim. Reduced contrast vs the
                //    previous version: bright at top, cool dim around the
                //    upper-right (no hard black), warm dim at the bottom.
                //    Subtle blur takes the edge off the gradient transitions.
                Circle()
                    .strokeBorder(bezelGradient, lineWidth: rimWidth)
                    .blur(radius: 0.8)
                    .allowsHitTesting(false)

                // 3. Subtle dispersion ring — a barely-there cyan tint just
                //    inside the bezel, hinting at the glass thickness
                //    bending light. No hard ring, just a soft inner glow.
                Circle()
                    .strokeBorder(tint.opacity(0.18), lineWidth: rimWidth * 0.5)
                    .blur(radius: rimWidth * 0.5)
                    .padding(rimWidth * 0.4)
                    .allowsHitTesting(false)

                // 4. Hairline outer edge — crisp definition only, no weight
                Circle()
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.6)
                    .allowsHitTesting(false)

                // 5. One soft specular pill at the crown — barely visible,
                //    just a hint of an overhead softbox
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.0),  location: 0.0),
                                .init(color: Color.white.opacity(0.60), location: 0.5),
                                .init(color: Color.white.opacity(0.0),  location: 1.0),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.20, height: rimWidth * 0.40)
                    .rotationEffect(.degrees(-18))
                    .blur(radius: 1.4)
                    .offset(x: -size * 0.22, y: -size * 0.42)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        // Soft ground shadow under the orb — sells "sitting above the water"
        .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 22)
        .shadow(color: tint.opacity(0.20), radius: 30, x: 0, y: 0)
    }

    /// Soft angular gradient — gentler contrast than the previous "loupe"
    /// version. No pure black; the underside is just a dimmer cool tint.
    private var bezelGradient: AngularGradient {
        let stops: [Gradient.Stop] = [
            .init(color: Color.white.opacity(0.42), location: 0.00), // 12 o'clock
            .init(color: Color.white.opacity(0.30), location: 0.10),
            .init(color: tint.opacity(0.32),        location: 0.22),
            .init(color: tint.opacity(0.18),        location: 0.38),
            .init(color: Color(red: 0.05, green: 0.12, blue: 0.22).opacity(0.45), location: 0.50), // 6 o'clock — dim cool, not black
            .init(color: tint.opacity(0.18),        location: 0.62),
            .init(color: tint.opacity(0.32),        location: 0.78),
            .init(color: Color.white.opacity(0.30), location: 0.90),
            .init(color: Color.white.opacity(0.42), location: 1.00),
        ]
        return AngularGradient(
            stops: stops,
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
}

/// The caustic — a bright concentrated focus of light on the water surface
/// directly under the orb. Real glass spheres act as converging lenses,
/// focusing overhead light into a small hot spot below the sphere.
/// Sits *behind* the orb in z-order so the orb appears above its caustic.
struct OrbCaustic: View {
    /// 0...1 — how bright the caustic is right now. Breath-driven from outside.
    var intensity: Double = 0.6
    var tint: Color = Color(red: 0.471, green: 0.765, blue: 0.843)

    var body: some View {
        ZStack {
            // Outer halo — soft diffuse spread
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(0.28 * intensity),
                            tint.opacity(0.0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 18)

            // Hot core — concentrated focus point
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.55 * intensity),
                            tint.opacity(0.35 * intensity),
                            tint.opacity(0.0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 140, height: 140)
                .blur(radius: 6)
                .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
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

        OrbCaustic(intensity: 0.9)
            .offset(y: 18)
        LiquidGlassOrb()
            .frame(width: 220, height: 220)
    }
}
