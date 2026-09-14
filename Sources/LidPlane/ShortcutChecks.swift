// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Carbon
import LidPlaneCore

enum ShortcutChecks {
    static func run() throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "Foldable.ShortcutChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let initial = ShortcutConfiguration(keyCode: 6, modifiers: 15)
        let replacement = ShortcutConfiguration(keyCode: 7, modifiers: 15)
        var calls = 0
        let shortcut = try GlobalShortcut(configuration: initial) { calls += 1 }
        try require(GlobalShortcut.dispatchTestEvent() == noErr && calls == 1, "Custom shortcut dispatch failed")
        var reserved: EventHotKeyRef?
        defer { if let reserved { UnregisterEventHotKey(reserved) } }
        let reservation = RegisterEventHotKey(replacement.keyCode, replacement.carbonModifiers,
            EventHotKeyID(signature: 0x54455354, id: 99), GetApplicationEventTarget(), 0, &reserved)
        try require(reservation == noErr, "Could not reserve conflict-test chord")
        do { try shortcut.replace(with: replacement); throw NSError(domain: "Foldable.ShortcutChecks", code: 2) }
        catch { try require(shortcut.configuration == initial && shortcut.isRegistered, "Conflict lost working shortcut") }
        if let reserved { UnregisterEventHotKey(reserved) }; reserved = nil
        try shortcut.replace(with: replacement)
        try require(GlobalShortcut.dispatchTestEvent() == noErr && calls == 2, "Replacement dispatch failed")
        shortcut.pauseRegistration(); try require(!shortcut.isRegistered, "Recording must suspend toggle")
        try shortcut.resumeRegistration(); try require(shortcut.isRegistered, "Recording cancellation must restore toggle")
        try require(GlobalShortcut.dispatchTestEvent() == noErr && calls == 3, "Restored dispatch failed")
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 250, height: 80), styleMask: [.titled], backing: .buffered, defer: false)
        let recorder = ShortcutRecordingView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
        window.contentView = recorder
        var states: [Bool] = []; var recorded: ShortcutConfiguration?
        recorder.onRecording = { states.append($0) }; recorder.onChange = { recorded = $0 }
        recorder.begin()
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.control, .command], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "l", charactersIgnoringModifiers: "l", isARepeat: false, keyCode: 37)!
        recorder.keyDown(with: event)
        try require(recorded == .default && states == [true, false], "Focused recorder did not capture and finish")
        recorder.begin()
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
        try require(!recorder.recording && states.suffix(2) == [true, false], "Leaving settings must cancel recording")
        print("PASS: custom hotkey dispatch/replacement, conflict rollback, recorder capture and focus cancellation")
    }
}
