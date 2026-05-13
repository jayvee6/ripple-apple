import Foundation
import Metal
import MetalKit
import simd

/// Drives the 2D wave simulation + lit water render pass.
/// Mirrors the WebGPU implementation in web ripple's index.html, but
/// targets Metal directly. Three ping-pong textures rotate each frame.
final class WaterRenderer: NSObject, MTKViewDelegate {
    static let maxDrops = 8

    // MARK: - Drop struct must match MSL layout
    struct Drop {
        var pos: SIMD2<Float>
        var intensity: Float
        var _pad: Float = 0
    }
    struct SimParams {
        var waveSpeed: Float
        var damping: Float
        var dropCount: UInt32
        var _pad: Float = 0
        // Followed by Drop[8] in raw buffer below.
    }
    struct RenderParams {
        var resolution: SIMD2<Float>
        var time: Float
        var _pad: Float = 0
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let computePipeline: MTLComputePipelineState
    private let renderPipeline: MTLRenderPipelineState

    // Three ping-pong height textures, rotated per frame.
    private var textures: [MTLTexture] = []
    private var frameIndex: Int = 0

    private var simW: Int = 0
    private var simH: Int = 0

    // Uniform buffers (triple-buffered to avoid GPU stalls)
    private static let inflightFrames = 3
    private var simUniformBuffers: [MTLBuffer] = []
    private var renderUniformBuffers: [MTLBuffer] = []
    private var currentBufferIndex = 0

    // Pending drops to inject on the next frame.
    private var pendingDrops: [Drop] = []
    private let dropLock = NSLock()

    // Simulation tuning
    var waveSpeed: Float = 0.42
    var damping: Float = 0.9965

    private let startTime = CFAbsoluteTimeGetCurrent()

    init?(view: MTKView) {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice() else { return nil }
        guard let queue = device.makeCommandQueue() else { return nil }
        guard let library = try? device.makeDefaultLibrary(bundle: .main) else { return nil }

        guard let kernel = library.makeFunction(name: "waveStep"),
              let vert   = library.makeFunction(name: "waterVertex"),
              let frag   = library.makeFunction(name: "waterFragment") else { return nil }

        guard let computePipeline = try? device.makeComputePipelineState(function: kernel) else { return nil }

        let renderDesc = MTLRenderPipelineDescriptor()
        renderDesc.vertexFunction = vert
        renderDesc.fragmentFunction = frag
        renderDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        guard let renderPipeline = try? device.makeRenderPipelineState(descriptor: renderDesc) else { return nil }

        self.device = device
        self.commandQueue = queue
        self.computePipeline = computePipeline
        self.renderPipeline = renderPipeline

        super.init()

        // Allocate inflight uniform buffers
        let simSize = MemoryLayout<SimParams>.stride + Self.maxDrops * MemoryLayout<Drop>.stride
        for _ in 0..<Self.inflightFrames {
            if let b = device.makeBuffer(length: simSize, options: .storageModeShared) {
                simUniformBuffers.append(b)
            }
            if let b = device.makeBuffer(length: MemoryLayout<RenderParams>.stride, options: .storageModeShared) {
                renderUniformBuffers.append(b)
            }
        }

        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.delegate = self
        view.framebufferOnly = false
        view.preferredFramesPerSecond = 120
        view.isPaused = false
    }

    // MARK: - Public surface

    /// Drop a pulse at a screen-space point. The view translates and forwards.
    func triggerPulse(at screenPoint: CGPoint, viewSize: CGSize, intensity: Float = 1.0) {
        guard simW > 0, simH > 0 else { return }
        let sx = Float(screenPoint.x / max(viewSize.width, 1)) * Float(simW)
        let sy = Float(screenPoint.y / max(viewSize.height, 1)) * Float(simH)
        let d = Drop(pos: SIMD2(sx, sy), intensity: intensity)
        dropLock.lock()
        pendingDrops.append(d)
        dropLock.unlock()
    }

