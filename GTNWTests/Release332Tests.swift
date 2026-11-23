//
//  Release332Tests.swift
//  GTNWTests
//
//  3.32.0: the herd's review notes — visible, fallible pre-war reasoning; a stated casus belli; a war-termination
//  test every war declares before its first move. Seven categories, as every release.
//

import XCTest
import SwiftUI
@testable import GTNW

enum R332 {
    /// A nation set up to be weighed: ambition, ethic, forces, stability.
    @MainActor
    static func shape(_ gs: GameState, _ id: String, ambition: Int? = nil, ethic: Int? = nil, outcry: Double? = nil,
                      military: Int? = nil, stability: Int? = nil, population: Int? = nil, gdp: Double? = nil) {
        guard let i = gs.countries.firstIndex(where: { $0.id == id }) else { return }
        if let a = ambition { gs.countries[i].profile.ambition = a }
        if let e = ethic { gs.countries[i].profile.ethic = e }
        if let m = military { gs.countries[i].militaryStrength = m }
        if let s = stability { gs.countries[i].stability = s }
        if let p = population { gs.countries[i].population = p }
        if let g = gdp { gs.countries[i].gdp = g }
        if let o = outcry { gs.countries[i].profile.outcry = o }
    }

    /// Every player-facing string 3.32 added.
    @MainActor
    static func texts(_ gs: GameState) -> [String] {
        var out = CasusBelli.allCases.flatMap { [$0.title] } + WarBias.allCases.map(\.note)
        out += gs.shadow.deliberations.flatMap { [$0.statement, $0.mustBeTrue, $0.wouldBreakIt, $0.offRamp, $0.doneTest.note]
            + $0.instruments.flatMap { [$0.name, $0.note] } }
        out += gs.shadow.casusLog.map(\.statement)
        out += IntelSource.allCases.flatMap { [$0.title, $0.blindSpot] } + IntelField.allCases.map(\.label)
        out += Doctrine.allCases.map(\.title) + OneSitting.all.flatMap { [$0.title, $0.goal] }
        out += gs.shadow.peaceTerms.map(\.headline) + gs.shadow.sittingDebrief
        out += Debrief.lines(gs).flatMap { [$0.title, $0.body] } + [Legends.markdown(gs)]
        out += gs.shadow.intel.map { $0.line(name: "Ruritania", now: gs.turn) }
        out += gs.shadow.doctrines.compactMap { k, v in
            Doctrine(rawValue: String(k.split(separator: ":").last ?? "")).flatMap { Doctrines.reason($0, v, year: gs.currentYear) }
        }
        return out
    }
}

// MARK: - Unit

final class Release332UnitTests: XCTestCase {
    /// Unit: a reason belongs to its era, and the facts decide what it is worth.
    func testCasusBelliErasAndWeight() {
        XCTAssertTrue(CasusBelli.dynasticClaim.available(year: 1740))
        XCTAssertFalse(CasusBelli.dynasticClaim.available(year: 1990), "no cabinet claims a throne in 1990")
        XCTAssertFalse(CasusBelli.humanitarian.available(year: 1960))
        XCTAssertTrue(CasusBelli.humanitarian.available(year: 1999))
        XCTAssertFalse(CasusBelli.civilisingMission.available(year: 1960))
        XCTAssertTrue(CasusBelli.preemption.available(year: 1950))
        XCTAssertGreaterThan(CasusBelli.defenceOfAlly.weight, CasusBelli.fabricated.weight)
        for c in CasusBelli.allCases {
            XCTAssertEqual(WarCouncil.strength(c, supported: false), c.weight / 3, accuracy: 0.0001)
            XCTAssertGreaterThan(WarCouncil.strength(c, supported: true), WarCouncil.strength(c, supported: false))
            XCTAssertFalse(c.title.isEmpty)
        }
    }

    /// Unit: the three estimates move with the numbers they are made from.
    @MainActor
    func testEstimatesFollowTheNumbers() throws {
        let (_, gs) = try R329.game(1900)
        R332.shape(gs, "USA", military: 80, population: 80)
        R332.shape(gs, "MEX", military: 20, stability: 80, population: 15)
        let a = try XCTUnwrap(gs.getCountry(id: "USA")), weak = try XCTUnwrap(gs.getCountry(id: "MEX"))
        R332.shape(gs, "MEX", military: 90, population: 90)
        let strong = try XCTUnwrap(gs.getCountry(id: "MEX"))
        XCTAssertGreaterThan(WarCouncil.capability(a, weak), WarCouncil.capability(a, strong))
        var calm = weak, unrest = weak
        calm.stability = 90; calm.profile.outcry = 0
        unrest.stability = 10; unrest.profile.outcry = 90
        XCTAssertGreaterThan(WarCouncil.resolve(calm), WarCouncil.resolve(unrest), "a settled country fights harder")
        var spied = a
        spied.spyNetworks["MEX"] = 90
        XCTAssertGreaterThan(WarCouncil.confidence(spied, about: weak, year: 1900), WarCouncil.confidence(a, about: weak, year: 1900))
        XCTAssertGreaterThan(WarCouncil.confidence(a, about: weak, year: 1975), WarCouncil.confidence(a, about: weak, year: 1900),
                             "satellites see more than attachés")
        for v in [-1.0, 0, 0.5, 1, 2] {
            let e = WarEstimate(capability: v, resolve: v, confidence: v)
            XCTAssertTrue((0.03...0.97).contains(WarCouncil.warOdds(e)), "odds stay bounded for \(v)")
        }
    }

    /// Unit: a government is wrong for the reasons it states — mirror-imaging understates their will, domestic
    /// pressure overstates our own strength, thin information drifts both ways but never off the scale.
    func testBiasesDistortInStatedDirections() {
        let truth = WarEstimate(capability: 0.5, resolve: 0.6, confidence: 0.3)
        XCTAssertEqual(WarCouncil.believed(truth: truth, biases: [], roll: 0.5).resolve, truth.resolve, accuracy: 0.0001)
        XCTAssertLessThan(WarCouncil.believed(truth: truth, biases: [.mirrorImaging], roll: 0.5).resolve, truth.resolve)
        XCTAssertGreaterThan(WarCouncil.believed(truth: truth, biases: [.domesticPressure], roll: 0.5).capability, truth.capability)
        let high = WarCouncil.believed(truth: truth, biases: [.staleIntelligence], roll: 1)
        let low = WarCouncil.believed(truth: truth, biases: [.staleIntelligence], roll: 0)
        XCTAssertGreaterThan(high.capability, low.capability, "stale information is wrong in a direction")
        for r in stride(from: 0.0, through: 1.0, by: 0.1) {
            let e = WarCouncil.believed(truth: truth, biases: WarBias.allCases, roll: r)
            XCTAssertTrue((0.01...0.99).contains(e.capability))
            XCTAssertTrue((0.02...1).contains(e.resolve))
        }
        for b in WarBias.allCases { XCTAssertFalse(b.note.isEmpty) }
    }

