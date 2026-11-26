//
//  HolySeeTests.swift
//  GTNWTests
//
//  3.37.0: the Holy See's statecraft (HolySee.swift). One unit test per action's mechanics (odds, costs, cooldowns,
//  visible results); the command box, the chief of staff and the GTNWCore-facing model; a short Vatican game that
//  mediates a dispute, appeals in a crisis and wins on its record; proof that none of it is offered to any other
//  nation; determinism; saves (round-trip and older saves); the play events; the content rules.
//

import XCTest
@testable import GTNW

enum R337E {
    @MainActor
    static func game(_ player: String = "VAT", year: Int = 2025, seed: UInt64 = 337) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(playerCountryID: player, turnLength: .month, year: year, seed: seed)
        e.crisisManager.activeCrisis = nil
        e.crisisManager.pendingCrises = []
        return (e, try XCTUnwrap(e.gameState))
    }

    /// A fresh action and no cooldowns (unit tests take several actions in one turn).
    static func fresh(_ gs: GameState) {
        gs.actionsUsedThisTurn = 0
        gs.shadow.holySee.lastUsed = [:]
    }

    static func rel(_ gs: GameState, _ a: String, _ b: String) -> Int { gs.getCountry(id: a)?.diplomaticRelations[b] ?? 0 }

    /// Two nations in a bitter dispute (not at war), both friendly to the Holy See.
    static func dispute(_ gs: GameState, _ a: String, _ b: String, mutual: Int = -50, toVAT: Int = 90) {
        for (x, y) in [(a, b), (b, a)] {
            if let i = gs.countries.firstIndex(where: { $0.id == x }) {
                gs.countries[i].atWarWith.remove(y)
            }
            gs.setRelation(from: x, to: y, value: mutual)
            gs.setRelation(from: x, to: "VAT", value: toVAT)
        }
        gs.activeWars.removeAll { Set([$0.aggressor, $0.defender]) == Set([a, b]) }
    }

    /// Two nations at war.
    @MainActor
    static func war(_ e: GameEngine, _ gs: GameState, _ a: String, _ b: String, toVAT: Int = 90) {
        dispute(gs, a, b, mutual: -70, toVAT: toVAT)
        e.declareWar(aggressor: a, defender: b, scripted: true)
    }

    /// Wait for the computer's moves (a main-actor Task started by `endTurn`).
    @MainActor
    static func settle(_ e: GameEngine) async {
        for _ in 0..<2_000 where e.isProcessingAITurn { await Task.yield() }
        for _ in 0..<500 where e.isProcessingAITurn { try? await Task.sleep(nanoseconds: 2_000_000) }
    }

    @MainActor
    static func run(_ e: GameEngine, _ o: HolySeeOrder, roll: Double? = nil) throws -> HolySeeResult {
        try XCTUnwrap(e.runHolySee(o, roll: roll), e.holySeeProblem(o) ?? "refused")
    }
}

// MARK: - Unit: each action

final class HolySeeActionTests: XCTestCase {
    /// Mediation: both must accept; success ends the dispute with a treaty signed at the Vatican and keeps them from war.
    @MainActor
    func testMediate() throws {
        let (e, gs) = try R337E.game()
        R337E.dispute(gs, "ARG", "CHL")
        let o = HolySeeOrder(action: .mediate, first: "ARG", second: "CHL")
        XCTAssertNil(e.holySeeProblem(o))
        XCTAssertGreaterThan(HolySeeModel.pairOdds(gs, .mediate, "ARG", "CHL"), 0.5)
        let treaties = gs.treaties.count
        let r = try R337E.run(e, o, roll: 0)
        XCTAssertTrue(r.success)
        XCTAssertTrue(r.lines[0].contains("sign a treaty"), r.lines[0])
        XCTAssertEqual(gs.shadow.holySee.record.treatiesAtVatican, 1)
        XCTAssertEqual(gs.treaties.count, treaties + 1)
        XCTAssertEqual(Set(gs.treaties.last?.signatories ?? []), ["ARG", "CHL"])
        XCTAssertGreaterThan(R337E.rel(gs, "ARG", "CHL"), -50, "tension drops")
        XCTAssertTrue(HolySeeModel.holds(gs, "ARG", "CHL"), "a treaty signed at the Vatican keeps them from war")
        e.declareWar(aggressor: "ARG", defender: "CHL")
        XCTAssertFalse(gs.getCountry(id: "ARG")?.atWarWith.contains("CHL") ?? true)
        // Cooldown.
        gs.actionsUsedThisTurn = 0
        R337E.dispute(gs, "IND", "PAK")
        XCTAssertTrue(e.holySeeProblem(HolySeeOrder(action: .mediate, first: "IND", second: "PAK"))?.contains("following up") ?? false)
        // Refused: no treaty, a little goodwill lost.
        R337E.fresh(gs)
        let before = R337E.rel(gs, "IND", "VAT")
        let no = try R337E.run(e, HolySeeOrder(action: .mediate, first: "IND", second: "PAK"), roll: 0.99)
        XCTAssertFalse(no.success)
        XCTAssertTrue(no.lines[0].contains("decline"), no.lines[0])
        XCTAssertLessThan(R337E.rel(gs, "IND", "VAT"), before)
        XCTAssertEqual(gs.shadow.holySee.record.treatiesAtVatican, 1)
        // Nothing to mediate.
        R337E.fresh(gs)
        R337E.dispute(gs, "FRA", "DEU", mutual: 40)
        XCTAssertTrue(e.holySeeProblem(HolySeeOrder(action: .mediate, first: "FRA", second: "DEU"))?.contains("no dispute") ?? false)
        XCTAssertNotNil(e.holySeeProblem(HolySeeOrder(action: .mediate, first: "FRA", second: "FRA")))
    }

