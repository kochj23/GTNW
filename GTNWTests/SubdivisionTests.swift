//
//  SubdivisionTests.swift
//  GTNWTests
//
//  3.36.0: states and provinces. Data integrity (the states by year, the electors), the map (geometry for every
//  subdivision, a rendered map in both skins), the election counted state by state, secession, occupation and the
//  annex-provinces peace, the chief of staff and order targets, saves, and determinism.
//

import XCTest
import SwiftUI
@testable import GTNW

enum SubFixtures {
    @MainActor
    static func engine(year: Int = 2025, player: String = "USA", seed: UInt64 = 36, turnLength: TurnLength = .month) -> GameEngine {
        let e = GameEngine()
        e.startNewGame(playerCountryID: player, turnLength: turnLength, year: year, seed: seed)
        e.crisisManager.activeCrisis = nil
        return e
    }

    /// U.S. states of the Union on a day (not territories, not the District).
    static func states(_ gs: GameState) -> [Subdivision] {
        gs.subdivisions(of: "USA").filter { Subdivisions.isUSState($0.id, on: gs.currentDate) }
    }
}

// MARK: - Data

final class SubdivisionDataTests: XCTestCase {

    func testRowsParseWithUniqueIDs() {
        XCTAssertGreaterThan(Subdivisions.all.count, 500)
        XCTAssertEqual(Set(Subdivisions.all.map(\.id)).count, Subdivisions.all.count)
        XCTAssertEqual(Subdivisions.byNation["USA"]?.count, 51, "50 states and the District")
        for n in ["USA", "CAN", "MEX", "BRA", "RUS", "CHN", "IND", "AUS", "DEU", "FRA", "GBR", "JPN"] {
            XCTAssertFalse(Subdivisions.byNation[n, default: []].isEmpty, n)
        }
        XCTAssertEqual(Subdivisions.byNation["GBR"]?.map(\.name).sorted(), ["England", "Northern Ireland", "Scotland", "Wales"])
        XCTAssertEqual(Subdivisions.byNation["DEU"]?.count, 16)
        XCTAssertEqual(Subdivisions.byNation["JPN"]?.count, 47)
        XCTAssertEqual(Subdivisions.byNation["CAN"]?.count, 13)
        for s in Subdivisions.all {
            XCTAssertFalse(s.name.isEmpty, s.id)
            XCTAssertTrue((-90...90).contains(s.lat) && (-180...180).contains(s.lon), s.id)
            XCTAssertGreaterThan(s.weight, 0, s.id)
        }
    }

    @MainActor
    func testUSStateCountByYear() {
        XCTAssertEqual(SubFixtures.states(SubFixtures.engine(year: 1789).gameState!).count, 13, "the thirteen original states")
        XCTAssertEqual(SubFixtures.states(SubFixtures.engine(year: 1950).gameState!).count, 48)
        XCTAssertEqual(SubFixtures.states(SubFixtures.engine(year: 2025).gameState!).count, 50)
        // Admission by date, not by year: Hawaii joined on August 21, 1959.
        XCTAssertFalse(Subdivisions.isUSState("US-HI", on: GameCalendar.date(year: 1959, month: 8, day: 20)))
        XCTAssertTrue(Subdivisions.isUSState("US-HI", on: GameCalendar.date(year: 1959, month: 8, day: 21)))
        XCTAssertEqual(USStatesHistory.original.count + USStatesHistory.admitted.count, 50)
        XCTAssertEqual(OccupationModel.historicalStates(year: 1959), 50, "agrees with the star count")
    }

    @MainActor
    func testTerritoriesBeforeStatehood() {
        let gs = SubFixtures.engine(year: 1870).gameState!
        XCTAssertEqual(gs.provinceName("US-ND"), "Dakota Territory")
        XCTAssertEqual(gs.provinceName("US-SD"), "Dakota Territory")
        XCTAssertEqual(Subdivisions.historical(Subdivisions.byID["US-ND"]!, on: gs.currentDate).kind, "Territory")
        XCTAssertEqual(gs.provinceName("US-OH"), "Ohio")
        XCTAssertEqual(gs.provinceOwner("US-ND"), "USA")
        let early = SubFixtures.engine(year: 1789).gameState!
        XCTAssertNil(early.provinceOwner("US-CA"), "California is not U.S. land in 1789")
        XCTAssertEqual(early.provinceName("US-OH"), "Northwest Territory")
        XCTAssertNil(early.provinceOwner("US-KY"), "Kentucky is part of Virginia until 1792")
    }

