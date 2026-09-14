// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MetalKit
import MetalPerformanceShaders
import OSLog

final class PlaneRenderer: NSObject, MTKViewDelegate {
    let gpu: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    let texture: MTLTexture
    private var desktopTexture: CVMetalTexture?
    private var desktopBuffer: CVPixelBuffer?
    private var textureCache: CVMetalTextureCache?
    private var blurLevels: [MTLTexture] = []
    private var reducedSource: MTLTexture?
    private var blurFilters: [MPSImageGaussianBlur] = []
    private var blurDirty = true
    private lazy var downsampler = MPSImageLanczosScale(device: gpu)
    private var frameRevision = 0
    private var lastRenderedState: [Double] = []
    private(set) var skippedUnchangedDraws = 0
    private(set) var busyDraws = 0
    private let inFlight = DispatchSemaphore(value: 2)
    var delta: Float = 0
    var opacity: Float = 1
    var geometryWeight: Float = 1
    private var presentationGeneration = 0
    func invalidatePresentation() { presentationGeneration += 1; lastRenderedState = [] }
    var blur = true
    var blurStrength: Float = 1.0
    var warp = true
    var perspective = false
    var foldStyle: Float = 0
    var foldDepth: Float = 1
    private var projectionMode: Float { warp ? (perspective ? 2 : 1) : 0 }
    var tick: (() -> Void)?
    var didDraw = false
    private(set) var completedDraws = 0
    var onRenderComplete: ((Bool) -> Void)?
    private let logger = Logger(subsystem: "app.fold.mac", category: "Renderer")
    private(set) var attemptedDraws = 0
    private(set) var missingDrawables = 0

    init(gpu: MTLDevice) throws {
        self.gpu = gpu
        queue = gpu.makeCommandQueue()!
        let library = try gpu.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexMain")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try gpu.makeRenderPipelineState(descriptor: descriptor)
        texture = try MTKTextureLoader(device: gpu).newTexture(cgImage: Self.artwork(), options: [.SRGB: false])
        super.init()
        CVMetalTextureCacheCreate(nil, nil, gpu, nil, &textureCache)
    }