    /// Peace talks at the Vatican: only for nations at war; success is a ceasefire.
    @MainActor
    func testHostTalks() throws {
        let (e, gs) = try R337E.game()
        R337E.dispute(gs, "ETH", "ERI")
        XCTAssertTrue(e.holySeeProblem(HolySeeOrder(action: .hostTalks, first: "ETH", second: "ERI"))?.contains("not at war") ?? false)
        R337E.war(e, gs, "ETH", "ERI")
        XCTAssertTrue(gs.getCountry(id: "ETH")?.atWarWith.contains("ERI") ?? false)
        let r = try R337E.run(e, HolySeeOrder(action: .hostTalks, first: "ETH", second: "ERI"), roll: 0)
        XCTAssertTrue(r.success)
        XCTAssertFalse(gs.getCountry(id: "ETH")?.atWarWith.contains("ERI") ?? true, "a ceasefire")
        XCTAssertEqual(gs.shadow.holySee.record.ceasefires, 1)
        XCTAssertNotNil(gs.shadow.holySee.lastUsed[HolySeeAction.hostTalks.rawValue])
    }

    /// The back channel: a thaw between hostile nations not at war, with a prisoner release.
    @MainActor
    func testBackChannel() throws {
        let (e, gs) = try R337E.game()
        R337E.dispute(gs, "USA", "CUB", mutual: -60)
        let r = try R337E.run(e, HolySeeOrder(action: .backChannel, first: "USA", second: "CUB"), roll: 0)
        XCTAssertTrue(r.success)
        XCTAssertEqual(R337E.rel(gs, "USA", "CUB"), -35)
        XCTAssertEqual(gs.shadow.holySee.record.thaws, 1)
        XCTAssertGreaterThanOrEqual(gs.shadow.holySee.record.returned, 1, "a prisoner release")
        R337E.fresh(gs)
        R337E.dispute(gs, "GBR", "IRL", mutual: 30)
        XCTAssertNotNil(e.holySeeProblem(HolySeeOrder(action: .backChannel, first: "GBR", second: "IRL")))
    }

    /// The appeal: only in a nuclear crisis; success eases DEFCON and is a crisis defused.
    @MainActor
    func testAppealForPeace() throws {
        let (e, gs) = try R337E.game()
        gs.defconLevel = .defcon4
        XCTAssertTrue(e.holySeeProblem(HolySeeOrder(action: .appealForPeace))?.contains("nuclear crisis") ?? false)
        gs.defconLevel = .defcon2
        let side = try XCTUnwrap(HolySeeModel.escalatingSide(gs))
        XCTAssertGreaterThan(side.nuclearWarheads, 0)
        let r = try R337E.run(e, HolySeeOrder(action: .appealForPeace), roll: 0)
        XCTAssertTrue(r.success, r.lines.joined())
        XCTAssertEqual(gs.defconLevel, .defcon3)
        XCTAssertEqual(gs.shadow.holySee.record.crisesDefused, 1)
        R337E.fresh(gs)
        gs.defconLevel = .defcon1
        let no = try R337E.run(e, HolySeeOrder(action: .appealForPeace), roll: 0.99)
        XCTAssertFalse(no.success)
        XCTAssertEqual(gs.defconLevel, .defcon1)
        // Not before Vatican Radio.
        let (e2, g2) = try R337E.game(year: 1929)
        if g2.getPlayerCountry() != nil {
            g2.defconLevel = .defcon2
            XCTAssertTrue(e2.holySeeProblem(HolySeeOrder(action: .appealForPeace))?.contains("1931") ?? false)
        }
    }