    /// Unit: the done-test follows the estimate — a walkover declares ground, a close fight declares a ceiling.
    @MainActor
    func testDoneTestKinds() throws {
        let (_, gs) = try R329.game(1890)
        let a = try XCTUnwrap(gs.getCountry(id: "USA")), d = try XCTUnwrap(gs.getCountry(id: "MEX"))
        let walkover = WarEstimate(capability: 0.9, resolve: 0.2, confidence: 0.8)
        let close = WarEstimate(capability: 0.45, resolve: 0.7, confidence: 0.4)
        XCTAssertEqual(WarCouncil.doneTest(a, d, in: gs, estimate: walkover).kind, .territoryHeld)
        var lonely = a
        lonely.alliances = []
        XCTAssertEqual(WarCouncil.doneTest(lonely, d, in: gs, estimate: close).kind, .costCeiling)
        let (_, modern) = try R329.game(1995)
        let ma = try XCTUnwrap(modern.getCountry(id: "USA")), md = try XCTUnwrap(modern.getCountry(id: "IRQ"))
        XCTAssertEqual(WarCouncil.doneTest(ma, md, in: modern, estimate: close).kind, .treatySigned)
        for t in [walkover, close] {
            let test = WarCouncil.doneTest(a, d, in: gs, estimate: t)
            XCTAssertGreaterThan(test.months, 0)
            XCTAssertGreaterThan(test.casualties, 0)
            XCTAssertFalse(test.note.isEmpty)
        }
    }

    /// Unit: a source sees what it can see, and nothing a later century invented.
    func testIntelSourcesAndReach() {
        XCTAssertFalse(IntelSource.satellite.sees.isEmpty)
        XCTAssertEqual(IntelSource.satellite.from, 1960)
        XCTAssertFalse(IntelSource.borderInformant.sees.contains(.fleet), "he has never seen the fleet")
        XCTAssertTrue(IntelSource.borderInformant.sees.contains(.army))
        XCTAssertFalse(IntelSource.pressReports.sees.contains(.army))
        XCTAssertLessThan(IntelSource.satellite.error, IntelSource.pressReports.error)
        for src in IntelSource.allCases {
            XCTAssertFalse(src.title.isEmpty)
            XCTAssertFalse(src.blindSpot.isEmpty)
        }
        var c = CountryFactory.createAllCountries().first { $0.id == "USA" }!
        c.militaryStrength = 50
        XCTAssertEqual(Intelligence.truth(.army, of: c), 50)
        XCTAssertGreaterThan(Intelligence.observe(.army, of: c, by: .pressReports, roll: 1), 50)
        XCTAssertLessThan(Intelligence.observe(.army, of: c, by: .pressReports, roll: 0), 50)
        XCTAssertEqual(Intelligence.observe(.army, of: c, by: .spyNetwork, roll: 0.5), 50, accuracy: 0.001)
        let r = IntelReport(subject: "JPN", field: .army, value: 44, asOfTurn: 2, asOfDate: Date(), source: .borderInformant)
        XCTAssertTrue(r.line(name: "Japan", now: 7).contains("5 turns old"))
        XCTAssertTrue(r.line(name: "Japan", now: 7).contains("fleet"))
    }

    /// Unit: before the telegraph an order to the far side of the world may bring back no word at all.
    func testDispatchDarkness() {
        XCTAssertEqual(Dispatch.darkChance(year: 1900, degrees: 150), 0, "the cable reaches everywhere")
        XCTAssertEqual(Dispatch.darkChance(year: 1800, degrees: 10), 0, "a day's ride is not a dispatch")
        let early = Dispatch.darkChance(year: 1795, degrees: 140)
        XCTAssertGreaterThan(early, 0)
        XCTAssertLessThanOrEqual(early, 0.6)
        XCTAssertGreaterThan(early, Dispatch.darkChance(year: 1842, degrees: 140), "it got better before it got instant")
        XCTAssertGreaterThanOrEqual(Dispatch.months(degrees: 10), 2)
        XCTAssertGreaterThan(Dispatch.months(degrees: 160), Dispatch.months(degrees: 60))
    }

    /// Unit: the war record now carries who started it, what the century charged, and each nation's own shelf.
    func testHistoryCarriesInitiatorStakesAndNations() throws {
        XCTAssertFalse(HistoricalWars.rates.isEmpty, "base_rates.json ships")
        let r = try XCTUnwrap(HistoricalWars.interstate(year: 1950))
        let won = try XCTUnwrap(r.initiator_won)
        XCTAssertTrue((0...1).contains(won))
        let line = try XCTUnwrap(HistoricalWars.line(year: 1950))
        XCTAssertTrue(line.contains("wisely declined"), "survivorship is said out loud")
        XCTAssertTrue(line.contains("The side that started them won"))
        XCTAssertFalse(HistoricalWars.stakes.isEmpty)
        let stakes = try XCTUnwrap(HistoricalWars.stakes[HistoricalWars.era(1900)])
        XCTAssertGreaterThan(stakes.n, 0)
        XCTAssertFalse(HistoricalWars.nations.isEmpty, "nations have their own shelves")
        let someone = try XCTUnwrap(HistoricalWars.nations.first { !$0.value.isEmpty })
        let era = try XCTUnwrap(someone.value.keys.first)
        let year = Int(era.prefix(4)) ?? 1900
        let own = try XCTUnwrap(HistoricalWars.nationLine(someone.key, year: year, name: "Ruritania"))
        XCTAssertTrue(own.contains("Ruritania's own record"))
        XCTAssertNil(HistoricalWars.nationLine("ZZZ", year: 1900))
        XCTAssertTrue((0...1).contains(try XCTUnwrap(HistoricalWars.initiatorOdds(year: 1950))))
    }

