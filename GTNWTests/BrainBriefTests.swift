//
//  BrainBriefTests.swift
//  GTNWTests
//
//  3.37.0: what a model brain is told (BrainBrief.swift), every government's own fogged view of the others, the
//  war council for brain-ordered wars, the brain's memory, and the moves it may now make.
//

import XCTest
@testable import GTNW

@MainActor
enum BB {
    static func game(_ year: Int = 2025, seed: UInt64 = 7) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA", year: year, seed: seed)
        return (e, try XCTUnwrap(e.gameState))
    }

    static func index(_ gs: GameState, _ id: String) throws -> Int {
        try XCTUnwrap(gs.countries.firstIndex { $0.id == id })
    }

    /// The prompt a model would read: system and user parts.
    static func prompt(_ req: MoveRequest) -> String { BrainClient.systemPrompt + "\n" + BrainClient.userPrompt(req) }

    /// The line about `id` in a brief.
    static func line(_ text: String, _ id: String) -> String? {
        text.split(separator: "\n").map(String.init).first { $0.hasPrefix("- ") && $0.contains("[\(id)]") }
    }

    /// Spend generator draws until the next one is below `limit` (a council roll a test needs).
    static func nextRoll(below limit: Double, _ gs: GameState) {
        for _ in 0..<64 {
            var probe = gs.rng
            if Double.random(in: 0..<1, using: &probe) < limit { return }
            _ = gs.rng.next()
        }
    }
}

final class BrainBriefUnitTests: XCTestCase {
    /// Unit: the brief carries the nation's own state, its relations, the world, the player and its memory.
    @MainActor
    func testBriefCarriesEveryPart() throws {
        let (e, gs) = try BB.game()
        e.declareWar(aggressor: "RUS", defender: "UKR")
        gs.shadow.polls = [PollRecord(date: gs.currentDate, popularity: 48), PollRecord(date: gs.currentDate, popularity: 55)]
        gs.shadow.playerWarsStarted = 2
        gs.shadow.brainMemory["RUS"] = [BrainMemoryEntry(turn: 3, action: "CONDEMN", target: "USA", intent: "hostile",
                                                         rationale: "They armed our enemy.", outcome: nil)]
        XCTAssertTrue(e.applyWorldBrief(Data(R329.brief.utf8), day: "2026-11-15"))
        let req = try XCTUnwrap(e.buildMoveRequest(for: "RUS"))
        let s = req.worldStateSummary
        for part in ["[RUS] in 2025", "Your economy: GDP", "treasury", "debt", "trade deals", "sanctioned by",
                     "ground", "naval", "air", "ICBM", "SLBM", "bombers", "cyber offense", "missile defense", "Stability",
                     "approval", "Friends:", "Rivals:", "Allies:", "Blocs:", "CSTO", "Treaties:", "At war with: UKR",
                     "Other nations", "reach ", "Wars (", "RUS>UKR", "Real-world brief 2026-11-15", "RUS>UKR war 100",
                     "The human player: United States [USA]", "2 wars started", "Approval", "+7 lately",
                     "Your last moves", "CONDEMN USA \"They armed our enemy.\"", "Current intent: hostile"] {
            XCTAssertTrue(s.contains(part), "missing \(part)\n\(s)")
        }
        XCTAssertNotNil(BB.line(s, "UKR"), "its enemy is on the list")
        XCTAssertNotNil(BB.line(s, "USA"), "the player is on the list")
        XCTAssertTrue(BB.line(s, "USA")?.contains("PLAYER") ?? false)
        XCTAssertLessThanOrEqual(s.split(separator: "\n").filter { $0.hasPrefix("- ") }.count, 12, "capped at twelve nations")
        // The quieter moves are on offer.
        for verb in ["CONDEMN", "COVERT_ACTION", "TRADE_DEAL", "BACK_REBELS", "INTERNAL_REFORM"] {
            XCTAssertTrue(req.legalActions.contains(verb), verb)
        }
    }