    /// Envoys: averted (a three-year hold, the war is not declared), delayed (one year), or no change.
    @MainActor
    func testSendEnvoys() throws {
        let (e, gs) = try R337E.game()
        R337E.dispute(gs, "IND", "PAK", mutual: -60)
        let odds = HolySeeModel.pairOdds(gs, .sendEnvoys, "IND", "PAK")
        let r = try R337E.run(e, HolySeeOrder(action: .sendEnvoys, first: "IND", second: "PAK"), roll: 0)
        XCTAssertTrue(r.success)
        XCTAssertEqual(gs.shadow.holySee.record.warsAverted, 1)
        e.declareWar(aggressor: "PAK", defender: "IND")
        XCTAssertFalse(gs.getCountry(id: "PAK")?.atWarWith.contains("IND") ?? true, "the envoys hold the war off")
        XCTAssertTrue(gs.shadow.holySee.holds.contains { $0.held })
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("holds back from war") }, "\(gs.shadow.ticker.suffix(4).map(\.text))")

        R337E.fresh(gs)
        R337E.dispute(gs, "SAU", "IRN", mutual: -60)
        _ = try R337E.run(e, HolySeeOrder(action: .sendEnvoys, first: "SAU", second: "IRN"), roll: odds * 0.75)
        XCTAssertEqual(gs.shadow.holySee.record.warsDelayed, 1)
        let hold = try XCTUnwrap(gs.shadow.holySee.holds.last)
        XCTAssertEqual(GameCalendar.year(of: hold.until), gs.currentYear + 1, "a one-year delay")

        R337E.fresh(gs)
        R337E.dispute(gs, "GRC", "TUR", mutual: -60)
        let no = try R337E.run(e, HolySeeOrder(action: .sendEnvoys, first: "GRC", second: "TUR"), roll: 0.99)
        XCTAssertFalse(no.success)
        R337E.war(e, gs, "GRC", "TUR")
        R337E.fresh(gs)
        XCTAssertTrue(e.holySeeProblem(HolySeeOrder(action: .sendEnvoys, first: "GRC", second: "TUR"))?.contains("already at war") ?? false)
    }

    /// A teaching document: two years of willingness on its theme (better odds) and world opinion a point a turn.
    @MainActor
    func testEncyclical() throws {
        let (e, gs) = try R337E.game()
        XCTAssertNotNil(e.holySeeProblem(HolySeeOrder(action: .encyclical)), "a theme is needed")
        R337E.dispute(gs, "ARG", "CHL", toVAT: 0)
        let before = HolySeeModel.pairOdds(gs, .hostTalks, "ARG", "CHL")
        let r = try R337E.run(e, HolySeeOrder(action: .encyclical, option: TeachingTheme.peace.rawValue))
        XCTAssertTrue(r.lines[0].contains("Fratelli tutti"), r.lines[0])
        XCTAssertEqual(HolySeeModel.pairOdds(gs, .hostTalks, "ARG", "CHL"), before + 0.15, accuracy: 1e-9)
        XCTAssertEqual(gs.shadow.holySee.record.teachings, 1)
        // World opinion: nations at war warm to the Holy See a point a turn.
        R337E.war(e, gs, "ETH", "ERI", toVAT: 0)
        e.processHolySee()
        e.processHolySee()
        XCTAssertEqual(R337E.rel(gs, "ETH", "VAT"), 2)
        XCTAssertEqual(gs.shadow.holySee.teachings.last?.applied, 2)
        R337E.fresh(gs)
        gs.shadow.holySee.lastUsed[HolySeeAction.encyclical.rawValue] = gs.currentDate
        XCTAssertNotNil(e.holySeeProblem(HolySeeOrder(action: .encyclical, option: "nuclear")), "two years between documents")
    }

    /// Ratify a treaty: once; others are pressed to join (never a nuclear power to the prohibition treaty).
    @MainActor
    func testRatifyTreaty() throws {
        let (e, gs) = try R337E.game()
        for c in gs.liveCountries where c.id != "VAT" { gs.setRelation(from: c.id, to: "VAT", value: 60) }
        let r = try R337E.run(e, HolySeeOrder(action: .ratifyTreaty, option: "tpnw"), roll: 0)
        XCTAssertTrue(r.success)
        XCTAssertEqual(gs.shadow.holySee.record.treatiesRatified, 1)
        let treaty = try XCTUnwrap(gs.treaties.last)
        XCTAssertEqual(treaty.type, .nuclearDisarmament)
        XCTAssertEqual(treaty.signatories.first, "VAT")
        XCTAssertEqual(treaty.signatories.count, 13, "the Holy See and at most twelve")
        for id in treaty.signatories.dropFirst() { XCTAssertEqual(gs.getCountry(id: id)?.nuclearWarheads, 0, id) }
        R337E.fresh(gs)
        XCTAssertTrue(e.holySeeProblem(HolySeeOrder(action: .ratifyTreaty, option: "tpnw"))?.contains("already ratified") ?? false)
        XCTAssertFalse(HolySeeModel.openTreaties(gs).contains { $0.id == "tpnw" })
        let (e2, g2) = try R337E.game(year: 1960)
        if g2.getPlayerCountry() != nil {
            XCTAssertTrue(e2.holySeeProblem(HolySeeOrder(action: .ratifyTreaty, option: "npt"))?.contains("1968") ?? false)
        }
    }

    /// Humanitarian work: tracing the missing, sheltering refugees, a prisoner exchange.
    @MainActor
    func testHumanitarian() throws {
        let (e, gs) = try R337E.game()
        gs.activeWars.removeAll()
        for i in gs.countries.indices { gs.countries[i].atWarWith = [] }
        XCTAssertTrue(e.holySeeProblem(HolySeeOrder(action: .tracePrisoners))?.contains("no war") ?? false)
        R337E.war(e, gs, "ETH", "ERI")
        let t = try R337E.run(e, HolySeeOrder(action: .tracePrisoners), roll: 0)
        XCTAssertEqual(gs.shadow.holySee.record.traced, 1500)
        XCTAssertTrue(t.lines[0].contains("1500"), t.lines[0])
        R337E.fresh(gs)
        if let i = gs.countries.firstIndex(where: { $0.id == "ERI" }) { gs.countries[i].refugeeCount = 10_000 }
        _ = try R337E.run(e, HolySeeOrder(action: .shelterRefugees), roll: 0)
        XCTAssertEqual(gs.shadow.holySee.record.sheltered, 500)
        XCTAssertEqual(gs.getCountry(id: "ERI")?.refugeeCount, 9_500)
        R337E.fresh(gs)
        let x = try R337E.run(e, HolySeeOrder(action: .prisonerExchange, first: "ETH", second: "ERI"), roll: 0)
        XCTAssertTrue(x.success)
        XCTAssertEqual(gs.shadow.holySee.record.returned, 100)
        XCTAssertEqual(gs.shadow.holySee.record.livesSaved, 2100)
        R337E.fresh(gs)
        XCTAssertFalse(try R337E.run(e, HolySeeOrder(action: .prisonerExchange, first: "ETH", second: "ERI"), roll: 0.99).success)
    }

    /// Pastoral visits: civil society; pressure for reform under an authoritarian government (answered when it builds
    /// up); a visit to both sides of a war argues for peace.
    @MainActor
    func testPastoralVisit() throws {
        let (e, gs) = try R337E.game()
        let stability = gs.getCountry(id: "POL")?.stability ?? 0
        _ = try R337E.run(e, HolySeeOrder(action: .pastoralVisit, first: "POL"))
        XCTAssertEqual(gs.getCountry(id: "POL")?.stability, min(100, stability + 3))
        let auth = try XCTUnwrap(gs.liveCountries.first { HolySeeModel.isAuthoritarian($0) && $0.id != "VAT" })
        for _ in 0..<3 {
            R337E.fresh(gs)
            _ = try R337E.run(e, HolySeeOrder(action: .pastoralVisit, first: auth.id))
        }
        XCTAssertEqual(gs.shadow.holySee.reformPressure[auth.id], 36)
        e.processHolySee()
        XCTAssertEqual(gs.shadow.holySee.record.reforms, 1)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("eases restrictions") })
        // Both sides of a war.
        R337E.war(e, gs, "GBR", "ARG")
        R337E.fresh(gs)
        _ = try R337E.run(e, HolySeeOrder(action: .pastoralVisit, first: "GBR"), roll: 0)
        R337E.fresh(gs)
        let r = try R337E.run(e, HolySeeOrder(action: .pastoralVisit, first: "ARG"), roll: 0)
        XCTAssertTrue(r.lines.contains { $0.contains("visited both sides") }, r.lines.joined())
        XCTAssertFalse(gs.getCountry(id: "ARG")?.atWarWith.contains("GBR") ?? true)
        XCTAssertEqual(gs.shadow.holySee.record.ceasefires, 1)
    }

    /// The interfaith gathering: a day of truce, every faith an equal; at roll 0 every war's truce holds.
    @MainActor
    func testInterfaithGathering() throws {
        let (e, gs) = try R337E.game()
        R337E.war(e, gs, "ETH", "ERI")
        let wars = gs.activeWars.count
        let r = try R337E.run(e, HolySeeOrder(action: .interfaithGathering), roll: 0)
        XCTAssertTrue(r.lines[0].contains("as equals"))
        XCTAssertEqual(gs.activeWars.count, 0)
        XCTAssertEqual(gs.shadow.holySee.record.ceasefires, wars)
        XCTAssertEqual(gs.shadow.holySee.record.gatherings, 1)
        R337E.fresh(gs)
        gs.shadow.holySee.lastUsed[HolySeeAction.interfaithGathering.rawValue] = gs.currentDate
        XCTAssertNotNil(e.holySeeProblem(HolySeeOrder(action: .interfaithGathering)))
    }

    /// Debt relief: creditors agree by their relations; the poorest nations' debts fall.
    @MainActor
    func testDebtRelief() throws {
        let (e, gs) = try R337E.game()
        let poor = try XCTUnwrap(HolySeeModel.debtors(gs).first)
        if let i = gs.countries.firstIndex(where: { $0.id == poor.id }) { gs.countries[i].debtLevel = 50 }
        let no = try R337E.run(e, HolySeeOrder(action: .debtRelief), roll: 0.99)
        XCTAssertFalse(no.success)
        XCTAssertEqual(gs.shadow.holySee.record.debtRelievedB, 0)
        R337E.fresh(gs)
        let r = try R337E.run(e, HolySeeOrder(action: .debtRelief), roll: 0)
        XCTAssertTrue(r.success)
        XCTAssertGreaterThan(gs.shadow.holySee.record.debtRelievedB, 0)
        XCTAssertEqual(gs.getCountry(id: poor.id)?.debtLevel, 45)
    }

    /// Relations: patience improves the odds with a government hostile to religion; then it is accredited.
    @MainActor
    func testOpenRelations() throws {
        let (e, gs) = try R337E.game()
        let target = try XCTUnwrap(gs.liveCountries.first { HolySeeModel.hostileToReligion($0) })
        XCTAssertFalse(HolySeeModel.hasRelations(gs, target))
        XCTAssertTrue(HolySeeModel.hasRelations(gs, try XCTUnwrap(gs.getCountry(id: "FRA"))) || R337E.rel(gs, "FRA", "VAT") < 0)
        let odds = HolySeeModel.relationsOdds(gs, target)
        XCTAssertFalse(try R337E.run(e, HolySeeOrder(action: .openRelations, first: target.id), roll: 0.99).success)
        XCTAssertEqual(gs.shadow.holySee.attempts[target.id], 1)
        XCTAssertGreaterThan(HolySeeModel.relationsOdds(gs, target), odds, "patience counts")
        R337E.fresh(gs)
        let r = try R337E.run(e, HolySeeOrder(action: .openRelations, first: target.id), roll: 0)
        XCTAssertTrue(r.lines[0].contains("eases its restrictions"), r.lines[0])
        XCTAssertTrue(HolySeeModel.hasRelations(gs, try XCTUnwrap(gs.getCountry(id: target.id))))
        R337E.fresh(gs)
        XCTAssertTrue(e.holySeeProblem(HolySeeOrder(action: .openRelations, first: target.id))?.contains("already") ?? false)
    }

    /// The United Nations: once a game; a year of standing for every peace effort.
    @MainActor
    func testAddressUN() throws {
        let (e, gs) = try R337E.game()
        R337E.dispute(gs, "ARG", "CHL", toVAT: 0)
        let before = HolySeeModel.pairOdds(gs, .hostTalks, "ARG", "CHL")
        _ = try R337E.run(e, HolySeeOrder(action: .addressUN))
        XCTAssertTrue(gs.shadow.holySee.record.addressedUN)
        XCTAssertGreaterThan(HolySeeModel.pairOdds(gs, .hostTalks, "ARG", "CHL"), before)
        R337E.fresh(gs)
        XCTAssertTrue(e.holySeeProblem(HolySeeOrder(action: .addressUN))?.contains("already") ?? false)
    }

    /// Resigning ends the game with dignity: scored on the record, "A Dignified Farewell", not "Served the Full Term".
    @MainActor
    func testResign() throws {
        let (e, gs) = try R337E.game()
        gs.shadow.holySee.record.treatiesAtVatican = 1
        let points = gs.shadow.holySee.record.points
        _ = try R337E.run(e, HolySeeOrder(action: .resignOffice))
        XCTAssertEqual(gs.shadow.domesticEnding, .steppedDown)
        e.endTurn()
        XCTAssertTrue(gs.gameOver)
        XCTAssertEqual(e.victoryType, .servedFullTerm)
        XCTAssertEqual(gs.gameOverReason, VictoryType.servedFullTerm.description(for: gs))
        XCTAssertEqual(VictoryType.servedFullTerm.title(for: gs), "A Dignified Farewell")
        XCTAssertGreaterThanOrEqual(PeaceModel.scoreBonus(gs), points, "the record is in the score")
        XCTAssertFalse(gs.shadow.presidency.awards.contains("served_the_full_term"))
        XCTAssertTrue(gs.shadow.presidency.awards.contains("signed_at_the_vatican"))
        XCTAssertTrue(PresidencyEpilogue.verdictTemplate(gs, victory: nil).contains("chose to resign the papacy"))
    }
}

