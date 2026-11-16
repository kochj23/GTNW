//
//  Release328Tests.swift
//  GTNWTests
//
//  3.28.0 in all seven categories: no DEFCON before 1959, a finished presidency is a win, map flashes, small
//  islands (claim, seize, develop, no revolt, change hands with their owner), the war card's "Declare war on X"
//  plan, and Nova's leaked reasoning kept off the ticker.
//

import XCTest
import SwiftUI
@testable import GTNW

enum R328 {
    @MainActor
    static func game(_ year: Int? = nil) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA", year: year)
        return (e, try XCTUnwrap(e.gameState))
    }

    static let leaked = "Hmm, the user wants me to roleplay as Nova, a dry and sardonic commentator for a Cold War strategy game."
}

final class Release328UnitTests: XCTestCase {
    /// Unit: DEFCON is named from 1959; before that the meter is the ALERT level, and before Trinity level 1 is total war.
    @MainActor
    func testDefconNameFollowsTheEra() throws {
        XCTAssertEqual(EraWords.localize("DEFCON 1 - NUCLEAR WAR", year: 1812), "Alert level 1 - TOTAL WAR")
        XCTAssertEqual(EraWords.localize("DEFCON 1 - NUCLEAR WAR", year: 1950), "Alert level 1 - NUCLEAR WAR")
        XCTAssertEqual(EraWords.localize("DEFCON 1 - NUCLEAR WAR", year: 1962), "DEFCON 1 - NUCLEAR WAR")
        XCTAssertEqual(EraWords.localizeAlert("Chief of Staff: DEFCON raised", year: 1850), "Chief of Staff: Alert level raised",
                       "log lines change only the readiness words")
        let (_, old) = try R328.game(1850)
        XCTAssertEqual(old.defconName, "ALERT")
        XCTAssertFalse(old.defconLabel.contains("DEFCON"))
        let (_, now) = try R328.game()
        XCTAssertEqual(now.defconName, "DEFCON")
    }

    /// Unit: term limit and retirement are finishes; losing, impeachment and the rest are not.
    func testServedOutEndings() {
        XCTAssertEqual(Set(DomesticEnding.allCases.filter(\.servedOut)), [.termLimited, .retired])
    }

    /// Unit: an island's era and label (India's, not "British India", after 1947).
    @MainActor
    func testNorthSentinelEras() throws {
        XCTAssertEqual(PreStateModel.era(for: "NSI", year: 1800)?.kind, .indigenous)
        XCTAssertEqual(PreStateModel.era(for: "NSI", year: 1900)?.owner, "GBR")
        let (_, gs) = try R328.game()
        let st = try XCTUnwrap(gs.preState("NSI"))
        XCTAssertEqual(st.label, "North Sentinel Island (India)")
        XCTAssertTrue(Islands.uninhabited("BVT"))
        XCTAssertFalse(Islands.uninhabited("NSI"), "the Sentinelese live there")
        XCTAssertNotNil(WorldCountriesDatabase.template(id: "CPT"))
    }

    /// Unit (regression): a reasoning model's cut-off scratchpad never becomes Nova's line.
    func testLeakedReasoningIsRejected() {
        XCTAssertNil(NovaCommentary.clean(R328.leaked))
        XCTAssertNil(NovaCommentary.clean("Okay, so the player lost. Let me think"))
        XCTAssertEqual(NovaCommentary.clean("Bold move, sinking your own fleet."), "Bold move, sinking your own fleet.")
        XCTAssertEqual(AIOutputSanitizer.clean("thinking about it...</think>Nice war."), "Nice war.")
    }
}

final class Release328NationTests: XCTestCase {
    /// Functional (regression): playing France, a world emergency evacuates French citizens, not Americans.
    @MainActor
    func testEmergencyCardsSpeakForThePlayersNation() throws {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "FRA")
        let gs = try XCTUnwrap(e.gameState)
        let quake = try XCTUnwrap(EmergencyCatalog.all.first { $0.responses.contains(.evacuation) })
        let host = try XCTUnwrap(gs.getCountry(id: "BRA"), "a third country, not the United States")
        e.crisisManager.activeCrisis = nil
        e.crisisManager.presentCrisis(WorldWatch.emergencyCrisis(quake, in: host, gs: gs))
        let card = try XCTUnwrap(e.crisisManager.activeCrisis)
        let text = ([card.title, card.description] + card.options.flatMap { [$0.title, $0.description, $0.consequences.message] }).joined(separator: " ")
        XCTAssertFalse(text.contains("American"), text)
        XCTAssertFalse(text.contains("United States"), text)
        XCTAssertTrue(card.options.contains { $0.title == "Evacuate our citizens" })
        XCTAssertTrue(card.description.contains("What will France do?"))
    }
}

