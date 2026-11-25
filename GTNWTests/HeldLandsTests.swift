//
//  HeldLandsTests.swift
//  GTNWTests
//
//  3.37.0: governments the President installs count as held land (HeldLands.swift), and INVEST from the Govern
//  sheet (DevelopmentBoard.swift) is the command box's own order. Unit, functional and save round-trip.
//

import XCTest
@testable import GTNW

@MainActor
enum HL {
    /// A 2025 game with Iraq beaten and the settlement made.
    static func installed(_ g: PostWarGovernment, in e: GameEngine) -> String {
        let gs = e.gameState!
        let s = PostWarSettlement(loser: "IRQ", victor: gs.playerCountryID, date: gs.currentDate)
        gs.shadow.pendingSettlements.append(s)
        XCTAssertTrue(e.settle(s.id, choice: .government(g)))
        return "IRQ"
    }

    /// A 1890 game with Cameroon and Gabon freshly claimed, and actions to spare.
    static func colonies(seed: UInt64 = 7) -> (GameEngine, GameState) {
        let (e, gs) = RB.engine(year: 1890, seed: seed)
        XCTAssertTrue(e.claimLand("CMR"))
        XCTAssertTrue(e.claimLand("GAB"))
        gs.actionsUsedThisTurn = 0
        gs.shadow.aidRemaining = 100
        return (e, gs)
    }
}

// MARK: - Unit: puppets

final class HeldLandsUnitTests: XCTestCase {
    /// Unit: a client state is held land everywhere "held" is asked; the player's own nation is not "held abroad".
    @MainActor
    func testClientStateCountsAsHeldLand() {
        let (e, gs) = RB.engine(year: 2025)
        XCTAssertFalse(gs.isHeldByPlayer("IRQ"))
        let before = gs.heldLands.count
        let id = HL.installed(.clientState, in: e)
        XCTAssertTrue(gs.isPuppet(id))
        XCTAssertTrue(gs.isHeldByPlayer(id))
        XCTAssertEqual(gs.heldLands.count, before + 1)
        XCTAssertTrue(gs.puppets.map(\.id).contains(id))
        XCTAssertTrue(EmpireModel.holds(id, in: gs))
        XCTAssertTrue(EmpireModel.regionsHeld(gs).contains(gs.getCountry(id: id)!.region))
        XCTAssertTrue(RenameTarget.country(id).isHeld(in: gs), "the President may rename a puppet")
        XCTAssertTrue(gs.renamableTargets.contains(.country(id)))
        XCTAssertFalse(gs.isHeldByPlayer(gs.playerCountryID))
        XCTAssertNotNil(e.orderProblem(GameOrder(kind: .developLand, target: id)), "puppets aren't governed or developed")
    }

    /// Unit: a government that starts cool (a communist state, relations −20) is not a puppet; annexation is a
    /// territory, not a record.
    @MainActor
    func testCoolGovernmentsAndAnnexationAreNotPuppets() {
        let (e, gs) = RB.engine(year: 2025)
        let id = HL.installed(.communistState, in: e)
        XCTAssertNotNil(gs.shadow.installedGovernments[id], "recorded")
        XCTAssertFalse(gs.isPuppet(id), "relations of −20 don't make it his")
        XCTAssertEqual(HeldLands.lapse(id, in: gs), "relations cooled")

        let (e2, gs2) = RB.engine(year: 2025)
        let s = PostWarSettlement(loser: "IRQ", victor: gs2.playerCountryID, date: gs2.currentDate)
        gs2.shadow.pendingSettlements.append(s)
        XCTAssertTrue(e2.settle(s.id, choice: .annex))
        XCTAssertNil(gs2.shadow.installedGovernments["IRQ"])
        XCTAssertTrue(gs2.isHeldByPlayer("IRQ"), "a territory")
        XCTAssertFalse(gs2.isPuppet("IRQ"))
    }

    /// Unit: a fallen government, a war with him or a destroyed land ends the arrangement.
    @MainActor
    func testLapses() {
        let (e, gs) = RB.engine(year: 2025)
        let id = HL.installed(.clientState, in: e)
        let i = gs.countries.firstIndex { $0.id == id }!
        gs.countries[i].government = .theocracy
        XCTAssertEqual(HeldLands.lapse(id, in: gs), "its government fell")
        XCTAssertFalse(gs.isHeldByPlayer(id))
        gs.countries[i].government = gs.shadow.installedGovernments[id]!.government
        XCTAssertTrue(gs.isPuppet(id))
        gs.countries[i].atWarWith.insert(gs.playerCountryID)
        XCTAssertEqual(HeldLands.lapse(id, in: gs), "at war with you")
        gs.countries[i].atWarWith.remove(gs.playerCountryID)
        gs.countries[i].isDestroyed = true
        XCTAssertFalse(gs.isHeldByPlayer(id))
    }

