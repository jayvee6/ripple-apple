import SwiftUI
import MetalKit

/// SwiftUI wrapper for the MTKView that renders ripple's water.
/// Exposes a binding-driven `pulseTrigger` so views above can fire ripples
/// at the right moment in the breath cycle.
struct MetalWaterView: UIViewRepresentable {
    /// Increment this to inject a centered pulse on the next frame.
    /// (Using a counter rather than a Bool lets repeat triggers fire even
    /// when the value would otherwise be equal.)
    var pulseTrigger: Int
    var pulseIntensity: Float = 1.0

    final class Coordinator {
        var renderer: WaterRenderer?
        var lastSeenTrigger: Int = 0
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.backgroundColor = .black
        view.isOpaque = true
        if let renderer = WaterRenderer(view: view) {
            context.coordinator.renderer = renderer
            // First-time sizing so textures exist before the first frame
            view.delegate?.mtkView(view, drawableSizeWillChange: view.drawableSize)
        }
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        let coord = context.coordinator
        // Forward pulse triggers as they change
        if pulseTrigger != coord.lastSeenTrigger {
            coord.lastSeenTrigger = pulseTrigger
            let size = view.bounds.size
            coord.renderer?.triggerCenterPulse(viewSize: size, intensity: pulseIntensity)
        }
    }
}
