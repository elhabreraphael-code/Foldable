// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI
import LidPlaneCore

/// Only the focused settings control receives key events. No input monitor,
/// Accessibility grant, or keystroke collection outside this app is involved.
final class ShortcutRecordingView: NSView {
    private let button = NSButton(title: "Record shortcut…", target: nil, action: nil)
    private(set) var recording = false
    private var resignObserver: NSObjectProtocol?
    var onChange: (ShortcutConfiguration) -> Void = { _ in }
    var onRecording: (Bool) -> Void = { _ in }
    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 185, height: 30) }
    override init(frame: NSRect) {
        super.init(frame: frame)
        button.bezelStyle = .rounded; button.target = self; button.action = #selector(begin)
        button.setAccessibilityLabel("Record a new toggle shortcut")
        addSubview(button)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() { super.layout(); button.frame = bounds }
    @objc func begin() {
        guard window?.makeFirstResponder(self) == true else { return }
        recording = true; button.title = "Press keys · Esc cancels"; onRecording(true)
    }
    func finish() {
        guard recording else { return }
        recording = false; button.title = "Record shortcut…"; onRecording(false)
    }
    override func resignFirstResponder() -> Bool { finish(); return super.resignFirstResponder() }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        guard let window else { finish(); return }
        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in self?.finish() }
    }
    deinit { if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) } }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { finish(); return }
        if event.keyCode == 48 { finish(); window?.selectNextKeyView(nil); return }
        guard !event.isARepeat else { return }
        let chord = ShortcutConfiguration(event: event)
        finish(); onChange(chord)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording, window?.isKeyWindow == true else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event); return true
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    let onChange: (ShortcutConfiguration) -> Void
    let onRecording: (Bool) -> Void
    func makeNSView(context: Context) -> ShortcutRecordingView { ShortcutRecordingView(frame: .zero) }
    func updateNSView(_ view: ShortcutRecordingView, context: Context) { view.onChange = onChange; view.onRecording = onRecording }
    static func dismantleNSView(_ view: ShortcutRecordingView, coordinator: ()) { view.finish() }
}
