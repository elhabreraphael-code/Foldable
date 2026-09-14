// Fold additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Time-based easing, independent of whether a display refreshes at 60 or 120 Hz.
public enum MotionSmoothing {
    public static func advance(_ value: Double, to target: Double, elapsed: Double, response: Double) -> Double {
        guard value.isFinite, target.isFinite, elapsed.isFinite, response.isFinite else { return value.isFinite ? value : 0 }
        let dt = min(0.05, max(0, elapsed))
        let tau = min(0.12, max(0.02, response))
        return value + (target - value) * (1 - exp(-dt / tau))
    }
}

/// Analytic critically damped motion. Velocity survives target changes, so each
/// sensor sample does not restart the animation. No oscillation at the target.
public struct FoldSpring {
    public private(set) var value: Double = 0
    public private(set) var velocity: Double = 0
    public init() {}
    public mutating func reset(to value: Double = 0) {
        self.value = value.isFinite ? value : 0; velocity = 0
    }
    @discardableResult
    public mutating func advance(to target: Double, elapsed: Double, response: Double) -> Double {
        guard target.isFinite, elapsed.isFinite, response.isFinite, elapsed > 0 else { return value }
        let dt = min(0.05, elapsed)
        let omega = 2 / min(0.12, max(0.02, response))
        let offset = value - target
        let term = velocity + omega * offset
        let decay = exp(-omega * dt)
        let next = target + (offset + term * dt) * decay
        let nextVelocity = (velocity - omega * term * dt) * decay
        if (offset > 0 && next < target) || (offset < 0 && next > target) || abs(next - target) < 0.000001 {
            value = target; velocity = 0
        } else { value = next; velocity = nextVelocity }
        return value
    }
    public func isSettled(at target: Double) -> Bool {
        abs(value - target) < 0.00001 && abs(velocity) < 0.0001
    }
}
