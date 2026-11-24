//
//  ConsequencesTests.swift
//  GTNWTests
//
//  3.36.0: consequences (Shared/Engine/Shadow/Consequences.swift) — strikes on protected nations, fallout drift,
//  refugees, alliance councils (Denmark and Greenland), the post-presidency trial, and the save.
//

import XCTest
@testable import GTNW

enum Cons {
    @MainActor
    static func game(_ year: Int = 2025, player: String = "USA", seed: UInt64 = 36) throws -> (GameEngine, GameState) {
        let e = CmdFixtures.engine(year: year, player: player, seed: seed)
        return (e, try XCTUnwrap(e.gameState))
    }

    /// `loser` has surrendered to the player: terms imposed and in force.
    @MainActor
    static func surrender(_ gs: GameState, _ loser: String) {
        gs.shadow.peaceTerms.append(PeaceTerms(victor: gs.playerCountryID, loser: loser, date: gs.currentDate, years: 10, negotiated: false))
    }

    static func ticker(_ gs: GameState) -> String { gs.shadow.ticker.map(\.text).joined(separator: "\n") }
}

// MARK: - Unit

final class ConsequencesUnitTests: XCTestCase {
    /// Unit: who is protected, and why.
    @MainActor
    func testProtection() throws {
        let (_, gs) = try Cons.game()
        Cons.surrender(gs, "URY")
        XCTAssertEqual(Consequences.protection(of: "URY", in: gs), .surrendered)
        gs.treaties.append(Treaty(type: .nonAggression, signatories: ["USA", "NRU"], turn: gs.turn))
        XCTAssertEqual(Consequences.protection(of: "NRU", in: gs), .peace)
        gs.setRelation(from: "USA", to: "BLZ", value: 55)
        XCTAssertEqual(Consequences.protection(of: "BLZ", in: gs), .friend(55))
        gs.setRelation(from: "USA", to: "BLZ", value: 40)
        XCTAssertNil(Consequences.protection(of: "BLZ", in: gs), "40 is not above 40")
        XCTAssertNil(Consequences.protection(of: "USA", in: gs))
    }

    /// Unit: the wind carries fallout east in the westerlies and west in the trade winds; drift is deterministic.
    func testWindAndDrift() {
        let paris = Coordinates(lat: 48.9, lon: 2.3), berlin = Coordinates(lat: 52.5, lon: 13.4)
        XCTAssertGreaterThan(Consequences.windFactor(from: paris, to: berlin), Consequences.windFactor(from: berlin, to: paris))
        let belize = Coordinates(lat: 17.2, lon: -88.8), mexicoCity = Coordinates(lat: 19.4, lon: -99.1)
        XCTAssertEqual(Consequences.windFactor(from: belize, to: mexicoCity), 1.5, "trade winds blow west")
        XCTAssertEqual(Consequences.deltaLon(170, -170), 20)
        XCTAssertEqual(Consequences.people(thousands: 1_234), "about 1.2 million")
        XCTAssertEqual(Consequences.list(["A", "B", "C"]), "A, B and C")
    }

    /// Unit: older saves load with an empty record; a record round-trips.
    @MainActor
    func testSaveRoundTrip() throws {
        let (e, gs) = try Cons.game()
        Cons.surrender(gs, "URY")
        e.launchNuclearStrike(from: "USA", to: "URY", warheads: 2)
        e.declareWar(aggressor: "USA", defender: "DNK")
        XCTAssertFalse(gs.shadow.consequences.conduct.isEmpty)
        let back = try JSONDecoder().decode(ShadowState.self, from: JSONEncoder().encode(gs.shadow))
        XCTAssertEqual(back.consequences, gs.shadow.consequences)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs.shadow)) as? [String: Any])
        obj.removeValue(forKey: "consequences")
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(old.consequences, ConsequenceState())
        let partial = try JSONDecoder().decode(ConsequenceState.self, from: Data(#"{"expelledFrom":["NATO"]}"#.utf8))
        XCTAssertEqual(partial.expelledFrom, ["NATO"])
        XCTAssertTrue(partial.conduct.isEmpty)
    }
}

// MARK: - Functional

