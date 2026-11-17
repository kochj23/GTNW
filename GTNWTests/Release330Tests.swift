//
//  Release330Tests.swift
//  GTNWTests
//
//  3.30.0 in all seven categories: the historical war base rates and open records bundled, the attrition model
//  calibrated to them, the base-rate line for AI brains, and the open record's wars added to the era's rivalries.
//

import XCTest
import SwiftUI
@testable import GTNW

final class Release330UnitTests: XCTestCase {
    /// Unit: the bundled base rates load, with the era and bucket lookups and a fallback to the era's row.
    func testBaseRatesLoad() throws {
        XCTAssertFalse(HistoricalWars.rates.isEmpty, "base_rates.json is bundled")
        let cold = try XCTUnwrap(HistoricalWars.interstate(year: 1970))
        XCTAssertEqual(cold.median_months, 4.7, accuracy: 0.05)
        XCTAssertEqual(HistoricalWars.era(1815), "1789-1815")
        XCTAssertEqual(HistoricalWars.era(2025), "1992-present")
        XCTAssertEqual(HistoricalWars.bucket(strongerShare: 0.5), "even")
        XCTAssertEqual(HistoricalWars.bucket(strongerShare: 0.95), "overwhelming")
        let even = HistoricalWars.interstate(year: 1970, strongerShare: 0.5)
        XCTAssertEqual(even, cold, "an even bucket of under five wars falls back to the era's row")
        for era in [1800, 1850, 1900, 1930, 1970, 2020] {
            let r = try XCTUnwrap(HistoricalWars.interstate(year: era))
            XCTAssertLessThanOrEqual(r.q1_months, r.median_months)
            XCTAssertLessThanOrEqual(r.median_months, r.q3_months)
            XCTAssertLessThanOrEqual(r.decisive + r.negotiated, 1.001)
        }
    }

    /// Unit: the prompt line names the era, the median and the outcome shares.
    func testBaseRateLine() throws {
        let line = try XCTUnwrap(HistoricalWars.line(year: 1970))
        XCTAssertTrue(line.hasPrefix("Interstate wars 1946–1991: median 4.7 months"), line)
        XCTAssertTrue(line.contains("% ended in a ceasefire or settlement"))
    }
}

final class Release330FunctionalTests: XCTestCase {
    /// Functional: the attrition model's surrender floor and ceasefire odds follow the era's base rates.
    func testAttritionFollowsTheBaseRates() throws {
        let napoleonic = AttritionModel.minimumWeeks(year: 1805, difficulty: .normal)
        let late19th = AttritionModel.minimumWeeks(year: 1880, difficulty: .normal)
        XCTAssertGreaterThan(napoleonic, late19th, "Napoleonic wars ran far longer than the wars of 1871-1913")
        XCTAssertTrue((13...78).contains(late19th) && (13...78).contains(napoleonic))
        XCTAssertLessThan(AttritionModel.minimumWeeks(year: 1970, difficulty: .nightmare), AttritionModel.minimumWeeks(year: 1970, difficulty: .easy))
        var f = WarFront(attacker: "IND", defender: "PAK", startDate: Date(), lastBattle: Date(), attackerTroops: 100, defenderTroops: 100, attackerInitial: 100, defenderInitial: 100)
        f.battles = 2
        XCTAssertEqual(AttritionModel.ceasefireChance(f, year: 1970), 0, "not before the era's median length")
        f.battles = 60
        XCTAssertGreaterThan(AttritionModel.ceasefireChance(f, year: 1970), 0)
        f.attackerMomentum = 0.9
        XCTAssertEqual(AttritionModel.ceasefireChance(f, year: 1970), 0, "nobody settles while winning")
    }

    /// Functional: an open-record war the table lacked is a rivalry now (the Quasi-War, 1798).
    func testOpenWarsJoinTheRivalries() {
        XCTAssertFalse(HistoricalWars.openWars.isEmpty)
        XCTAssertTrue(WorldPolitics.rivalries.contains { $0.war && $0.a == "USA" && $0.b == "FRA" && $0.from == 1798 })
        XCTAssertFalse(WorldPolitics.rivalries.contains { $0.a == "IRN" && $0.b == "ISR" }, "ongoing open wars are not added")
    }
}