// MARK: - The command box, the chief of staff, the model

final class HolySeeCommandTests: XCTestCase {
    @MainActor
    func testCommandBoxPhrases() throws {
        let i = try XCTUnwrap(CommandParser.parse("mediate between Chile and Argentina"))
        XCTAssertEqual(i.verb, .mediate)
        XCTAssertEqual(i.targets, ["chile", "argentina"])
        XCTAssertEqual(CommandParser.parse("appeal for peace")?.verb, .appealForPeace)
        XCTAssertEqual(CommandParser.parse("issue an encyclical on the environment")?.detail, "environment")
        XCTAssertEqual(CommandParser.parse("ratify the treaty on the prohibition of nuclear weapons")?.detail, "tpnw")
        XCTAssertEqual(CommandParser.parse("ratify the comprehensive test ban treaty")?.detail, "ctbt")
        XCTAssertNotEqual(CommandParser.parse("ratify the antarctic treaty")?.verb, .ratifyTreaty, "the Antarctic Treaty is not an arms treaty")
        XCTAssertEqual(CommandParser.parse("host peace talks between Russia and Ukraine")?.targets, ["russia", "ukraine"])

        let (e, gs) = try R337E.game()
        R337E.dispute(gs, "ARG", "CHL")
        guard case .plan(let plan) = CmdFixtures.plan(e, "mediate between Chile and Argentina") else { return XCTFail("no plan") }
        XCTAssertEqual(plan.title, "MEDIATE A DISPUTE")
        XCTAssertEqual(plan.orders.first?.kind, .holySee)
        XCTAssertTrue(plan.warnings.contains { $0.text.contains("Beagle Channel") }, "the precedent is on the card")
        guard case .plan(let visit) = CmdFixtures.plan(e, "visit Poland") else { return XCTFail("no visit") }
        XCTAssertEqual(visit.orders.first?.mission, HolySeeAction.pastoralVisit.rawValue, "a pope's visit is pastoral")
        guard case .plan(let teach) = CmdFixtures.plan(e, "issue an encyclical on nuclear disarmament") else { return XCTFail("no teaching") }
        XCTAssertEqual(teach.orders.first?.detail, "nuclear")
        let o = try XCTUnwrap(plan.orders.first)
        XCTAssertNil(e.orderProblem(o))
        XCTAssertTrue(e.executeOrder(o))
        XCTAssertNotNil(gs.shadow.holySee.lastUsed[HolySeeAction.mediate.rawValue])
        if case .rejected(let why) = CmdFixtures.plan(e, "appeal for peace") { XCTAssertTrue(why.contains("nuclear crisis") || why.contains("actions"), why) }
        else { XCTFail("no crisis, no appeal") }
    }