    /// Unit: the terms of a peace follow how badly it was lost, and the paper erodes for stated reasons.
    @MainActor
    func testPeaceTermsArithmetic() throws {
        XCTAssertGreaterThan(Settlements.termYears(year: 1850), Settlements.termYears(year: 1990))
        let (_, gs) = try R329.game(1900)
        let loser = try XCTUnwrap(gs.getCountry(id: "MEX"))
        let crushed = Settlements.indemnity(loser: loser, momentum: 1, year: 1900)
        let narrow = Settlements.indemnity(loser: loser, momentum: 0, year: 1900)
        XCTAssertGreaterThan(crushed.total, narrow.total)
        XCTAssertGreaterThan(crushed.perYear, 0)
        XCTAssertLessThan(Settlements.forceCap(loser: loser, momentum: 1), Settlements.forceCap(loser: loser, momentum: 0))
        var t = PeaceTerms(victor: "USA", loser: "MEX", date: gs.currentDate, years: 20, negotiated: false)
        XCTAssertEqual(Settlements.breakChance(t, loser: loser), 0, "fresh paper does not tear")
        var angry = loser
        angry.profile.outcry = 95
        XCTAssertGreaterThan(Settlements.erosion(t, loser: angry, year: 1900), Settlements.erosion(t, loser: loser, year: 1900))
        t.strength = 0.1
        XCTAssertGreaterThan(Settlements.breakChance(t, loser: loser), 0)
    }

    /// Unit: a habit grows with wins, argues with losses, and admits its age.
    func testDoctrineMemory() {
        var r = DoctrineRecord()
        XCTAssertEqual(r.pull, 0)
        XCTAssertNil(Doctrines.reason(.blockade, r, year: 1950))
        r.wins = 9
        XCTAssertEqual(r.pull, 1.5, "the room's enthusiasm has a ceiling")
        r.wins = 3
        XCTAssertEqual(r.pull, 1.5, accuracy: 0.0001)
        r.losses = 2
        XCTAssertLessThan(r.pull, 1.5)
        r.lastWinYear = 1912
        r.lastWinNote = "the blockade of Veracruz worked"
        let fresh = Doctrines.reason(.blockade, r, year: 1915)
        XCTAssertTrue(fresh?.contains("1912") ?? false)
        let stale = Doctrines.reason(.blockade, r, year: 1941)
        XCTAssertTrue(stale?.contains("29 years ago") ?? false, "the staleness is visible in the reasoning")
        XCTAssertEqual(Doctrine.of(.navalBlockade), .blockade)
        XCTAssertEqual(Doctrine.of(.groundInvasion), .rapidWar)
        XCTAssertEqual(Doctrine.of(.stageCoup), .covert)
        XCTAssertNil(Doctrine.of(.satellite))
    }

    /// Unit: every one-sitting game is one sitting long.
    func testOneSittingCatalog() {
        XCTAssertGreaterThanOrEqual(OneSitting.all.count, 6)
        for s in OneSitting.all {
            XCTAssertTrue((6...10).contains(s.turns), "\(s.id) is \(s.turns) turns")
            XCTAssertNotNil(s.definition, "\(s.scenario) exists")
            XCTAssertFalse(s.goal.isEmpty)
            XCTAssertEqual(OneSitting.find(s.id)?.id, s.id)
        }
        XCTAssertNil(OneSitting.find("sit_nonsense"))
    }

}

// MARK: - Functional

final class Release332FunctionalTests: XCTestCase {
    /// Functional: a computer-run nation's war comes with three estimates, a pre-mortem, the cheaper instruments
    /// priced in the same numbers, and a test for calling it finished — and it reads as a government talking.
    @MainActor
    func testDeliberationIsRecordedAndLegible() throws {
        let (e, gs) = try R329.game(1905)
        R332.shape(gs, "DEU", ambition: 6, military: 75, population: 60)
        R332.shape(gs, "FRA", military: 55, stability: 70, population: 40)
        let d = try XCTUnwrap(e.deliberateWar(actor: "DEU", target: "FRA", roll: 0.8))
        XCTAssertEqual(gs.shadow.deliberations.count, 1)
        XCTAssertEqual(d.chose, "war", "an ambitious government goes")
        XCTAssertTrue((0...1).contains(d.estimate.capability) && (0...1).contains(d.estimate.resolve) && (0...1).contains(d.estimate.confidence))
        XCTAssertFalse(d.mustBeTrue.isEmpty)
        XCTAssertFalse(d.wouldBreakIt.isEmpty)
        XCTAssertFalse(d.offRamp.isEmpty)
        XCTAssertTrue(d.statement.contains("%"), "the numbers are in the words")
        XCTAssertTrue(d.statement.contains("Berlin"))
        XCTAssertGreaterThan(d.instruments.count, 1, "war is weighed against something")
        XCTAssertEqual(d.instruments.first?.id, "war")
        XCTAssertTrue(d.instruments.contains { $0.id != "war" && $0.cost < (d.instruments.first?.cost ?? 0) },
                      "a cheaper instrument is priced in the same numbers")
        XCTAssertNotNil(gs.shadow.doneTests[WarCouncil.key("DEU", "FRA")])
        XCTAssertTrue(d.statement.contains(d.doneTest.note))
    }

