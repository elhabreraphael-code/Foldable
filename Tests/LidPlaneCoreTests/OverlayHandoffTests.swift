// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import LidPlaneCore

enum OverlayHandoffTests {
    static func run() {
        for distance in [-30.0, -0.01, 0] {
            XCTAssertEqual(OverlayHandoff.boundaryWeight(distanceDegrees: distance, angleMode: true), 0)
        }
        XCTAssertEqual(OverlayHandoff.boundaryWeight(distanceDegrees: 10, angleMode: true), 1)
        XCTAssertEqual(OverlayHandoff.boundaryWeight(distanceDegrees: -20, angleMode: false), 1)
        XCTAssertEqual(OverlayHandoff.opacity(delta: 0, boundary: 1, elapsedSinceFrame: 1), 0)
        XCTAssertEqual(OverlayHandoff.opacity(delta: 0.7, boundary: 1, elapsedSinceFrame: 0), 0)
        XCTAssertEqual(OverlayHandoff.opacity(delta: 0.7, boundary: 1, elapsedSinceFrame: 0.12), 1)
        XCTAssertEqual(OverlayHandoff.opacity(delta: .nan, boundary: 1, elapsedSinceFrame: 1), 0)
        // Slow opening and reversal must meet the real desktop at exactly zero.
        var previous = 1.0
        for i in (0...100).reversed() {
            let distance = Double(i) / 10
            let boundary = OverlayHandoff.boundaryWeight(distanceDegrees: distance, angleMode: true)
            let opacity = OverlayHandoff.opacity(delta: 0.1, boundary: boundary, elapsedSinceFrame: 1)
            precondition(opacity <= previous && opacity >= 0)
            previous = opacity
        }
        XCTAssertEqual(previous, 0)
        // Even with lagging geometry and a jitter filter, the raw boundary wins.
        let atEdge = OverlayHandoff.boundaryWeight(distanceDegrees: 0.1, angleMode: true)
        precondition(OverlayHandoff.opacity(delta: 0.5, boundary: atEdge, elapsedSinceFrame: 1) < 0.001)
        for hz in [60, 120] {
            let frames = Int(0.12 * Double(hz)) + 1
            XCTAssertEqual(OverlayHandoff.opacity(delta: 0.7, boundary: 1, elapsedSinceFrame: Double(frames) / Double(hz)), 1)
        }
        var resume = ResumeAlignment()
        precondition(resume.takeDelta(angle: 60, reference: 90, fresh: true) == nil)
        resume.suspend()
        precondition(resume.takeDelta(angle: 60, reference: 90, fresh: false) == nil)
        precondition(resume.pending)
        precondition(resume.takeDelta(angle: .nan, reference: 90, fresh: true) == nil)
        XCTAssertEqual(resume.takeDelta(angle: 60, reference: 90, fresh: true)!, .pi / 6)
        precondition(!resume.pending)
        precondition(resume.takeDelta(angle: 70, reference: 90, fresh: true) == nil)
        resume.suspend(); resume.cancel()
        precondition(!resume.pending)
        print("PASS: transparent boundary with lag/jitter, smooth reversible handoff, refresh-independent arrival, and fresh-frame wake alignment")
    }
}