    /// Convenience: drop at the center of the view.
    func triggerCenterPulse(viewSize: CGSize, intensity: Float = 1.0) {
        triggerPulse(at: CGPoint(x: viewSize.width / 2, y: viewSize.height / 2),
                     viewSize: viewSize, intensity: intensity)
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Use modest sim resolution for perf — 60% of backing pixels.
        let scale: CGFloat = 0.6
        let w = max(64, Int(size.width * scale))
        let h = max(64, Int(size.height * scale))
        simW = w
        simH = h

        let desc = MTLTextureDescriptor()
        desc.pixelFormat = .r32Float
        desc.width = w
        desc.height = h
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .private

        textures.removeAll(keepingCapacity: true)
        for _ in 0..<3 {
            if let t = device.makeTexture(descriptor: desc) {
                textures.append(t)
            }
        }
    }

    func draw(in view: MTKView) {
        guard textures.count == 3,
              let drawable = view.currentDrawable,
              let renderPassDesc = view.currentRenderPassDescriptor
        else { return }

        let bufferIndex = currentBufferIndex
        currentBufferIndex = (currentBufferIndex + 1) % Self.inflightFrames
        let simBuffer = simUniformBuffers[bufferIndex]
        let renderBuffer = renderUniformBuffers[bufferIndex]

        // Snapshot & clear pending drops
        dropLock.lock()
        let dropsThisFrame = pendingDrops
        pendingDrops.removeAll(keepingCapacity: true)
        dropLock.unlock()

        // Write sim uniforms
        let simParams = SimParams(
            waveSpeed: waveSpeed,
            damping: damping,
            dropCount: UInt32(min(dropsThisFrame.count, Self.maxDrops))
        )
        let simPtr = simBuffer.contents()
        simPtr.copyMemory(from: [simParams], byteCount: MemoryLayout<SimParams>.stride)
        let dropsPtr = simPtr.advanced(by: MemoryLayout<SimParams>.stride)
        for i in 0..<Self.maxDrops {
            let d: Drop = i < dropsThisFrame.count ? dropsThisFrame[i] : Drop(pos: .zero, intensity: 0)
            dropsPtr.advanced(by: i * MemoryLayout<Drop>.stride)
                .copyMemory(from: [d], byteCount: MemoryLayout<Drop>.stride)
        }

        // Write render uniforms
        let rp = RenderParams(
            resolution: SIMD2(Float(simW), Float(simH)),
            time: Float(CFAbsoluteTimeGetCurrent() - startTime)
        )
        renderBuffer.contents().copyMemory(from: [rp], byteCount: MemoryLayout<RenderParams>.stride)

        // Rotate texture roles each frame: previous / current / next
        let stateIdx = frameIndex % 3
        let currentTex  = textures[stateIdx]
        let previousTex = textures[(stateIdx + 2) % 3]
        let nextTex     = textures[(stateIdx + 1) % 3]

        guard let cmdBuffer = commandQueue.makeCommandBuffer() else { return }

        // Compute pass — one wave step
        if let computeEnc = cmdBuffer.makeComputeCommandEncoder() {
            computeEnc.setComputePipelineState(computePipeline)
            computeEnc.setTexture(currentTex,  index: 0)
            computeEnc.setTexture(previousTex, index: 1)
            computeEnc.setTexture(nextTex,     index: 2)
            computeEnc.setBuffer(simBuffer, offset: 0, index: 0)
            let tg = MTLSize(width: 8, height: 8, depth: 1)
            let groups = MTLSize(
                width: (simW + 7) / 8,
                height: (simH + 7) / 8,
                depth: 1
            )
            computeEnc.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
            computeEnc.endEncoding()
        }

        // Render pass — full-screen lit water
        if let renderEnc = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) {
            renderEnc.setRenderPipelineState(renderPipeline)
            renderEnc.setFragmentTexture(nextTex, index: 0)
            renderEnc.setFragmentBuffer(renderBuffer, offset: 0, index: 0)
            renderEnc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            renderEnc.endEncoding()
        }

        cmdBuffer.present(drawable)
        cmdBuffer.commit()
        frameIndex += 1
    }
}
