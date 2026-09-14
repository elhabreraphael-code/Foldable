// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import LidPlaneCore

// Runs with Command Line Tools; does not require the Xcode-only XCTest framework.
func XCTAssertEqual(_ actual: Double, _ expected: Double, accuracy: Double = 0.000001, file: StaticString = #file, line: UInt = #line) {
    precondition(abs(actual-expected) <= accuracy, "Expected \(expected), got \(actual)", file: file, line: line)
}

@main struct AutoAnchorTests {
    static func main() {
        let checks = AutoAnchorTests()
        checks.testWaitsForPauseThenEasesToNewAngle()
        checks.testMovementInterruptsSettling()
        checks.testSlowCumulativeMovementRestartsDebounce()
        checks.testSmallSensorJitterDoesNotPreventSettling()
        checks.testDisabledModeHoldsReferenceAndManualAnchorResets()
        MotionPolicyTests.run()
        MotionSmoothingTests.run()
        OverlayHandoffTests.run()
        CapturePolicyTests.run()
        FoldSpringTests.run()
        FinalBuildTests.run()
        OpeningMotionTests.run()
        print("PASS: all five debounce, jitter, interruption and manual-anchor checks")
    }
    func testWaitsForPauseThenEasesToNewAngle() {
        var state = AutoAnchor(angle: 110, now: 0)
        XCTAssertEqual(state.delay, 0.15)
        XCTAssertEqual(state.duration, 0.2)
        state.update(angle: 80, now: 0.1, enabled: true)
        state.update(angle: 80, now: 0.24, enabled: true)
        XCTAssertEqual(state.reference, 110)
        state.update(angle: 80, now: 0.251, enabled: true)
        state.update(angle: 80, now: 0.351, enabled: true)
        XCTAssertEqual(state.reference, 95, accuracy: 0.01)
        state.update(angle: 80, now: 0.46, enabled: true)
        XCTAssertEqual(state.reference, 80)
    }

    func testMovementInterruptsSettling() {
        var state = AutoAnchor(angle: 110, now: 0)
        state.update(angle: 80, now: 0.1, enabled: true)
        state.update(angle: 80, now: 0.251, enabled: true)
        state.update(angle: 80, now: 0.301, enabled: true)
        let reference = state.reference
        state.update(angle: 70, now: 0.32, enabled: true)
        state.update(angle: 70, now: 0.46, enabled: true)
        XCTAssertEqual(state.reference, reference)
    }

    func testSlowCumulativeMovementRestartsDebounce() {
        var state = AutoAnchor(angle: 110, now: 0)
        for i in 1...10 { state.update(angle: 110 - Double(i), now: Double(i) * 0.3, enabled: true) }
        XCTAssertEqual(state.reference, 110)
    }

    func testSmallSensorJitterDoesNotPreventSettling() {
        var state = AutoAnchor(angle: 110, now: 0)
        state.update(angle: 80, now: 0.1, enabled: true)
        for i in 2...20 { state.update(angle: 80 + (i.isMultiple(of: 2) ? 0.3 : -0.3), now: Double(i) * 0.1, enabled: true) }
        XCTAssertEqual(state.reference, 80, accuracy: 0.4)
    }

    func testDisabledModeHoldsReferenceAndManualAnchorResets() {
        var state = AutoAnchor(angle: 110, now: 0)
        state.update(angle: 70, now: 1, enabled: false)
        state.update(angle: 70, now: 10, enabled: false)
        XCTAssertEqual(state.reference, 110)
        state.anchor(at: 70, now: 11)
        state.update(angle: 60, now: 11.1, enabled: true)
        XCTAssertEqual(state.reference, 70)
    }
}