final class ConsequencesFunctionalTests: XCTestCase {
    /// Functional: the card warns plainly before EXECUTE; after the strike, a tribunal, allies distance, approval falls.
    @MainActor
    func testStrikeOnSurrenderedNation() throws {
        let (e, gs) = try Cons.game()
        Cons.surrender(gs, "URY")
        let plan = try XCTUnwrap(CmdFixtures.confirmedPlan(e, "launch a nuclear strike on Uruguay with 2 warheads"))
        XCTAssertTrue(plan.warnings.contains { $0.level == 2 && $0.text.contains("already surrendered") && $0.text.contains("war-crimes") },
                      plan.warnings.map(\.text).joined(separator: " | "))
        let before = gs.shadow.popularity
        let gbr = gs.getCountry(id: "GBR")?.diplomaticRelations["USA"] ?? 0
        e.launchNuclearStrike(from: "USA", to: "URY", warheads: 2)
        XCTAssertEqual(gs.shadow.consequences.conduct.first?.kind, .nuclearOnSurrendered)
        XCTAssertGreaterThanOrEqual(gs.shadow.impeachmentStage, 2, "the tribunal drafts articles")
        XCTAssertLessThan(gs.shadow.popularity, before - 17)
        XCTAssertLessThan(gs.getCountry(id: "GBR")?.diplomaticRelations["USA"] ?? 0, gbr, "allies distance themselves")
        XCTAssertTrue(Cons.ticker(gs).contains("tribunal opens a case"))
    }

    /// Functional: a friend struck with no war — the card says so; an enemy at war gets no such warning.
    @MainActor
    func testFriendWarningOnlyForFriends() throws {
        let (e, gs) = try Cons.game()
        gs.setRelation(from: "USA", to: "BLZ", value: 60)
        let p = try XCTUnwrap(CmdFixtures.confirmedPlan(e, "launch a nuclear strike on Belize with 1 warhead"))
        XCTAssertTrue(p.warnings.contains { $0.text.contains("is a friend (relations +60)") })
        XCTAssertTrue(p.warnings.contains { $0.text.hasPrefix("Fallout will drift over") })
        gs.setRelation(from: "USA", to: "BLZ", value: -20)
        let q = try XCTUnwrap(CmdFixtures.confirmedPlan(e, "launch a nuclear strike on Belize with 1 warhead"))
        XCTAssertFalse(q.warnings.contains { $0.text.contains("is a friend") })
    }

    /// Functional: fallout drifts to the neighbors, who blame the striker; refugees flee into them.
    @MainActor
    func testFalloutDriftAndRefugees() throws {
        let (e, gs) = try Cons.game()
        let mex = try XCTUnwrap(gs.getCountry(id: "MEX"))
        let rel = mex.diplomaticRelations["USA"] ?? 0
        e.launchNuclearStrike(from: "USA", to: "BLZ", warheads: 3)
        let after = try XCTUnwrap(gs.getCountry(id: "MEX"))
        XCTAssertGreaterThan(after.radiationLevel, mex.radiationLevel)
        XCTAssertLessThan(after.diplomaticRelations["USA"] ?? 0, rel)
        XCTAssertGreaterThan(after.acceptedRefugees, mex.acceptedRefugees)
        XCTAssertTrue(Cons.ticker(gs).contains("Fallout from the strike on Belize drifts over"))
        XCTAssertTrue(Cons.ticker(gs).contains("flee Belize after the nuclear strike into"))
        let wave = try XCTUnwrap(gs.shadow.consequences.waves.last)
        XCTAssertEqual(wave.origin, "BLZ")
        XCTAssertNotNil(wave.receivers["MEX"])
    }

