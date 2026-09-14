// Foldable additions; SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public struct ShortcutConfiguration: Codable, Equatable {
    public let keyCode: UInt32
    /// Portable flags: control=1, option=2, shift=4, command=8.
    public let modifiers: UInt32
    public init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }
    public static let `default` = Self(keyCode: 37, modifiers: 9)
    public static let suggestions = [Self.default, Self(keyCode: 3, modifiers: 3), Self(keyCode: 40, modifiers: 9)]
    public static let keys: [UInt32: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",25:"9",26:"7",28:"8",29:"0",31:"O",32:"U",34:"I",35:"P",37:"L",38:"J",40:"K",45:"N",46:"M",49:"Space"]
    public var validationError: String? {
        guard Self.keys[keyCode] != nil else { return "Choose a letter, number, or Space with at least two modifier keys." }
        guard modifiers & ~15 == 0, modifiers.nonzeroBitCount >= 2 else { return "Use at least two of Control, Option, Shift, and Command." }
        if ([20, 21, 23].contains(keyCode) && [12, 13].contains(modifiers)) || (keyCode == 12 && [9, 12, 14].contains(modifiers)) || (keyCode == 49 && modifiers == 10) {
            return "That combination is reserved for a macOS system action. Try a recommended shortcut."
        }
        return nil
    }
    public var label: String {
        [(UInt32(1), "⌃"), (2, "⌥"), (4, "⇧"), (8, "⌘")].filter { modifiers & $0.0 != 0 }.map { $0.1 }.joined() + (Self.keys[keyCode] ?? "?")
    }
}

public enum FoldStyle: Int, CaseIterable, Identifiable {
    case classic = 0, origami = 1
    public var id: Int { rawValue }
    public var title: String { self == .classic ? "V1 · Classic" : "V2 · Origami (Beta)" }
}
