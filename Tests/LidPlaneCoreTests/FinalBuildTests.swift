// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import LidPlaneCore

enum FinalBuildTests {
    static func run() {
        for width in [8.0, 15, 22] {
            var lastOpacity = 0.0
            for i in 0...1000 {
                let distance = Double(i) / 1000 * width
                let p = OverlayHandoff.presentation(delta: distance * .pi / 180, rawDistance: distance,
                    angleMode: true, width: width, elapsedSinceFrame: 1)
                precondition(p.geometry >= 0 && p.geometry <= 1 && p.opacity >= lastOpacity && p.opacity <= 1)
                lastOpacity = p.opacity
                // The last dissolve happens only after geometric flattening.
                if p.opacity > 0 && p.opacity < 0.5 { precondition(distance * p.geometry < 0.04) }
            }
            let lagging = OverlayHandoff.presentation(delta: 1, rawDistance: 0.5, angleMode: true, width: width, elapsedSinceFrame: 1)
            precondition(lagging.geometry < 0.00001 && lagging.opacity < 0.05)
        }
        for distance in [-10.0, 0] {
            let p = OverlayHandoff.presentation(delta: 1, rawDistance: distance, angleMode: true, width: 15, elapsedSinceFrame: 1)
            XCTAssertEqual(p.geometry, 0); XCTAssertEqual(p.opacity, 0)
        }
        let arriving = OverlayHandoff.presentation(delta: 1, rawDistance: 30, angleMode: true, width: 15, elapsedSinceFrame: 0)
        XCTAssertEqual(arriving.opacity, 0)
        let bad = OverlayHandoff.presentation(delta: .nan, rawDistance: 20, angleMode: true, width: 15, elapsedSinceFrame: 1)
        XCTAssertEqual(bad.opacity, 0)
        for chord in ShortcutConfiguration.suggestions {
            precondition(chord.validationError == nil)
            let data = try! JSONEncoder().encode(chord)
            precondition(try! JSONDecoder().decode(ShortcutConfiguration.self, from: data) == chord)
        }
        precondition(ShortcutConfiguration.default.label == "⌃⌘L")
        for chord in [ShortcutConfiguration(keyCode: 37, modifiers: 8), .init(keyCode: 37, modifiers: 0),
                      .init(keyCode: 12, modifiers: 12), .init(keyCode: 53, modifiers: 15), .init(keyCode: 37, modifiers: 255)] {
            precondition(chord.validationError != nil)
        }
        print("PASS: staged flatten-before-dissolve, lag bounds, invalid samples, shortcut validation and persistence")
    }
}