    /// The chief of staff lists the Holy See's actions in a Vatican game and puts one on a card.
    @MainActor
    func testChiefOfStaff() throws {
        let (e, gs) = try R337E.game()
        R337E.dispute(gs, "ARG", "CHL")
        let all = ChatTools.run("actions", arguments: ["category": "diplomatic"], engine: e).text
        XCTAssertTrue(all.contains("holy_see"), all)
        XCTAssertTrue(all.contains("mediate (two nations)"), all)
        let out = ChatTools.run("propose_orders", arguments: ["steps": [["verb": "mediate", "targets": ["Argentina", "Chile"]]]], engine: e, planID: 1)
        XCTAssertFalse(out.isError, out.text)
        guard case .plan(let p)? = out.plan?.steps.first?.outcome else { return XCTFail(out.text) }
        XCTAssertEqual(p.orders.first?.kind, .holySee)
        let teach = ChatTools.run("propose_orders", arguments: ["steps": [["verb": "encyclical", "theme": "environment"]]], engine: e, planID: 2)
        guard case .plan(let t)? = teach.plan?.steps.first?.outcome else { return XCTFail(teach.text) }
        XCTAssertEqual(t.orders.first?.detail, "environment")
        XCTAssertTrue(ChatTools.run("propose_orders", arguments: ["steps": [["verb": "encyclical", "theme": "dragons"]]], engine: e, planID: 3).isError)
    }