    /// Unit: tribute is half the land's base output as a territory, with no ramp-up and no garrison.
    @MainActor
    func testTributeIsHalfTheBase() throws {
        let (e, gs) = RB.engine(year: 2025)
        let id = HL.installed(.clientState, in: e)
        let c = try XCTUnwrap(gs.getCountry(id: id))
        let tabled = ExpansionModel.deposits[id] != nil || WorldCountriesDatabase.postColonialAfrica.contains(id)
        let base = tabled ? ExpansionModel.deposits(for: id, year: 2025).reduce(0) { $0 + LandDevelopment.money($1) } : c.gdp * 1000 * 0.02
        XCTAssertEqual(HeldLands.tribute(c, in: gs), base * 0.5, accuracy: 1e-9)
        XCTAssertGreaterThan(HeldLands.totalTribute(gs), 0)
    }
}

// MARK: - Functional: puppets

final class HeldLandsFunctionalTests: XCTestCase {
    /// Functional: the turn's economy pays the tribute into the funds; a government that falls stops paying and the
    /// news says so.
    @MainActor
    func testTributePaysAndStopsWhenTheGovernmentFalls() {
        let (e, gs) = RB.engine(year: 2025)
        let id = HL.installed(.clientState, in: e)
        let yf = gs.turnLength.yearFraction
        let expected = (ExpansionModel.ledger(gs).filter { $0.income > 0 }.reduce(0) { $0 + $1.income }
                        + gs.shadow.acquisitionIncome + HeldLands.totalTribute(gs)) * yf
        e.processTerritoryEconomy()
        XCTAssertEqual(gs.shadow.lastTurnCash, expected, accuracy: 1e-9)
        XCTAssertNotNil(gs.shadow.installedGovernments[id])

        let i = gs.countries.firstIndex { $0.id == id }!
        gs.countries[i].government = .military
        let withoutTribute = (ExpansionModel.ledger(gs).filter { $0.income > 0 }.reduce(0) { $0 + $1.income } + gs.shadow.acquisitionIncome) * yf
        e.processTerritoryEconomy()
        XCTAssertNil(gs.shadow.installedGovernments[id], "dropped for good")
        XCTAssertEqual(gs.shadow.lastTurnCash, withoutTribute, accuracy: 1e-9)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("government you installed") })
    }

    /// Functional: the President renames a puppet; the record screens count it and the library and fifty years
    /// later treat it as held; the score's land tally counts it.
    @MainActor
    func testRenameRecordAndScore() {
        let (e, gs) = RB.engine(year: 2025)
        let scoreBefore = GameScore.calculate(from: gs, victoryType: nil).expansionBonus ?? 0
        let id = HL.installed(.clientState, in: e)
        XCTAssertGreaterThan(GameScore.calculate(from: gs, victoryType: nil).expansionBonus ?? 0, scoreBefore)
        XCTAssertTrue(e.rename(.country(id), to: "Freedonia").succeeded)
        XCTAssertEqual(gs.getCountry(id: id)?.name, "Freedonia")
        XCTAssertTrue(gs.namedLands.contains(id))
        let lands = PresidencyEpilogue.landsHeld(gs) ?? ""
        XCTAssertTrue(lands.contains("1 government installed (Freedonia)"), lands)
        XCTAssertTrue(PresidencyEpilogue.library(gs).contains("Freedonia"))
        XCTAssertTrue(PresidencyEpilogue.library(gs).contains("whose government"))
        let i = gs.countries.firstIndex { $0.id == id }!
        gs.countries[i].stability = 60
        XCTAssertEqual(PresidencyEpilogue.fiftyYearsLater(gs).first { $0.land == id }?.survives, true)
        // Once it turns on him it is no longer his to rename.
        gs.countries[i].diplomaticRelations[gs.playerCountryID] = -50
        XCTAssertFalse(e.rename(.country(id), to: "Other").succeeded)
        XCTAssertEqual(PresidencyEpilogue.fiftyYearsLater(gs).first { $0.land == id }?.survives, false)
    }

    /// Save round-trip: installed governments survive a save; an older save without them loads with none.
    @MainActor
    func testSaveRoundTripAndOldSaves() throws {
        let (e, gs) = RB.engine(year: 2025)
        let id = HL.installed(.clientState, in: e)
        let back = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(gs))
        XCTAssertEqual(back.shadow.installedGovernments, gs.shadow.installedGovernments)
        XCTAssertTrue(back.isPuppet(id))
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: try JSONEncoder().encode(gs.shadow)) as? [String: Any])
        obj["installedGovernments"] = nil
        let old = try JSONDecoder().decode(ShadowState.self, from: try JSONSerialization.data(withJSONObject: obj))
        XCTAssertTrue(old.installedGovernments.isEmpty)
        let rec = try JSONDecoder().decode(InstalledGovernment.self, from: Data("{}".utf8))
        XCTAssertEqual(rec.government, .authoritarian)
        // A command log entry from the Govern sheet decodes too.
        let r = CommandRecord(turn: 1, date: gs.currentDate, source: .sheet, orders: [GameOrder(kind: .developLand, target: "CMR")])
        XCTAssertEqual(try JSONDecoder().decode(CommandRecord.self, from: try JSONEncoder().encode(r)), r)
    }
}