    @MainActor
    func testOtherNationsUndividedBeforeTheirModernProvinces() {
        let gs1900 = SubFixtures.engine(year: 1900).gameState!
        XCTAssertTrue(gs1900.subdivisions(of: "CAN").isEmpty)
        XCTAssertTrue(gs1900.subdivisions(of: "CHN").isEmpty)
        XCTAssertTrue(gs1900.subdivisions(of: "DEU").isEmpty)
        let gs1962 = SubFixtures.engine(year: 1962).gameState!
        XCTAssertFalse(gs1962.subdivisions(of: "CAN").isEmpty)
        XCTAssertTrue(gs1962.subdivisions(of: "DEU").isEmpty, "two Germanys: the modern states wait for 1990")
        XCTAssertEqual(gs1962.provinceOwner("UA-43"), "RUS")
    }

    func testElectorsMatchTheOfficialTotals() {
        for (year, total) in [(2024, 538), (1964, 538), (1960, 537), (1912, 531), (1860, 303), (1792, 135)] {
            XCTAssertEqual(ElectionCycle.historicalElectorate(year: year).values.reduce(0, +), total, "\(year)")
        }
        XCTAssertEqual(USStatesHistory.electors("US-CA", year: 2024), 54)
        XCTAssertEqual(USStatesHistory.electors("US-VA", year: 1864), 0, "the Confederate states cast no vote in 1864")
        XCTAssertNil(USStatesHistory.electors("US-DC", year: 1960))
        XCTAssertEqual(USStatesHistory.electors("US-DC", year: 1964), 3)
    }

    @MainActor
    func testPopulationSharesSumToOne() {
        let gs = SubFixtures.engine(year: 2025).gameState!
        for n in ["USA", "RUS", "CHN", "GBR"] {
            XCTAssertEqual(gs.provinceShares(of: n).values.reduce(0, +), 1, accuracy: 0.0001, n)
        }
        XCTAssertGreaterThan(gs.populationShare("US-CA"), gs.populationShare("US-WY") * 20)
    }
}

// MARK: - The map

final class SubdivisionMapTests: XCTestCase {

    func testGeometryCoversEverySubdivision() {
        let geo = SubdivisionGeometry.shared
        XCTAssertGreaterThan(geo.borders.count, 500)
        for s in Subdivisions.all { XCTAssertNotNil(geo.outlines[s.id], s.id) }
        // A point in Kansas is Kansas.
        XCTAssertEqual(geo.hit(CGPoint(x: -98.5, y: -38.5), live: Set(Subdivisions.all.map(\.id))), "US-KS")
        // A city-state wins over the province around it.
        XCTAssertEqual(geo.hit(CGPoint(x: 13.4, y: -52.52), live: Set(Subdivisions.all.map(\.id))), "DE-BE")
    }

    @MainActor
    func testLayerDescribesAndLabels() {
        let gs = SubFixtures.engine(year: 2025).gameState!
        let layer = SubdivisionLayer(gs)
        XCTAssertTrue(layer.describe("US-CA").hasPrefix("California — State"))
        XCTAssertTrue(layer.describe("US-CA").contains("% of the people"))
        XCTAssertTrue(layer.describe("US-CA").contains("United States"))
        let world = CGAffineTransform(scaleX: 4, y: 4)
        XCTAssertTrue(layer.labels(transform: world, zoom: .world).isEmpty, "no labels at world zoom")
        XCTAssertFalse(layer.labels(transform: CGAffineTransform(scaleX: 20, y: 20), zoom: .country).isEmpty)
    }

