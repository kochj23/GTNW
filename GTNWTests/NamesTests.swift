//
//  NamesTests.swift
//  GTNWTests
//
//  3.36.0: names. The content check on every name (NameScreen), renaming the President's own country and the lands
//  he holds from the sheet, the command box and the chief of staff (RenamePlanner, GameOrder .rename, ChatTools),
//  the consequences (people and recognition, deterministic), old saves holding a refused name, and the Hall of
//  Cartography kept across games.
//

import XCTest
import SwiftUI
@testable import GTNW

@MainActor
final class NamesTests: XCTestCase {

    private var hallFolder: URL!

    override func setUp() {
        super.setUp()
        hallFolder = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw-hall-\(UUID().uuidString)", isDirectory: true)
        CartographyHall.folder = hallFolder
        CartographyHall.reset()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: hallFolder)
        CartographyHall.folder = nil
        CartographyHall.reset()
        super.tearDown()
    }

    /// 2025, the United States (holding its Pacific islands), with Mexico and Cuba made its territories.
    private func game(seed: UInt64 = 11) throws -> (GameEngine, GameState) {
        let e = CmdFixtures.engine(year: 2025, seed: seed)
        let gs = try XCTUnwrap(e.gameState)
        for id in ["MEX", "CUB"] {
            let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == id })
            gs.countries[i].territoryOf = gs.playerCountryID
        }
        return (e, gs)
    }

    // MARK: Unit: the content check

    func testHatefulSexualAndReligionMockingNamesAreRefused() {
        let refused = ["racismland", "RacismLand", "Racism Land", "New Racistan", "Nazistan", "naziland", "Hitler Island", "N a z i",
                       "Fourth Reich", "KKK Islands", "Holocaustia", "Aryan Nation", "Pornland", "Sexland", "Sexy Island", "XXX",
                       "Zorbsexualqua", "Boobs Bay", "Jesus Poop Land", "Allahshit", "Buddha Butt", "Stupid Bible Land",
                       "No Muslims Land", "Jewfree", "Mexicans Out", "Whites Only", "Women Are Weak", "Infidel Island"]
        for n in refused {
            XCTAssertTrue(NameScreen.isBlocked(n), n)
            XCTAssertEqual(NameScreen.check(n), .blocked(NameScreen.blockedReason), n)
            XCTAssertNil(CombatModel.validTerritoryName(n), n)
        }
    }

    func testCrudeJokesGibberishAndRealPlacesAreAllowed() {
        let allowed = ["ShitGibbon", "asdfasdf", "Freedonia", "New Albion", "Christmas Island", "Essex", "Middlesex", "Sussex",
                       "Grapeland", "Japan", "Pakistan", "Spice Islands", "Scunthorpe", "Fagatogo", "Fort Wilson", "Lynchburg",
                       "Buttfart Island", "Port Liberty", "Red, White and Blue Land", "Isla Libertad", "Gimme KEN", "zzzzzz",
                       "Madagascar", "Santiago", "Nazareth", "Godthab", "Kilimanjaro", "Holy Moly Land", "Area 51", "Blackwater Bay"]
        for n in allowed {
            XCTAssertFalse(NameScreen.isBlocked(n), n)
            XCTAssertEqual(NameScreen.check(n), .ok(n), n)
        }
    }

    func testShapeRulesAndNeutralReasons() {
        XCTAssertEqual(NameScreen.check(""), .invalid(NameScreen.shapeReason))
        XCTAssertEqual(NameScreen.check("Two\nLines"), .invalid(NameScreen.shapeReason))
        XCTAssertEqual(NameScreen.check(String(repeating: "a", count: 41)), .invalid(NameScreen.shapeReason))
        XCTAssertEqual(NameScreen.check("  New Albion "), .ok("New Albion"))
        for r in [NameScreen.shapeReason, NameScreen.blockedReason] {
            XCTAssertFalse(ChatSafety.violates(r))
            XCTAssertFalse(r.lowercased().contains("racis"), "the reason never repeats the name")
        }
    }

    func testToneSortsDignifiedSillyAndMocking() {
        XCTAssertEqual(NameScreen.tone("New Albion"), .dignified)
        XCTAssertEqual(NameScreen.tone("Port Liberty"), .dignified)
        XCTAssertEqual(NameScreen.tone("asdfasdf"), .silly)
        XCTAssertEqual(NameScreen.tone("Xkcdqrst"), .silly)
        XCTAssertEqual(NameScreen.tone("%@%n%s"), .silly)
        XCTAssertEqual(NameScreen.tone("ShitGibbon"), .mocking)
        XCTAssertEqual(NameScreen.tone("Loser Island"), .mocking)
        XCTAssertEqual(NameScreen.pieces("ShitGibbon"), ["shit", "gibbon"])
        XCTAssertEqual(NameScreen.pieces("USALand"), ["usa", "land"])
    }

    // MARK: Functional: renaming

    func testRenamingOwnCountryChangesItsNameEverywhere() throws {
        let (e, gs) = try game()
        XCTAssertEqual(e.rename(.country("USA"), to: "Freedonia"), .renamed(from: "United States", to: "Freedonia"))
        XCTAssertEqual(gs.getPlayerCountry()?.name, "Freedonia")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("United States is now Freedonia") })
        XCTAssertEqual(gs.nameBook.first?.current, "Freedonia")
        XCTAssertTrue(e.logMessages.contains { $0.message.contains("Freedonia") })
        let status = ChatTools.run("game_status", arguments: [:], engine: e).text
        XCTAssertTrue(status.contains("Freedonia"), status)
        XCTAssertEqual(e.rename(.country("USA"), to: "Freedonia"), .unchanged)
        XCTAssertEqual(e.rename(.country("USA"), to: "racismland"), .refused(NameScreen.blockedReason))
        XCTAssertEqual(gs.getPlayerCountry()?.name, "Freedonia")
    }

    func testOnlyOwnCountryAndHeldLandsCanBeRenamed() throws {
        let (e, gs) = try game()
        XCTAssertTrue(e.rename(.country("MEX"), to: "New Columbia").succeeded)
        XCTAssertTrue(e.renameTerritory("CUB", to: "Iceland Two"))
        XCTAssertEqual(e.rename(.country("FRA"), to: "Gaul"), .refused("You can rename your own country and the lands you hold."))
        XCTAssertFalse(e.renameTerritory("USA", to: "Freedonia"), "renameTerritory stays territories-only")
        XCTAssertEqual(gs.getCountry(id: "FRA")?.name, "France")
        XCTAssertEqual(gs.renamableTargets.first, .country("USA"))
        let ids = Set(gs.renamableTargets.map(\.id))
        XCTAssertTrue(ids.isSuperset(of: ["USA", "MEX", "CUB", "MID"]), "\(ids)")
        XCTAssertFalse(ids.contains("FRA"))
        XCTAssertFalse(e.renameTerritory("MEX", to: "Nazistan"))
        XCTAssertEqual(gs.getCountry(id: "MEX")?.name, "New Columbia")
        let before = gs.actionsRemaining
        XCTAssertTrue(e.rename(.country("MEX"), to: "Mexico Nuevo").succeeded)
        XCTAssertEqual(gs.actionsRemaining, before, "a rename spends no action")
    }

    func testPeopleAndNationsReactMoreToAMockingName() throws {
        let (e1, g1) = try game(seed: 5)
        let (e2, g2) = try game(seed: 5)
        let s0 = try XCTUnwrap(g1.getCountry(id: "MEX")?.stability)
        let rel0 = g1.countries.filter { $0.id != "USA" }.reduce(0) { $0 + ($1.diplomaticRelations["USA"] ?? 0) }
        XCTAssertTrue(e1.rename(.country("MEX"), to: "New Columbia").succeeded)
        XCTAssertTrue(e2.rename(.country("MEX"), to: "Loser Dump").succeeded)
        let s1 = try XCTUnwrap(g1.getCountry(id: "MEX")?.stability), s2 = try XCTUnwrap(g2.getCountry(id: "MEX")?.stability)
        XCTAssertLessThan(s1, s0)
        XCTAssertLessThan(s2, s1, "a mocking name costs more")
        XCTAssertGreaterThanOrEqual(s0 - s2, 6)
        XCTAssertLessThanOrEqual(s0 - s2, 7, "small")
        let rel1 = g1.countries.filter { $0.id != "USA" }.reduce(0) { $0 + ($1.diplomaticRelations["USA"] ?? 0) }
        let rel2 = g2.countries.filter { $0.id != "USA" }.reduce(0) { $0 + ($1.diplomaticRelations["USA"] ?? 0) }
        XCTAssertLessThan(rel2, rel1)
        XCTAssertLessThanOrEqual(rel0 - rel2, 30, "at most ten nations, three points each")
        XCTAssertTrue(g2.shadow.ticker.contains { $0.text.contains("refuse") })
        // Nobody lives in Antarctica or on an empty island to mind the name.
        XCTAssertFalse(RenameTarget.country(Antarctica.id).isInhabited(in: g1))
        let wake0 = g1.getCountry(id: "WAK")?.stability
        XCTAssertTrue(e1.rename(.country("WAK"), to: "Loser Rock").succeeded)
        XCTAssertEqual(g1.getCountry(id: "WAK")?.stability, wake0, "an empty island has no people to react")
    }

    func testRenameConsequencesAreDeterministic() throws {
        func play() throws -> (String, [Int], UInt64) {
            let (e, gs) = try game(seed: 77)
            e.rename(.country("MEX"), to: "asdfasdf")
            e.rename(.country("USA"), to: "Freedonia")
            e.rename(.country("CUB"), to: "ShitGibbon")
            var rng = gs.rng
            return (gs.shadow.ticker.map(\.text).joined(separator: "|"), gs.countries.map(\.stability), rng.next())
        }
        let a = try play(), b = try play()
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
        XCTAssertEqual(a.2, b.2)
    }

    // MARK: Functional: the command box

    func testParserReadsRenameCommandsKeepingTheNameAsTyped() throws {
        let i = try XCTUnwrap(CommandParser.parse("rename Mexico to \"Port O'Brien-Smith\""))
        XCTAssertEqual(i.verb, .rename)
        XCTAssertEqual(i.renames, [RenameRequest(target: "mexico", name: "Port O'Brien-Smith")])
        XCTAssertEqual(CommandParser.parse("Please rename my country to Freedonia.")?.renames, [RenameRequest(target: "me", name: "Freedonia")])
        XCTAssertEqual(CommandParser.parse("rename the United States as Land of the Free")?.renames?.first?.name, "Land of the Free")
        XCTAssertEqual(CommandParser.parse("rename Cuba")?.renames, [])
        XCTAssertEqual(CommandParser.parse("sanction Iran")?.verb, .sanction, "other orders unchanged")
    }

    func testCommandBoxRenameCardRunsWithNoActionsLeft() throws {
        let (e, gs) = try game()
        gs.actionsUsedThisTurn = gs.actionsPerTurn
        guard case .plan(let p) = e.planCommand(try XCTUnwrap(CommandParser.parse("rename my country to Freedonia")), source: .parser) else {
            return XCTFail("expected a card")
        }
        XCTAssertEqual(p.title, "RENAME")
        XCTAssertEqual(p.actionsNeeded, 0)
        XCTAssertEqual(p.orders, [GameOrder(kind: .rename, target: "USA", detail: "Freedonia")])
        XCTAssertEqual(p.committed, ["United States → Freedonia"])
        let r = e.executeCommand(p.orders, source: .parser)
        XCTAssertEqual(r.carried.count, 1)
        XCTAssertEqual(gs.getPlayerCountry()?.name, "Freedonia")
        XCTAssertEqual(gs.shadow.commandLog.last?.orders.first?.detail, "Freedonia", "the replay keeps the order")
    }

    func testCommandBoxRefusesWithNeutralReasons() throws {
        let (e, _) = try game()
        func refusal(_ text: String) -> String? {
            if case .rejected(let why) = e.planCommand(CommandParser.parse(text) ?? CommandIntent(), source: .parser) { return why }
            return nil
        }
        XCTAssertEqual(refusal("rename Mexico to racismland"), NameScreen.blockedReason)
        XCTAssertEqual(refusal("rename France to Gaul"), "France isn't yours to rename. You can rename your own country and the lands you hold.")
        XCTAssertNotNil(refusal("rename Cuba"))
        XCTAssertEqual(e.orderProblem(GameOrder(kind: .rename, target: "MEX", detail: "Nazistan")), NameScreen.blockedReason, "a tampered order is checked again")
        XCTAssertFalse(e.executeOrder(GameOrder(kind: .rename, target: "FRA", detail: "Gaul")))
    }

    // MARK: Functional: the chief of staff

    func testChiefOfStaffProposesSeveralRenamesOnOneCard() throws {
        let (e, gs) = try game()
        let renames: [[String: Any]] = [["target": "Mexico", "name": "Alpha"], ["target": "Cuba", "name": "Bravo"],
                                        ["target": "me", "name": "Charlie Republic"], ["target": "France", "name": "Delta"],
                                        ["target": "Cuba", "name": "Pornland"]]
        let out = ChatTools.run("propose_orders", arguments: ["steps": [["verb": "rename", "renames": renames]]], engine: e, planID: 3)
        XCTAssertFalse(out.isError, out.text)
        guard case .plan(let p)? = out.plan?.steps.first?.outcome else { return XCTFail(out.text) }
        XCTAssertEqual(p.orders.map(\.target), ["MEX", "CUB", "USA"])
        XCTAssertTrue(p.warnings.contains { $0.text.hasPrefix("Left out: France") })
        XCTAssertFalse(out.text.contains("Pornland"), "the refused name is not echoed")
        XCTAssertEqual(gs.getCountry(id: "MEX")?.name, "Mexico", "nothing runs before EXECUTE")
        e.executeCommand(p.orders, source: .chat)
        XCTAssertEqual(gs.getCountry(id: "MEX")?.name, "Alpha")
        XCTAssertEqual(gs.getPlayerCountry()?.name, "Charlie Republic")
        // Too many on one card, and a single rename with targets + name.
        let many = (0...CommandParser.maxRenames).map { ["target": "Mexico", "name": "N\($0)"] }
        XCTAssertTrue(ChatTools.run("propose_orders", arguments: ["steps": [["verb": "rename", "renames": many]]], engine: e).isError)
        let one = ChatTools.run("propose_orders", arguments: ["steps": [["verb": "rename", "targets": ["Alpha"], "name": "Echo"]]], engine: e)
        guard case .plan(let q)? = one.plan?.steps.first?.outcome else { return XCTFail(one.text) }
        XCTAssertEqual(q.orders, [GameOrder(kind: .rename, target: "MEX", detail: "Echo")])
        XCTAssertTrue(ChatTools.run("game_status", arguments: [:], engine: e).text.contains("held_lands"))
    }

    // MARK: One rename path for seas, mountains and departments

    func testSeasAndDepartmentsGoThroughTheSameRenamePathAndHall() throws {
        let (e, gs) = try game()
        gs.actionsUsedThisTurn = gs.actionsPerTurn
        let i = try XCTUnwrap(CommandParser.parse("rename the Gulf of Mexico to Gulf of Plenty"))
        guard case .plan(let p) = e.planCommand(i, source: .parser) else { return XCTFail("expected a card") }
        XCTAssertEqual(p.actionsNeeded, 0)
        XCTAssertEqual(e.executeCommand(p.orders, source: .parser).carried.count, 1)
        XCTAssertEqual(gs.shadow.powerPlays.featureNames["GEO_GULF_MEXICO"], "Gulf of Plenty")
        XCTAssertEqual(CartographyHall.entries().first?.kind, "feature")
        XCTAssertEqual(CartographyHall.lastName(forLand: "GEO_GULF_MEXICO"), "Gulf of Plenty")
        // The content check is the same for every target.
        XCTAssertEqual(e.renamePlaceProblem("GEO_ALPS", to: "Nazistan"), NameScreen.blockedReason)
        XCTAssertEqual(e.rename(.feature("GEO_ALPS"), to: "racismland"), .refused(NameScreen.blockedReason))
        XCTAssertNotNil(e.renamePlaceProblem("GEO_ALPS", to: "see https://example.com"))
        // The chief of staff can mix lands and places on one card.
        let out = ChatTools.run("propose_orders", arguments: ["steps": [["verb": "rename", "renames": [
            ["target": "Mexico", "name": "Alpha"], ["target": "the Pentagon", "name": "Department of Peace"]]]]], engine: e, planID: 9)
        guard case .plan(let q)? = out.plan?.steps.first?.outcome else { return XCTFail(out.text) }
        XCTAssertEqual(q.orders.map(\.target), ["MEX", "DEPT_DEFENSE"])
        e.executeCommand(q.orders, source: .chat)
        XCTAssertEqual(gs.shadow.powerPlays.departmentNames["DEPT_DEFENSE"], "Department of Peace")
        XCTAssertEqual(Set(CartographyHall.entries().map(\.kind)), ["feature", "land", "department"])
    }

    // MARK: Saves

    func testOldSaveWithABlockedNameShowsTheRealName() throws {
        let (_, gs) = try game()
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "MEX" })
        // As a 3.35 save would hold it: the name was accepted then.
        gs.countries[i].name = "racismland"
        gs.shadow.renames = [RenameRecord(land: "MEX", from: "Mexico", to: "racismland", date: gs.currentDate)]
        gs.shadow.post("Mexico is renamed racismland by order of the President.", date: gs.currentDate, severity: 1)
        gs.shadow.logWar("Mexico renamed racismland.")
        let record = try SaveCodec.record(gs, slot: 1)
        let loaded = try SaveCodec.decode(record.payload, schemaVersion: record.schemaVersion)
        XCTAssertEqual(loaded.getCountry(id: "MEX")?.name, "Mexico")
        XCTAssertEqual(loaded.shadow.renames.first?.to, "Mexico")
        XCTAssertFalse(loaded.shadow.ticker.contains { $0.text.contains("racismland") })
        XCTAssertFalse(loaded.shadow.warLog.contains { $0.contains("racismland") })
        XCTAssertEqual(NameScreen.shown("racismland", fallback: "Mexico"), "Mexico")
    }

    func testRenamedGameRoundTripsThroughASave() throws {
        let (e, gs) = try game()
        e.rename(.country("USA"), to: "Freedonia")
        e.rename(.country("CUB"), to: "ShitGibbon")
        let record = try SaveCodec.record(gs, slot: 1)
        let loaded = try SaveCodec.decode(record.payload, schemaVersion: record.schemaVersion)
        XCTAssertEqual(loaded.getPlayerCountry()?.name, "Freedonia")
        XCTAssertEqual(loaded.getCountry(id: "CUB")?.name, "ShitGibbon", "crude names survive a load")
        XCTAssertEqual(loaded.shadow.renames.count, 2)
        // An order saved before 3.36 (no name field) still decodes.
        let old = #"{"kind":"action","target":"FRA","action":"Sanctions"}"#
        XCTAssertNil(try JSONDecoder().decode(GameOrder.self, from: Data(old.utf8)).detail)
        let intent = #"{"targets":["France"],"forces":{"all":false,"tactical":false,"light":false}}"#
        XCTAssertNil(try JSONDecoder().decode(CommandIntent.self, from: Data(intent.utf8)).renames)
    }

    // MARK: The Hall of Cartography

    func testHallKeepsEveryNameAcrossGamesOutsideTheSave() throws {
        let (e1, g1) = try game(seed: 1)
        e1.rename(.country("CUB"), to: "Frostheim")
        let (e2, _) = try game(seed: 2)
        e2.rename(.country("CUB"), to: "Snowhold")
        e2.rename(.country("USA"), to: "Freedonia")
        let all = CartographyHall.entries()
        XCTAssertEqual(all.map(\.to), ["Freedonia", "Snowhold", "Frostheim"])
        XCTAssertEqual(Set(all.map(\.game)).count, 2)
        XCTAssertEqual(all.last?.from, "Cuba")
        XCTAssertEqual(all.last?.kind, "land")
        XCTAssertEqual(all.first?.kind, "nation")
        XCTAssertEqual(all.first?.gameLabel, "United States, 2025")
        XCTAssertEqual(CartographyHall.lastName(forLand: "CUB"), "Snowhold")
        XCTAssertNil(CartographyHall.lastName(forLand: "ATA"))
        // Persisted beside the store, read back after the cache is dropped; never in the save.
        CartographyHall.reset()
        XCTAssertEqual(CartographyHall.entries().count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: hallFolder.appendingPathComponent(CartographyHall.fileName).path))
        let payload = String(decoding: try SaveCodec.record(g1, slot: 1).payload, as: UTF8.self)
        XCTAssertFalse(payload.contains("Snowhold"))
        // In memory only when no folder is set.
        CartographyHall.folder = nil
        CartographyHall.reset()
        XCTAssertTrue(CartographyHall.entries().isEmpty)
    }

    #if os(macOS)
    func testNamesTabAndRenameSheetRenderInBothSkins() throws {
        let (e, gs) = try game()
        e.rename(.country("CUB"), to: "Frostheim")
        e.rename(.country("USA"), to: "Freedonia")
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let views: [AnyView] = [
                AnyView(RecordsSheet(gameState: gs, hall: [:], tab: .names)),
                AnyView(TerritoryNameSheet(gameState: gs, countryID: "USA", live: false, name: "Nazistan").environmentObject(e)),
            ]
            for v in views {
                let r = ImageRenderer(content: v.frame(width: 640, height: 700))
                r.scale = 1
                XCTAssertNotNil(r.cgImage, theme.rawValue)
            }
        }
    }
    #endif
}