    /// Hidden for every other nation: no sheet button, nothing in the chief of staff's list, the command box refuses,
    /// the order is refused, and the turn processing never draws a number.
    @MainActor
    func testHiddenForOtherNations() throws {
        for id in ["USA", "ITA", "MCO"] {
            let (e, gs) = try R337E.game(id)
            XCTAssertFalse(HolySeeModel.isOffered(gs), id)
            let all = ChatTools.run("actions", arguments: ["category": "diplomatic"], engine: e).text
            XCTAssertFalse(all.contains("holy_see"), id)
            XCTAssertFalse(all.contains("appealForPeace"), id)
            R337E.dispute(gs, "ARG", "CHL")
            if case .rejected(let why) = CmdFixtures.plan(e, "mediate between Chile and Argentina") {
                XCTAssertTrue(why.contains("Only the Holy See"), why)
            } else { XCTFail(id) }
            XCTAssertTrue(e.holySeeProblem(HolySeeOrder(action: .appealForPeace))?.contains("Only the Holy See") ?? false)
            XCTAssertNil(e.runHolySee(HolySeeOrder(action: .addressUN), roll: 0))
            XCTAssertFalse(e.executeOrder(HolySeeOrder(action: .addressUN).gameOrder))
            if case .plan(let p) = CmdFixtures.plan(e, "visit France") { XCTAssertNotEqual(p.orders.first?.kind, .holySee, id) }
            let rng = gs.rng
            e.processHolySee()
            XCTAssertEqual(gs.rng, rng, "no number drawn outside a Vatican game")
            XCTAssertFalse(e.holySeeHoldsWar("ARG", "CHL"))
            XCTAssertEqual(HolySeeModel.scoreBonus(gs), 0)
            XCTAssertNil(HolySeeModel.victory(gs))
            XCTAssertTrue(HolySeeModel.earnedAwards(gs, victory: nil).isEmpty)
        }
    }

