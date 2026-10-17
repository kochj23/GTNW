//
//  GTNWFrameTests.swift
//  GTNWTests
//
//  // MARK: - Frame
//  Startup smoke: the test host (the real GTNW.app) booted, the app's root
//  objects construct, the first screen renders offscreen, and the built binary
//  launches hidden with `--launch-smoke`, reaches its run loop and exits 0.
//  No windows are activated, no mouse/keyboard automation.
//
//  Created by Jordan Koch on 2026.
//

import XCTest
import SwiftUI
@testable import GTNW

#if os(macOS)
import AppKit

final class GTNWFrameTests: XCTestCase {

    @MainActor
    func testTestHostIsTheGTNWAppAndBooted() {
        XCTAssertTrue(Bundle.main.bundlePath.hasSuffix(".app"), "tests must be hosted by GTNW.app")
        XCTAssertEqual(Bundle.main.executableURL?.lastPathComponent, "GTNW")
        XCTAssertNotNil(NSApp, "NSApplication must exist — app reached main()")
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.wopr.gtnw.macos")
    }

    @MainActor
    func testRootObjectsConstructWithoutCrashing() {
        let engine = GameEngine()
        XCTAssertNil(engine.gameState, "fresh launch starts on the start screen")
        XCTAssertEqual(engine.brainConfig.liveSessionTimeout, BrainConfig.default.liveSessionTimeout)
        _ = ThemeManager.shared
        _ = AIBackendManager.shared
        _ = ShadowPack.shared
    }

    @MainActor
    func testAPIServerStartIsIdempotent() {
        let server = NovaAPIServer.shared
        server.start()
        server.start()          // used to leak the first listener and fail to rebind
        XCTAssertTrue(server.isListening)
    }

    @MainActor
    func testFirstScreenRendersOffscreen() throws {
        let engine = GameEngine()
        let root = MainTabView().environmentObject(engine).environmentObject(ThemeManager.shared)
            .frame(width: 1200, height: 800)
        let renderer = ImageRenderer(content: root)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage, "root view failed to render")
        XCTAssertGreaterThanOrEqual(image.width, 1000)
    }

    /// The start screen must render in every skin (a skin switch rebuilds the root).
    @MainActor
    func testStartScreenRendersInEverySkin() throws {
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let root = MainTabView().environmentObject(GameEngine()).environmentObject(ThemeManager.shared)
                .frame(width: 1000, height: 700)
            let renderer = ImageRenderer(content: root)
            renderer.scale = 1
            XCTAssertNotNil(renderer.cgImage, "start screen failed to render in \(theme)")
        }
    }

    func testLaunchSmokeFlagIsRecognised() {
        XCTAssertEqual(LaunchSmoke.flag, "--launch-smoke")
        XCTAssertFalse(LaunchSmoke.isRequested, "the test host itself must not be in smoke mode")
    }

    /// Execute the built binary hidden with `--launch-smoke`: it must stay alive
    /// through startup (no crash) and then exit 0 on its own.
    func testBuiltBinaryLaunchesAndExitsCleanly() throws {
        let exe = try XCTUnwrap(Bundle.main.executableURL)
        let p = Process()
        p.executableURL = exe
        p.arguments = [LaunchSmoke.flag, "-ApplePersistenceIgnoreState", "YES"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        let start = Date()
        try p.run()

        // Alive after 1.5s → survived startup.
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(p.isRunning, "app died during startup (status \(p.isRunning ? 0 : p.terminationStatus))")

        // Should quit itself within ~2.5s; hard stop at 15s.
        let deadline = Date().addingTimeInterval(15)
        while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if p.isRunning { p.terminate(); XCTFail("smoke launch did not exit on its own") ; return }
        XCTAssertEqual(p.terminationReason, .exit)
        XCTAssertEqual(p.terminationStatus, 0)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 2.0)
    }
}
#endif
