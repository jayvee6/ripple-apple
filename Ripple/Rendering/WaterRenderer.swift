import Foundation
import Metal
import MetalKit
import simd
import QuartzCore

/// Drives the 2D wave simulation + lit water render.
///
/// World-class pass:
///  • Fixed-timestep accumulator — device-independent physics (was 2× on 120Hz)
///  • Triple-buffered uniforms gated by a DispatchSemaphore (was a data race)
///  • .private textures zero-cleared on (re)alloc (was uninitialised garbage)
///  • Released-from-rest drop seeding into current+previous (was velocity-biased)
///  • Frequency-dependent viscosity + sponge boundary in the kernel
///  • 60fps cap + quiescence pause for battery
///  • rgba16Float target (no banding, EDR-capable specular)
final class WaterRenderer: NSObject, MTKViewDelegate {
    static let maxDrops = 8

    // MARK: - Uniform structs (must match Shaders.metal layout exactly)

    struct Drop {
        var pos: SIMD2<Float>
        var intensity: Float
        var _pad: Float = 0
    }
    struct SimParams {
        var waveSpeed: Float
        var damping: Float
        var viscosity: Float
        var spongeBand: Float
        var spongeEdge: Float
        var dropRadius: Float
        var dropCount: UInt32
        var _pad: Float = 0
    }
    struct RenderParams {
        var resolution: SIMD2<Float>
        var time: Float
        var normalScale: Float
        var aspect: Float
        var _pad0: Float = 0
        var _pad1: Float = 0
        var _pad2: Float = 0
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let clearPipeline: MTLComputePipelineState
    private let seedPipeline: MTLComputePipelineState
    private let wavePipeline: MTLComputePipelineState
    private let renderPipeline: MTLRenderPipelineState

    // Three ping-pong height textures, rotated per SIM STEP (not per frame).
    private var textures: [MTLTexture] = []
    private var simStep: Int = 0
    private var simW = 0
    private var simH = 0

    // Triple-buffered uniforms + a real CPU/GPU gate.
    private static let inflight = 3
    private let frameSemaphore = DispatchSemaphore(value: inflight)
    private var simUniformBuffers: [MTLBuffer] = []
    private var renderUniformBuffers: [MTLBuffer] = []
    private var bufferIndex = 0

    // Fixed-timestep accumulator. Sim advances at a constant 60Hz regardless
    // of display refresh, so waveSpeed/damping are device-independent.
    private static let simHz: Double = 60
    private static let simDT: Double = 1.0 / simHz
    private static let maxStepsPerFrame = 4   // clamp to avoid spiral-of-death
    private var accumulator: Double = 0
    private var lastTime: CFTimeInterval = CACurrentMediaTime()
    private let startTime: CFTimeInterval = CACurrentMediaTime()

    // Pending drops.
    private var pendingDrops: [Drop] = []
    private let dropLock = NSLock()

    // Quiescence: pause the render loop when the pool has been still long
    // enough that there's nothing to animate. Resumed instantly on a pulse.
    private var lastActivity: CFTimeInterval = CACurrentMediaTime()
    private static let settleSeconds: CFTimeInterval = 30
    private weak var mtkView: MTKView?

    // Tuning (per fixed 60Hz step)
    var waveSpeed: Float = 0.42
    var damping: Float = 0.9992      // tiny global sink; viscosity does the real work
    var viscosity: Float = 0.018     // μ on ∇²(c−p) — high freqs die fast
    private let spongeEdge: Float = 0.92