final class Release328FunctionalTests: XCTestCase {
    /// Functional (regression, session 7a806b5e): two full terms ending under the 22nd Amendment is a victory.
    @MainActor
    func testTermLimitIsAVictoryNotADefeat() throws {
        let (e, gs) = try R328.game()
        e.endPresidency(.termLimited)
        XCTAssertFalse(VictoryChecker.checkDefeat(gameState: gs).defeated)
        XCTAssertEqual(VictoryChecker.checkVictory(gameState: gs), .servedFullTerm)
        XCTAssertEqual(gs.shadow.domesticEnding, .termLimited, "the check leaves the ending in place")
        e.endPresidency(.impeached)   // already ended: no change
        XCTAssertEqual(gs.shadow.domesticEnding, .termLimited)
    }

    /// Functional: an uninhabited island is taken whatever the roll, never revolts, and can be developed.
    @MainActor
    func testClaimAndDevelopAnEmptyIsland() throws {
        let (e, gs) = try R328.game(1850)
        XCTAssertEqual(gs.preState("BVT")?.era.kind, .indigenous)
        XCTAssertEqual(e.claimIndigenousLand("BVT", troops: 1, roll: 0.999), true)
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "BVT" })
        XCTAssertEqual(gs.countries[i].territoryOf, "USA")
        gs.countries[i].stability = 2
        gs.shadow.garrisons["BVT"] = 0
        e.processOccupation()
        XCTAssertEqual(gs.getCountry(id: "BVT")?.territoryOf, "USA", "nobody there to rise up")
        XCTAssertEqual(gs.getCountry(id: "BVT")?.profile.outcry, 0)
        gs.shadow.aidRemaining = 5
        let before = ExpansionModel.annualIncome(try XCTUnwrap(gs.getCountry(id: "BVT")), in: gs)
        XCTAssertTrue(e.developIsland("BVT", .farms))
        XCTAssertTrue(e.developIsland("BVT", .militaryBase))
        XCTAssertGreaterThan(ExpansionModel.annualIncome(try XCTUnwrap(gs.getCountry(id: "BVT")), in: gs), before)
        XCTAssertEqual(gs.shadow.aidRemaining, 3.7, accuracy: 0.001)
        XCTAssertNotNil(e.islandProjectProblem(.airstrip, on: "BVT"), "no airstrips in 1850")
    }

    /// Functional: the war card offers war on either side, and the plan declares war and sends troops.
    @MainActor
    func testWarCardDeclaresOnEitherSide() throws {
        let (e, gs) = try R328.game()
        let ven = try XCTUnwrap(gs.getCountry(id: "VEN")), guy = try XCTUnwrap(gs.getCountry(id: "GUY"))
        e.declareWar(aggressor: "VEN", defender: "GUY")
        XCTAssertEqual(gs.mapFlashes.last?.ids, ["VEN", "GUY"])
        XCTAssertEqual(gs.mapFlashes.last?.tone, .hostile)
        let card = try XCTUnwrap(WorldWatch.warCrisis(aggressor: ven, defender: guy, gs: gs))
        let titles = card.options.map(\.title)
        XCTAssertTrue(titles.contains("Declare war on Venezuela"))
        XCTAssertTrue(titles.contains("Declare war on Guyana"))
        let pick = try XCTUnwrap(titles.firstIndex(of: "Declare war on Venezuela"))
        e.crisisManager.activeCrisis = nil
        e.crisisManager.presentCrisis(card)
        var g = gs
        e.crisisManager.resolveCrisis(optionIndex: pick, gameState: &g)
        XCTAssertTrue(gs.getCountry(id: "USA")?.atWarWith.contains("VEN") == true)
        XCTAssertFalse(gs.getCountry(id: "USA")?.atWarWith.contains("GUY") == true)
        XCTAssertTrue(gs.shadow.fronts.contains { $0.attacker == "VEN" && $0.defender == "GUY" && $0.usSide == "GUY" && $0.usTroops > 0 },
                      "troops moved to Guyana's front")
    }
}

