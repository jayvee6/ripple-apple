import SwiftUI

/// A glass loupe — a thick lens with a visible refractive bezel band.
/// The lens body is iOS 26 Liquid Glass (`.clear` variant for minimal
/// frost so the water reads through with high fidelity). Around it we
/// build a thick "glass thickness" rim using an angular gradient stroke
/// (catches imagined overhead light asymmetrically), plus an inner
/// refractive shadow and a couple of specular highlight pills at the top.
///
/// The goal is the look of a jeweler's loupe sitting on the water — not
/// chrome, not frosted ball; a precision-machined glass lens with depth.
struct LiquidGlassOrb: View {
    /// Tint color applied to the rim highlights. Aqua matches ripple's accent.
    var tint: Color = Color(red: 0.471, green: 0.765, blue: 0.843)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let rimWidth = size * 0.045          // ~10pt for a 220pt orb
            let innerShadowWidth = size * 0.022  // ~5pt — inner dark ring

            ZStack {
                // 1. Lens body — clear Liquid Glass so the water reads through.
                //    `.clear` variant has less frost than `.regular`.
                Circle()
                    .fill(Color.clear)
                    .glassEffect(.clear, in: Circle())
                    .padding(rimWidth * 0.6)

                // 2. Inner refractive shadow — just inside the bezel.
                //    Reads as the dark band where the glass thickness
                //    bends light away from the camera.
                Circle()
                    .strokeBorder(Color.black.opacity(0.32), lineWidth: innerShadowWidth)
                    .blur(radius: innerShadowWidth * 0.45)
                    .padding(rimWidth * 0.45)
                    .allowsHitTesting(false)

                // 3. The bezel — thick glass rim with asymmetric specular sweep
                Circle()
                    .strokeBorder(bezelGradient, lineWidth: rimWidth)
                    .allowsHitTesting(false)

                // 4. Hairline outer edge — crisp definition against the water
                Circle()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.6)
                    .allowsHitTesting(false)

                // 5. Hairline inner edge — where the lens body meets the bezel
                Circle()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                    .padding(rimWidth)
                    .allowsHitTesting(false)

                // 6. Specular pill — narrow elongated highlight near the top of
                //    the bezel, like a softbox slat reflection sweeping across
                //    the upper edge of the glass.
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.0),  location: 0.0),
                                .init(color: Color.white.opacity(0.85), location: 0.5),
                                .init(color: Color.white.opacity(0.0),  location: 1.0),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.18, height: rimWidth * 0.55)
                    .rotationEffect(.degrees(-22))
                    .blur(radius: 0.8)
                    .offset(x: -size * 0.22, y: -size * 0.40)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)

                // 7. Tiny secondary highlight near 1 o'clock
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: size * 0.05, height: rimWidth * 0.4)
                    .rotationEffect(.degrees(28))
                    .blur(radius: 0.6)
                    .offset(x: size * 0.20, y: -size * 0.36)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 18)
        .shadow(color: tint.opacity(0.18), radius: 28, x: 0, y: 0)
    }

    /// Asymmetric angular gradient for the bezel — bright at top (12 o'clock),
    /// dark at bottom (6 o'clock), tinted on the right side.
    /// Built as a computed property so the Swift type-checker doesn't time out.
    private var bezelGradient: AngularGradient {
        let stops: [Gradient.Stop] = [
            .init(color: Color.white.opacity(0.55), location: 0.00),
            .init(color: Color.white.opacity(0.40), location: 0.08),
            .init(color: tint.opacity(0.45),        location: 0.18),
            .init(color: Color.black.opacity(0.50), location: 0.32),
            .init(color: Color.black.opacity(0.70), location: 0.50),
            .init(color: Color.black.opacity(0.55), location: 0.68),
            .init(color: tint.opacity(0.32),        location: 0.82),
            .init(color: Color.white.opacity(0.32), location: 0.92),
            .init(color: Color.white.opacity(0.55), location: 1.00),
        ]
        return AngularGradient(
            stops: stops,
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
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
