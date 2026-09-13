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