final class Release328IntegrationTests: XCTestCase {
    /// Integration: annexing a country brings its islands (India's North Sentinel) with it.
    @MainActor
    func testIslandsChangeHandsWithTheirOwner() throws {
        let (e, gs) = try R328.game()
        XCTAssertEqual(gs.preState("NSI")?.era.owner, "IND")
        let s = PostWarSettlement(loser: "IND", victor: "USA", date: gs.currentDate)
        gs.shadow.pendingSettlements.append(s)
        XCTAssertTrue(e.settle(s.id, choice: .annex))
        XCTAssertEqual(gs.getCountry(id: "NSI")?.territoryOf, "USA")
    }

    /// Integration: an AI power claims an unheld island; built projects survive a save round trip.
    @MainActor
    func testAITakesIslandsAndProjectsAreSaved() throws {
        let (e, gs) = try R328.game(1850)
        XCTAssertTrue(e.aiTakeLand("WAK", by: "GBR"))
        XCTAssertEqual(gs.getCountry(id: "WAK")?.territoryOf, "GBR")
        gs.shadow.islandProjects["BVT"] = [.fishery]
        let back = try JSONDecoder().decode(ShadowState.self, from: JSONEncoder().encode(gs.shadow))
        XCTAssertEqual(back.islandProjects["BVT"], [.fishery])
    }
}

final class Release328SecurityTests: XCTestCase {
    /// Security: no building on someone else's land, twice, or on credit; no war plan against yourself.
    @MainActor
    func testIllegalOrdersAreRefused() throws {
        let (e, gs) = try R328.game(1850)
        gs.shadow.aidRemaining = 0.1
        XCTAssertFalse(e.developIsland("GBR", .farms))
        XCTAssertEqual(e.claimIndigenousLand("BVT", troops: 1, roll: 0), true)
        XCTAssertFalse(e.developIsland("BVT", .militaryBase), "can't afford it")
        gs.shadow.aidRemaining = 5
        XCTAssertTrue(e.developIsland("BVT", .fishery))
        XCTAssertFalse(e.developIsland("BVT", .fishery), "one of each")
        let wars = gs.activeWars.count
        e.executeWarPlan(against: "USA")
        e.executeWarPlan(against: "NOPE")
        XCTAssertEqual(gs.activeWars.count, wars)
        XCTAssertNil(NovaCommentary.clean("<think>plan</think>"))
    }
}

final class Release328RetryTests: XCTestCase {
    /// Retry: declaring the same war twice (or a blockade on an enemy) never makes a second war record.
    @MainActor
    func testDeclareWarIsIdempotent() throws {
        let (e, gs) = try R328.game()
        e.declareWar(aggressor: "USA", defender: "VEN")
        e.declareWar(aggressor: "USA", defender: "VEN")
        e.executeWarPlan(against: "VEN")
        XCTAssertEqual(gs.activeWars.filter { $0.aggressor == "USA" && $0.defender == "VEN" }.count, 1)
    }
}

final class Release328PerformanceTests: XCTestCase {
    /// Performance: island status lookups stay cheap enough to run every frame.
    @MainActor
    func testIslandLookups() throws {
        let (_, gs) = try R328.game()
        measure { for _ in 0..<50 { _ = gs.colonyLandIDs; _ = gs.indigenousLandIDs } }
    }
}

#if os(macOS)
final class Release328FrameTests: XCTestCase {
    /// UI state: the map draws flashes and island dots, with an island selected, in both skins.
    @MainActor
    func testMapRendersFlashesAndIslands() throws {
        let (_, gs) = try R328.game()
        defer { Theme.forced = nil }
        gs.flash(["IND", "PAK"], .hostile)
        gs.flash(["JPN"], .disaster)
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let map = VectorWorldMap(gameState: gs, selectedCountryID: .constant("NSI"), zoom: .constant(.world), filter: .constant(.alignment))
                .frame(width: 1000, height: 500)
            let r = ImageRenderer(content: map)
            r.scale = 1
            XCTAssertNotNil(r.cgImage, "map failed to render in \(theme)")
        }
    }
}
#endif