    /// Unit: a nation the observer can barely see is shown as estimates with a source and an age, never the truth,
    /// and a field no source of its can see is a question mark.
    @MainActor
    func testFoggyNationShowsEstimatesNotTheTruth() throws {
        let (e, gs) = try BB.game()
        let o = try BB.index(gs, "BOL"), t = try BB.index(gs, "AUS")
        gs.countries[o].militaryStrength = 20          // no satellites, no signals: attachés and the press only
        gs.countries[o].spyNetworks["AUS"] = 0
        gs.countries[o].diplomaticRelations["AUS"] = -30   // a rival it still has an attaché with
        gs.countries[t].militaryStrength = 87
        gs.countries[t].navalForces = 77
        gs.countries[t].nuclearWarheads = 4321
        let s = try XCTUnwrap(e.buildMoveRequest(for: "BOL")).worldStateSummary
        let line = try XCTUnwrap(BB.line(s, "AUS"), s)
        XCTAssertFalse(s.contains("4321"), line)
        XCTAssertFalse(line.contains("army~87"), line)
        XCTAssertFalse(line.contains("77"), line)
        XCTAssertTrue(line.contains("[attache,"), line)
        XCTAssertTrue(line.contains("fleet ?"), "an attaché never sees the fleet: \(line)")
        XCTAssertTrue(line.contains("reach "), line)
        // Its own figures are the truth.
        XCTAssertTrue(s.contains("military 20/100"))
    }

    /// Unit: every estimate is off, by no more than its source's error grown with age, the same on every call, and
    /// building a brief spends no generator draw.
    @MainActor
    func testEstimatesAreBoundedDeterministicAndFree() throws {
        let (e, gs) = try BB.game()
        let rng = gs.rng
        let a = try XCTUnwrap(e.buildMoveRequest(for: "CHN")).worldStateSummary
        let b = try XCTUnwrap(e.buildMoveRequest(for: "CHN")).worldStateSummary
        XCTAssertEqual(a, b)
        XCTAssertEqual(gs.rng, rng, "a brief is pure")
        let chn = try XCTUnwrap(gs.getCountry(id: "CHN"))
        for subject in gs.liveCountries where subject.id != "CHN" && subject.militaryStrength > 10 {
            guard let est = Intelligence.estimate(.army, of: subject, for: chn, in: gs) else { continue }
            let truth = Double(subject.militaryStrength)
            let bound = est.source.error * (1 + 0.15 * Double(est.age)) * truth + 1e-9
            XCTAssertLessThanOrEqual(abs(est.value - truth), bound, subject.id)
            XCTAssertGreaterThan(abs(est.value - truth), 0, "never exactly right: \(subject.id)")
            XCTAssertLessThan(est.age, est.source.cadence)
        }
        // Another observer sees the same nation differently.
        let usa = try XCTUnwrap(gs.getCountry(id: "USA")), rus = try XCTUnwrap(gs.getCountry(id: "RUS"))
        let ind = try XCTUnwrap(gs.getCountry(id: "IND"))
        XCTAssertNotEqual(Intelligence.estimate(.army, of: ind, for: usa, in: gs)?.value,
                          Intelligence.estimate(.army, of: ind, for: rus, in: gs)?.value)
    }

    /// Unit: a crowded world still fits the token budget; the brief shrinks its lists before it truncates.
    @MainActor
    func testBriefStaysUnderTheTokenCap() throws {
        let (e, gs) = try BB.game()
        XCTAssertTrue(e.applyWorldBrief(Data(R329.brief.utf8), day: "2026-11-15"))
        let pairs = [("RUS", "UKR"), ("CHN", "IND"), ("PAK", "IND"), ("ISR", "IRN"), ("PRK", "KOR"), ("TUR", "SYR"),
                     ("SAU", "YEM"), ("ETH", "ERI"), ("ARM", "AZE"), ("VEN", "COL"), ("EGY", "LBY"), ("MAR", "DZA")]
        for (a, d) in pairs { e.declareWar(aggressor: a, defender: d) }
        let long = String(repeating: "We hold the line because history demands it of us and of our allies. ", count: 5)
        for id in ["RUS", "CHN", "IND", "FRA"] {
            gs.shadow.brainMemory[id] = (0..<5).map { BrainMemoryEntry(turn: $0, action: "COVERT_ACTION", target: "USA",
                                                                       intent: "hostile", rationale: BrainMemory.clean(long),
                                                                       outcome: "council stood the war down: CONDEMN instead") }
        }
        for k in 0..<10 { gs.shadow.post("A long dispatch number \(k) about the state of the world " + long, date: gs.currentDate, severity: 3) }
        for id in ["RUS", "CHN", "IND", "FRA", "BOL", "UKR"] {
            let req = try XCTUnwrap(e.buildMoveRequest(for: id))
            XCTAssertLessThanOrEqual(req.worldStateSummary.count, BrainBrief.maxChars, id)
            XCTAssertLessThan(BrainBrief.tokens(BB.prompt(req)), BrainBrief.tokenCap, "\(id): \(BB.prompt(req).count) chars")
        }
    }

