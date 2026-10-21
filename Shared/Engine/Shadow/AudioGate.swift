//
//  AudioGate.swift
//  Global Thermal Nuclear War
//
//  The mute switch. When the environment has GTNW_MUTE=1, the launch arguments have `-GTNWMute YES`, or the app is
//  running as an XCTest host (XCTestConfigurationFilePath is set), every audio path is a no-op: no players, no
//  speech, no audio engine is ever created. Under XCTest the app also stays out of sight (it never activates and
//  keeps its windows ordered out), so test and snapshot runs never take over the desktop.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation
#if os(macOS)
import AppKit
#endif

enum AudioGate {
    /// Overrides for tests of the gate itself; nil = read the process.
    nonisolated(unsafe) static var environmentOverride: [String: String]?
    nonisolated(unsafe) static var defaultsOverride: UserDefaults?

    private static var environment: [String: String] { environmentOverride ?? ProcessInfo.processInfo.environment }

    /// Running as an XCTest host.
    static var underXCTest: Bool { environment["XCTestConfigurationFilePath"] != nil }

    /// True when nothing may make a sound.
    static var muted: Bool {
        underXCTest || environment["GTNW_MUTE"] == "1" || (defaultsOverride ?? .standard).bool(forKey: "GTNWMute")
    }

    /// Counts sounds that were asked for while muted (for tests).
    nonisolated(unsafe) static private(set) var suppressed = 0

    /// Call before any playback: true if it may play; false (and counted) when muted.
    static func allow() -> Bool {
        if muted { suppressed += 1; return false }
        return true
    }

    #if os(macOS)
    /// Under XCTest: never activate, and keep any window off the screen.
    static func hideUnderTest() {
        guard underXCTest else { return }
        NSApplication.shared.setActivationPolicy(.prohibited)
        let hide = { NSApplication.shared.windows.forEach { $0.orderOut(nil) } }
        for delay in stride(from: 0.0, through: 3.0, by: 0.1) { DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: hide) }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification, NSWindow.didChangeOcclusionStateNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
                (note.object as? NSWindow)?.orderOut(nil)
            }
        }
    }
    #endif
}