    #if os(macOS)
    @MainActor
    func testMapRendersStatesInBothSkins() throws {
        let e = SubFixtures.engine(year: 2025)
        let gs = try XCTUnwrap(e.gameState)
        e.secede("US-TX", reason: "for the test")   // a held province is filled in its holder's color
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            for zoom in [MapZoom.world, .country] {
                let map = VectorWorldMap(gameState: gs, selectedCountryID: .constant("USA"), zoom: .constant(zoom), filter: .constant(.alignment))
                let r = ImageRenderer(content: map.frame(width: 900, height: 500))
                r.scale = 1
                guard let cg = r.cgImage else { throw XCTSkip("renderer produced no image") }
                XCTAssertEqual(cg.width, 900)
            }
            gs.shadow.provinces.lastElection = ["US-CA": 60, "US-TX": 40, "US-OH": 50.4]
            gs.shadow.provinces.lastElectionYear = 2028
            let r = ImageRenderer(content: ElectionStateMap(gameState: gs).frame(width: 600))
            XCTAssertNotNil(r.cgImage)
        }
    }
    #endif
}

// MARK: - Elections

final class StateElectionTests: XCTestCase {

    func testCountedStateByState() {
        let t = ElectionCycle.tally(year: 2028, twoPartyShare: 52)
        XCTAssertEqual(t.shares.count, 51)
        XCTAssertEqual(t.stateElectors.values.reduce(0, +), 538)
        let carried = t.shares.filter { $0.value > 50 }.reduce(0) { $0 + t.stateElectors[$1.key]! }
        XCTAssertEqual(carried, t.playerEV, "the electors are the sum of the states carried")
        XCTAssertEqual(t.playerEV + t.opponentEV, 538)
    }

    /// Close states decide a close election: one state's swing changes the winner.
    func testAnElectionDecidedByOneState() throws {
        // Find a national share where the count is closest to a tie, then swing the tipping state the other way.
        var best: (share: Double, t: ElectionCycle.Tally)?
        for k in 0...40 {
            let share = 48 + Double(k) * 0.1
            let t = ElectionCycle.tally(year: 2028, twoPartyShare: share)
            if t.outcome == .won, best == nil || t.playerEV < best!.t.playerEV { best = (share, t) }
        }
        let won = try XCTUnwrap(best)
        let tip = try XCTUnwrap(ElectionCycle.tippingState(won.t))
        let margin = won.t.shares[tip]! - 50
        let flipped = ElectionCycle.tally(year: 2028, twoPartyShare: won.share, swing: [tip: -(margin + 0.5)])
        if won.t.playerEV - won.t.stateElectors[tip]! < won.t.majority {
            XCTAssertNotEqual(flipped.outcome, .won, "\(tip) decided it")
        }
        XCTAssertEqual(flipped.playerEV, won.t.playerEV - won.t.stateElectors[tip]!)
    }

    @MainActor
    func testHoldElectionKeepsTheStateMapAndTellsTheNews() {
        let e = SubFixtures.engine(year: 2025)
        let gs = e.gameState!
        gs.shadow.electionsEnabled = true
        gs.shadow.popularity = 55
        e.holdElection(on: GameCalendar.electionDay(year: 2028))
        XCTAssertEqual(gs.shadow.provinces.lastElectionYear, 2028)
        XCTAssertEqual(gs.shadow.provinces.lastElection.count, 51)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.hasPrefix("Election map:") })
        XCTAssertEqual(gs.shadow.lastElection?.totalEV, 538)
    }

    @MainActor
    func testStatesThatLeftDoNotVote() {
        let e = SubFixtures.engine(year: 2025)
        let gs = e.gameState!
        e.secede("US-CA", reason: "for the test")
        let voters = gs.electorate(on: GameCalendar.electionDay(year: 2028))!
        XCTAssertNil(voters["US-CA"])
        XCTAssertEqual(voters.values.reduce(0, +), 538 - 54)
    }

    @MainActor
    func testConfederateStatesHeldByTheConfederacy() {
        let e = SubFixtures.engine(year: 1862)
        let gs = e.gameState!
        XCTAssertNotNil(gs.getCountry(id: "CSA"))
        XCTAssertEqual(gs.provinceOwner("US-VA"), "CSA")
        XCTAssertEqual(gs.provinceOwner("US-KY"), "USA", "a border state stays")
        XCTAssertEqual(gs.provinceOwner("US-WV"), nil, "West Virginia is admitted in 1863")
        XCTAssertNil(gs.electorate(on: GameCalendar.electionDay(year: 1864))?["US-VA"])
    }
}

