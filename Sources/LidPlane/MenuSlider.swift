// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// A small native slider inside the existing menu; no settings window or focus grab.
final class MenuSlider: NSView {
    let slider: NSSlider
    private let label = NSTextField(labelWithString: "")
    private let title: String
    private let step: Double
    private let onChange: (Double) -> Void

    init(title: String, value: Double, range: ClosedRange<Double>, step: Double, enabled: Bool = true, onChange: @escaping (Double) -> Void) {
        self.title = title; self.step = step; self.onChange = onChange
        slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: 270, height: 60))
        label.frame = NSRect(x: 16, y: 34, width: 240, height: 18)
        label.font = .systemFont(ofSize: 12)
        label.textColor = enabled ? .labelColor : .disabledControlTextColor
        slider.frame = NSRect(x: 16, y: 8, width: 238, height: 22)
        slider.isContinuous = true; slider.isEnabled = enabled
        slider.target = self; slider.action = #selector(changed)
        slider.setAccessibilityLabel(title)
        addSubview(label); addSubview(slider); updateLabel()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func changed() {
        slider.doubleValue = (slider.doubleValue / step).rounded() * step
        updateLabel(); onChange(slider.doubleValue)
    }
    private func updateLabel() {
        label.stringValue = "\(title): \(slider.doubleValue.formatted(.number.precision(.fractionLength(0...1))))°"
    }
}
