//
//  KeyBindings.swift
//  Global Thermal Nuclear War
//
//  3.33.0: remappable gameplay shortcuts (macOS). The menu commands read their key from `KeyBindingStore`; the
//  player changes them in Settings → Keys, and Reset puts back the defaults (the shortcuts the game always had).
//  Stored as JSON in UserDefaults; under XCTest a throwaway suite, never the real defaults.
//

import SwiftUI

/// A gameplay command that has a keyboard shortcut.
enum GameShortcut: String, CaseIterable, Identifiable, Codable {
    case newGame, aiSettings, toggleSkin, commandBox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newGame: return "New Game"
        case .aiSettings: return "AI Backend Settings"
        case .toggleSkin: return "Switch Skin (Retro / Modern)"
        case .commandBox: return "Command Box"
        }
    }

    /// Today's shortcuts: ⌘N, ⌥⌘A, ⇧⌘R, and the command box's ⌘K (3.34.0).
    var defaultBinding: KeyBinding {
        switch self {
        case .newGame: return KeyBinding(key: "n", command: true)
        case .aiSettings: return KeyBinding(key: "a", command: true, option: true)
        case .toggleSkin: return KeyBinding(key: "r", command: true, shift: true)
        case .commandBox: return KeyBinding(key: "k", command: true)
        }
    }
}

/// One key plus modifiers. `key` is a single lowercase letter or digit.
struct KeyBinding: Codable, Equatable, Hashable {
    var key: String
    var command = false
    var option = false
    var shift = false
    var control = false

    var modifiers: EventModifiers {
        var m: EventModifiers = []
        if command { m.insert(.command) }
        if option { m.insert(.option) }
        if shift { m.insert(.shift) }
        if control { m.insert(.control) }
        return m
    }

    var shortcut: KeyboardShortcut? {
        guard let c = key.first, key.count == 1 else { return nil }
        return KeyboardShortcut(KeyEquivalent(c), modifiers: modifiers)
    }

    /// Menu-style text in Apple's modifier order, e.g. "⌥⌘A".
    var display: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + key.uppercased()
    }

    /// What VoiceOver says, e.g. "Option Command A".
    var spoken: String {
        ([control ? "Control" : nil, option ? "Option" : nil, shift ? "Shift" : nil, command ? "Command" : nil]
            .compactMap { $0 } + [key.uppercased()]).joined(separator: " ")
    }
}

/// Why a binding was refused.
enum KeyBindingError: Error, Equatable {
    case invalidKey          // not exactly one letter or digit
    case needsModifier       // ⌘ or ⌃ is required, or typing in a text field would fire it
    case reserved            // a system or app shortcut (⌘Q, ⌘W, ⌘, …)
    case taken(GameShortcut) // another gameplay shortcut already uses it
}

final class KeyBindingStore: ObservableObject {
    static let defaultsKey = "GTNW.keyBindings"
    static let shared = KeyBindingStore(defaults: AudioGate.underXCTest
                                        ? UserDefaults(suiteName: "GTNW.tests.keys.\(UUID().uuidString)")! : .standard)

    /// System and standard app shortcuts a gameplay command may not take.
    static let reserved: Set<KeyBinding> = Set(["q", "w", "h", "m", ",", "c", "v", "x", "z", "a", "s", "o", "p", "f"]
        .map { KeyBinding(key: $0, command: true) }
        + [KeyBinding(key: "z", command: true, shift: true), KeyBinding(key: "f", command: true, control: true)])