    /// The record's points and Honest Broker's conditions.
    @MainActor
    func testScoreAndVictoryConditions() throws {
        let (_, gs) = try R337E.game()
        var r = HolySeeRecord()
        r.treatiesAtVatican = 1; r.crisesDefused = 1; r.traced = 5_000
        XCTAssertEqual(r.points, 150 + 150 + 50)
        r.traced = 1_000_000
        XCTAssertEqual(r.points, 300 + 300, "lives saved are capped")
        gs.shadow.holySee.record = r
        XCTAssertTrue(HolySeeModel.victoryProblem(gs)?.contains("years in office") ?? false)
        gs.turn = 24
        XCTAssertNil(HolySeeModel.victoryProblem(gs))
        XCTAssertEqual(VictoryChecker.checkVictory(gameState: gs), .honestBroker)
        XCTAssertEqual(VictoryType.honestBroker.baseScore, 1300)
        gs.shadow.holySee.record.crisesDefused = 0
        gs.shadow.holySee.record.treatiesAtVatican = 0
        XCTAssertTrue(HolySeeModel.victoryProblem(gs)?.contains("points") ?? false)
    }
}

// MARK: - Functional: a short Vatican game

final class HolySeeGameTests: XCTestCase {
    /// Functional: a Vatican game played through the command box: a dispute mediated to a treaty signed at the
    /// Vatican, an appeal in a nuclear crisis, then the rest of the record, until Honest Broker wins it.
    @MainActor
    func testShortVaticanGameWinsOnPeace() async throws {
        let (e, gs) = try R337E.game(seed: 2026)
        var refused: [String] = []
        func order(_ text: String) -> Bool {
            guard gs.actionsRemaining > 0, !gs.gameOver else { return false }
            let outcome = CmdFixtures.plan(e, text)
            guard case .plan(let p) = outcome else { refused.append("\(gs.turn) \(text): \(outcome)"); return false }
            let ok = e.executeCommand(p.orders, source: .parser).carried.count == 1
            if !ok { refused.append("\(gs.turn) \(text): not carried") }
            return ok
        }
        var mediated = false, appealed = false
        for _ in 0..<60 where !gs.gameOver {
            e.crisisManager.activeCrisis = nil
            e.crisisManager.pendingCrises = []
            if gs.shadow.holySee.record.treatiesAtVatican == 0 {
                R337E.dispute(gs, "ARG", "CHL")
                if order("mediate between Chile and Argentina") { mediated = true }
            }
            if gs.shadow.holySee.record.crisesDefused == 0 {
                gs.defconLevel = .defcon2
                for c in gs.liveCountries where c.nuclearWarheads > 0 { gs.setRelation(from: c.id, to: "VAT", value: 90) }
                if order("appeal for peace") { appealed = true }
            }
            for text in ["issue an encyclical on peace", "address the united nations", "ratify the nuclear ban treaty",
                         "campaign for debt relief", "convene an interfaith gathering", "trace prisoners"] {
                _ = order(text)
            }
            if gs.shadow.holySee.record.warsAverted < 2 {
                R337E.dispute(gs, "IND", "PAK", mutual: -60)
                _ = order("send envoys to India and Pakistan")
            }
            if !gs.gameOver { e.endTurn(); await R337E.settle(e) }
        }
        XCTAssertTrue(mediated, "a dispute was mediated: \(refused.prefix(30))")
        XCTAssertTrue(appealed, "an appeal was made in a crisis")
        let r = gs.shadow.holySee.record
        XCTAssertGreaterThanOrEqual(r.treatiesAtVatican, 1, "a treaty signed at the Vatican")
        XCTAssertGreaterThanOrEqual(r.crisesDefused, 1, "a nuclear crisis defused")
        XCTAssertTrue(gs.gameOver, (HolySeeModel.victoryProblem(gs) ?? "") + " \(refused.prefix(40)) \(gs.shadow.holySee.log.map(\.text).prefix(20))")
        XCTAssertEqual(e.victoryType, .honestBroker, gs.gameOverReason)
        XCTAssertGreaterThanOrEqual(r.points, HolySeeModel.victoryPoints)
        XCTAssertTrue(gs.shadow.presidency.awards.contains("honest_broker"))
        XCTAssertTrue(gs.shadow.presidency.awards.contains("signed_at_the_vatican"))
        XCTAssertTrue(gs.shadow.presidency.awards.contains("back_from_the_brink"))
        let verdict = PresidencyEpilogue.verdictTemplate(gs, victory: .honestBroker)
        XCTAssertTrue(verdict.contains("The Holy See mediated"), verdict)
        XCTAssertTrue(R337D.americanisms(verdict).isEmpty, verdict)
        let score = GameScore.calculate(from: gs, victoryType: .honestBroker)
        XCTAssertGreaterThanOrEqual(score.peaceBonus ?? 0, r.points)
    }
}

// MARK: - Determinism, saves, play events, content

final class HolySeePersistenceTests: XCTestCase {
    /// Determinism: the same seed and the same orders give the same record and the same news.
    @MainActor
    func testSameSeedSameRecord() async throws {
        func play() async throws -> (HolySeeRecord, [String]) {
            let (e, gs) = try R337E.game(seed: 41)
            R337E.dispute(gs, "ARG", "CHL", toVAT: 10)
            _ = e.runHolySee(HolySeeOrder(action: .mediate, first: "ARG", second: "CHL"))
            _ = e.runHolySee(HolySeeOrder(action: .debtRelief))
            e.endTurn()
            await R337E.settle(e)
            gs.actionsUsedThisTurn = 0
            _ = e.runHolySee(HolySeeOrder(action: .ratifyTreaty, option: "tpnw"))
            e.endTurn()
            await R337E.settle(e)
            return (gs.shadow.holySee.record, gs.shadow.ticker.map(\.text).filter { !$0.hasPrefix("Hall of Infamy") && !$0.hasPrefix("Nova:") })
        }
        let a = try await play(), b = try await play()
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
    }

