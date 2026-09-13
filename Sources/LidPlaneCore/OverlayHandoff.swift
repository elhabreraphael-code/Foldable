// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Fade and flatten before the raw activation ceiling, so removing the panel
/// reveals the already-visible desktop instead of cutting off a lagging fold.
public enum OverlayHandoff {
    public static func smoothstep(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        let x = min(1, max(0, value))
        return x * x * (3 - 2 * x)
    }
    public static func boundaryWeight(distanceDegrees: Double, angleMode: Bool) -> Double {
        angleMode ? smoothstep(distanceDegrees / 10) : 1
    }
    public static func opacity(delta: Double, boundary: Double, elapsedSinceFrame: Double) -> Double {
        guard delta.isFinite else { return 0 }
        return smoothstep(abs(delta) / (3 * .pi / 180))
            * min(1, max(0, boundary)) * smoothstep(elapsedSinceFrame / 0.12)
    }
}

/// A restarted stream must begin from a new sensor sample and a new desktop frame.
/// Never carry a pre-sleep image or eased angle into the unlocked desktop.
public struct ResumeAlignment {
    public private(set) var pending = false
    public init() {}
    public mutating func suspend() { pending = true }
    public mutating func cancel() { pending = false }
    public mutating func takeDelta(angle: Double, reference: Double, fresh: Bool) -> Double? {
        guard pending, fresh, angle.isFinite, reference.isFinite else { return nil }
        pending = false
        return (reference - angle) * .pi / 180
    }
}