    /// Functional: a cautious government with a workable cheaper instrument holds off, and the record says so.
    @MainActor
    func testCautiousGovernmentStepsBack() throws {
        let (e, gs) = try R329.game(1890)
        R332.shape(gs, "USA", ambition: 1, ethic: 6, outcry: 0, military: 60)
        // A settled, cheap-to-buy neighbour: the cautious government has a real alternative and no illusion of a
        // walkover (a shaky target would set off the short-war illusion instead).
        R332.shape(gs, "MEX", military: 10, stability: 90, gdp: 0.01)
        if let i = gs.countries.firstIndex(where: { $0.id == "MEX" }) { gs.countries[i].diplomaticRelations["BRA"] = 80 }
        R332.shape(gs, "BRA", ambition: 1, ethic: 6, outcry: 0, military: 40)
        let d = try XCTUnwrap(e.deliberateWar(actor: "BRA", target: "MEX", roll: 0.05))
        XCTAssertNotEqual(d.chose, "war")
        XCTAssertTrue(d.statement.contains("cheaper instrument"))
        XCTAssertNil(gs.shadow.doneTests[WarCouncil.key("BRA", "MEX")], "no war, no test")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("steps back from war") })
    }

    /// Functional: every declaration states a reason; a thin one costs more standing than a strong one.
    @MainActor
    func testStatedReasonCostsOrBuysStanding() throws {
        let (e, gs) = try R329.game(1935)
        let watcher = "GBR"
        R332.shape(gs, "JPN", military: 70, population: 70)
        let before = gs.getCountry(id: watcher)?.diplomaticRelations["JPN"] ?? 0
        let thin = try XCTUnwrap(e.stateCasus(actor: "JPN", target: "BRA", casus: .fabricated))
        XCTAssertFalse(thin.supported)
        let afterThin = gs.getCountry(id: watcher)?.diplomaticRelations["JPN"] ?? 0
        XCTAssertLessThan(afterThin, before, "nobody believes it")
        XCTAssertTrue(gs.shadow.casusLog.contains { $0.casus == .fabricated })
        // A war in defence of an ally: the reason the facts bear out.
        if let i = gs.countries.firstIndex(where: { $0.id == "USA" }) { gs.countries[i].alliances.insert("GBR") }
        if let j = gs.countries.firstIndex(where: { $0.id == "DEU" }) { gs.countries[j].atWarWith.insert("GBR") }
        let strong = try XCTUnwrap(e.stateCasus(actor: "USA", target: "DEU"))
        XCTAssertEqual(strong.casus, .defenceOfAlly)
        XCTAssertTrue(strong.supported)
        XCTAssertGreaterThan(strong.strength, thin.strength)
    }

    /// Functional: the President states his own reason before he orders the war, and only one the era recognises.
    @MainActor
    func testPresidentStatesHisReason() throws {
        let (e, gs) = try R329.game(1960)
        XCTAssertFalse(e.statePlayerCasus(target: "CUB", casus: .dynasticClaim), "not in 1960")
        XCTAssertFalse(e.statePlayerCasus(target: "ZZZ", casus: .preemption))
        XCTAssertTrue(e.statePlayerCasus(target: "CUB", casus: .preemption))
        XCTAssertEqual(gs.shadow.statedCasus["CUB"], "preemption")
        e.declareWar(aggressor: "USA", defender: "CUB")
        XCTAssertEqual(gs.shadow.casusLog.last?.casus, .preemption)
        XCTAssertNil(gs.shadow.statedCasus["CUB"], "the case is spent once war is declared")
        XCTAssertTrue(gs.getCountry(id: "USA")?.atWarWith.contains("CUB") ?? false)
    }

    /// Functional: what the President reads has an age and a source, and it goes stale while he reads it.
    @MainActor
    func testReportsHaveAnAgeAndGoStale() throws {
        let (e, gs) = try R329.game(1930)
        gs.turnLength = .month
        gs.rng = GameRNG(seed: 7)
        for _ in 0..<3 { gs.turn += 1; e.collectIntelligence() }
        XCTAssertFalse(gs.shadow.intel.isEmpty, "somebody reported something")
        let subject = try XCTUnwrap(gs.shadow.intel.first?.subject)
        let r = try XCTUnwrap(Intelligence.latest(.army, about: subject, in: gs.shadow.intel) ?? gs.shadow.intel.first)
        XCTAssertEqual(r.asOfTurn, gs.turn - (gs.turn - r.asOfTurn))
        if let line = e.intelLine(about: subject) { XCTAssertTrue(line.contains("—")) }
        // The world moves on; the report does not.
        if let i = gs.countries.firstIndex(where: { $0.id == subject }) { gs.countries[i].militaryStrength = 1 }
        let believed = try XCTUnwrap(e.believedValue(.army, about: subject))
        if believed.report != nil { XCTAssertGreaterThan(believed.value, 1, "the garrison has moved; the paper has not") }
        let mine = try XCTUnwrap(e.believedValue(.army, about: "USA"))
        XCTAssertNil(mine.report, "we do not need an informant to count our own regiments")
    }

    /// Functional: a war opened on a figure that is months old and wrong is visible and counted.
    @MainActor
    func testAttackOnStaleIntelligenceIsVisible() throws {
        let (e, gs) = try R329.game(1935)
        gs.turnLength = .month
        R332.shape(gs, "JPN", ambition: 6, military: 80, population: 70)
        R332.shape(gs, "BRA", military: 70, population: 40)
        gs.shadow.worldIntel["BRA"] = IntelReport(subject: "BRA", field: .army, value: 10, asOfTurn: gs.turn,
                                                  asOfDate: gs.currentDate, source: .borderInformant)
        gs.turn += 8   // the figure is now eight turns old, and the army it counted has quadrupled
        let d = try XCTUnwrap(e.deliberateWar(actor: "JPN", target: "BRA", roll: 0.5))
        XCTAssertTrue(d.biases.contains(.staleIntelligence))
        XCTAssertTrue(d.statement.contains("8 turns old"))
        XCTAssertGreaterThan(d.estimate.capability, d.truth.capability, "it thinks it is stronger than it is")
        XCTAssertEqual(gs.shadow.worldStats["stale_wars"], 1, "scoreable")
    }

    /// Functional: the fog panel says the absence out loud.
    @MainActor
    func testFogPanelSaysWhatIsMissing() throws {
        let (e, gs) = try R329.game(1890)
        gs.turn = 9
        let quiet = Intelligence.silence(gs)
        XCTAssertFalse(quiet.isEmpty, "a blank map is a lie")
        XCTAssertTrue(quiet.contains { $0.contains("No reports from") })
        for _ in 0..<20 { gs.turn += 1; e.collectIntelligence() }
        XCTAssertLessThan(Intelligence.silence(gs).count, quiet.count, "reports fill the map in")
    }

    /// Functional: an order to the far side of the world goes out, costs no action, and is carried out when the
    /// dispatch finally arrives.
    @MainActor
    func testOrdersMayComeBackUnknown() throws {
        let (e, gs) = try R329.game(1800)
        gs.turnLength = .month
        let me = try XCTUnwrap(gs.getPlayerCountry())
        let far = try XCTUnwrap(gs.unclaimedLandIDs.compactMap { id -> (String, Double)? in
            guard let t = WorldCountriesDatabase.template(id: id) else { return nil }
            let c = t.toCountry().coordinates
            return (id, hypot(me.coordinates.lat - c.lat, me.coordinates.lon - c.lon))
        }.max { $0.1 < $1.1 }?.0)
        gs.actionsUsedThisTurn = 0
        let used = gs.actionsUsedThisTurn
        XCTAssertTrue(e.dispatchGoesDark(land: far, kind: "claim_land", troops: 5, roll: 0))
        XCTAssertEqual(gs.actionsUsedThisTurn, used, "an order with no word back costs no action")
        XCTAssertEqual(gs.shadow.dispatches.count, 1)
        XCTAssertFalse(gs.getCountry(id: far)?.isTerritory ?? false, "nothing has happened yet")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Nothing will come back") })
        for _ in 0..<10 where !gs.shadow.dispatches.isEmpty {
            gs.turn += 1
            e.processDispatches()
            if gs.shadow.dispatches.isEmpty { break }
            gs.startDate = GameCalendar.calendar.date(byAdding: .month, value: 1, to: gs.startDate) ?? gs.startDate
        }
        XCTAssertTrue(gs.shadow.dispatches.isEmpty, "the answer came in the end")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Word has come back") })
    }

    /// Functional: a win teaches the room a lesson, and the room says where the lesson came from.
    @MainActor
    func testDoctrineTiltsTheCabinetLegibly() throws {
        let (e, gs) = try R329.game(1914)
        let me = try XCTUnwrap(gs.getPlayerCountry()), target = try XCTUnwrap(gs.getCountry(id: "MEX"))
        let before = AdviceEngine.advise(action: .navalBlockade, player: me, target: target, gameState: gs)
        e.recordDoctrine(.blockade, actor: "USA", won: true, note: "the blockade of Veracruz brought them to terms")
        e.recordDoctrine(.blockade, actor: "USA", won: true, note: "the blockade of Veracruz brought them to terms")
        let after = AdviceEngine.advise(action: .navalBlockade, player: me, target: target, gameState: gs)
        XCTAssertTrue(after.reason.contains("We have done this before"))
        XCTAssertTrue(after.reason.contains("\(gs.currentYear)"))
        XCTAssertNotEqual(before.reason, after.reason)
        XCTAssertEqual(gs.shadow.doctrines[Doctrines.key("USA", .blockade)]?.wins, 2)
        // A war that took years teaches nothing about short wars.
        e.recordDoctrine(.rapidWar, actor: "USA", won: true, days: 1200, note: "the war was won")
        XCTAssertEqual(gs.shadow.doctrines[Doctrines.key("USA", .rapidWar)]?.wins, 0)
        XCTAssertEqual(gs.shadow.doctrines[Doctrines.key("USA", .rapidWar)]?.losses, 1)
    }

    /// Functional: a one-sitting game stops on time, with a scorecard and a debrief.
    @MainActor
    func testOneSittingFinishesInOneSitting() throws {
        let e = GameEngine()
        let s = try XCTUnwrap(OneSitting.find("sit_cuba"))
        e.startOneSitting(s)
        let gs = try XCTUnwrap(e.gameState)
        XCTAssertEqual(gs.shadow.sittingID, s.id)
        XCTAssertEqual(gs.turnLength, s.turnLength)
        for _ in 0..<(s.turns + 1) where gs.shadow.domesticEnding == nil {
            gs.turn += 1
            e.processShadowTurn()
        }
        XCTAssertEqual(gs.shadow.domesticEnding, .retired, "a finish, not a defeat")
        XCTAssertFalse(gs.shadow.sittingDebrief.isEmpty)
        XCTAssertTrue(gs.shadow.sittingDebrief[0].contains("ONE SITTING"))
        XCTAssertLessThanOrEqual(gs.turn, s.turns + 1)
    }

}

