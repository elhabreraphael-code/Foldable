// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later
import Carbon
import AppKit
import LidPlaneCore

/// Registers the toggle chord only. Never observes global keyboard input.
final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private static let signature: OSType = 0x4C504C4E
    private(set) var configuration: ShortcutConfiguration
    var isRegistered: Bool { hotKey != nil }

    init(configuration: ShortcutConfiguration = .default, action: @escaping () -> Void) throws {
        self.configuration = configuration; self.action = action
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == GlobalShortcut.signature, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue().action()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else { throw Self.error(result, configuration) }
        do { try replace(with: configuration) }
        catch { if let handler { RemoveEventHandler(handler) }; handler = nil; throw error }
    }
    func replace(with candidate: ShortcutConfiguration) throws {
        if let message = candidate.validationError {
            throw NSError(domain: "Foldable.Shortcut", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        if candidate == configuration, hotKey != nil { return }
        var replacement: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let result = RegisterEventHotKey(candidate.keyCode, candidate.carbonModifiers, identifier, GetApplicationEventTarget(), 0, &replacement)
        guard result == noErr else { throw Self.error(result, candidate) }
        // Keep the working chord if registration fails; save only after success.
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = replacement; configuration = candidate
    }
    func pauseRegistration() { if let hotKey { UnregisterEventHotKey(hotKey) }; hotKey = nil }
    func resumeRegistration() throws { try replace(with: configuration) }
    static func dispatchTestEvent() -> OSStatus {
        var event: EventRef?
        let created = CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, EventAttributes(kEventAttributeUserEvent), &event)
        guard created == noErr, let event else { return created }
        defer { ReleaseEvent(event) }
        var identifier = EventHotKeyID(signature: signature, id: 1)
        let parameter = SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &identifier)
        guard parameter == noErr else { return parameter }
        return SendEventToEventTarget(event, GetApplicationEventTarget())
    }
    private static func error(_ status: OSStatus, _ chord: ShortcutConfiguration) -> NSError {
        NSError(domain: "Foldable.Shortcut", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not register \(chord.label) (\(status)). It may be used by macOS or another app. Your previous shortcut is preserved; try another combination."])
    }
    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}

extension ShortcutConfiguration {
    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers & 1 != 0 { value |= UInt32(controlKey) }
        if modifiers & 2 != 0 { value |= UInt32(optionKey) }
        if modifiers & 4 != 0 { value |= UInt32(shiftKey) }
        if modifiers & 8 != 0 { value |= UInt32(cmdKey) }
        return value
    }
    var eventModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & 1 != 0 { flags.insert(.control) }
        if modifiers & 2 != 0 { flags.insert(.option) }
        if modifiers & 4 != 0 { flags.insert(.shift) }
        if modifiers & 8 != 0 { flags.insert(.command) }
        return flags
    }
    init(event: NSEvent) {
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.control) { modifiers |= 1 }
        if event.modifierFlags.contains(.option) { modifiers |= 2 }
        if event.modifierFlags.contains(.shift) { modifiers |= 4 }
        if event.modifierFlags.contains(.command) { modifiers |= 8 }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }
}