// MARK: - INVEST from the Govern sheet

final class GovernInvestTests: XCTestCase {
    /// Unit: the land being governed comes first, then every other one still developing, with the dossier's figures.
    @MainActor
    func testRowsMatchTheDossierFigures() throws {
        let (_, gs) = HL.colonies()
        let rows = LandDevelopment.governRows(first: "GAB", in: gs)
        XCTAssertEqual(rows.first?.id, "GAB")
        XCTAssertTrue(rows.contains { $0.id == "CMR" })
        let cmr = try XCTUnwrap(gs.getCountry(id: "CMR"))
        let r = try XCTUnwrap(rows.first { $0.id == "CMR" })
        XCTAssertEqual(r.now, ExpansionModel.annualIncome(cmr, in: gs), accuracy: 1e-9)
        XCTAssertEqual(r.full, ExpansionModel.annualIncome(cmr, in: gs, developed: true), accuracy: 1e-9)
        XCTAssertEqual(r.months, 24)
        XCTAssertEqual(r.cost, LandDevelopment.investCost(cmr, in: gs))
        XCTAssertNil(r.problem)
        XCTAssertTrue(r.line.contains("24 MONTHS LEFT"))
        XCTAssertTrue(r.spoken.hasPrefix("Invest "))
        // A developed land: listed only when it is the one being governed, with the reason its button is off.
        gs.shadow.books.developed["GAB"] = 5
        let again = LandDevelopment.governRows(first: "GAB", in: gs)
        XCTAssertEqual(again.first?.id, "GAB")
        XCTAssertEqual(again.first?.problem, "\(gs.getCountry(id: "GAB")!.name) is already fully developed.")
        XCTAssertFalse(LandDevelopment.governRows(first: "CMR", in: gs).contains { $0.id == "GAB" })
    }

    /// Unit: no actions or no money disables INVEST with a plain reason, and the sheet's order is refused.
    @MainActor
    func testDisabledReasons() {
        let (e, gs) = HL.colonies()
        gs.actionsUsedThisTurn = gs.actionsPerTurn
        XCTAssertTrue(LandDevelopment.governRows(first: "CMR", in: gs).first?.problem?.hasPrefix("No actions left") ?? false)
        XCTAssertFalse(e.investFromSheet("CMR"))
        gs.actionsUsedThisTurn = 0
        gs.shadow.aidRemaining = 0
        if let i = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) { gs.countries[i].gdp = 0 }
        XCTAssertTrue(LandDevelopment.governRows(first: "CMR", in: gs).first?.problem?.hasPrefix("Not enough money") ?? false)
        XCTAssertFalse(e.investFromSheet("CMR"))
        XCTAssertEqual(LandDevelopment.bought("CMR", in: gs), 0)
    }

    /// Functional: the Govern sheet's INVEST does exactly what typing "invest in Cameroon" does, and the command
    /// log says it came from the sheet.
    @MainActor
    func testSheetInvestIsTheCommandBoxOrder() throws {
        let (typed, a) = HL.colonies()
        let plan = try XCTUnwrap(CmdFixtures.confirmedPlan(typed, "invest in Cameroon"))
        XCTAssertEqual(plan.orders, [GameOrder(kind: .developLand, target: "CMR")])
        XCTAssertEqual(typed.executeCommand(plan.orders, source: .parser).carried.count, 1)

        let (sheet, b) = HL.colonies()
        XCTAssertTrue(sheet.investFromSheet("CMR"))
        XCTAssertEqual(b.shadow.books.developed, a.shadow.books.developed)
        XCTAssertEqual(b.shadow.aidRemaining, a.shadow.aidRemaining, accuracy: 1e-9)
        XCTAssertEqual(b.actionsRemaining, a.actionsRemaining)
        XCTAssertEqual(LandDevelopment.monthsToDevelop("CMR", in: b), 18)
        XCTAssertEqual(b.shadow.commandLog.last?.source, .sheet)
        XCTAssertEqual(b.shadow.commandLog.last?.orders, [GameOrder(kind: .developLand, target: "CMR")])
        XCTAssertEqual(LandDevelopment.governRows(first: "CMR", in: b).first?.months, 18)
    }
}