    /// Functional: refugees at the President's own border are a cabinet decision.
    @MainActor
    func testRefugeeCrisisCard() throws {
        let (e, gs) = try Cons.game()
        e.launchNuclearStrike(from: "USA", to: "MEX", warheads: 2)
        let card = try XCTUnwrap(([e.crisisManager.activeCrisis].compactMap { $0 } + e.crisisManager.pendingCrises)
            .first { $0.title.hasPrefix("REFUGEES FROM") })
        XCTAssertEqual(card.options.map(\.title), ["Take them in", "Aid the region", "Close the border"])
        XCTAssertTrue(card.description.contains("after your own attack"))
        e.crisisManager.activeCrisis = card
        e.crisisManager.pendingCrises = []
        var g: GameState = gs
        let ruth = gs.shadow.ruthlessness
        e.crisisManager.resolveCrisis(optionIndex: 2, gameState: &g)
        XCTAssertEqual(gs.shadow.consequences.waves.last?.playerChoice, "close")
        XCTAssertEqual(gs.shadow.ruthlessness, ruth + 3, accuracy: 0.001)
    }
}

// MARK: - Integration

final class ConsequencesIntegrationTests: XCTestCase {
    /// Integration: invading Denmark as the United States calls a NATO council; keeping at it gets the United States
    /// expelled, NATO turns away, and Greenland governs itself and closes itself to Washington.
    @MainActor
    func testDenmarkInvasionCostsNATOAndGreenland() throws {
        let (e, gs) = try Cons.game()
        XCTAssertNil(gs.getCountry(id: "GRL"), "Greenland is drawn under Denmark")
        XCTAssertEqual(Consequences.breakawayLands(of: "DNK", in: gs).map(\.id), ["GRL"])
        let p = try XCTUnwrap(CmdFixtures.confirmedPlan(e, "invade Denmark"))
        XCTAssertTrue(p.warnings.contains { $0.text.contains("NATO calls an emergency council") }, p.warnings.map(\.text).joined(separator: " | "))
        XCTAssertTrue(p.warnings.contains { $0.text.contains("Greenland") })
        let fra = gs.getCountry(id: "FRA")?.diplomaticRelations["USA"] ?? 0
        e.declareWar(aggressor: "USA", defender: "DNK")
        let council = try XCTUnwrap(gs.shadow.consequences.councils.first)
        XCTAssertEqual(council.alliance, "NATO")
        XCTAssertTrue(council.members.contains("FRA"))
        XCTAssertLessThan(gs.getCountry(id: "FRA")?.diplomaticRelations["USA"] ?? 0, fra)
        XCTAssertTrue(gs.shadow.consequences.conduct.contains { $0.kind == .attackOnAlly && $0.target == "DNK" })
        // The war goes on past the council.
        gs.turn += 1
        e.processConsequenceTurn()
        XCTAssertTrue(gs.shadow.consequences.councils[0].expelled)
        XCTAssertEqual(gs.shadow.consequences.expelledFrom, ["NATO"])
        XCTAssertNil(Consequences.alliance(with: "GBR", in: gs), "no longer an ally in NATO")
        let grl = try XCTUnwrap(gs.getCountry(id: "GRL"))
        XCTAssertNil(grl.territoryOf)
        XCTAssertEqual(grl.diplomaticRelations["USA"], -60)
        XCTAssertEqual(gs.getPlayerCountry()?.diplomaticRelations["GRL"], -60)
        XCTAssertTrue(Cons.ticker(gs).contains("NATO expels"))
        XCTAssertTrue(Cons.ticker(gs).contains("Greenland takes charge of its own affairs"))
        XCTAssertTrue(gs.shadow.consequences.brokenAway.contains("GRL"))
        XCTAssertTrue(Consequences.breakawayLands(of: "DNK", in: gs).isEmpty, "it breaks away once")
    }

    /// Integration: an attack that stops before the next turn ends with a reprimand, not expulsion.
    @MainActor
    func testCouncilReprimandsWhenTheAttackStops() throws {
        let (e, gs) = try Cons.game()
        e.declareWar(aggressor: "USA", defender: "NOR")
        for i in gs.countries.indices { gs.countries[i].atWarWith.remove("NOR"); gs.countries[i].atWarWith.remove("USA") }
        gs.shadow.fronts.removeAll()
        gs.turn += 1
        e.processConsequenceTurn()
        XCTAssertTrue(gs.shadow.consequences.councils[0].closed)
        XCTAssertFalse(gs.shadow.consequences.councils[0].expelled)
        XCTAssertNil(gs.getCountry(id: "GRL"), "no expulsion, no breakaway")
        XCTAssertTrue(Cons.ticker(gs).contains("formal reprimand"))
    }