// MARK: - Integration

final class Release332IntegrationTests: XCTestCase {
    /// Integration: a war that cannot be won is abandoned at the ceiling its own government declared, instead of
    /// grinding on forever — the hole the attrition model left open.
    @MainActor
    func testWarEndsAtItsDeclaredTest() throws {
        let (e, gs) = try R329.game(1890)
        gs.turnLength = .month
        gs.rng = GameRNG(seed: 4242)
        R332.shape(gs, "BRA", ambition: 6, military: 40, population: 20)
        R332.shape(gs, "ARG", military: 38, stability: 85, population: 18)
        e.declareWar(aggressor: "BRA", defender: "ARG")
        XCTAssertTrue(gs.getCountry(id: "BRA")?.atWarWith.contains("ARG") ?? false)
        let test = try XCTUnwrap(gs.shadow.doneTests[WarCouncil.key("BRA", "ARG")])
        e.syncFronts()
        var ended = 0
        for _ in 0..<80 where ended == 0 {
            gs.turn += 1
            e.processShadowTurn()
            if !(gs.getCountry(id: "BRA")?.atWarWith.contains("ARG") ?? false) { ended = gs.turn }
        }
        XCTAssertGreaterThan(ended, 0, "the war ends")
        let months = Double(ended) * 1.0
        XCTAssertLessThanOrEqual(months, test.months * 2.5 + 6, "it ends near the test it declared, not never")
        XCTAssertTrue(gs.shadow.warLog.contains { $0.contains("ARG") || $0.contains("Argentina") })
    }

    /// Integration: a computer-run power that attacks the player does it with a record, and that record is what the
    /// post-game column quotes.
    @MainActor
    func testRivalAttacksWithARecord() throws {
        let (e, gs) = try R329.game(1950)
        R332.shape(gs, "RUS", ambition: 6, outcry: 70, military: 85, population: 180)
        if let i = gs.countries.firstIndex(where: { $0.id == "RUS" }) { gs.countries[i].diplomaticRelations["USA"] = -90 }
        e.declareWar(aggressor: "RUS", defender: "USA")
        let d = try XCTUnwrap(gs.shadow.deliberations.last)
        XCTAssertEqual(d.actor, "RUS")
        XCTAssertEqual(d.target, "USA")
        XCTAssertTrue(d.biases.contains(.domesticPressure))
        XCTAssertTrue(d.statement.contains("Moscow"))
        XCTAssertNotNil(gs.shadow.casusLog.last)
        XCTAssertNotNil(gs.shadow.doneTests[WarCouncil.key("RUS", "USA")])
        XCTAssertTrue(gs.getCountry(id: "USA")?.atWarWith.contains("RUS") ?? false)
    }

