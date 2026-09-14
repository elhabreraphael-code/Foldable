// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import LidPlaneCore

enum FoldSpringTests {
    static func run() {
        func simulate(hz: Int, duration: Double) -> Double {
            var spring = FoldSpring()
            for _ in 0..<Int(Double(hz) * duration) { spring.advance(to: 1, elapsed: 1 / Double(hz), response: 0.12) }
            return spring.value
        }
        XCTAssertEqual(simulate(hz: 60, duration: 0.1), simulate(hz: 120, duration: 0.1), accuracy: 0.0000001)
        XCTAssertEqual(simulate(hz: 60, duration: 1), simulate(hz: 120, duration: 1), accuracy: 0.000001)
        for hz in [30, 60, 120] {
            var spring = FoldSpring()
            var previous = 0.0
            for _ in 0..<(hz * 2) {
                let value = spring.advance(to: 1, elapsed: 1 / Double(hz), response: 0.075)
                precondition(value >= previous && value <= 1, "Step must not ring")
                previous = value
            }
            precondition(spring.isSettled(at: 1))
            for _ in 0..<(hz * 2) {
                let value = spring.advance(to: 0, elapsed: 1 / Double(hz), response: 0.075)
                precondition(value <= previous && value >= 0, "Opening must not overshoot zero")
                previous = value
            }
            precondition(spring.isSettled(at: 0))
            // Realistic close/open/close trace, including reversal before settling.
            for i in 0..<(hz * 4) {
                let target = 0.5 + 0.5 * sin(Double(i) / Double(hz) * 4)
                spring.advance(to: target, elapsed: 1 / Double(hz), response: 0.045)
                precondition(spring.value.isFinite && spring.value >= 0 && spring.value <= 1)
                let distance = target * 180 / Double.pi
                let weight = OverlayHandoff.presentationBoundary(delta: spring.value, rawDistance: distance, angleMode: true, width: 15)
                precondition(weight >= 0 && weight <= 1)
                XCTAssertEqual(OverlayHandoff.presentationBoundary(delta: spring.value, rawDistance: -0.01, angleMode: true, width: 15), 0)
            }
        }
        var spring = FoldSpring()
        spring.advance(to: 1, elapsed: 0.02, response: 0.12)
        let velocity = spring.velocity
        spring.advance(to: 0, elapsed: 0.000001, response: 0.12)
        precondition(abs(spring.velocity - velocity) < 0.001, "A reversal preserves velocity continuity")
        let value = spring.value
        XCTAssertEqual(spring.advance(to: .nan, elapsed: 0.02, response: 0.04), value)
        XCTAssertEqual(spring.advance(to: 1, elapsed: -1, response: 0.04), value)
        spring.reset(to: 0.75)
        XCTAssertEqual(spring.value, 0.75); XCTAssertEqual(spring.velocity, 0)
        spring.reset(to: .nan); XCTAssertEqual(spring.value, 0)
        precondition(spring.advance(to: 1, elapsed: 100, response: 0.12) < 0.3)
        // Endpoint velocity AND acceleration vanish for the quintic handoff.
        let epsilon = 0.0001
        precondition(OverlayHandoff.smoothstep(epsilon) / (epsilon * epsilon) < 0.002)
        precondition((1 - OverlayHandoff.smoothstep(1 - epsilon)) / (epsilon * epsilon) < 0.002)
        for width in [8.0, 15, 22] {
            XCTAssertEqual(OverlayHandoff.boundaryWeight(distanceDegrees: width, angleMode: true, width: width), 1)
            XCTAssertEqual(OverlayHandoff.boundaryWeight(distanceDegrees: 0, angleMode: true, width: width), 0)
        }
        XCTAssertEqual(OverlayHandoff.opacity(delta: 1, boundary: .nan, elapsedSinceFrame: 1), 0)
        print("PASS: analytic spring cadence, continuous reversals, no ringing, stalls, invalid input, quintic endpoints and raw-ceiling safety")
    }
}