final class Release330IntegrationTests: XCTestCase {
    /// Integration: the brain's move request carries the era's base rate.
    @MainActor
    func testMoveRequestCarriesTheBaseRate() throws {
        let (e, _) = try R329.game(1970)
        let req = try XCTUnwrap(e.buildMoveRequest(for: "IND"))
        XCTAssertTrue(req.worldStateSummary.contains("History: Interstate wars 1946–1991"))
        XCTAssertTrue(BrainClient.userPrompt(req).contains("median 4.7 months"))
    }

    /// Integration: the 3.29.0 promise still holds under the calibration: Russia–Ukraine runs past 24 months in most
    /// seeds, while two comparable non-rivals can settle.
    @MainActor
    func testCalibratedWarsStillLast() throws {
        let (e, gs) = try R329.game(2025)
        gs.turnLength = .month
        let countries = gs.countries, wars = gs.activeWars, fronts = gs.shadow.fronts, turn = gs.turn
        var running = 0
        for seed in 1...10 {
            gs.countries = countries; gs.activeWars = wars; gs.shadow.fronts = fronts; gs.turn = turn
            gs.rng = GameRNG(seed: UInt64(seed + 100))
            e.declareWar(aggressor: "RUS", defender: "UKR")
            e.syncFronts()
            R329.fight(e, gs, months: 24)
            if R329.fighting(gs, "RUS", "UKR") { running += 1 }
        }
        XCTAssertGreaterThanOrEqual(running, 8, "still fighting in \(running)/10")
    }
}

final class Release330SecurityTests: XCTestCase {
    /// Security: no Correlates of War record is bundled: open_wars holds only UCDP and curated records, base_rates
    /// only aggregates, and the raw COW files stay out of the app.
    func testOnlyOpenRecordsShip() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "open_wars", withExtension: "json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertTrue((root["attribution"] as? String)?.contains("CC BY 4.0") ?? false)
        let wars = try XCTUnwrap(root["wars"] as? [[String: Any]])
        XCTAssertTrue(wars.allSatisfy { ["UCDP-ACD", "curated"].contains($0["source"] as? String ?? "") })
        let rates = try String(contentsOf: try XCTUnwrap(Bundle.main.url(forResource: "base_rates", withExtension: "json")), encoding: .utf8)
        XCTAssertFalse(rates.contains("\"side_a\""), "aggregates only")
        XCTAssertFalse(rates.contains("cow-inter-"))
        for raw in ["wars", "Inter-StateWarData_v4.0", "NMCv7", "States2024"] {
            XCTAssertNil(Bundle.main.url(forResource: raw, withExtension: raw == "wars" ? "json" : nil), raw)
        }
        XCTAssertNil(Bundle.main.url(forResource: "Inter-StateWarData_v4.0", withExtension: "csv"))
    }
}

final class Release330RetryTests: XCTestCase {
    /// Retry: without base rates (a missing resource) the model falls back to the 3.29.0 constants.
    func testFallbackWithoutRates() throws {
        var f = WarFront(attacker: "A", defender: "B", startDate: Date(), lastBattle: Date(), attackerTroops: 100, defenderTroops: 100, attackerInitial: 100, defenderInitial: 100)
        f.battles = 200
        let r = try JSONDecoder().decode(HistoricalWars.Rate.self, from: Data(#"{"n":3,"median_months":1,"q1_months":1,"q3_months":2,"decisive":1,"negotiated":0,"initiator_won":null,"extra":5}"#.utf8))
        XCTAssertEqual(r.n, 3, "older or newer base-rate files still decode")
        XCTAssertEqual(HistoricalWars.bucket(strongerShare: 0.65), "lopsided")
        XCTAssertGreaterThan(AttritionModel.ceasefireChance(f, year: 1970), 0)
        XCTAssertLessThanOrEqual(AttritionModel.ceasefireChance(f, year: 1970), 0.05, "capped")
    }
}

final class Release330PerformanceTests: XCTestCase {
    /// Performance: base-rate lookups are cheap enough for every week of every front.
    func testLookupsAreCheap() {
        _ = HistoricalWars.rates
        measure { for y in 1789...2030 { _ = AttritionModel.minimumWeeks(year: y, difficulty: .normal, strongerShare: 0.7) } }
    }
}

#if os(macOS)
final class Release330FrameTests: XCTestCase {
    /// Frame: the Records sheet still renders in a 1798 game with the Quasi-War on the board.
    @MainActor
    func testRecordsRenderWithOpenWars() throws {
        let (_, gs) = try R329.game(1798)
        let r = ImageRenderer(content: RecordsSheet(gameState: gs, hall: [:]))
        r.scale = 1
        XCTAssertNotNil(r.cgImage)
    }
}
#endif
