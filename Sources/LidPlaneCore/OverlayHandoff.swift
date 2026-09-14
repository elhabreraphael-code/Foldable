// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Fade and flatten before the raw activation ceiling, so removing the panel
/// reveals the already-visible desktop instead of cutting off a lagging fold.
public enum OverlayHandoff {
    public static func smoothstep(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        let x = min(1, max(0, value))
        // Quintic: both velocity and acceleration reach zero at either edge.
        return min(1, max(0, x * x * x * (x * (x * 6 - 15) + 10)))
    }
    public static func boundaryWeight(distanceDegrees: Double, angleMode: Bool, width: Double = 10) -> Double {
        guard distanceDegrees.isFinite, width.isFinite else { return 0 }
        return angleMode ? smoothstep(distanceDegrees / max(1, width)) : 1
    }
    /// The smoothed fold drives the transition at display cadence. The raw
    /// envelope remains a hard upper bound so lag/jitter cannot cross the ceiling.
    public static func presentationBoundary(delta: Double, rawDistance: Double, angleMode: Bool, width: Double) -> Double {
        guard delta.isFinite else { return 0 }
        return min(boundaryWeight(distanceDegrees: delta * 180 / .pi, angleMode: angleMode, width: width),
                   boundaryWeight(distanceDegrees: rawDistance, angleMode: angleMode, width: width))
    }

    public struct Presentation {
        public let geometry: Double
        public let opacity: Double
    }
    /// Flatten first, dissolve last: avoid mixing visibly displaced desktop text.
    /// A boundary envelope limits deformation near the ceiling. Away from the
    /// handoff, preserve the spring: capping displacement to the raw angle would
    /// cancel its interpolation on every opening sample.
    public static func presentation(delta: Double, rawDistance: Double, angleMode: Bool,
                                    width: Double, elapsedSinceFrame: Double) -> Presentation {
        guard delta.isFinite, rawDistance.isFinite, width.isFinite, elapsedSinceFrame.isFinite else {
            return Presentation(geometry: 0, opacity: 0)
        }
        if !angleMode {
            return Presentation(geometry: 1, opacity: opacity(delta: delta, boundary: 1, elapsedSinceFrame: elapsedSinceFrame))
        }
        let degrees = max(0, delta * 180 / .pi)
        let distance = max(0, min(degrees, rawDistance))
        let span = max(1, width)
        let weight = smoothstep(distance / span)
        // Release the distance cap continuously outside the handoff. Closing
        // already has distance == degrees, so its established curve is unchanged.
        let ratio = degrees > 0 ? distance / degrees : 0
        let geometricCap = ratio + (1 - ratio) * weight
        return Presentation(geometry: weight * weight * geometricCap,
            opacity: smoothstep(distance / (span * 0.35)) * smoothstep(elapsedSinceFrame / 0.16))
    }

    public static func opacity(delta: Double, boundary: Double, elapsedSinceFrame: Double) -> Double {
        guard delta.isFinite, boundary.isFinite, elapsedSinceFrame.isFinite else { return 0 }
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

/// Reconstruct the handoff envelope between whole-degree HID samples. The main
/// fold keeps the user's response; this short boundary response prevents a long
/// smoothing preference from delaying the final flatten/dissolve. The actual
/// raw ceiling remains an independent, immediate visibility guard in the app.
public struct HandoffSmoothing {
    private var spring = FoldSpring()
    private var initialized = false
    public init() {}
    public mutating func reset() { spring.reset(); initialized = false }
    public mutating func advance(distance: Double, elapsed: Double, response: Double, width: Double = 15) -> Double {
        guard distance.isFinite, width.isFinite else { reset(); return 0 }
        if !initialized {
            spring.reset(to: max(0, distance)); initialized = true
        }
        // At/beyond the ceiling discard history, including any pre-sleep state.
        guard distance > 0 else { spring.reset(); return 0 }
        let filtered = max(0, spring.advance(to: distance, elapsed: elapsed, response: min(0.03, response)))
        // Release filtering latency only after the geometry is nearly flat.
        // The quintic has zero slope/curvature at the ceiling: fast openings
        // cannot carry a delayed, visibly warped frame into the hard cutoff.
        let blend = OverlayHandoff.smoothstep(distance / max(1, width))
        return distance + (filtered - distance) * blend
    }
    public func isSettled(at distance: Double) -> Bool { spring.isSettled(at: max(0, distance)) }
}
