// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import LidPlaneCore

enum OpeningMotionTests {
    static func run() {
        // Whole-degree HID samples held for two display refreshes reproduce the
        // old opening-only staircase. Exercise each supported motion response.
        for hz in [60, 120] {
            for response in [0.02, 0.045, 0.12] {
                var fold = FoldSpring()
                var envelope = HandoffSmoothing()
                fold.reset(to: 110 * .pi / 180)
                var oldValues: [Double] = [], newValues: [Double] = []
                var previous = 110.0
                for frame in 0..<hz {
                    let distance = 110 - Double(frame / 2)
                    let delta = fold.advance(to: distance * .pi / 180, elapsed: 1 / Double(hz), response: response)
                    let boundary = envelope.advance(distance: distance, elapsed: 1 / Double(hz), response: response)
                    let p = OverlayHandoff.presentation(delta: delta, rawDistance: boundary,
                        angleMode: true, width: 15, elapsedSinceFrame: 1)
                    let rendered = delta * p.geometry * 180 / .pi
                    precondition(rendered <= previous + 1e-9 && rendered >= distance - 1e-9, "Opening must follow the continuous spring away from the edge")
                    previous = rendered
                    if frame > hz / 4 {
                        oldValues.append(min(delta * 180 / .pi, distance))
                        newValues.append(rendered)
                    }
                }
                func accelerationEnergy(_ values: [Double]) -> Double {
                    (2..<values.count).reduce(0) { sum, i in
                        let acceleration = values[i] - 2 * values[i-1] + values[i-2]
                        return sum + acceleration * acceleration
                    }
                }
                let ratio = accelerationEnergy(newValues) / accelerationEnergy(oldValues)
                precondition(ratio < 0.25, "Display interpolation must reduce sample-step acceleration: \(ratio)")
            }
        }
        // Preserve the closing curve when the eased hinge trails the raw sample.
        for i in 1...1000 {
            let degrees = Double(i) / 20
            let p = OverlayHandoff.presentation(delta: degrees * .pi / 180, rawDistance: degrees + 2,
                angleMode: true, width: 15, elapsedSinceFrame: 1)
            let weight = OverlayHandoff.smoothstep(degrees / 15)
            XCTAssertEqual(p.geometry, weight * weight)
        }
        // The handoff continues between samples, but always disappears at the
        // actual ceiling. Include the narrowest span and a fast opening trace.
        var worstDisplacement = 0.0
        for hz in [60, 120] {
            for speed in [15.0, 45, 90, 180] {
                for width in [8.0, 15, 22] {
                    var fold = FoldSpring(), envelope = HandoffSmoothing()
                    fold.reset(to: 60 * .pi / 180)
                    var previous = 60.0
                    for frame in 0...Int(61 / speed * Double(hz)) {
                        let distance = max(0, (60 - Double(frame) / Double(hz) * speed).rounded())
                        let delta = fold.advance(to: distance * .pi / 180, elapsed: 1 / Double(hz), response: 0.12)
                        let boundary = envelope.advance(distance: distance, elapsed: 1 / Double(hz), response: 0.12, width: width)
                        let p = OverlayHandoff.presentation(delta: delta, rawDistance: boundary,
                            angleMode: true, width: width, elapsedSinceFrame: 1)
                        let rendered = delta * p.geometry * 180 / .pi
                        precondition(rendered.isFinite && rendered <= previous + 1e-9 && p.opacity >= 0 && p.opacity <= 1)
                        if distance == 0 {
                            XCTAssertEqual(rendered, 0); XCTAssertEqual(p.opacity, 0)
                            if speed <= 90 { worstDisplacement = max(worstDisplacement, previous) }

                            break
                        }
                        previous = rendered
                    }
                }
            }
        }
        precondition(worstDisplacement < 0.06, "Flatten before removing the overlay even at the narrowest handoff")
        // A fresh stream starts aligned, never easing from an old lid position.
        var envelope = HandoffSmoothing()
        _ = envelope.advance(distance: 70, elapsed: 1/120, response: 0.12)
        envelope.reset()
        XCTAssertEqual(envelope.advance(distance: 5, elapsed: 1/120, response: 0.12), 5)
        XCTAssertEqual(envelope.advance(distance: -1, elapsed: 1/120, response: 0.12), 0)
        XCTAssertEqual(envelope.advance(distance: .nan, elapsed: 1/120, response: 0.12), 0)
        print("PASS: opening interpolation at 60/120 Hz, quantized samples, all responses, ceiling and wake resets; largest pre-cutoff displacement through 90°/s: \(worstDisplacement)°")
    }
}