    /// Integration: a war the record itself fought is not deliberated away and the world does not punish its
    /// reasons twice.
    @MainActor
    func testScriptedWarsAreNotVetoed() throws {
        let (e, gs) = try R329.game(1914)
        R332.shape(gs, "AUT", ambition: 1, ethic: 6, outcry: 0)
        let watcher = gs.getCountry(id: "USA")?.diplomaticRelations["AUT"] ?? 0
        e.declareWar(aggressor: "AUT", defender: "SRB", scripted: true)
        XCTAssertTrue(gs.getCountry(id: "AUT")?.atWarWith.contains("SRB") ?? false, "history is not talked out of it")
        XCTAssertTrue(gs.shadow.deliberations.isEmpty)
        XCTAssertEqual(gs.getCountry(id: "USA")?.diplomaticRelations["AUT"] ?? 0, watcher, "no second reaction")
        XCTAssertNotNil(gs.shadow.doneTests[WarCouncil.key("AUT", "SRB")], "it still declares a test")
    }

    /// Integration: reparations are paid, the beaten army is held down, and the paper can still be torn up.
    @MainActor
    func testPeaceTermsPaidEnforcedAndBroken() throws {
        let (e, gs) = try R329.game(1925)
        gs.turnLength = .year
        R332.shape(gs, "DEU", ambition: 6, outcry: 90, military: 60, stability: 30, gdp: 0.5)
        let t = try XCTUnwrap(e.writePeaceTerms(victor: "USA", loser: "DEU", negotiated: false, territory: []))
        XCTAssertGreaterThan(t.indemnityOwed, 0)
        XCTAssertNotNil(t.forceCap)
        let owed = t.indemnityOwed, gdpBefore = gs.getCountry(id: "DEU")?.gdp ?? 0
        if let i = gs.countries.firstIndex(where: { $0.id == "DEU" }) { gs.countries[i].militaryStrength = 95 }
        e.processPeaceTerms(breakRoll: 1)
        let now = try XCTUnwrap(gs.shadow.peaceTerms.first)
        XCTAssertLessThan(now.indemnityOwed, owed, "an instalment was paid")
        XCTAssertLessThan(gs.getCountry(id: "DEU")?.gdp ?? 0, gdpBefore)
        XCTAssertEqual(gs.getCountry(id: "DEU")?.militaryStrength, now.forceCap, "the cap is enforced")
        XCTAssertLessThan(now.strength, 1, "the paper weakens")
        let rel = gs.getCountry(id: "USA")?.diplomaticRelations["DEU"] ?? 0
        if let k = gs.shadow.peaceTerms.indices.first { gs.shadow.peaceTerms[k].strength = 0.05 }
        e.processPeaceTerms(breakRoll: 0)
        XCTAssertTrue(gs.shadow.peaceTerms.first?.broken ?? false)
        XCTAssertLessThan(gs.getCountry(id: "USA")?.diplomaticRelations["DEU"] ?? 0, rel)
        XCTAssertTrue(gs.shadow.warLog.contains { $0.contains("tears up the treaty") })
    }

    /// Integration: the President's own settlement leaves terms on paper.
    @MainActor
    func testVictorySettlementWritesTerms() throws {
        let (e, gs) = try R329.game(1950)
        e.declareWar(aggressor: "USA", defender: "CUB")
        gs.shadow.pendingSettlements.append(PostWarSettlement(loser: "CUB", victor: "USA", date: gs.currentDate))
        let id = try XCTUnwrap(gs.shadow.pendingSettlements.first?.id)
        XCTAssertTrue(e.settle(id, choice: .annex))
        let t = try XCTUnwrap(gs.shadow.peaceTerms.last)
        XCTAssertEqual(t.victor, "USA")
        XCTAssertEqual(t.territory, ["CUB"])
        XCTAssertFalse(t.negotiated)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Terms between") })
    }

    /// Integration: the debrief names the decisions, the near-miss and the gap between belief and truth, all from
    /// what the game recorded.
    @MainActor
    func testDebriefIsBuiltFromTheRecord() throws {
        let (e, gs) = try R329.game(1960)
        e.statePlayerCasus(target: "CUB", casus: .fabricated)
        e.declareWar(aggressor: "USA", defender: "CUB")
        R332.shape(gs, "BRA", ambition: 1, ethic: 6, outcry: 0, military: 30)
        if let i = gs.countries.firstIndex(where: { $0.id == "USA" }) { gs.countries[i].stability = 20 }
        e.deliberateWar(actor: "BRA", target: "USA", roll: 0.05)
        let lines = e.debrief()
        XCTAssertEqual(lines.count, Set(lines.map(\.title)).count)
        let all = lines.map { $0.title + " " + $0.body }.joined(separator: "\n")
        XCTAssertTrue(all.contains("THE DECISIONS THAT BENT IT"))
        XCTAssertTrue(all.contains("Cuba"))
        XCTAssertTrue(all.contains("WHAT WE BELIEVED, AND WHAT WAS TRUE"))
        XCTAssertTrue(all.contains("believed"))
        XCTAssertTrue(all.contains("THE CRISIS THAT ALMOST HAPPENED"))
    }

    /// Integration: the chronicle writes itself out of the record, and quotes it.
    @MainActor
    func testLegendsChronicleQuotesTheRecord() throws {
        let (e, gs) = try R329.game(1905)
        e.deliberateWar(actor: "DEU", target: "FRA", roll: 0.8)
        e.declareWar(aggressor: "DEU", defender: "FRA", scripted: true)
        e.writePeaceTerms(victor: "DEU", loser: "FRA", negotiated: true)
        let md = Legends.markdown(gs)
        XCTAssertTrue(md.hasPrefix("# "))
        XCTAssertTrue(md.contains("## Why they went"))
        XCTAssertTrue(md.contains("## The peace"))
        XCTAssertTrue(md.contains("## Debrief"))
        let quote = try XCTUnwrap(gs.shadow.deliberations.first?.statement.prefix(40))
        XCTAssertTrue(md.contains(String(quote)), "the chronicle quotes the deliberation verbatim")
        XCTAssertTrue(md.contains("Every line above happened in this game"))
    }

}

