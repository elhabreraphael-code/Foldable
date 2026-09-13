// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import Carbon
import Foundation

/// Registers one chord with the system, without observing other keystrokes.
final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private static let signature: OSType = 0x4C504C4E

    init(action: @escaping () -> Void) throws {
        self.action = action
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
        guard result == noErr else { throw Self.error(result) }
        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let registration = RegisterEventHotKey(UInt32(kVK_ANSI_L), UInt32(controlKey | cmdKey), identifier, GetApplicationEventTarget(), 0, &hotKey)
        guard registration == noErr else {
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            throw Self.error(registration)
        }
    }

    /// Exercises event dispatch without generating input in another app.
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

    private static func error(_ status: OSStatus) -> NSError {
        NSError(domain: "LidPlane.Shortcut", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not register Control–Command–L (\(status)). Another app may already use it."])
    }
    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
