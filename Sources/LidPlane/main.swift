// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MetalKit

if CommandLine.arguments.contains("--probe") {
    let sensor = LidSensor()
    print(sensor.diagnostic)
    exit(sensor.read() == nil ? 1 : 0)
}
if CommandLine.arguments.contains("--preview") {
    _ = NSApplication.shared
    do {
        guard let gpu = MTLCreateSystemDefaultDevice() else { fatalError("Metal unavailable") }
        let renderer = try PlaneRenderer(gpu: gpu)
        try renderer.preview(to: URL(fileURLWithPath: "dist/open.png"), angle: 0)
        try renderer.preview(to: URL(fileURLWithPath: "dist/folded.png"), angle: 35 * .pi / 180)
        renderer.perspective = true
        try renderer.preview(to: URL(fileURLWithPath: "dist/perspective.png"), angle: 35 * .pi / 180)
        try RenderChecks.run(renderer)
        print("Metal render checks passed")
        exit(0)
    } catch { print(error); exit(1) }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = MenuBarApp()
app.delegate = delegate
app.run()