// MARK: - Secession, occupation, the peace

final class ProvinceGameplayTests: XCTestCase {

    @MainActor
    func testASecessionMakesANationOnTheMap() throws {
        let e = SubFixtures.engine(year: 2025)
        let gs = try XCTUnwrap(e.gameState)
        let usPeople = gs.getPlayerCountry()!.population
        let id = try XCTUnwrap(e.secede("US-TX", reason: "after the nuclear strikes"))
        let tx = try XCTUnwrap(gs.getCountry(id: id))
        XCTAssertEqual(tx.name, "Texas")
        XCTAssertNil(tx.territoryOf)
        XCTAssertEqual(gs.provinceOwner("US-TX"), id)
        XCTAssertLessThan(gs.getPlayerCountry()!.population, usPeople)
        XCTAssertLessThan(tx.diplomaticRelations["USA"] ?? 0, 0)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Texas declares independence") })
        XCTAssertFalse(gs.provinces(heldBy: "USA").contains { $0.id == "US-TX" })
    }

    @MainActor
    func testCollapseAndATriggerBreakAStateAway() throws {
        let e = SubFixtures.engine(year: 2025, turnLength: .year)
        let gs = try XCTUnwrap(e.gameState)
        let pi = gs.countries.firstIndex { $0.id == "USA" }!
        var seceded: String?
        for _ in 0..<60 where seceded == nil {
            gs.countries[pi].stability = 5
            gs.countries[pi].profile.outcry = 95
            gs.countries[pi].atWarWith = ["MEX"]
            gs.shadow.provinces.names["US-VT"] = "Freedonia"   // a name nobody there chose
            gs.shadow.provinces.occupied["US-VT"] = "MEX"       // and an army in the streets
            e.processSubdivisions()
            seceded = gs.shadow.provinces.seceded.keys.first
        }
        XCTAssertEqual(seceded, "US-VT", "the most restless state goes")
        XCTAssertEqual(gs.getCountry(id: "US-VT")?.name, "Freedonia", "under the name it was given")
    }

    @MainActor
    func testQuietNationsDrawNothingFromTheRNG() throws {
        let e = SubFixtures.engine(year: 2025)
        let gs = try XCTUnwrap(e.gameState)
        let before = gs.rng
        e.processSubdivisions()
        XCTAssertEqual(gs.rng, before, "unrest drifts deterministically; only a province on the edge rolls")
    }

    @MainActor
    func testWonWarRecordsOccupationAndThePeaceAnnexesProvinces() throws {
        let e = SubFixtures.engine(year: 2025)
        let gs = try XCTUnwrap(e.gameState)
        gs.shadow.pendingSettlements.append(PostWarSettlement(loser: "MEX", victor: "USA", date: gs.currentDate))
        e.recordOccupations()
        let s = gs.shadow.pendingSettlements[0]
        let held = e.occupiedProvinces(for: s.id)
        XCTAssertFalse(held.isEmpty)
        XCTAssertLessThan(held.count, gs.subdivisions(of: "MEX").count, "a bare win holds the near provinces, not all")
        XCTAssertTrue(held.contains { $0.id == "MX-CHH" || $0.id == "MX-SON" || $0.id == "MX-TAM" || $0.id == "MX-COA" }, "the border first")
        XCTAssertTrue(e.annexOccupied(s.id))
        for p in held { XCTAssertEqual(gs.provinceOwner(p.id), "USA") }
        XCTAssertTrue(gs.shadow.pendingSettlements.isEmpty)
        XCTAssertNil(gs.getCountry(id: "MEX")?.territoryOf, "Mexico keeps its government")
        let terms = try XCTUnwrap(gs.shadow.peaceTerms.last)
        XCTAssertEqual(Set(terms.territory), Set(held.map(\.id)))
        XCTAssertTrue(gs.renamableProvinces.contains { $0.id == held[0].id }, "the President may rename what he took")
    }
}

