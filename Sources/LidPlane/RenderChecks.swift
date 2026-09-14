// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MetalKit

/// Generated pixels only: a bright rectangle makes clipped blur unmistakable.
enum RenderChecks {
    static func run(_ renderer: PlaneRenderer) throws {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1600, height: 1000, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        let source = renderer.gpu.makeTexture(descriptor: descriptor)!
        let pixels = [UInt8](repeating: 255, count: 1600 * 1000 * 4)
        pixels.withUnsafeBytes {
            source.replace(region: MTLRegionMake2D(0, 0, 1600, 1000), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 6400)
        }
        let oldSettings = (renderer.blur, renderer.warp, renderer.perspective, renderer.foldStyle)
        defer { (renderer.blur, renderer.warp, renderer.perspective, renderer.foldStyle) = oldSettings }
        renderer.foldStyle = 0
        renderer.warp = true; renderer.perspective = true; renderer.blur = true
        let angle: Float = 0.6
        let blurred = NSBitmapImageRep(cgImage: try renderer.preview(to: nil, angle: angle, sourceTexture: source))
        renderer.blur = false
        let sharp = NSBitmapImageRep(cgImage: try renderer.preview(to: nil, angle: angle, sourceTexture: source))
        func brightness(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> CGFloat {
            image.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!.redComponent
        }
        func leftEdge(at y: Int) -> Int {
            let height = 1 - (Double(y) + 0.5) / 625
            return Int(1000 * height * sin(Double(angle)) / 3.2)
        }
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "LidPlane.RenderChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let top = 125, bottom = 500
        let left = leftEdge(at: top), right = 999 - left
        try require(brightness(blurred, left - 8, top) > 0.1, "Top-left blur was clipped outside the image")
        try require(brightness(blurred, right + 8, top) > 0.1, "Top-right blur was clipped outside the image")
        try require(brightness(blurred, left + 8, top) < 0.95, "Image boundary did not soften inward")
        try require(brightness(sharp, left - 8, top) < 0.04, "Blur-off unexpectedly feathers the border")
        try require(brightness(blurred, leftEdge(at: bottom) - 8, bottom) < 0.04, "Blur is not tighter near the hinge")
        try require(brightness(blurred, 500, top) > 0.99, "Edge treatment changed the image interior")
        let identity = NSBitmapImageRep(cgImage: try renderer.preview(to: nil, angle: 0, sourceTexture: source))
        for (x, y) in [(0, 0), (999, 624), (0, 312), (500, 312)] {
            try require(brightness(identity, x, y) > 0.99, "Aligned frame must preserve even the edge pixels")
        }
        let transparent = NSBitmapImageRep(cgImage: try renderer.preview(to: nil, angle: angle, opacity: 0, sourceTexture: source))
        let half = NSBitmapImageRep(cgImage: try renderer.preview(to: nil, angle: 0, opacity: 0.5, sourceTexture: source))
        try require(transparent.colorAt(x: 500, y: 312)!.alphaComponent == 0, "Handoff must reveal the live desktop completely")
        try require(abs(half.colorAt(x: 500, y: 312)!.alphaComponent - 0.5) < 0.01, "Handoff alpha must survive Metal output")
        if let bytes = half.bitmapData {
            let offset = 312 * half.bytesPerRow + 500 * 4
            try require((0..<4).allSatisfy { abs(Int(bytes[offset + $0]) - 128) <= 1 }, "Output must be premultiplied for correct window compositing")
        }
        renderer.foldStyle = 1
        let origami = NSBitmapImageRep(cgImage: try renderer.preview(to: nil, angle: angle, sourceTexture: source))
        let origamiIdentity = NSBitmapImageRep(cgImage: try renderer.preview(to: nil, angle: 0, sourceTexture: source))
        var difference = 0.0
        for y in stride(from: 10, to: 625, by: 20) {
            for x in stride(from: 10, to: 1000, by: 20) {
                difference += Double(abs(brightness(origami, x, y) - brightness(sharp, x, y)))
                try require(brightness(origamiIdentity, x, y) > 0.99, "Origami must become exact identity at zero")
            }
        }
        try require(difference > 20, "V2 must have visibly different geometry from V1")
        for style in [Float(0), 0.5, 1] {
            renderer.foldStyle = style
            let faded = NSBitmapImageRep(cgImage: try renderer.preview(to: nil, angle: angle, opacity: 0.25, sourceTexture: source))
            try require(abs(faded.colorAt(x: 500, y: 500)!.alphaComponent - 0.25) < 0.01, "Style morph must preserve alpha")
        }
        print("PASS: distinct Origami geometry, identity at zero, and transparent compositing during style morphs")
        print("PASS: exact aligned edges, transparent handoff and premultiplied compositing")
        print("PASS: blur crosses both borders, softens inward, tightens near the hinge, and respects blur-off")
    }
}
