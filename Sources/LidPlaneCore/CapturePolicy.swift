// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Capture only near activation. Hysteresis and a grace interval avoid restarting
/// ScreenCaptureKit repeatedly when the lid hovers at the prewarm boundary.
public struct CapturePolicy {
    public private(set) var requested = false
    private var outsideSince: TimeInterval?
    public init() {}
    public mutating func reset() { requested = false; outsideSince = nil }
    public mutating func update(angle: Double, activation: Double, lead: Double,
                                angleMode: Bool, now: TimeInterval) -> Bool {
        guard angle.isFinite, activation.isFinite, lead.isFinite, now.isFinite else { reset(); return false }
        let start = activation + min(15, max(10, lead))
        if !angleMode || angle <= start {
            requested = true; outsideSince = nil
        } else if requested && angle > start + 3 {
            if outsideSince == nil { outsideSince = now }
            if now - outsideSince! >= 0.65 { reset() }
        } else { outsideSince = nil }
        return requested
    }
}

public enum FrameCadence {
    public static func framesPerSecond(requested: Int, displayMaximum: Int, conserveEnergy: Bool) -> Int {
        min(conserveEnergy ? 60 : 120, max(1, displayMaximum), requested == 120 ? 120 : 60)
    }
}