    /// Integration: the presidency ends; the record goes to court; charges are quoted verbatim.
    @MainActor
    func testPostPresidencyTrial() throws {
        let (e, gs) = try Cons.game()
        XCTAssertNil(Consequences.trial(gs), "no trial while in office")
        Cons.surrender(gs, "URY")
        e.launchNuclearStrike(from: "USA", to: "URY", warheads: 1)
        e.declareWar(aggressor: "USA", defender: "DNK")
        gs.shadow.domesticEnding = .impeached
        let lines = Debrief.lines(gs)
        let trial = try XCTUnwrap(lines.first { $0.title == "THE TRIAL" })
        for c in gs.shadow.consequences.conduct { XCTAssertTrue(trial.body.contains(c.text), c.text) }
        XCTAssertTrue(trial.body.contains("the International Criminal Court"))
        XCTAssertTrue(trial.body.contains("Verdict: guilty on"))
        XCTAssertTrue(trial.body.contains("life imprisonment") || trial.body.contains("20 years"))
        gs.shadow.domesticEnding = .assassinated
        XCTAssertNil(Consequences.trial(gs))
    }

    /// Integration: before 1945 no court sits; the record stands without a verdict.
    @MainActor
    func testNoCourtBefore1945() throws {
        let (e, gs) = try Cons.game(1900)
        Cons.surrender(gs, "MEX")
        e.declareWar(aggressor: "USA", defender: "MEX")
        XCTAssertEqual(gs.shadow.consequences.conduct.first?.kind, .attackOnSurrendered)
        XCTAssertEqual(gs.shadow.impeachmentStage, 0, "no tribunal before Nuremberg")
        gs.shadow.domesticEnding = .lostElection
        let t = try XCTUnwrap(Consequences.trial(gs))
        XCTAssertEqual(t.title, "THE RECORD BEFORE ANY COURT")
        XCTAssertFalse(t.body.contains("Verdict"))
    }
}

// MARK: - Determinism and safety

final class ConsequencesDeterminismTests: XCTestCase {
    /// Same seed, same orders: the same fallout, refugees and councils, and no draw from the RNG.
    @MainActor
    func testDeterministicAndNoRNG() throws {
        func play() throws -> (ConsequenceState, [Int], String) {
            let (e, gs) = try Cons.game(seed: 99)
            let rng = gs.rng
            e.driftFallout(from: "BLZ", attacker: "USA", radiation: 40)
            e.sendRefugees(from: "BLZ", cause: "USA", thousands: 300, why: "after the nuclear strike")
            e.attackOnAlly("DNK", how: "a war")
            e.processConsequenceTurn()
            XCTAssertEqual(gs.rng, rng, "consequences never draw from the RNG")
            var s = gs.shadow.consequences
            for i in s.waves.indices { s.waves[i].id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
            return (s, gs.countries.map(\.radiationLevel), Cons.ticker(gs))
        }
        let a = try play(), b = try play()
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
        XCTAssertEqual(a.2, b.2)
    }

    /// Safety: every line this release shows is neutral — no slurs, no embellishment words.
    @MainActor
    func testWordingIsNeutral() throws {
        let (e, gs) = try Cons.game()
        Cons.surrender(gs, "URY")
        e.launchNuclearStrike(from: "USA", to: "URY", warheads: 1)
        e.declareWar(aggressor: "USA", defender: "DNK")
        gs.turn += 1
        e.processConsequenceTurn()
        gs.shadow.domesticEnding = .termLimited
        var texts = gs.shadow.ticker.map(\.text) + gs.shadow.consequences.conduct.map(\.text)
        texts += Debrief.lines(gs).flatMap { [$0.title, $0.body] }
        texts += ConductKind.allCases.map(\.charge)
        for t in texts {
            for banned in ["butcher", "monster", "evil", "slaughter", "massacre", "genocide", "http", "127.0.0.1"] {
                XCTAssertFalse(t.lowercased().contains(banned), "\(banned) in: \(t)")
            }
        }
    }
}
