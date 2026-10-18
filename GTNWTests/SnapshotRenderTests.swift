//
//  SnapshotRenderTests.swift
//  GTNWTests
//
//  Renders the Situation Room and its sheets offscreen in both skins (no windows, no UI automation) so layout
//  regressions show up in CI artifacts. Images go to the temporary directory.
//

import XCTest
import SwiftUI
@testable import GTNW

#if os(macOS)
final class SnapshotRenderTests: XCTestCase {

    @MainActor
    private func render<V: View>(_ view: V, size: CGSize, name: String) throws -> URL {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        guard let cg = renderer.cgImage else { throw XCTSkip("renderer produced no image") }
        let rep = NSBitmapImageRep(cgImage: cg)
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let dir = ProcessInfo.processInfo.environment["GTNW_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("GTNWSnapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).png")
        try data.write(to: url)
        XCTAssertGreaterThan(cg.width, 100)
        return url
    }

    @MainActor
    func testRenderSituationRoomInBothSkins() throws {
        let engine = GameEngine()
        engine.startScenario(.world1990, turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        for _ in 0..<3 { gs.turn += 1; engine.processShadowTurn() }
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let room = SituationRoomView(gameState: gs).environmentObject(engine)
            let url = try render(room, size: CGSize(width: 1500, height: 940), name: "situation-\(theme.rawValue)")
            print("SNAPSHOT \(url.path)")
            let compact = SituationRoomView(gameState: gs).environmentObject(engine)
            print("SNAPSHOT \(try render(compact, size: CGSize(width: 820, height: 1100), name: "situation-compact-\(theme.rawValue)").path)")
            let war = WarRoomView(gameState: gs).environmentObject(engine)
            print("SNAPSHOT \(try render(war, size: CGSize(width: 940, height: 640), name: "warroom-\(theme.rawValue)").path)")
            print("SNAPSHOT \(try render(BudgetView(gameState: gs).environmentObject(engine), size: CGSize(width: 820, height: 560), name: "budget-\(theme.rawValue)").path)")
            print("SNAPSHOT \(try render(CityView(gameState: gs, countryID: "USA"), size: CGSize(width: 760, height: 500), name: "city-\(theme.rawValue)").path)")
            print("SNAPSHOT \(try render(WorldEvaluationView(gameState: gs), size: CGSize(width: 720, height: 520), name: "eval-\(theme.rawValue)").path)")
            let rails = HStack(alignment: .top) {
                AdvisorRail(gameState: gs, selected: gs.getCountry(id: "IRQ"), briefingRole: .constant(nil), scrolls: false).frame(width: 190)
                CountryDossier(gameState: gs, country: gs.getCountry(id: "IRQ"), onSheet: { _ in }, scrolls: false).frame(width: 300)
            }.environmentObject(engine)
            print("SNAPSHOT \(try render(rails, size: CGSize(width: 500, height: 900), name: "rails-\(theme.rawValue)").path)")
            print("SNAPSHOT \(try render(AidSheet(gameState: gs, countryID: "ETH").environmentObject(engine), size: CGSize(width: 640, height: 420), name: "aid-\(theme.rawValue)").path)")
        }
    }

    /// The same screens at 2× text (sizes scaled like the app's frames), for visual review of clipping.
    @MainActor
    func testRenderKeyScreensAtTwoX() throws {
        let engine = GameEngine()
        engine.startScenario(.world1990, turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        defer { Theme.forced = nil; FontScale.forced = nil }
        FontScale.forced = 2
        func sz(_ w: CGFloat, _ h: CGFloat) -> CGSize { CGSize(width: FontScale.w(w), height: FontScale.h(h)) }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            print("SNAPSHOT \(try render(MainTabView().environmentObject(GameEngine()).environmentObject(ThemeManager.shared), size: sz(1400, 900), name: "2x-start-\(t)").path)")
            print("SNAPSHOT \(try render(SituationRoomView(gameState: gs).environmentObject(engine), size: sz(1400, 900), name: "2x-situation-\(t)").path)")
            print("SNAPSHOT \(try render(WarRoomView(gameState: gs).environmentObject(engine), size: sz(940, 640), name: "2x-warroom-\(t)").path)")
            print("SNAPSHOT \(try render(BudgetView(gameState: gs).environmentObject(engine), size: sz(820, 560), name: "2x-budget-\(t)").path)")
            print("SNAPSHOT \(try render(WorldEvaluationView(gameState: gs), size: sz(720, 520), name: "2x-eval-\(t)").path)")
            print("SNAPSHOT \(try render(AidSheet(gameState: gs, countryID: "ETH").environmentObject(engine), size: sz(640, 420), name: "2x-aid-\(t)").path)")
            print("SNAPSHOT \(try render(LeaderboardView().environmentObject(engine), size: sz(1000, 700), name: "2x-leaderboard-\(t)").path)")
            print("SNAPSHOT \(try render(ThemeSettingsView(), size: sz(460, 300), name: "2x-settings-\(t)").path)")
            let rails = HStack(alignment: .top) {
                AdvisorRail(gameState: gs, selected: gs.getCountry(id: "IRQ"), briefingRole: .constant(nil), scrolls: false).frame(width: FontScale.w(190))
                CountryDossier(gameState: gs, country: gs.getCountry(id: "IRQ"), onSheet: { _ in }, scrolls: false).frame(width: FontScale.w(300))
            }.environmentObject(engine)
            print("SNAPSHOT \(try render(rails, size: sz(500, 900), name: "2x-rails-\(t)").path)")
        }
    }
}
#endif