    /// Unit: the shrink order ends, and a brief that cannot fit is cut to the cap.
    func testCapsShrinkToAFloor() {
        var caps = BrainBrief.Caps()
        var n = 0
        while caps.shrink() { n += 1 }
        XCTAssertGreaterThan(n, 5)
        XCTAssertEqual(caps.nations, 4)
        XCTAssertFalse(caps.shrink())
    }
}

final class BrainBriefFunctionalTests: XCTestCase {
    @MainActor override func setUp() async throws { AIFixtures.resetShared() }
    @MainActor override func tearDown() async throws { AIFixtures.resetShared() }

    /// A cautious government with a cheap alternative in hand (the 3.32 step-back case) on a neighbour it can reach.
    @MainActor
    private func cautious() throws -> (GameEngine, GameState) {
        let (e, gs) = try BB.game(1890)
        R332.shape(gs, "BRA", ambition: 1, ethic: 6, outcry: 0, military: 40)
        R332.shape(gs, "URY", military: 10, stability: 90, gdp: 0.01)
        let u = try BB.index(gs, "URY")
        gs.countries[u].diplomaticRelations["BRA"] = 80
        XCTAssertTrue(Reach.canReach("BRA", "URY", in: gs))
        return (e, gs)
    }

    /// Functional: a brain's war declaration goes before the council; a council that stands it down takes its
    /// cheaper instrument instead, on the record, and there is no war.
    @MainActor
    func testCouncilCanStandDownABrainWar() throws {
        let (e, gs) = try cautious()
        BB.nextRoll(below: 0.5, gs)
        let result = e.applyMove(MoveResponse(action: "DECLARE_WAR", target: "URY", rationale: "test"), for: "BRA")
        let d = try XCTUnwrap(gs.shadow.deliberations.last)
        XCTAssertEqual(d.actor, "BRA")
        XCTAssertNotEqual(d.chose, "war")
        XCTAssertEqual(result, .applied(WarCouncil.brainAlternative(d.chose, target: "URY").verb))
        XCTAssertFalse(gs.getCountry(id: "BRA")?.atWarWith.contains("URY") ?? true, "the war was stood down")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("steps back from war") })
    }

    /// Functional: a council that goes ahead gives the brain its war (and writes the paper once).
    @MainActor
    func testCouncilThatGoesAheadDeclaresTheWar() throws {
        let (e, gs) = try BB.game()
        let before = gs.shadow.deliberations.count
        XCTAssertEqual(e.applyMove(MoveResponse(action: "DECLARE_WAR", target: "UKR"), for: "RUS"), .applied("DECLARE_WAR"))
        XCTAssertTrue(gs.getCountry(id: "RUS")?.atWarWith.contains("UKR") ?? false)
        XCTAssertEqual(gs.shadow.deliberations.count, before + 1)
    }

    /// Functional: through the turn loop, the stood-down war is remembered with what happened instead, and the next
    /// brief tells the brain so.
    @MainActor
    func testTurnLoopRemembersTheStandDown() async throws {
        let (e, gs) = try cautious()
        while !e.brainThinks("BRA", turn: gs.turn) { gs.turn += 1 }
        e.setBrain(.kit(backend: "ollama", model: "m"), for: "BRA")
        e.brainTransportOverride = { req, _ in
            req.countryId == "BRA" ? MoveResponse(action: "DECLARE_WAR", target: "URY", rationale: "They insulted our flag.") : nil
        }
        BB.nextRoll(below: 0.5, gs)
        await e.processAITurnsWithBrains()
        let m = try XCTUnwrap(gs.shadow.brainMemory["BRA"]?.last)
        XCTAssertEqual(m.action, "DECLARE_WAR")
        XCTAssertEqual(m.target, "URY")
        XCTAssertEqual(m.rationale, "They insulted our flag.")
        XCTAssertTrue(m.outcome?.contains("council stood the war down") ?? false, "\(String(describing: m.outcome))")
        let next = try XCTUnwrap(e.buildMoveRequest(for: "BRA")).worldStateSummary
        XCTAssertTrue(next.contains("DECLARE_WAR URY \"They insulted our flag.\" (council stood the war down"), next)
    }

    /// Functional: the quieter moves run the built-in AI's own code, and the gates hold.
    @MainActor
    func testQuietMovesAndTheirGates() throws {
        let (e, gs) = try BB.game()
        let before = gs.getCountry(id: "RUS")?.diplomaticRelations["UKR"] ?? 0
        XCTAssertEqual(e.applyMove(MoveResponse(action: "CONDEMN", target: "RUS"), for: "UKR"), .applied("CONDEMN"))
        XCTAssertLessThan(gs.getCountry(id: "RUS")?.diplomaticRelations["UKR"] ?? 0, before, "the condemned think less of us")
        let stab = gs.getCountry(id: "IRN")?.stability ?? 0
        XCTAssertEqual(e.applyMove(MoveResponse(action: "BACK_REBELS", target: "IRN"), for: "ISR"), .applied("BACK_REBELS"))
        XCTAssertLessThan(gs.getCountry(id: "IRN")?.stability ?? 0, stab)
        XCTAssertEqual(e.applyMove(MoveResponse(action: "INTERNAL_REFORM"), for: "FRA"), .applied("INTERNAL_REFORM"))
        XCTAssertEqual(e.applyMove(MoveResponse(action: "TRADE_DEAL", target: "JPN"), for: "FRA"), .applied("TRADE_DEAL"))
        XCTAssertEqual(e.applyMove(MoveResponse(action: "COVERT_ACTION", target: "CHN"), for: "FRA"), .applied("COVERT_ACTION"))
        // No trade with an enemy, no rebels against an ally.
        e.declareWar(aggressor: "RUS", defender: "UKR")
        XCTAssertEqual(e.applyMove(MoveResponse(action: "TRADE_DEAL", target: "UKR"), for: "RUS"), .rejectedIllegal)
        e.formAlliance(country1: "FRA", country2: "DEU")
        XCTAssertEqual(e.applyMove(MoveResponse(action: "BACK_REBELS", target: "DEU"), for: "FRA"), .rejectedIllegal)
        if case .failure(let why) = e.validateMove(MoveResponse(action: "TRADE_DEAL", target: "UKR"), for: "RUS") {
            XCTAssertTrue(why.reason.contains("at war"))
        } else { XCTFail("trade with an enemy must be refused") }
    }

    /// Retry: a brain that never answers falls back to the built-in AI exactly as before; nothing is remembered,
    /// and two such games from one seed play the same.
    @MainActor
    func testFallbackIsUnchanged() async throws {
        func play() async throws -> (GameRNG, [String: [BrainMemoryEntry]], Set<String>) {
            let (e, gs) = try BB.game(seed: 99)
            for id in ["RUS", "CHN", "IND"] { e.setBrain(.kit(backend: "ollama", model: "m"), for: id) }
            e.brainTransportOverride = { _, _ in nil }
            await e.processAITurnsWithBrains()
            return (gs.rng, gs.shadow.brainMemory, e.lastTurnFallbackCountryIDs)
        }
        let a = try await play(), b = try await play()
        XCTAssertEqual(a.0, b.0)
        XCTAssertTrue(a.1.isEmpty, "a fallback is not the brain's move")
        XCTAssertEqual(a.2, b.2)
        XCTAssertFalse(a.2.isEmpty)
    }
}

final class BrainBriefSaveTests: XCTestCase {
    /// Save round-trip: the memory survives a save, and a save from before 3.37 loads with none.
    @MainActor
    func testMemoryRoundTripsAndOldSavesLoad() throws {
        let (_, gs) = try BB.game()
        let entry = BrainMemoryEntry(turn: 4, action: "DECLARE_WAR", target: "UKR", intent: "hostile",
                                     rationale: "Buffer zone.", outcome: "council stood the war down: CONDEMN instead")
        gs.shadow.brainMemory["RUS"] = [entry]
        let back = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(back.shadow.brainMemory["RUS"], [entry])
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs.shadow)) as? [String: Any])
        obj["brainMemory"] = nil
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertTrue(old.brainMemory.isEmpty)
    }
}
