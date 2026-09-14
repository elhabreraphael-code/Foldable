// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import LidPlaneCore

enum CapturePolicyTests {
    static func run() {
        for lead in [10.0, 12, 15] {
            var policy = CapturePolicy()
            precondition(!policy.update(angle: 150, activation: 110, lead: lead, angleMode: true, now: 0))
            precondition(!policy.update(angle: 110 + lead + 0.01, activation: 110, lead: lead, angleMode: true, now: 1))
            precondition(policy.update(angle: 110 + lead, activation: 110, lead: lead, angleMode: true, now: 2))
            precondition(policy.update(angle: 75, activation: 110, lead: lead, angleMode: true, now: 3))
            // Hover in the hysteresis band: no stream teardown/restart loop.
            for i in 0..<100 {
                precondition(policy.update(angle: 110 + lead + (i.isMultiple(of: 2) ? 1 : 2.9), activation: 110, lead: lead, angleMode: true, now: 4 + Double(i) / 10))
            }
            precondition(policy.update(angle: 160, activation: 110, lead: lead, angleMode: true, now: 20))
            precondition(policy.update(angle: 160, activation: 110, lead: lead, angleMode: true, now: 20.64))
            // Brief reopening then reversing cancels teardown.
            precondition(policy.update(angle: 100, activation: 110, lead: lead, angleMode: true, now: 20.65))
            precondition(policy.update(angle: 160, activation: 110, lead: lead, angleMode: true, now: 21))
            precondition(!policy.update(angle: 160, activation: 110, lead: lead, angleMode: true, now: 21.66))
            precondition(!policy.requested)
            precondition(policy.update(angle: 80, activation: 110, lead: lead, angleMode: true, now: 22))
            policy.reset()
            precondition(!policy.update(angle: 150, activation: 110, lead: lead, angleMode: true, now: 23))
        }
        var policy = CapturePolicy()
        precondition(policy.update(angle: 180, activation: 110, lead: 12, angleMode: false, now: 0))
        precondition(!policy.update(angle: .nan, activation: 110, lead: 12, angleMode: false, now: 1))
        // Changing the activation angle reevaluates the same policy immediately.
        precondition(policy.update(angle: 140, activation: 140, lead: 12, angleMode: true, now: 2))
        precondition(policy.update(angle: 140, activation: 90, lead: 12, angleMode: true, now: 3))
        precondition(!policy.update(angle: 140, activation: 90, lead: 12, angleMode: true, now: 4))
        precondition(FrameCadence.framesPerSecond(requested: 120, displayMaximum: 60, conserveEnergy: false) == 60)
        precondition(FrameCadence.framesPerSecond(requested: 120, displayMaximum: 120, conserveEnergy: false) == 120)
        precondition(FrameCadence.framesPerSecond(requested: 120, displayMaximum: 120, conserveEnergy: true) == 60)
        precondition(FrameCadence.framesPerSecond(requested: 0, displayMaximum: 120, conserveEnergy: false) == 60)
        precondition(FrameCadence.framesPerSecond(requested: 120, displayMaximum: 48, conserveEnergy: false) == 48)
        print("PASS: 10/12/15° prewarm, idle teardown, hysteresis, reversal, settings changes, invalid sensor and display/Low Power cadence")
    }
}