    init?(view: MTKView) {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice() else { return nil }
        guard let queue = device.makeCommandQueue() else { return nil }
        guard let library = try? device.makeDefaultLibrary(bundle: .main) else { return nil }
        guard let clearFn = library.makeFunction(name: "clearTex"),
              let seedFn  = library.makeFunction(name: "seedDrops"),
              let waveFn  = library.makeFunction(name: "waveStep"),
              let vert    = library.makeFunction(name: "waterVertex"),
              let frag    = library.makeFunction(name: "waterFragment"),
              let clearPS = try? device.makeComputePipelineState(function: clearFn),
              let seedPS  = try? device.makeComputePipelineState(function: seedFn),
              let wavePS  = try? device.makeComputePipelineState(function: waveFn)
        else { return nil }

        let rd = MTLRenderPipelineDescriptor()
        rd.vertexFunction = vert
        rd.fragmentFunction = frag
        rd.colorAttachments[0].pixelFormat = .rgba16Float
        guard let renderPS = try? device.makeRenderPipelineState(descriptor: rd) else { return nil }

        self.device = device
        self.commandQueue = queue
        self.clearPipeline = clearPS
        self.seedPipeline = seedPS
        self.wavePipeline = wavePS
        self.renderPipeline = renderPS
        super.init()

        let simSize = MemoryLayout<SimParams>.stride + Self.maxDrops * MemoryLayout<Drop>.stride
        for _ in 0..<Self.inflight {
            simUniformBuffers.append(device.makeBuffer(length: simSize, options: .storageModeShared)!)
            renderUniformBuffers.append(device.makeBuffer(length: MemoryLayout<RenderParams>.stride,
                                                          options: .storageModeShared)!)
        }

        // rgba16Float for no banding + EDR-capable specular highlights.
        view.device = device
        view.colorPixelFormat = .rgba16Float
        view.delegate = self
        view.preferredFramesPerSecond = 60   // water never needs 120; halves display+GPU power
        view.isPaused = false
        self.mtkView = view
    }

    // MARK: - Public surface

    func triggerPulse(at screenPoint: CGPoint, viewSize: CGSize, intensity: Float = 1.0) {
        guard simW > 0, simH > 0 else { return }
        let w = max(viewSize.width, 1)
        let h = max(viewSize.height, 1)
        let sx = Float(screenPoint.x / w) * Float(simW)
        // Flip Y: screen origin is top-left; the fragment's UV space (and
        // thus the displayed field) is Y-up. Without this, off-centre taps
        // ripple mirrored vertically vs. where the user touched.
        let sy = Float(1.0 - screenPoint.y / h) * Float(simH)
        dropLock.lock()
        pendingDrops.append(Drop(pos: SIMD2(sx, sy), intensity: intensity))
        dropLock.unlock()

        lastActivity = CACurrentMediaTime()
        // Resume the loop if we paused it while the pool was still.
        if let v = mtkView, v.isPaused {
            DispatchQueue.main.async { v.isPaused = false }
        }
    }

