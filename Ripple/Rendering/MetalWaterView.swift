import SwiftUI
import MetalKit

/// SwiftUI wrapper for the MTKView that renders ripple's water.
/// Exposes a binding-driven `pulseTrigger` so views above can fire ripples
/// at the right moment in the breath cycle.
struct MetalWaterView: UIViewRepresentable {
    /// Increment this to inject a centered pulse on the next frame.
    var pulseTrigger: Int
    var pulseIntensity: Float = 1.0

    @Environment(\.scenePhase) private var scenePhase

    final class Coordinator {
        var renderer: WaterRenderer?
        var lastSeenTrigger: Int = 0
        weak var view: MTKView?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.backgroundColor = .black
        view.isOpaque = true
        context.coordinator.view = view
        if let renderer = WaterRenderer(view: view) {
            context.coordinator.renderer = renderer
            view.delegate?.mtkView(view, drawableSizeWillChange: view.drawableSize)
        }
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        let coord = context.coordinator

        // Pause all GPU work when the app isn't foreground-active — a
        // meditation app is often left on screen; never burn battery
        // rendering water nobody is looking at.
        view.isPaused = (scenePhase != .active)

        if pulseTrigger != coord.lastSeenTrigger {
            coord.lastSeenTrigger = pulseTrigger
            // A pulse must override an idle/scene pause so the ripple shows.
            if scenePhase == .active { view.isPaused = false }
            coord.renderer?.triggerCenterPulse(viewSize: view.bounds.size,
                                               intensity: pulseIntensity)
        }
    }

    /// Teardown — stop the render loop and drop the renderer so the view
    /// can't keep driving the GPU after it leaves the hierarchy.
    static func dismantleUIView(_ view: MTKView, coordinator: Coordinator) {
        view.isPaused = true
        view.delegate = nil
        coordinator.renderer = nil
    }
}
