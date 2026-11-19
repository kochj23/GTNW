//
//  KeyBindingTests.swift
//  GTNWTests
//
//  3.33.0: remappable gameplay shortcuts (Shared/Models/KeyBindings.swift). Unit, Functional, Security, Retry and
//  Frame. Every store here uses a throwaway UserDefaults suite.
//

import XCTest
import SwiftUI
@testable import GTNW

private func freshStore() -> (KeyBindingStore, UserDefaults) {
    let d = UserDefaults(suiteName: "GTNW.tests.keys.\(UUID().uuidString)")!
    return (KeyBindingStore(defaults: d), d)
}

// MARK: - Unit

final class KeyBindingUnitTests: XCTestCase {

    func testDefaultsAreTodaysShortcuts() {
        XCTAssertEqual(GameShortcut.newGame.defaultBinding.display, "⌘N")
        XCTAssertEqual(GameShortcut.aiSettings.defaultBinding.display, "⌥⌘A")
        XCTAssertEqual(GameShortcut.toggleSkin.defaultBinding.display, "⇧⌘R")
        let (s, _) = freshStore()
        for g in GameShortcut.allCases { XCTAssertEqual(s.binding(for: g), g.defaultBinding) }
        XCTAssertTrue(s.isDefault)
    }

    func testShortcutCarriesKeyAndModifiers() throws {
        let k = try XCTUnwrap(GameShortcut.aiSettings.defaultBinding.shortcut)
        XCTAssertEqual(k.key, KeyEquivalent("a"))
        XCTAssertEqual(k.modifiers, [.command, .option])
        XCTAssertEqual(GameShortcut.aiSettings.defaultBinding.spoken, "Option Command A")
    }
}

// MARK: - Functional

final class KeyBindingFunctionalTests: XCTestCase {

    func testRemapPersistsAndResets() throws {
        let (s, d) = freshStore()
        try s.set(KeyBinding(key: "G", command: true, shift: true), for: .newGame)
        XCTAssertEqual(s.binding(for: .newGame).display, "⇧⌘G", "stored lowercase, shown upper")
        XCTAssertEqual(KeyBindingStore(defaults: d).binding(for: .newGame).display, "⇧⌘G", "survives a relaunch")
        XCTAssertFalse(s.isDefault)
        s.reset(.newGame)
        XCTAssertEqual(s.binding(for: .newGame), GameShortcut.newGame.defaultBinding)
        try s.set(KeyBinding(key: "k", command: true, control: true), for: .toggleSkin)
        s.resetAll()
        XCTAssertTrue(s.isDefault)
        XCTAssertNil(d.data(forKey: KeyBindingStore.defaultsKey), "defaults leave nothing behind")
    }

    func testResettingOneFreesItsDefaultFromAnother() throws {
        let (s, _) = freshStore()
        try s.set(KeyBinding(key: "j", command: true), for: .newGame)
        try s.set(KeyBinding(key: "n", command: true), for: .toggleSkin)   // ⌘N is free now
        s.reset(.newGame)
        XCTAssertEqual(s.binding(for: .newGame).display, "⌘N")
        XCTAssertEqual(s.binding(for: .toggleSkin), GameShortcut.toggleSkin.defaultBinding, "no two commands share a key")
    }
}

// MARK: - Security (bad input never lands)

final class KeyBindingSecurityTests: XCTestCase {

    func testRefusals() {
        let (s, _) = freshStore()
        XCTAssertThrowsError(try s.set(KeyBinding(key: "", command: true), for: .newGame)) { XCTAssertEqual($0 as? KeyBindingError, .invalidKey) }
        XCTAssertThrowsError(try s.set(KeyBinding(key: "ab", command: true), for: .newGame)) { XCTAssertEqual($0 as? KeyBindingError, .invalidKey) }
        XCTAssertThrowsError(try s.set(KeyBinding(key: "é", command: true), for: .newGame)) { XCTAssertEqual($0 as? KeyBindingError, .invalidKey) }
        XCTAssertThrowsError(try s.set(KeyBinding(key: "g"), for: .newGame)) { XCTAssertEqual($0 as? KeyBindingError, .needsModifier) }
        XCTAssertThrowsError(try s.set(KeyBinding(key: "q", command: true), for: .newGame)) { XCTAssertEqual($0 as? KeyBindingError, .reserved) }
        XCTAssertThrowsError(try s.set(KeyBinding(key: "r", command: true, shift: true), for: .newGame)) {
            XCTAssertEqual($0 as? KeyBindingError, .taken(.toggleSkin))
        }
        XCTAssertTrue(s.isDefault, "nothing refused was stored")
    }

    func testTheSharedStoreNeverTouchesRealDefaultsUnderTest() throws {
        let before = UserDefaults.standard.data(forKey: KeyBindingStore.defaultsKey)
        try KeyBindingStore.shared.set(KeyBinding(key: "y", command: true, control: true), for: .toggleSkin)
        KeyBindingStore.shared.resetAll()
        XCTAssertEqual(UserDefaults.standard.data(forKey: KeyBindingStore.defaultsKey), before)
    }
}

// MARK: - Retry (a corrupt or stale saved map falls back)

final class KeyBindingRetryTests: XCTestCase {

    func testCorruptOrConflictingSavedBindingsFallBackToDefaults() throws {
        let d = UserDefaults(suiteName: "GTNW.tests.keys.\(UUID().uuidString)")!
        d.set(Data("not json".utf8), forKey: KeyBindingStore.defaultsKey)
        XCTAssertTrue(KeyBindingStore(defaults: d).isDefault)
        let bad: [String: KeyBinding] = ["newGame": KeyBinding(key: "q", command: true),           // reserved
                                         "toggleSkin": KeyBinding(key: "a", command: true, option: true),   // ⌥⌘A is taken
                                         "noSuchCommand": KeyBinding(key: "z", command: true, control: true)]
        d.set(try JSONEncoder().encode(bad), forKey: KeyBindingStore.defaultsKey)
        let s = KeyBindingStore(defaults: d)
        XCTAssertEqual(s.binding(for: .newGame), GameShortcut.newGame.defaultBinding)
        XCTAssertEqual(s.binding(for: .toggleSkin), GameShortcut.toggleSkin.defaultBinding)
    }
}

// MARK: - Frame (Settings → Keys renders)

final class KeyBindingFrameTests: XCTestCase {

    @MainActor
    func testKeysSettingsRenders() {
        let (s, _) = freshStore()
        let v = NSHostingView(rootView: KeyBindingsSettingsView(store: s).frame(width: 640, height: 320))
        v.frame = NSRect(x: 0, y: 0, width: 640, height: 320)
        v.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(v.fittingSize.height, 0)
        let r = ImageRenderer(content: KeyBindingsSettingsView(store: s).frame(width: 640, height: 320))
        XCTAssertNotNil(r.cgImage)
    }
}