    func setDesktopFrame(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard let textureCache else { return false }
        var wrapped: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .bgra8Unorm,
            CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), 0, &wrapped)
        guard result == kCVReturnSuccess, let wrapped else { return false }
        frameRevision += 1
        desktopTexture = wrapped
        desktopBuffer = pixelBuffer
        blurDirty = true
        return true
    }

    func useArtwork() {
        desktopTexture = nil
        desktopBuffer = nil
        blurLevels.removeAll(); reducedSource = nil; blurFilters.removeAll()
        if let textureCache { CVMetalTextureCacheFlush(textureCache, 0) }
        frameRevision += 1
        blurDirty = true
    }

    private var source: MTLTexture { desktopTexture.flatMap(CVMetalTextureGetTexture) ?? texture }

    private func prepareBlur(_ command: MTLCommandBuffer, source: MTLTexture) {
        let reducedWidth = max(2, source.width / 2)
        let reducedHeight = max(2, source.height / 2)
        if blurLevels.first?.width != reducedWidth || blurLevels.first?.height != reducedHeight {
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: reducedWidth, height: reducedHeight, mipmapped: false)
            desc.usage = [.shaderRead, .shaderWrite]
            desc.storageMode = .private
            reducedSource = gpu.makeTexture(descriptor: desc)
            blurLevels = (0..<4).map { _ in gpu.makeTexture(descriptor: desc)! }
            blurFilters = [Float(2), 6, 16, 40].map {
                let filter = MPSImageGaussianBlur(device: gpu, sigma: $0 * Float(reducedHeight) / 1000)
                filter.edgeMode = .clamp
                return filter
            }
            blurDirty = true
        }
        if blurDirty, let reducedSource {
            downsampler.encode(commandBuffer: command, sourceTexture: source, destinationTexture: reducedSource)
            for (filter, destination) in zip(blurFilters, blurLevels) {
                filter.encode(commandBuffer: command, sourceTexture: reducedSource, destinationTexture: destination)
            }
            blurDirty = false
        }
    }

    private func bindTextures(_ encoder: MTLRenderCommandEncoder, source: MTLTexture) {
        encoder.setFragmentTexture(source, index: 0)
        for index in 0..<4 { encoder.setFragmentTexture(blurLevels.indices.contains(index) ? blurLevels[index] : source, index: index+1) }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    @discardableResult
    func preview(to url: URL?, angle: Float, opacity: Float = 1, sourceTexture: MTLTexture? = nil) throws -> CGImage {
        let previewSource = sourceTexture ?? texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1000, height: 625, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared
        let output = gpu.makeTexture(descriptor: descriptor)!
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let command = queue.makeCommandBuffer()!
        // Diagnostic inputs can change without a new desktop frame arriving.
        blurDirty = true
        prepareBlur(command, source: previewSource)
        let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
        var params = SIMD4<Float>(angle, 1.6, blur ? blurStrength : 0, projectionMode)
        encoder.setRenderPipelineState(pipeline)
        bindTextures(encoder, source: previewSource)
        encoder.setFragmentBytes(&params, length: MemoryLayout.size(ofValue: params), index: 0)
        var alpha = opacity
        encoder.setFragmentBytes(&alpha, length: MemoryLayout<Float>.size, index: 1)
        var style = SIMD2<Float>(foldStyle, foldDepth)
        encoder.setFragmentBytes(&style, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        var pixels = [UInt8](repeating: 0, count: 1000*625*4)
        output.getBytes(&pixels, bytesPerRow: 4000, from: MTLRegionMake2D(0, 0, 1000, 625), mipmapLevel: 0)
        let data = Data(pixels)
        let image = CGImage(width: 1000, height: 625, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4000,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                            provider: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        if let url { try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url) }
        return image
    }

    func draw(in view: MTKView) {
        attemptedDraws += 1
        tick?()
        // Static desktop + settled hinge: reuse the drawable already on screen.
        // New capture frames and every presentation generation invalidate this.
        let state = [Double(delta), Double(opacity), Double(geometryWeight), Double(blurStrength),
            Double(projectionMode), Double(foldStyle), Double(foldDepth), blur ? 1 : 0, Double(view.drawableSize.width),
            Double(view.drawableSize.height), Double(frameRevision), Double(presentationGeneration)]
        guard state != lastRenderedState else { skippedUnchangedDraws += 1; return }
        guard inFlight.wait(timeout: .now()) == .success else { busyDraws += 1; return }
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer() else { missingDrawables += 1; inFlight.signal(); return }
        let source = self.source
        let retainedFrame = desktopBuffer
        let retainedTexture = desktopTexture
        if blur && abs(delta) > 0.003 { prepareBlur(command, source: source) }
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { inFlight.signal(); return }
        var params = SIMD4<Float>(delta * geometryWeight, Float(view.drawableSize.width / max(1, view.drawableSize.height)), blur ? blurStrength : 0, projectionMode)
        encoder.setRenderPipelineState(pipeline)
        bindTextures(encoder, source: source)
        encoder.setFragmentBytes(&params, length: MemoryLayout.size(ofValue: params), index: 0)
        var alpha = opacity
        encoder.setFragmentBytes(&alpha, length: MemoryLayout<Float>.size, index: 1)
        var style = SIMD2<Float>(foldStyle, foldDepth)
        encoder.setFragmentBytes(&style, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        let generation = presentationGeneration
        command.present(drawable)
        command.addCompletedHandler { [weak self, inFlight] buffer in
            // Capture surfaces must remain alive until the GPU finishes reading them.
            withExtendedLifetime((retainedFrame, retainedTexture)) {}
            inFlight.signal()
            if let error = buffer.error { self?.logger.error("GPU command failed: \(error.localizedDescription, privacy: .public)") }
            DispatchQueue.main.async {
                if buffer.error == nil { self?.completedDraws += 1 }
                if self?.presentationGeneration == generation { self?.onRenderComplete?(buffer.error == nil) }
            }
        }
        command.commit()
        lastRenderedState = state
        didDraw = true
    }

    static func artwork() -> CGImage {
        let width = 1600, height = 1000
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        let colors = [NSColor(red: 0.05, green: 0.08, blue: 0.22, alpha: 1).cgColor,
                      NSColor(red: 0.18, green: 0.33, blue: 0.65, alpha: 1).cgColor]
        let background = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(background, start: .zero, end: CGPoint(x: width, y: height), options: [])
        // Original vector artwork: broad satin ribbons, drawn locally without assets.
        for index in 0..<9 {
            let i = CGFloat(index)
            ctx.saveGState()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -200, y: 950 - i * 75))
            path.addCurve(to: CGPoint(x: 1750, y: 100 - i * 80), control1: CGPoint(x: 520, y: 1400 - i * 130), control2: CGPoint(x: 480, y: -160 - i * 40))
            path.addLine(to: CGPoint(x: 1800, y: -400))
            path.addLine(to: CGPoint(x: -200, y: -400)); path.closeSubpath()
            ctx.addPath(path); ctx.clip()
            let warm = index < 4
            let top = warm ? NSColor(calibratedRed: 1.0, green: 0.63 - i * 0.045, blue: 0.28 + i * 0.045, alpha: 1) : NSColor(calibratedRed: 0.30 + i * 0.035, green: 0.49 + i * 0.022, blue: 0.94, alpha: 1)
            let bottom = warm ? NSColor(calibratedRed: 0.35, green: 0.08 + i * 0.025, blue: 0.20, alpha: 1) : NSColor(calibratedRed: 0.045, green: 0.07, blue: 0.22 + i * 0.025, alpha: 1)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [bottom.cgColor, top.cgColor] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 500, y: -80 - i*30), end: CGPoint(x: 900, y: 860 - i*55), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.restoreGState()
        }
        return ctx.makeImage()!
    }

    // Default: parallel projection onto the reference plane, compensating tilt
    // without keystone taper. Optional perspective mode uses a finite eye position.
    // Both assume a stationary viewer; units are screen heights and hinge is y=0.
    static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; float2 uv; };
    vertex VertexOut vertexMain(uint id [[vertex_id]]) {
        float2 p = float2((id << 1) & 2, id & 2);
        return {float4(p * 2.0 - 1.0, 0, 1), float2(p.x, 1.0-p.y)};
    }
    fragment float4 fragmentMain(VertexOut in [[stage_in]], texture2d<float> art [[texture(0)]],
        texture2d<float> b1 [[texture(1)]], texture2d<float> b2 [[texture(2)]],
        texture2d<float> b3 [[texture(3)]], texture2d<float> b4 [[texture(4)]],
        constant float4 &p [[buffer(0)]], constant float &opacity [[buffer(1)]],
        constant float2 &style [[buffer(2)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float alpha = clamp(opacity, 0.0, 1.0);
        if (alpha == 0.0) return float4(0);
        // Exact identity avoids a dark antialiased border at the handoff.
        if (abs(p.x) < 0.000001) return float4(art.sample(s, in.uv).rgb * alpha, alpha);
        float2 uv = in.uv;
        float height = 1.0 - uv.y;
        float a = clamp(p.x, -0.65, 1.25);
        float depth = height * sin(a);
        if (p.w > 0.5) {
            float3 eye = float3(0, 0.65, 1.6);
            float3 physical = float3((uv.x-0.5)*p.y, height*cos(a), depth);
            float t = p.w > 1.5 ? eye.z / max(0.25, eye.z-physical.z) : 1.0;
            float3 hit = eye + t * (physical-eye);
            uv = float2(hit.x/p.y+0.5, 1.0-hit.y);
        }
        // V2: three articulated panels collapse toward the hinge. Alternating
        // depth forms a continuous accordion silhouette, with soft crease light.
        // Inverse projection avoids holes and remains exactly identity at zero.
        float material = 1.0;
        if (p.w > 0.5 && style.x > 0.00001) {
            float bend = clamp(a * clamp(style.y, 0.5, 1.4), -1.2, 1.2);
            float compression = max(0.30, cos(bend));
            float sourceHeight = height / compression;
            float panelCoordinate = clamp(sourceHeight, 0.0, 0.999999) * 3.0;
            float panel = floor(panelCoordinate);
            float local = fract(panelCoordinate);
            float ridge = (int(panel) % 2 == 0) ? local : 1.0 - local;
            float panelDepth = sin(abs(bend)) * ridge / 3.0;
            float panelScale = p.w > 1.5 ? 1.0 / (1.0 + panelDepth * 1.7) : 1.0;
            float2 origamiUV = float2((in.uv.x - 0.5) / panelScale + 0.5, 1.0 - sourceHeight);
            float creaseDistance = min(abs(sourceHeight - 1.0/3.0), abs(sourceHeight - 2.0/3.0));
            float crease = exp(-pow(creaseDistance / 0.016, 2.0));
            float facing = (int(panel) % 2 == 0) ? 1.0 : 0.90;
            float origamiLight = 1.0 - sin(abs(bend)) * ((1.0 - facing) + crease * 0.17);
            float blend = clamp(style.x, 0.0, 1.0);
            uv = mix(uv, origamiUV, blend);
            material = mix(1.0, origamiLight, blend);
        }
        // Radius varies across the surface, not just over time. Gaussian levels
        // avoid the repeated edges / speckling from sparse disc sampling.
        float radius = p.z * smoothstep(0.08, 1.0, height) * abs(sin(a)) * 65.0;
        float3 color;
        if (radius < 2.0) color = mix(art.sample(s, uv).rgb, b1.sample(s, uv).rgb, radius/2.0);
        else if (radius < 6.0) color = mix(b1.sample(s, uv).rgb, b2.sample(s, uv).rgb, (radius-2.0)/4.0);
        else if (radius < 16.0) color = mix(b2.sample(s, uv).rgb, b3.sample(s, uv).rgb, (radius-6.0)/10.0);
        else color = mix(b3.sample(s, uv).rgb, b4.sample(s, uv).rgb, clamp((radius-16.0)/24.0, 0.0, 1.0));
        // Blur the image boundary too, instead of clipping the already-blurred
        // content to a razor-sharp UV rectangle. Extend the edge colour outward
        // and feather its coverage over the same progressive source-space radius.
        // Three sigma on either side approximates the Gaussian edge falloff.
        float2 sourceSize = float2(art.get_width(), art.get_height());
        float sigmaPixels = radius * sourceSize.y / 1000.0;
        float2 feather = max(3.0 * sigmaPixels / sourceSize, fwidth(uv));
        float2 coverage = smoothstep(-feather, feather, uv)
                        * (1.0 - smoothstep(1.0 - feather, 1.0 + feather, uv));
        float mask = coverage.x * coverage.y;
        float closing = smoothstep(0.90, 1.60, max(p.x, 0.0));
        return float4(mix(float3(0.008, 0.009, 0.012), color * material, mask) * (1.0 - 0.82 * closing) * alpha, alpha);
    }
    """
}