    private let defaults: UserDefaults
    @Published private(set) var bindings: [GameShortcut: KeyBinding]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        var b = Dictionary(uniqueKeysWithValues: GameShortcut.allCases.map { ($0, $0.defaultBinding) })
        if let data = defaults.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([String: KeyBinding].self, from: data) {
            for (k, v) in saved {
                guard let s = GameShortcut(rawValue: k), Self.validate(v, for: s, in: b) == nil else { continue }
                b[s] = v
            }
        }
        bindings = b
    }

    func binding(for s: GameShortcut) -> KeyBinding { bindings[s] ?? s.defaultBinding }

    func shortcut(for s: GameShortcut) -> KeyboardShortcut? { binding(for: s).shortcut }

    /// Check a binding for `s` against the others in `current`. nil means it is acceptable.
    static func validate(_ b: KeyBinding, for s: GameShortcut, in current: [GameShortcut: KeyBinding]) -> KeyBindingError? {
        guard b.key.count == 1, let c = b.key.first, c.isASCII, c.isLetter || c.isNumber, b.key == b.key.lowercased() else {
            return .invalidKey
        }
        guard b.command || b.control else { return .needsModifier }
        if b != s.defaultBinding, reserved.contains(b) { return .reserved }
        if let other = current.first(where: { $0.key != s && $0.value == b })?.key { return .taken(other) }
        return nil
    }

    /// Change one shortcut. Throws `KeyBindingError` and changes nothing if it is refused.
    func set(_ b: KeyBinding, for s: GameShortcut) throws {
        var b = b
        b.key = b.key.lowercased()
        if let e = Self.validate(b, for: s, in: bindings) { throw e }
        bindings[s] = b
        save()
    }

    func reset(_ s: GameShortcut) {
        // Restoring a default can collide with a custom binding elsewhere; that one goes back to its default too.
        for (other, b) in bindings where other != s && b == s.defaultBinding { bindings[other] = other.defaultBinding }
        bindings[s] = s.defaultBinding
        save()
    }

    func resetAll() {
        bindings = Dictionary(uniqueKeysWithValues: GameShortcut.allCases.map { ($0, $0.defaultBinding) })
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    var isDefault: Bool { GameShortcut.allCases.allSatisfy { binding(for: $0) == $0.defaultBinding } }

    private func save() {
        let custom = Dictionary(uniqueKeysWithValues: bindings.filter { $0.value != $0.key.defaultBinding }.map { ($0.key.rawValue, $0.value) })
        if custom.isEmpty { defaults.removeObject(forKey: Self.defaultsKey); return }
        if let data = try? JSONEncoder().encode(custom) { defaults.set(data, forKey: Self.defaultsKey) }
    }
}

extension View {
    /// Attach a remappable gameplay shortcut (no shortcut if the stored one is unusable).
    @ViewBuilder
    func gameShortcut(_ s: GameShortcut, store: KeyBindingStore) -> some View {
        if let k = store.shortcut(for: s) { keyboardShortcut(k) } else { self }
    }
}

#if os(macOS)
/// Settings → Keys: each gameplay shortcut, editable, with Reset and Reset All.
struct KeyBindingsSettingsView: View {
    @ObservedObject var store: KeyBindingStore = .shared
    @State private var message: String?

    var body: some View {
        Form {
            Section("Gameplay shortcuts") {
                ForEach(GameShortcut.allCases) { s in row(s) }
                if let message {
                    Text(message).font(.scaled(.caption)).foregroundColor(.red)
                        .accessibilityLabel("Shortcut not changed: \(message)")
                }
                HStack {
                    Spacer()
                    Button("Reset All to Defaults") { store.resetAll(); message = nil }
                        .disabled(store.isDefault)
                        .accessibilityHint("Puts every gameplay shortcut back to the game's default")
                }
            }
            Text("A shortcut needs ⌘ or ⌃ and one letter or digit. System shortcuts (⌘Q, ⌘W, ⌘, …) cannot be taken.")
                .font(.scaled(.caption)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }

    private func row(_ s: GameShortcut) -> some View {
        let b = store.binding(for: s)
        return HStack(spacing: 8) {
            Text(s.title).frame(minWidth: FontScale.of(200), alignment: .leading)
            Text(b.display).font(.scaled(.body).monospaced()).frame(minWidth: FontScale.of(60))
                .accessibilityLabel("Current shortcut \(b.spoken)")
            TextField("Key", text: Binding(get: { b.key }, set: { new in
                guard let c = new.last else { return }
                apply(s) { $0.key = String(c).lowercased() }
            }))
            .frame(width: FontScale.of(36))
            .accessibilityLabel("\(s.title) key")
            Toggle("⌃", isOn: Binding(get: { b.control }, set: { v in apply(s) { $0.control = v } })).accessibilityLabel("Control")
            Toggle("⌥", isOn: Binding(get: { b.option }, set: { v in apply(s) { $0.option = v } })).accessibilityLabel("Option")
            Toggle("⇧", isOn: Binding(get: { b.shift }, set: { v in apply(s) { $0.shift = v } })).accessibilityLabel("Shift")
            Toggle("⌘", isOn: Binding(get: { b.command }, set: { v in apply(s) { $0.command = v } })).accessibilityLabel("Command")
            Button("Reset") { store.reset(s); message = nil }
                .disabled(b == s.defaultBinding)
                .accessibilityLabel("Reset \(s.title) to \(s.defaultBinding.spoken)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(s.title), \(b.spoken)")
    }

    private func apply(_ s: GameShortcut, _ change: (inout KeyBinding) -> Void) {
        var b = store.binding(for: s)
        change(&b)
        do { try store.set(b, for: s); message = nil } catch let e as KeyBindingError { message = Self.describe(e) } catch {}
    }

    static func describe(_ e: KeyBindingError) -> String {
        switch e {
        case .invalidKey: return "use one letter or digit"
        case .needsModifier: return "add ⌘ or ⌃"
        case .reserved: return "that is a system shortcut"
        case .taken(let other): return "already used by \(other.title)"
        }
    }
}
#endif