// MARK: - Security

final class Release332SecurityTests: XCTestCase {
    /// Security: the record is bounded, and junk in a save cannot steer a war.
    @MainActor
    func testRecordsAreBoundedAndInputChecked() throws {
        let (e, gs) = try R329.game(1900)
        for _ in 0..<(WarCouncil.keep + 20) {
            gs.turn += 1   // one sitting per pair per turn, so the record only grows as time passes
            e.deliberateWar(actor: "DEU", target: "FRA", roll: 0.9)
            e.stateCasus(actor: "DEU", target: "FRA", casus: .borderIncident, applyReaction: false)
        }
        XCTAssertEqual(gs.shadow.deliberations.count, WarCouncil.keep)
        XCTAssertEqual(gs.shadow.casusLog.count, WarCouncil.keep)
        gs.shadow.statedCasus["FRA"] = "not-a-reason"
        e.declareWar(aggressor: "USA", defender: "FRA")
        XCTAssertNotNil(gs.shadow.casusLog.last)
        XCTAssertNotEqual(gs.shadow.casusLog.last?.statement, "not-a-reason")
        XCTAssertNil(e.deliberateWar(actor: "ZZZ", target: "FRA"))
        XCTAssertNil(e.stateCasus(actor: "USA", target: "ZZZ"))
    }

    /// Security (content rule): 3.31's banned-word scan covers every string 3.32 added.
    @MainActor
    func testNewStringsStayWithinTheContentRules() throws {
        let (e, gs) = try R329.game(1998)
        e.deliberateWar(actor: "RUS", target: "USA", roll: 0.3)
        e.stateCasus(actor: "RUS", target: "USA")
        for t in R332.texts(gs) {
            let low = t.lowercased() + " "
            for w in R331.banned { XCTAssertFalse(low.contains(w), "\"\(w)\" in: \(t)") }
        }
    }

    /// Security: the chronicle is never written to disk from a test host, and an export says nothing it should not.
    @MainActor
    func testExportIsSilentUnderTest() throws {
        let (_, gs) = try R329.game(1950)
        XCTAssertNil(Legends.export(gs), "a test host writes no files")
        XCTAssertFalse(Legends.markdown(gs).contains(NSHomeDirectory()), "no local paths in the chronicle")
    }

    /// Security: one-sitting and dispatch orders check what they are given.
    @MainActor
    func testOneSittingAndDispatchCheckInput() throws {
        let (e, gs) = try R329.game(1800)
        XCTAssertFalse(e.dispatchGoesDark(land: "ZZZ", kind: "claim_land", roll: 0))
        XCTAssertTrue(gs.shadow.dispatches.isEmpty)
        let bogus = OneSitting(id: "sit_bogus", scenario: "nope", title: "x", goal: "y", turns: 8, turnLength: .week)
        e.startOneSitting(bogus)
        XCTAssertNotEqual(e.gameState?.shadow.sittingID, "sit_bogus", "a sitting needs a scenario")
        e.checkOneSitting()   // harmless with no sitting under way
        XCTAssertNil(e.gameState?.shadow.sittingDebrief.first)
    }

    /// Security: the intelligence record stays bounded however long the game runs.
    @MainActor
    func testIntelligenceRecordIsBounded() throws {
        let (e, gs) = try R329.game(1990)
        gs.rng = GameRNG(seed: 3)
        for _ in 0..<40 { gs.turn += 1; e.collectIntelligence() }
        let perSubject = Dictionary(grouping: gs.shadow.intel, by: \.subject).mapValues(\.count)
        for (subject, n) in perSubject {
            XCTAssertLessThanOrEqual(n, Intelligence.keepPerSubject, "\(subject) holds \(n) reports")
        }
        XCTAssertLessThanOrEqual(gs.shadow.doctrines.count, Doctrines.keep + 1)
    }

}

// MARK: - Performance

final class Release332PerformanceTests: XCTestCase {
    /// Performance: deliberating is cheap enough to do before every war in a living world.
    @MainActor
    func testDeliberationIsCheap() throws {
        let (_, gs) = try R329.game(1950)
        let a = try XCTUnwrap(gs.getCountry(id: "USA")), d = try XCTUnwrap(gs.getCountry(id: "RUS"))
        measure { for i in 0..<400 { _ = WarCouncil.deliberate(a, d, in: gs, roll: Double(i % 10) / 10) } }
    }

    /// Performance: checking every war's done-test each turn stays out of the way.
    @MainActor
    func testDoneTestSweepIsCheap() throws {
        let (e, gs) = try R329.game(1950)
        for c in gs.liveCountries.prefix(40) where c.id != "USA" {
            e.declareWar(aggressor: "USA", defender: c.id)
        }
        e.syncFronts()
        measure { e.checkWarDoneTests() }
    }

    /// Performance: a turn of collection over a full board stays cheap.
    @MainActor
    func testIntelligenceCollectionIsCheap() throws {
        let (e, gs) = try R329.game(1990)
        gs.rng = GameRNG(seed: 11)
        measure { gs.turn += 1; e.collectIntelligence() }
    }

    /// Performance: the chronicle and the debrief are generated from the record, not recomputed from the world.
    @MainActor
    func testChronicleIsCheap() throws {
        let (e, gs) = try R329.game(1950)
        for _ in 0..<20 { e.deliberateWar(actor: "RUS", target: "USA", roll: 0.4) }
        e.writePeaceTerms(victor: "RUS", loser: "USA", negotiated: true)
        measure { _ = Legends.markdown(gs) }
    }

}

// MARK: - Retry