// MARK: - Chief of staff and orders

final class ProvinceCommandTests: XCTestCase {

    @MainActor
    func testStateNamesResolveToTheirHolder() {
        let e = SubFixtures.engine(year: 2025)
        let gs = e.gameState!
        guard case .one(.nation(let id), let note) = CommandTargets.resolve("Bavaria", in: gs) else { return XCTFail("Bavaria") }
        XCTAssertEqual(id, "DEU")
        XCTAssertTrue(note?.contains("Bavaria is a state held by") == true)
        guard case .one(.nation(let us), _) = CommandTargets.resolve("California", in: gs) else { return XCTFail("California") }
        XCTAssertEqual(us, "USA")
        guard case .one(.nation(let geo), _) = CommandTargets.resolve("Georgia", in: gs) else { return XCTFail("Georgia") }
        XCTAssertEqual(geo, "GEO", "a nation's exact name wins over a state's")
    }

    @MainActor
    func testLandVerbsOnAProvinceGoToThePeaceTable() {
        let e = SubFixtures.engine(year: 2025)
        guard case .rejected(let why) = CmdFixtures.plan(e, "buy Bavaria") else { return XCTFail("buy Bavaria") }
        XCTAssertTrue(why.contains("peace table"))
    }

    @MainActor
    func testCountryToolListsStatesAndAnswersForOne() {
        let e = SubFixtures.engine(year: 2025)
        let out = ChatTools.run("country", arguments: ["name": "Germany"], engine: e).text
        XCTAssertTrue(out.contains("states_and_provinces"))
        XCTAssertTrue(out.contains("Bavaria"))
        let tx = ChatTools.run("country", arguments: ["name": "Texas"], engine: e).text
        XCTAssertTrue(tx.contains("\"electoral_votes\":40"), tx)
        XCTAssertTrue(tx.contains("United States"))
    }
}

// MARK: - Saves and determinism

final class ProvinceSaveTests: XCTestCase {

    @MainActor
    func testSaveRoundTripAndOldSaves() throws {
        let e = SubFixtures.engine(year: 2025)
        let gs = try XCTUnwrap(e.gameState)
        e.secede("US-VT", reason: "for the test")
        gs.shadow.provinces.names["US-OH"] = "Buckeye Republic"
        gs.shadow.provinces.unrest["US-OH"] = 42
        gs.shadow.provinces.lastElection = ["US-OH": 50.2]
        let loaded = try SaveCodec.decode(try SaveCodec.encode(gs))
        XCTAssertEqual(loaded.shadow.provinces, gs.shadow.provinces)
        XCTAssertEqual(loaded.provinceName("US-OH"), "Buckeye Republic")
        XCTAssertEqual(loaded.provinceOwner("US-VT"), "US-VT")

        // A save from before 3.36 has no ledger: it loads with the subdivisions of its year.
        var shadow = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs.shadow)) as? [String: Any])
        shadow.removeValue(forKey: "provinces")
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: shadow))
        XCTAssertEqual(old.provinces, ProvinceLedger())
        let partial = try JSONDecoder().decode(ProvinceLedger.self, from: Data(#"{"names":{"US-OH":"X"}}"#.utf8))
        XCTAssertEqual(partial.names, ["US-OH": "X"])
        XCTAssertTrue(partial.owners.isEmpty)
    }

    @MainActor
    func testSameSeedSameProvinces() {
        func play() -> ProvinceLedger {
            let e = SubFixtures.engine(year: 2025, seed: 99, turnLength: .year)
            let gs = e.gameState!
            let pi = gs.countries.firstIndex { $0.id == "USA" }!
            for _ in 0..<12 {
                gs.countries[pi].stability = 8
                gs.countries[pi].profile.outcry = 92
                gs.countries[pi].atWarWith = ["CAN"]
                gs.shadow.provinces.occupied["US-ME"] = "CAN"
                e.processSubdivisions()
            }
            return gs.shadow.provinces
        }
        XCTAssertEqual(play(), play())
    }
}
