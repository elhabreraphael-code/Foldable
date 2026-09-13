// Fold additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import LidPlaneCore

enum MotionSmoothingTests {
    static func run() {
        func simulate(hz: Int) -> Double {
            var value = 0.0
            for _ in 0..<hz { value = MotionSmoothing.advance(value, to: 1, elapsed: 1 / Double(hz), response: 0.12) }
            return value
        }
        XCTAssertEqual(simulate(hz: 60), simulate(hz: 120), accuracy: 0.000001)
        var value = 0.0
        for _ in 0..<120 {
            let next = MotionSmoothing.advance(value, to: 1, elapsed: 1.0/120, response: 0.045)
            precondition(next >= value && next <= 1, "Closing must not overshoot")
            value = next
        }
        for _ in 0..<120 {
            let next = MotionSmoothing.advance(value, to: 0, elapsed: 1.0/120, response: 0.045)
            precondition(next <= value && next >= 0, "Reopening must not overshoot")
            value = next
        }
        XCTAssertEqual(value, 0, accuracy: 0.000001)
        XCTAssertEqual(MotionSmoothing.advance(0.2, to: .nan, elapsed: 0.01, response: 0.04), 0.2)
        XCTAssertEqual(MotionSmoothing.advance(0.2, to: 1, elapsed: -1, response: 0.04), 0.2)
        precondition(MotionSmoothing.advance(0, to: 1, elapsed: 20, response: 0.12) < 0.4, "Resume must not jump after a stall")
        print("PASS: 60/120 Hz equivalence, reversible easing, no overshoot, invalid input and stall recovery")
    }
}