    /// Saves: the Holy See's state survives a round-trip; an older save (no `holySee`) loads with an empty one.
    @MainActor
    func testSaveRoundTrip() throws {
        let (e, gs) = try R337E.game()
        R337E.dispute(gs, "IND", "PAK", mutual: -60)
        _ = try R337E.run(e, HolySeeOrder(action: .sendEnvoys, first: "IND", second: "PAK"), roll: 0)
        R337E.fresh(gs)
        _ = try R337E.run(e, HolySeeOrder(action: .encyclical, option: "nuclear"))
        gs.shadow.holySee.lastUsed["sendEnvoys"] = gs.currentDate
        let back = try SaveCodec.decode(try SaveCodec.encode(gs))
        XCTAssertEqual(back.shadow.holySee, gs.shadow.holySee)
        XCTAssertEqual(back.shadow.holySee.record.warsAverted, 1)

        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs.shadow)) as? [String: Any])
        obj["holySee"] = nil
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(old.holySee, HolySeeState())
        // A half-written record (an older field set) decodes with defaults.
        let partial = try JSONDecoder().decode(HolySeeState.self, from: Data(#"{"record":{"ceasefires":2}}"#.utf8))
        XCTAssertEqual(partial.record.ceasefires, 2)
        XCTAssertEqual(partial.record.points, 240)
        // The steppedDown ending round-trips.
        gs.shadow.domesticEnding = .steppedDown
        XCTAssertEqual(try SaveCodec.decode(try SaveCodec.encode(gs)).shadow.domesticEnding, .steppedDown)
    }

    /// Every action logs a play event Nova's reports pick up.
    @MainActor
    func testPlayEvents() async throws {
        let dir = StoreFixtures.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "VAT", turnLength: .month, year: 2025, seed: 5)
        let gs = try XCTUnwrap(e.gameState)
        e.crisisManager.activeCrisis = nil
        let id = try XCTUnwrap(gs.shadow.playSessionID)
        R337E.dispute(gs, "ARG", "CHL")
        _ = try R337E.run(e, HolySeeOrder(action: .mediate, first: "ARG", second: "CHL"), roll: 0)
        R337E.fresh(gs)
        _ = try R337E.run(e, HolySeeOrder(action: .pastoralVisit, first: "POL"))
        _ = await service.syncNow()
        let events = await remote.events(id)
        let kinds = Set(events.map(\.kind))
        XCTAssertTrue(kinds.contains("holy_see_mediation"), "\(kinds)")
        XCTAssertTrue(kinds.contains("holy_see_visit"), "\(kinds)")
        let d = try XCTUnwrap(events.first { $0.kind == "holy_see_mediation" }.map(PlayFixtures.detail))
        XCTAssertEqual(d["success"] as? Bool, true)
        XCTAssertEqual(d["first"] as? String, "ARG")
    }

    /// Content rules: every line the Holy See's actions show passes the content check, names no real pope, uses no
    /// American office words, and makes no rite or sacrament a mechanic.
    @MainActor
    func testContentRules() throws {
        var texts: [String] = HolySeeAction.allCases.flatMap { [$0.title, $0.summary, $0.precedent] }
        texts += TeachingTheme.allCases.flatMap { [$0.title, $0.example] } + ArmsTreaty.all.map(\.name)
        texts += HolySeeModel.awards.flatMap { [$0.name, $0.description] }
        texts += [DomesticEnding.steppedDown.headline, VictoryType.honestBroker.description]
        let (e, gs) = try R337E.game()
        R337E.war(e, gs, "ETH", "ERI")
        R337E.dispute(gs, "ARG", "CHL")
        for (o, roll) in [(HolySeeOrder(action: .mediate, first: "ARG", second: "CHL"), 0.99),
                          (HolySeeOrder(action: .hostTalks, first: "ETH", second: "ERI"), 0.99), (HolySeeOrder(action: .interfaithGathering), 0.0)] {
            R337E.fresh(gs)
            texts += try R337E.run(e, o, roll: roll).lines
        }
        let banned = ["sacrament", "excommunicat", "canoniz", "blessing", "miracle", "heretic", "infidel", "crusade", "pray for",
                      "Francis", "Benedict", "John Paul", "Paul VI", "John XXIII", "Pius", "Leo XIV"]
        for t in texts {
            XCTAssertFalse(ChatSafety.violates(t), t)
            XCTAssertTrue(R337D.americanisms(t).isEmpty, t)
            for b in banned { XCTAssertFalse(t.localizedCaseInsensitiveContains(b), "\(b): \(t)") }
        }
    }
}
