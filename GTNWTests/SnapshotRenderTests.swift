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

    /// 3.4.0: the sizing step for a ground invasion, an air strike and a nuclear strike, and the expedition control.
    @MainActor
    func testRenderAttackSizing() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        let mex = gs.getCountry(id: "MEX"), irn = gs.getCountry(id: "IRN")
        let old = GameEngine()
        old.startNewGame(administration: Advisor.fillmoreAdministration(), turnLength: .month)
        let gs1850 = try XCTUnwrap(old.gameState)
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            let panels = VStack(alignment: .leading, spacing: 10) {
                AttackSizingPanel(action: .groundInvasion, size: .constant(AttackSizing.preset(.standard, for: .groundInvasion, in: gs)),
                                  gameState: gs, target: mex, live: false)
                AttackSizingPanel(action: .airStrike, size: .constant(AttackSizing.preset(.overwhelming, for: .airStrike, in: gs)),
                                  gameState: gs, target: mex, live: false)
                AttackSizingPanel(action: .strategicNuke, size: .constant(AttackSize(warheads: 12)), gameState: gs, target: irn, live: false)
            }
            .padding(10).background(Theme.isRetro ? EGA.blue : Color.black)
            print("SNAPSHOT \(try render(panels, size: CGSize(width: FontScale.w(460), height: FontScale.h(560)), name: "attack-sizing-\(t)").path)")
            let dossier = CountryDossier(gameState: gs1850, country: nil, onSheet: { _ in }, scrolls: false, unclaimedID: "NGA")
                .environmentObject(old).frame(width: FontScale.w(300))
            print("SNAPSHOT \(try render(dossier, size: CGSize(width: FontScale.w(320), height: FontScale.h(320)), name: "expedition-\(t)").path)")
        }
    }

    /// 3.5.0: fleets at sea and on station on the map, and the fleet-order sheet, in 2025 and 1850.
    @MainActor
    func testRenderFleets() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        XCTAssertNotNil(engine.orderFleet("seventh", to: "PRK", mission: .showOfForce))
        gs.turn += 1; engine.processFleets()
        gs.actionsUsedThisTurn = 0
        XCTAssertNotNil(engine.orderFleet("fifth", to: "JPN", mission: .blockade))
        XCTAssertNotNil(engine.orderFleet("sixth", to: "LBY", mission: .strike))
        // Freeze the Fifth Fleet halfway to Japan for the picture.
        if let i = gs.shadow.fleetDeployments.firstIndex(where: { $0.fleetID == "fifth" }) {
            gs.shadow.fleetDeployments[i].departed = gs.currentDate.addingTimeInterval(-5 * 86_400)
            gs.shadow.fleetDeployments[i].arrives = gs.currentDate.addingTimeInterval(5 * 86_400)
        }
        let old = GameEngine()
        old.startNewGame(administration: Advisor.fillmoreAdministration(), turnLength: .month)
        let gs1850 = try XCTUnwrap(old.gameState)
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            let map = VectorWorldMap(gameState: gs, selectedCountryID: .constant("JPN"), zoom: .constant(.world), filter: .constant(.alignment))
            print("SNAPSHOT \(try render(VStack { map; MapLegend(filter: .alignment) }.background(Color.black), size: CGSize(width: 1100, height: 600), name: "fleets-map-\(t)").path)")
            let sheet = FleetOrderSheet(gameState: gs, targetID: "JPN", scrolls: false, fleetID: "third", mission: .strike).environmentObject(engine)
            print("SNAPSHOT \(try render(sheet, size: CGSize(width: FontScale.w(720), height: FontScale.h(620)), name: "fleet-orders-\(t)").path)")
            let sheet1850 = FleetOrderSheet(gameState: gs1850, targetID: "NGA", scrolls: false, fleetID: "africa", mission: .amphibious).environmentObject(old)
            print("SNAPSHOT \(try render(sheet1850, size: CGSize(width: FontScale.w(720), height: FontScale.h(620)), name: "fleet-orders-1850-\(t)").path)")
        }
    }

    /// 3.6.0: the arsenal line and legal labels under an action in 1918, 1944, 1990, 2000 and 2025.
    @MainActor
    func testRenderArsenalLines() throws {
        let cases: [(Int, PresidentialAction)] = [(1918, .groundInvasion), (1918, .chemicalAttack), (1944, .biologicalAttack),
                                                   (1990, .deployMissiles), (2000, .chemicalAttack), (2025, .chemicalAttack), (2025, .airStrike)]
        var rows: [(title: String, action: PresidentialAction, gs: GameState, problem: String?)] = []
        for (year, action) in cases {
            let engine = GameEngine()
            engine.startNewGame(turnLength: .month)
            let gs = try XCTUnwrap(engine.gameState)
            gs.eraStartYear = year
            rows.append(("\(year) — \(action.rawValue.uppercased())", action, gs, engine.wmdProblem(action)))
        }
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let view = VStack(alignment: .leading, spacing: 8) {
                ForEach(rows.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: rows[i].title).font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber)
                        ArsenalLine(action: rows[i].action, gameState: rows[i].gs, problem: rows[i].problem)
                    }
                    .padding(6).frame(maxWidth: .infinity, alignment: .leading).themedPanel(retroFill: EGA.black)
                }
            }
            .padding(10).background(Theme.isRetro ? EGA.blue : Color.black)
            print("SNAPSHOT \(try render(view, size: CGSize(width: FontScale.w(560), height: FontScale.h(760)), name: "arsenal-lines-\(theme.rawValue)").path)")
        }
    }

    /// 3.7.0: the Resources panel, the impeachment-risk badge and the claim warning, in both skins.
    @MainActor
    func testRenderTerritoryWealth() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.wilsonAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        for (id, name) in [("ZMB", "Gotit"), ("ERI", "Gimme"), ("GHA", "Gold Coast"), ("COD", "Rubberland"), ("ZAF", "")] {
            gs.actionsUsedThisTurn = 0
            if gs.unclaimedLandIDs.contains(id) { XCTAssertTrue(engine.claimLand(id)); if !name.isEmpty { engine.renameTerritory(id, to: name) } }
        }
        for _ in 0..<30 { gs.turn += 1; engine.processTerritoryEconomy() }
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            print("SNAPSHOT \(try render(ResourcesSheet(gameState: gs, scrolls: false), size: CGSize(width: FontScale.w(640), height: FontScale.h(560)), name: "resources-\(t)").path)")
            gs.shadow.ruthlessness = 30.5; gs.shadow.popularity = 31
            let log = gs.shadow.expansionLog
            gs.shadow.expansionLog = Array(repeating: gs.currentDate, count: 20)   // mid-spree: the next claim tips it
            let bar = SituationTopBar(gameState: gs, onSheet: { _ in }, part: .statsOnly).environmentObject(engine)
            print("SNAPSHOT \(try render(bar, size: CGSize(width: FontScale.w(900), height: FontScale.h(70)), name: "impeachment-risk-\(t)").path)")
            let dossier = CountryDossier(gameState: gs, country: nil, onSheet: { _ in }, scrolls: false, unclaimedID: "NGA")
                .environmentObject(engine).frame(width: FontScale.w(300))
            print("SNAPSHOT \(try render(dossier, size: CGSize(width: FontScale.w(320), height: FontScale.h(420)), name: "claim-warning-\(t)").path)")
            gs.shadow.ruthlessness = 0; gs.shadow.popularity = 50; gs.shadow.expansionLog = log
        }
    }

    /// 3.8.0: the Congress sheet, the top bar with Congress and a War Powers clock, and cabinet warnings.
    @MainActor
    func testRenderCongressAndWarnings() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .week)
        let gs = try XCTUnwrap(engine.gameState)
        gs.eraStartYear = 1990
        engine.requestAuthorization(target: "IRQ", kind: .useOfForce, roll: 0.999)
        gs.actionsUsedThisTurn = 0
        engine.declareWar(aggressor: "USA", defender: "MEX")
        for _ in 0..<7 { gs.turn += 1; engine.processWarPowers() }
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            print("SNAPSHOT \(try render(CongressSheet(gameState: gs, targetID: "IRQ").environmentObject(engine), size: CGSize(width: FontScale.w(640), height: FontScale.h(420)), name: "congress-\(t)").path)")
            let bar = SituationTopBar(gameState: gs, onSheet: { _ in }, part: .statsOnly).environmentObject(engine)
            print("SNAPSHOT \(try render(bar, size: CGSize(width: FontScale.w(1100), height: FontScale.h(70)), name: "topbar-congress-\(t)").path)")
            let warnings = VStack(alignment: .leading, spacing: 8) {
                CabinetWarningsView(warnings: engine.advisorWarnings(for: .attack(.groundInvasion, target: "CUB", size: nil)))
                CabinetWarningsView(warnings: engine.advisorWarnings(for: .attack(.strategicNuke, target: "RUS", size: AttackSize(warheads: 20))))
                CabinetWarningsView(warnings: engine.advisorWarnings(for: .fleet(fleetID: "sixth", target: "LBY", mission: .strike, preset: .overwhelming)))
            }
            .padding(10).frame(width: FontScale.w(520)).background(Theme.isRetro ? EGA.blue : Color.black)
            print("SNAPSHOT \(try render(warnings, size: CGSize(width: FontScale.w(520), height: FontScale.h(460)), name: "cabinet-warnings-\(t)").path)")
        }
    }

    /// 3.9.0: the Govern sheet, the Manpower sheet, and the World Map grid's unclaimed-land and territory sheets.
    @MainActor
    func testRenderGovernManpowerAndGrid() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.wilsonAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        XCTAssertTrue(engine.claimLand("GMB", troops: 5))
        engine.renameTerritory("GMB", to: "Fort Wilson")
        engine.setGovernance("GMB", .localElections)
        for _ in 0..<8 { gs.turn += 1; engine.processOccupation() }
        gs.actionsUsedThisTurn = 0
        engine.callUp(.mobilization)
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            print("SNAPSHOT \(try render(GovernSheet(gameState: gs, countryID: "GMB").environmentObject(engine), size: CGSize(width: FontScale.w(640), height: FontScale.h(420)), name: "govern-\(t)").path)")
            print("SNAPSHOT \(try render(ManpowerSheet(gameState: gs).environmentObject(engine), size: CGSize(width: FontScale.w(620), height: FontScale.h(420)), name: "manpower-\(t)").path)")
            print("SNAPSHOT \(try render(UnclaimedLandSheet(gameState: gs, landID: "NGA").environmentObject(engine), size: CGSize(width: FontScale.w(560), height: FontScale.h(320)), name: "grid-unclaimed-\(t)").path)")
            let detail = CountryDetailSheet(country: gs.getCountry(id: "GMB")!, gameState: gs).environmentObject(engine)
            print("SNAPSHOT \(try render(detail, size: CGSize(width: FontScale.w(800), height: FontScale.h(700)), name: "grid-territory-\(t)").path)")
        }
    }

    /// 3.10.0: Antarctica on the map and in its dossier (1913 and 2025), and the group-action sheet.
    @MainActor
    func testRenderAntarcticaAndGroupActions() throws {
        let old = GameEngine()
        old.startNewGame(administration: Advisor.wilsonAdministration(), turnLength: .month)
        let g1913 = try XCTUnwrap(old.gameState)
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            let map = VectorWorldMap(gameState: g1913, selectedCountryID: .constant(Antarctica.id), zoom: .constant(.world), filter: .constant(.alignment))
            print("SNAPSHOT \(try render(VStack { map; MapLegend(filter: .alignment, showUnclaimed: true) }.background(Color.black), size: CGSize(width: 1100, height: 620), name: "antarctica-map-\(t)").path)")
            let dossiers = HStack(alignment: .top) {
                CountryDossier(gameState: g1913, country: nil, onSheet: { _ in }, scrolls: false, unclaimedID: Antarctica.id).environmentObject(old).frame(width: FontScale.w(300))
                CountryDossier(gameState: gs, country: nil, onSheet: { _ in }, scrolls: false, unclaimedID: Antarctica.id).environmentObject(engine).frame(width: FontScale.w(300))
            }
            print("SNAPSHOT \(try render(dossiers, size: CGSize(width: FontScale.w(620), height: FontScale.h(640)), name: "antarctica-dossier-\(t)").path)")
            let sheet = GroupActionSheet(gameState: gs, live: false, pick: .allies, kind: .aid, amount: 12, split: .byNeed).environmentObject(engine)
            print("SNAPSHOT \(try render(sheet, size: CGSize(width: FontScale.w(820), height: FontScale.h(560)), name: "group-action-\(t)").path)")
        }
    }

    /// 3.11.0: playing Britain in 2025 and the Ottoman Empire in 1913: the cabinet rail, the removal-risk badge,
    /// and the new removal endings.
    @MainActor
    func testRenderPlayAsOtherNations() throws {
        let engine = GameEngine()
        engine.startNewGame(playerCountryID: "GBR", turnLength: .month)
        let gbr = try XCTUnwrap(engine.gameState)
        let ott = GameEngine()
        ott.startNewGame(playerCountryID: "TUR", administration: Advisor.wilsonAdministration(), turnLength: .month)
        let tur = try XCTUnwrap(ott.gameState)
        gbr.shadow.ruthlessness = 25; gbr.shadow.popularity = 30
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            let rails = HStack(alignment: .top) {
                AdvisorRail(gameState: gbr, selected: nil, briefingRole: .constant(nil), scrolls: false).frame(width: FontScale.w(220))
                AdvisorRail(gameState: tur, selected: nil, briefingRole: .constant(nil), scrolls: false).frame(width: FontScale.w(220))
            }
            print("SNAPSHOT \(try render(rails, size: CGSize(width: FontScale.w(460), height: FontScale.h(560)), name: "nation-cabinets-\(t)").path)")
            let bar = SituationTopBar(gameState: gbr, onSheet: { _ in }, part: .statsOnly).environmentObject(engine)
            print("SNAPSHOT \(try render(bar, size: CGSize(width: FontScale.w(900), height: FontScale.h(70)), name: "nation-topbar-\(t)").path)")
            let endings = HStack { ForEach([DomesticEnding.noConfidence, .coup, .partyCongress], id: \.self) { DomesticEndingBanner(ending: $0) } }
            print("SNAPSHOT \(try render(endings, size: CGSize(width: FontScale.w(900), height: FontScale.h(240)), name: "nation-endings-\(t)").path)")
        }
    }

    /// 3.12.0: the coalition sheet (Gulf 1990) and the Pearl Harbor scorecard a week in.
    @MainActor
    func testRenderCoalitionAndScorecard() throws {
        let gulf = GameEngine()
        gulf.startScenario(try XCTUnwrap(ScenarioDefinition.find("world1990")), turnLength: .week)
        let g1 = try XCTUnwrap(gulf.gameState)
        let pearl = GameEngine()
        pearl.startScenario(try XCTUnwrap(ScenarioDefinition.find("pearl1941")), turnLength: .week)
        let g2 = try XCTUnwrap(pearl.gameState)
        g2.turn += 1; pearl.processShadowTurn()
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            print("SNAPSHOT \(try render(CoalitionSheet(gameState: g1, targetID: "IRQ").environmentObject(gulf), size: CGSize(width: FontScale.w(640), height: FontScale.h(520)), name: "coalition-\(t)").path)")
            print("SNAPSHOT \(try render(ScorecardSheet(gameState: g2), size: CGSize(width: FontScale.w(700), height: FontScale.h(320)), name: "scorecard-pearl-\(t)").path)")
        }
    }

    /// 3.12.2: a computer-run nation's dossier with its historical leader (France 1960), and the Gulf War scorecard.
    @MainActor
    func testRenderLeadersAndGulfScorecard() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        gs.eraStartYear = 1960
        engine.processCabinets()
        let gulf = GameEngine()
        gulf.startScenario(try XCTUnwrap(ScenarioDefinition.find("gulf1990")), turnLength: .week)
        let g2 = try XCTUnwrap(gulf.gameState)
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let t = theme.rawValue
            let dossier = CountryDossier(gameState: gs, country: gs.getCountry(id: "FRA"), onSheet: { _ in }, scrolls: false).environmentObject(engine).frame(width: FontScale.w(300))
            print("SNAPSHOT \(try render(dossier, size: CGSize(width: FontScale.w(320), height: FontScale.h(760)), name: "leader-dossier-\(t)").path)")
            print("SNAPSHOT \(try render(ScorecardSheet(gameState: g2), size: CGSize(width: FontScale.w(700), height: FontScale.h(340)), name: "scorecard-gulf-\(t)").path)")
        }
    }
}
#endif