final class Release332RetryTests: XCTestCase {
    /// Retry: saves from before 3.32 load with no deliberations, reasons or tests.
    @MainActor
    func testOldSavesLoad() throws {
        let (_, gs) = try R329.game(1950)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs.shadow)) as? [String: Any])
        for k in ["deliberations", "casusLog", "doneTests", "statedCasus"] { obj[k] = nil }
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertTrue(old.deliberations.isEmpty)
        XCTAssertTrue(old.casusLog.isEmpty)
        XCTAssertTrue(old.doneTests.isEmpty)
        XCTAssertTrue(old.statedCasus.isEmpty)
    }

    /// Retry: the same war declared twice is one war, one reason and one test; a done-test survives a save.
    @MainActor
    func testRepeatsAndRoundTrip() throws {
        let (e, gs) = try R329.game(1950)
        e.declareWar(aggressor: "USA", defender: "CUB")
        e.declareWar(aggressor: "USA", defender: "CUB")
        XCTAssertEqual(gs.shadow.casusLog.filter { $0.target == "CUB" }.count, 1)
        XCTAssertEqual(gs.activeWars.filter { $0.defender == "CUB" }.count, 1)
        let back = try JSONDecoder().decode(ShadowState.self, from: JSONEncoder().encode(gs.shadow))
        XCTAssertEqual(back.doneTests[WarCouncil.key("USA", "CUB")]?.kind, gs.shadow.doneTests[WarCouncil.key("USA", "CUB")]?.kind)
        XCTAssertEqual(back.deliberations.count, gs.shadow.deliberations.count)
    }

    /// Retry: saves from before 3.32.1–3.32.3 load with no reports, dispatches, terms, habits or sitting.
    @MainActor
    func testOldSavesLoadTheRest() throws {
        let (_, gs) = try R329.game(1950)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs.shadow)) as? [String: Any])
        for k in ["intel", "worldIntel", "dispatches", "peaceTerms", "doctrines", "sittingID", "sittingTurns", "sittingDebrief"] { obj[k] = nil }
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertTrue(old.intel.isEmpty)
        XCTAssertTrue(old.worldIntel.isEmpty)
        XCTAssertTrue(old.dispatches.isEmpty)
        XCTAssertTrue(old.peaceTerms.isEmpty)
        XCTAssertTrue(old.doctrines.isEmpty)
        XCTAssertNil(old.sittingID)
        XCTAssertNil(old.sittingTurns)
        XCTAssertTrue(old.sittingDebrief.isEmpty)
    }

    /// Retry: one peace per war, and everything new survives a save.
    @MainActor
    func testTermsAndHabitsRoundTrip() throws {
        let (e, gs) = try R329.game(1950)
        e.writePeaceTerms(victor: "USA", loser: "CUB", negotiated: true)
        XCTAssertNil(e.writePeaceTerms(victor: "USA", loser: "CUB", negotiated: true), "one piece of paper per war")
        e.recordDoctrine(.covert, actor: "USA", won: true, note: "it worked")
        gs.shadow.intel.append(IntelReport(subject: "CUB", field: .army, value: 7, asOfTurn: 1, asOfDate: gs.currentDate, source: .spyNetwork))
        let back = try JSONDecoder().decode(ShadowState.self, from: JSONEncoder().encode(gs.shadow))
        XCTAssertEqual(back.peaceTerms.count, 1)
        XCTAssertEqual(back.peaceTerms.first?.indemnityOwed, gs.shadow.peaceTerms.first?.indemnityOwed)
        XCTAssertEqual(back.doctrines[Doctrines.key("USA", .covert)]?.wins, 1)
        XCTAssertEqual(back.intel.first?.source, .spyNetwork)
        XCTAssertNotNil(e.peaceTerms(between: "CUB", and: "USA"))
    }

}

// MARK: - Frame

#if os(macOS)
final class Release332FrameTests: XCTestCase {
    /// Frame: the WAR tab of the Records sheet and a dossier with a stated reason render in both skins.
    @MainActor
    func testWarRecordRenders() throws {
        let (e, gs) = try R329.game(1905)
        e.deliberateWar(actor: "DEU", target: "FRA", roll: 0.7)
        e.stateCasus(actor: "DEU", target: "FRA")
        e.statePlayerCasus(target: "FRA", casus: .borderIncident)
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let records = RecordsSheet(gameState: gs, hall: [:], tab: .war)
            let r = ImageRenderer(content: records.environmentObject(e))
            r.scale = 1
            XCTAssertNotNil(r.cgImage, "records \(theme)")
            let dossier = CountryDossier(gameState: gs, country: gs.getCountry(id: "FRA"), onSheet: { _ in }, scrolls: false)
                .frame(width: FontScale.w(300)).environmentObject(e)
            let d = ImageRenderer(content: dossier)
            d.scale = 1
            XCTAssertNotNil(d.cgImage, "dossier \(theme)")
        }
    }

    /// Frame: the fog and legends panels, the one-sitting list and the end screen's debrief render in both skins.
    @MainActor
    func testFogLegendsAndDebriefRender() throws {
        let (e, gs) = try R329.game(1890)
        gs.rng = GameRNG(seed: 5)
        for _ in 0..<3 { gs.turn += 1; e.collectIntelligence() }
        _ = e.dispatchGoesDark(land: gs.unclaimedLandIDs.sorted().first ?? "ATA", kind: "claim_land", roll: 0)
        e.deliberateWar(actor: "DEU", target: "FRA", roll: 0.8)
        e.writePeaceTerms(victor: "DEU", loser: "FRA", negotiated: true)
        e.recordDoctrine(.blockade, actor: "USA", won: true, note: "it worked")
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            for tab in [RecordsSheet.Tab.fog, .legends] {
                let r = ImageRenderer(content: RecordsSheet(gameState: gs, hall: [:], tab: tab))
                r.scale = 1
                XCTAssertNotNil(r.cgImage, "\(tab) \(theme)")
            }
            let list = ImageRenderer(content: OneSittingList { _ in }.frame(width: FontScale.w(620)))
            list.scale = 1
            XCTAssertNotNil(list.cgImage, "one sitting \(theme)")
            let score = GameScore.calculate(from: gs, victoryType: nil)
            let end = ImageRenderer(content: VictoryScreen(gameState: gs, victoryType: nil, score: score,
                                                           onNewGame: {}, onViewLeaderboard: {})
                .frame(width: FontScale.w(900), height: FontScale.h(1200)))
            end.scale = 1
            XCTAssertNotNil(end.cgImage, "end screen \(theme)")
        }
    }

}
#endif
