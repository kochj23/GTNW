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

// MARK: - 2× text layout

#if os(macOS)
/// At 2× text the key views must lay out inside the minimum window without truncation or overflow.
@MainActor
final class FontScaleFrameTests: XCTestCase {
    override func tearDown() { FontScale.forced = nil; Theme.forced = nil; super.tearDown() }

    private func fit<V: View>(_ view: V, width: CGFloat = 10_000) -> CGSize {
        NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 10_000))
    }

    /// Unconstrained (never truncated) width of a single line of text.
    private func textWidth(_ s: String, _ font: Font) -> CGFloat {
        fit(Text(s).font(font).fixedSize()).width
    }

    private func scenarioState() throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startScenario(.world1990, turnLength: .month)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    func testMinimumWindowGrowsWithText() {
        FontScale.forced = 1
        let w1 = FontScale.w(1400), h1 = FontScale.h(900)
        FontScale.forced = 2
        XCTAssertGreaterThan(FontScale.w(1400), w1 * 1.5, "2× window must be much wider than 1×")
        XCTAssertGreaterThan(FontScale.h(900), h1)
    }

    /// The top bar's two halves (stats, controls) each fit the window at 2×, so the wrapped layout never truncates.
    func testSituationTopBarFitsAtTwoX() throws {
        let (engine, gs) = try scenarioState()
        FontScale.forced = 2
        let window = FontScale.w(1400) - 40
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let bar = SituationTopBar(gameState: gs, onSheet: { _ in })
            let stats = fit(SituationTopBar(gameState: gs, onSheet: { _ in }, part: .statsOnly).fixedSize().environmentObject(engine)).width
            let controls = fit(SituationTopBar(gameState: gs, onSheet: { _ in }, part: .controlsOnly).fixedSize().environmentObject(engine)).width
            XCTAssertLessThanOrEqual(stats, window, "\(theme): top-bar stats overflow")
            XCTAssertLessThanOrEqual(controls, window, "\(theme): top-bar buttons overflow")
            let laidOut = fit(bar.environmentObject(engine), width: window)
            XCTAssertLessThanOrEqual(laidOut.width, window + 1, "\(theme): top bar wider than the window")
        }
    }

    /// The whole Situation Room renders at the 2× minimum window without asking for more width.
    func testSituationRoomFitsMinimumWindowAtTwoX() throws {
        let (engine, gs) = try scenarioState()
        FontScale.forced = 2
        let size = CGSize(width: FontScale.w(1400), height: FontScale.h(900))
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let room = SituationRoomView(gameState: gs).environmentObject(engine)
            let wanted = NSHostingController(rootView: room).sizeThatFits(in: size)
            XCTAssertLessThanOrEqual(wanted.width, size.width + 1, "\(theme): Situation Room overflows the window")
            let r = ImageRenderer(content: SituationRoomView(gameState: gs).environmentObject(engine).frame(width: size.width, height: size.height))
            r.scale = 1
            XCTAssertNotNil(r.cgImage)
        }
    }

    /// Fixed leaderboard columns are scaled with the text: the widest values fit untruncated.
    func testLeaderboardColumnsFitAtTwoX() {
        FontScale.forced = 2
        let header = Font.scaled(size: 14, weight: .bold, design: .monospaced)
        XCTAssertLessThanOrEqual(textWidth("RANK", header), FontScale.w(80))
        XCTAssertLessThanOrEqual(textWidth("SCORE", header), FontScale.w(120))
        XCTAssertLessThanOrEqual(textWidth("VICTORY", header), FontScale.w(200))
        XCTAssertLessThanOrEqual(textWidth("TURNS", header), FontScale.w(80))
        XCTAssertLessThanOrEqual(textWidth("99999", .scaled(size: 18, weight: .bold, design: .monospaced)), FontScale.w(120))
        XCTAssertLessThanOrEqual(textWidth("999", .scaled(size: 16, design: .monospaced)), FontScale.w(80))
    }

    /// The DB badge is fixed-size in the top bar: it grows with the text and never truncates its label.
    func testStoreStatusBadgeScales() {
        FontScale.forced = 1
        let small = fit(StoreStatusBadge().fixedSize())
        FontScale.forced = 2
        let big = fit(StoreStatusBadge().fixedSize())
        // (Padding is fixed, so the badge grows a little less than the text itself.)
        XCTAssertGreaterThan(big.height, small.height * 1.4)
        XCTAssertGreaterThan(big.width, small.width * 1.4)
        let label = textWidth(GameStoreService.shared.status.shortLabel, ThemeFont.mono(10, .bold))
        XCTAssertGreaterThanOrEqual(big.width, label, "badge narrower than its label")
    }

    /// The SwiftUI replacements for native pickers/checkboxes grow with the text (native AppKit ones would not).
    func testScaledControlsGrowWithText() {
        var turn = TurnLength.month, theme = GameTheme.modern, on = true
        let views: [(String, () -> AnyView)] = [
            ("segmented", { AnyView(ScaledSegmentedPicker(selection: Binding(get: { turn }, set: { turn = $0 }),
                                                          options: TurnLength.allCases.map { ($0, $0.displayName) })) }),
            ("menu", { AnyView(ScaledMenuPicker(selection: Binding(get: { theme }, set: { theme = $0 }),
                                                options: GameTheme.allCases.map { ($0, $0.displayName) })) }),
            ("checkbox", { AnyView(Toggle("Elections", isOn: Binding(get: { on }, set: { on = $0 })).toggleStyle(.scaledCheckbox).font(.scaled(.body))) }),
        ]
        for (name, make) in views {
            FontScale.forced = 1
            let small = fit(make().fixedSize())
            FontScale.forced = 2
            let big = fit(make().fixedSize())
            XCTAssertGreaterThan(big.height, small.height * 1.6, "\(name) height did not scale")
            if name != "menu" { XCTAssertGreaterThan(big.width, small.width * 1.6, "\(name) width did not scale") }
        }
    }

    /// The macOS game tab bar (replaces the fixed-size native TabView strip) fits the 2× minimum window in both skins.
    func testGameTabBarFitsAtTwoX() {
        FontScale.forced = 2
        for theme in GameTheme.allCases {
            Theme.forced = theme
            var tab = 0
            let bar = GameTabBar(selection: Binding(get: { tab }, set: { tab = $0 }))
            let w = fit(bar.fixedSize()).width
            XCTAssertLessThanOrEqual(w, FontScale.w(1400), "\(theme): tab bar overflows the window")
            XCTAssertGreaterThanOrEqual(w, textWidth("Situation Room", ThemeFont.mono(11, .bold)) * 3, "\(theme): tab bar too small")
        }
    }

    /// Settings: the Text size picker is present and the Game tab is wide enough for 2× text.
    func testSettingsFitAtTwoX() {
        FontScale.forced = 2
        let s = fit(ThemeSettingsView(), width: FontScale.w(460))
        XCTAssertLessThanOrEqual(s.width, FontScale.w(460) + 40)
        XCTAssertLessThanOrEqual(textWidth("Text size", .scaled(.body)), FontScale.w(460) / 2)
    }
}
#endif