    func triggerCenterPulse(viewSize: CGSize, intensity: Float = 1.0) {
        triggerPulse(at: CGPoint(x: viewSize.width / 2, y: viewSize.height / 2),
                     viewSize: viewSize, intensity: intensity)
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let scale: CGFloat = 0.6
        simW = max(64, Int(size.width * scale))
        simH = max(64, Int(size.height * scale))

        let desc = MTLTextureDescriptor()
        desc.pixelFormat = .r32Float   // r16Float quantises the slow decay tail → keep 32
        desc.width = simW
        desc.height = simH
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .private

        textures = (0..<3).compactMap { _ in device.makeTexture(descriptor: desc) }
        simStep = 0
        accumulator = 0
        lastTime = CACurrentMediaTime()

        // Zero the freshly-allocated .private textures so the pool opens
        // as glass and rotations don't propagate undefined memory.
        guard textures.count == 3,
              let cmd = commandQueue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(clearPipeline)
        for t in textures {
            enc.setTexture(t, index: 0)
            enc.dispatchThreads(MTLSize(width: simW, height: simH, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        }
        enc.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
    }

    func draw(in view: MTKView) {
        guard textures.count == 3,
              let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor else { return }

        // Fixed-timestep: accumulate real elapsed wall-clock time.
        let now = CACurrentMediaTime()
        var dt = now - lastTime
        lastTime = now
        if dt > 0.25 { dt = 0.25 }   // clamp after a hitch
        accumulator += dt

        dropLock.lock()
        let drops = pendingDrops
        pendingDrops.removeAll(keepingCapacity: true)
        dropLock.unlock()

        var steps = Int(accumulator / Self.simDT)
        accumulator -= Double(steps) * Self.simDT
        if !drops.isEmpty { steps = max(steps, 1) }   // always start a fresh ripple
        steps = min(steps, Self.maxStepsPerFrame)

        // Quiescence: if nothing's happening and the pool has had time to
        // settle, pause the loop. Resumed by triggerPulse.
        if drops.isEmpty, now - lastActivity > Self.settleSeconds {
            view.isPaused = true
            return
        }

        frameSemaphore.wait()
        let bi = bufferIndex
        bufferIndex = (bufferIndex + 1) % Self.inflight
        let simBuf = simUniformBuffers[bi]
        let renderBuf = renderUniformBuffers[bi]

        // Sim uniforms (no per-frame Array allocs — typed pointer writes).
        let dropRadius = max(6.0, 0.035 * Float(min(simW, simH)))
        let spongeBand = max(8.0, 0.06 * Float(min(simW, simH)))
        let sp = simBuf.contents().bindMemory(to: SimParams.self, capacity: 1)
        sp.pointee = SimParams(waveSpeed: waveSpeed, damping: damping,
                               viscosity: viscosity, spongeBand: spongeBand,
                               spongeEdge: spongeEdge, dropRadius: dropRadius,
                               dropCount: UInt32(min(drops.count, Self.maxDrops)))
        let dropsPtr = simBuf.contents()
            .advanced(by: MemoryLayout<SimParams>.stride)
            .bindMemory(to: Drop.self, capacity: Self.maxDrops)
        for i in 0..<Self.maxDrops {
            dropsPtr[i] = i < drops.count ? drops[i] : Drop(pos: .zero, intensity: 0)
        }

        let rp = renderBuf.contents().bindMemory(to: RenderParams.self, capacity: 1)
        rp.pointee = RenderParams(
            resolution: SIMD2(Float(simW), Float(simH)),
            time: Float(now - startTime),
            normalScale: 4.0 * Float(simW) / 700.0,  // resolution-invariant
            aspect: Float(max(simW, 1)) / Float(max(simH, 1))
        )

        guard let cmd = commandQueue.makeCommandBuffer() else {
            frameSemaphore.signal(); return
        }
        cmd.addCompletedHandler { [frameSemaphore] _ in frameSemaphore.signal() }

        let tg = MTLSize(width: 8, height: 8, depth: 1)
        let full = MTLSize(width: simW, height: simH, depth: 1)

        // Seed drops once, released-from-rest, into the (current, previous)
        // pair the first wave step will read.
        if !drops.isEmpty, let enc = cmd.makeComputeCommandEncoder() {
            let cur = textures[simStep % 3]
            let prev = textures[(simStep + 2) % 3]
            enc.setComputePipelineState(seedPipeline)
            enc.setTexture(cur, index: 0)
            enc.setTexture(prev, index: 1)
            enc.setBuffer(simBuf, offset: 0, index: 0)
            enc.dispatchThreads(full, threadsPerThreadgroup: tg)
            enc.endEncoding()
        }

        // Exact fixed-timestep: run precisely `steps` wave steps (forced to
        // ≥1 only when there are fresh drops to launch). Rotating ping-pong
        // each step — after step S→S+1: new current == old next, new
        // previous == old current (verified leapfrog).
        let runSteps = max(steps, drops.isEmpty ? 0 : 1)
        for _ in 0..<runSteps {
            guard let enc = cmd.makeComputeCommandEncoder() else { break }
            let cur  = textures[simStep % 3]
            let prev = textures[(simStep + 2) % 3]
            let nxt  = textures[(simStep + 1) % 3]
            enc.setComputePipelineState(wavePipeline)
            enc.setTexture(cur,  index: 0)
            enc.setTexture(prev, index: 1)
            enc.setTexture(nxt,  index: 2)
            enc.setBuffer(simBuf, offset: 0, index: 0)
            enc.dispatchThreads(full, threadsPerThreadgroup: tg)
            enc.endEncoding()
            simStep += 1
        }

        // Render the most recently written field: after the loop the head
        // of the leapfrog is textures[simStep % 3] (the last 'nxt').
        let latest = textures[simStep % 3]
        if let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) {
            enc.setRenderPipelineState(renderPipeline)
            enc.setFragmentTexture(latest, index: 0)
            enc.setFragmentBuffer(renderBuf, offset: 0, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()
        }

        cmd.present(drawable)
        cmd.commit()
    }
}
