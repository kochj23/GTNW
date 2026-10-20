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

    /// 3.2.0: a U.S. territory on the map, the dossier badge, and the Terms of Surrender sheet.
    @MainActor
    func testRenderTerritoryAndSurrenderTerms() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        for target in ["MEX", "VEN"] {
            engine.declareWar(aggressor: "USA", defender: target)
            engine.syncFronts()
            let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.defender == target && $0.status == .fighting })
            engine.resolveFront(index: i, verdict: .attackerWon)
        }
        let mex = try XCTUnwrap(gs.shadow.pendingSettlements.first { $0.loser == "MEX" })
        XCTAssertTrue(engine.settle(mex.id, choice: .annex))
        let ven = try XCTUnwrap(gs.shadow.pendingSettlements.first { $0.loser == "VEN" })
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            print("SNAPSHOT \(try render(SituationRoomView(gameState: gs).environmentObject(engine), size: CGSize(width: 1500, height: 940), name: "territory-situation-\(t)").path)")
            print("SNAPSHOT \(try render(SettlementSheet(gameState: gs, settlement: ven, scrolls: false).environmentObject(engine), size: CGSize(width: FontScale.w(700), height: FontScale.h(1000)), name: "surrender-terms-\(t)").path)")
            let map = VectorWorldMap(gameState: gs, selectedCountryID: .constant(nil), zoom: .constant(.world), filter: .constant(.alignment))
            print("SNAPSHOT \(try render(VStack { map; MapLegend(filter: .alignment) }.background(Color.black), size: CGSize(width: 1100, height: 600), name: "territory-map-\(t)").path)")
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

    /// Integration (3.2.0): war → surrender → annex → save → load in a fresh engine → the loaded map still shows the
    /// territory, and the second pending surrender can still be answered after the reload.
    @MainActor
    func testWarToTerritorySurvivesSaveLoadAndRendersOnTheMap() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        for target in ["CUB", "VEN"] {
            engine.declareWar(aggressor: "USA", defender: target)
            engine.syncFronts()
            let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.defender == target && $0.status == .fighting })
            engine.resolveFront(index: i, verdict: .attackerWon)
        }
        let cub = try XCTUnwrap(gs.shadow.pendingSettlements.first { $0.loser == "CUB" })
        XCTAssertTrue(engine.settle(cub.id, choice: .annex))

        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        let engine2 = GameEngine()
        engine2.gameState = loaded
        let c = try XCTUnwrap(loaded.getCountry(id: "CUB"))
        XCTAssertTrue(c.isTerritory)
        XCTAssertEqual(c.alignment, loaded.getCountry(id: "USA")?.alignment)
        XCTAssertEqual(CombatModel.territoryTitle(ownerID: c.territoryOf ?? "", ownerName: "United States"), "U.S. TERRITORY")
        let ven = try XCTUnwrap(loaded.shadow.pendingSettlements.first { $0.loser == "VEN" })
        XCTAssertTrue(engine2.settle(ven.id, choice: .government(.democraticRepublic)))
        XCTAssertEqual(loaded.getCountry(id: "VEN")?.alignment, .western)

        let map = VectorWorldMap(gameState: loaded, selectedCountryID: .constant(nil), zoom: .constant(.world), filter: .constant(.alignment))
        let url = try render(VStack { map; MapLegend(filter: .alignment) }.background(Color.black),
                             size: CGSize(width: 1100, height: 600), name: "integration-territory-after-load")
        XCTAssertGreaterThan((try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0, 10_000)
    }

    /// 3.3.0: an 1850 world with unclaimed Africa (world + region zoom, Nigeria selected), its dossier, the naming
    /// sheet after a claim, the rename sheet, and the annex option with its optional name field.
    @MainActor
    func testRenderUnclaimedLandsAndNamingSheet() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.fillmoreAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        XCTAssertTrue(engine.claimLand("KEN"))
        XCTAssertTrue(engine.renameTerritory("KEN", to: "New Albion"))
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            for zoom in [MapZoom.world, .region] {
                let map = VectorWorldMap(gameState: gs, selectedCountryID: .constant("NGA"), zoom: .constant(zoom), filter: .constant(.alignment))
                print("SNAPSHOT \(try render(VStack { map; MapLegend(filter: .alignment, showUnclaimed: true) }.background(Color.black), size: CGSize(width: 1100, height: 600), name: "unclaimed-map-\(zoom.rawValue.lowercased())-\(t)").path)")
            }
            let other = VectorWorldMap(gameState: gs, selectedCountryID: .constant(nil), zoom: .constant(.world), filter: .constant(.unrest))
            print("SNAPSHOT \(try render(VStack { other; MapLegend(filter: .unrest, showUnclaimed: true) }.background(Color.black), size: CGSize(width: 1100, height: 600), name: "unclaimed-map-unrest-\(t)").path)")
            let dossiers = HStack(alignment: .top) {
                CountryDossier(gameState: gs, country: nil, onSheet: { _ in }, scrolls: false, unclaimedID: "NGA").frame(width: FontScale.w(300))
                CountryDossier(gameState: gs, country: gs.getCountry(id: "KEN"), onSheet: { _ in }, scrolls: false).frame(width: FontScale.w(300))
            }.environmentObject(engine)
            print("SNAPSHOT \(try render(dossiers, size: CGSize(width: FontScale.w(620), height: FontScale.h(760)), name: "unclaimed-dossier-\(t)").path)")
            let naming = TerritoryNameSheet(gameState: gs, countryID: "KEN", newlyClaimed: true, live: false, name: "Kenya").environmentObject(engine)
            print("SNAPSHOT \(try render(naming, size: CGSize(width: FontScale.w(560), height: FontScale.h(260)), name: "naming-sheet-\(t)").path)")
            let rename = TerritoryNameSheet(gameState: gs, countryID: "KEN", live: false, name: "<b>Robert'); --</b>").environmentObject(engine)
            print("SNAPSHOT \(try render(rename, size: CGSize(width: FontScale.w(560), height: FontScale.h(260)), name: "rename-sheet-\(t)").path)")
        }
    }

    /// Integration (3.3.0): claim → name → save → load in a fresh engine → the map still draws the named territory.
    @MainActor
    func testClaimedLandSurvivesSaveLoadAndRendersOnTheMap() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.fillmoreAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        XCTAssertTrue(engine.claimLand("NGA"))
        XCTAssertTrue(engine.renameTerritory("NGA", to: "New Albion"))
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.getCountry(id: "NGA")?.name, "New Albion")
        XCTAssertTrue(loaded.getCountry(id: "NGA")?.isTerritory ?? false)
        let map = VectorWorldMap(gameState: loaded, selectedCountryID: .constant("NGA"), zoom: .constant(.region), filter: .constant(.alignment))
        let url = try render(VStack { map; MapLegend(filter: .alignment, showUnclaimed: true) }.background(Color.black),
                             size: CGSize(width: 1100, height: 600), name: "integration-claimed-after-load")
        XCTAssertGreaterThan((try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0, 10_000)
    }
}
#endif
