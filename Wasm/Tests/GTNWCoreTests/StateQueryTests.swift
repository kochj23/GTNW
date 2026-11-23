//
//  StateQueryTests.swift
//  GTNWCoreTests
//
//  The web screens' "state and records" queries and verbs (NovaGames gtnw-lite screens domestic, empire, cities,
//  systems, intel, records, settings): every query leaves the game untouched, and every verb does what the app's
//  button does.
//

import XCTest
@testable import GTNWCore

final class StateQueryTests: XCTestCase {

    override class func setUp() {
        GTNWCoreTests.setUp()
    }

    override func tearDown() {
        CoreAI.brainsOn = false
        WebBrains.staged = [:]
        super.tearDown()
    }

    func json(_ s: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any] ?? [:]
    }

    func result(_ request: String, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        let r = json(GTNWBridge.query(request))
        XCTAssertEqual(r["ok"] as? Bool, true, "\(request): \(r["error"] ?? "")", file: file, line: line)
        return r["result"] as? [String: Any] ?? [:]
    }

    @discardableResult
    func act(_ order: String, ok: Bool = true, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        let r = json(GTNWBridge.act(order))
        XCTAssertEqual(r["ok"] as? Bool, ok, "\(order): \(r["error"] ?? "")", file: file, line: line)
        return r
    }

    func start(_ request: String) {
        XCTAssertEqual(json(GTNWBridge.newGame(request))["ok"] as? Bool, true)
    }

    func actions() -> Int { (json(GTNWBridge.snapshot())["state"] as? [String: Any])?["actionsRemaining"] as? Int ?? -1 }

    static let queries = [
        #"{"q":"congress","target":"CUB"}"#, #"{"q":"congress"}"#, #"{"q":"election"}"#, #"{"q":"dirtyTactics","target":"CUB","preset":"overwhelming"}"#,
        #"{"q":"territory","id":"CUB"}"#, #"{"q":"territory","id":"ATA","troops":3}"#, #"{"q":"acquisitions"}"#, #"{"q":"landMarket"}"#,
        #"{"q":"space"}"#, #"{"q":"cities","id":"USA"}"#, #"{"q":"systems"}"#, #"{"q":"intel"}"#, #"{"q":"records"}"#,
        #"{"q":"scorecard"}"#, #"{"q":"brains","jobs":true}"#,
    ]

    func testStateQueriesDoNotChangeTheGame() {
        let game = #"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#
        start(game)
        _ = GTNWBridge.endTurn(); _ = GTNWBridge.endTurn()
        let before = GTNWBridge.save()
        for q in Self.queries { _ = result(q) }
        XCTAssertEqual(json(GTNWBridge.save()) as NSDictionary, json(before) as NSDictionary, "a query changed the saved game")
        _ = GTNWBridge.endTurn(); _ = GTNWBridge.endTurn()
        let withQueries = json(GTNWBridge.snapshot())["state"] as? NSDictionary
        start(game)
        _ = GTNWBridge.endTurn(); _ = GTNWBridge.endTurn(); _ = GTNWBridge.endTurn(); _ = GTNWBridge.endTurn()
        XCTAssertEqual(json(GTNWBridge.snapshot())["state"] as? NSDictionary, withQueries)
    }

    func testCongressAndAnAuthorizationVote() {
        start(#"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#)
        let c = result(#"{"q":"congress","target":"CUB"}"#)
        XCTAssertEqual(c["usa"] as? Bool, true)
        XCTAssertEqual((c["kinds"] as? [Any])?.count, 2)
        XCTAssertEqual(c["warPowers"] as? String, "WAR POWERS: CLEAR")
        XCTAssertNotNil(c["risk"])
        let n = actions()
        let r = act(#"{"verb":"askCongress","target":"CUB","kind":"useOfForce"}"#)
        XCTAssertNotNil(r["report"])
        XCTAssertTrue(actions() == n - 1 || (r["state"] as? [String: Any])?["turn"] as? Int ?? 0 > 0)
        XCTAssertEqual((result(#"{"q":"congress","target":"CUB"}"#)["votes"] as? [Any])?.count, 1)
        act(#"{"verb":"askCongress","target":"CUB","kind":"nope"}"#, ok: false)
    }

    func testElectionCycleFollowsEachYearsLaw() {
        start(#"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#)
        let e = result(#"{"q":"election"}"#)
        let rules = e["rules"] as? [String: Any]
        XCTAssertEqual(rules?["year"] as? Int, 1964)
        XCTAssertEqual(rules?["debates"] as? Bool, false, "no televised debates between 1960 and 1976")
        let stages = e["stages"] as? [[String: Any]] ?? []
        XCTAssertTrue(stages.contains { $0["id"] as? String == "midtermCampaign" && $0["status"] as? String == "next" })
        XCTAssertTrue(stages.contains { $0["id"] as? String == "debate1" && $0["date"] == nil })
        XCTAssertTrue(stages.contains { $0["id"] as? String == "newHampshire" && $0["date"] != nil })
        XCTAssertNotNil(e["campaign"])

        start(#"{"player":"USA","year":1800,"seed":"7aa","rules":"golden"}"#)
        let early = result(#"{"q":"election"}"#)["rules"] as? [String: Any]
        XCTAssertEqual(early?["popularVote"] as? Bool, false)
        XCTAssertEqual(early?["ticket"] as? Bool, false, "before the 12th Amendment")
        let s1800 = result(#"{"q":"election"}"#)["stages"] as? [[String: Any]] ?? []
        XCTAssertTrue(s1800.contains { $0["id"] as? String == "iowa" && $0["status"] as? String == "none" }, "\(s1800)")

        start(#"{"player":"FRA","year":1962,"seed":"7aa","rules":"golden"}"#)
        XCTAssertEqual(result(#"{"q":"election"}"#)["usa"] as? Bool, false)
    }

    func testDirtyTacticsListAndAStance() {
        start(#"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#)
        let d = result(#"{"q":"dirtyTactics","target":"CUB"}"#)
        let tactics = d["tactics"] as? [[String: Any]] ?? []
        XCTAssertFalse(tactics.isEmpty)
        XCTAssertFalse((d["groups"] as? [Any] ?? []).isEmpty)
        if let usable = tactics.first(where: { $0["problem"] == nil && $0["stance"] as? Bool == false }), let id = usable["id"] as? String {
            act(#"{"verb":"dirtyTactic","id":"\#(id)","target":"CUB","covert":\#(usable["canBeCovert"] as? Bool == true)}"#)
        }
        act(#"{"verb":"dirtyTactic","id":"no-such-tactic"}"#, ok: false)
    }

    func testLandColoniesAndCampaignsIn1850() {
        start(#"{"player":"USA","year":1850,"seed":"1","rules":"golden"}"#)
        let ak = result(#"{"q":"territory","id":"USA_AK"}"#)
        XCTAssertEqual(ak["kind"] as? String, "colony")
        XCTAssertNotNil(ak["take"])
        XCTAssertNotNil(ak["deal"])
        let market = result(#"{"q":"landMarket"}"#)
        let lands = market["lands"] as? [[String: Any]] ?? []
        XCTAssertFalse(lands.isEmpty, "unclaimed land in 1850")
        guard let land = lands.first(where: { $0["emptyIsland"] as? Bool == true }) ?? lands.first, let id = land["id"] as? String else { return }
        let t = result(#"{"q":"territory","id":"\#(id)"}"#)
        XCTAssertNotNil(t["take"])
        let r = act(#"{"verb":"takeLand","id":"\#(id)","troops":1}"#)
        XCTAssertNotNil(r["report"])
        act(#"{"verb":"takeLand","id":"FRA"}"#, ok: false)
        act(#"{"verb":"claimCampaign","op":"cancel"}"#, ok: false)
        if (market["emptyIslands"] as? Int ?? 0) > 1 { act(#"{"verb":"claimCampaign","op":"launch","selection":"emptyIslands"}"#) }
    }

    func testTerritoryGovernRenameAndAlaska() {
        start(#"{"player":"USA","year":1867,"seed":"1","rules":"golden"}"#)
        let a = result(#"{"q":"acquisitions"}"#)
        XCTAssertGreaterThan(a["stars"] as? Int ?? 0, 30)
        let offers = a["offers"] as? [[String: Any]] ?? []
        if let alaska = offers.first(where: { $0["id"] as? String == "alaska" }) {
            XCTAssertEqual(alaska["seller"] as? String, "Russian Empire")
            act(#"{"verb":"acceptAcquisition","id":"alaska"}"#)
        }
        act(#"{"verb":"acceptAcquisition","id":"nowhere"}"#, ok: false)
        // A territory of our own: govern and rename it.
        let mine = (json(GTNWBridge.snapshot())["state"] as? [String: Any]).map { _ in result(#"{"q":"map"}"#) }
        let owned = (mine?["lands"] as? [String: [String: Any]] ?? [:]).first { $0.value["kind"] as? String == "territory" && $0.value["owner"] as? String == "USA" }
        if let id = owned.flatMap({ $0.value["selects"] as? String }), result(#"{"q":"territory","id":"\#(id)"}"#)["kind"] as? String == "mine" {
            act(#"{"verb":"governTerritory","id":"\#(id)","governance":"localElections"}"#)
            act(#"{"verb":"renameTerritory","id":"\#(id)","name":"New Name"}"#)
            XCTAssertEqual((result(#"{"q":"records"}"#)["names"] as? [[String: Any]])?.first?["current"] as? String, "New Name")
        }
        act(#"{"verb":"renameTerritory","id":"FRA","name":"Nope"}"#, ok: false)
    }

    func testSpaceCitiesSystemsIntelRecordsScorecard() {
        start(#"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#)
        XCTAssertEqual(result(#"{"q":"space"}"#)["spaceAge"] as? Bool, true)
        act(#"{"verb":"launchSatellite","type":"recon"}"#)
        let sats = result(#"{"q":"space"}"#)["satellites"] as? [[String: Any]] ?? []
        XCTAssertEqual(sats.first { $0["type"] as? String == "recon" }?["inOrbit"] as? Int, 1)
        act(#"{"verb":"launchSatellite","type":"gps"}"#, ok: false)
        XCTAssertEqual((result(#"{"q":"cities","id":"USA"}"#)["tiles"] as? [Any])?.count, 7)
        XCTAssertEqual(json(GTNWBridge.query(#"{"q":"cities","id":"ZZZ"}"#))["ok"] as? Bool, false)
        XCTAssertEqual((result(#"{"q":"systems"}"#)["sections"] as? [Any])?.count, 10)
        let intel = result(#"{"q":"intel"}"#)
        XCTAssertGreaterThan(intel["totalWarheads"] as? Int ?? 0, 0)
        XCTAssertFalse((intel["relations"] as? [Any] ?? []).isEmpty)
        let rec = result(#"{"q":"records"}"#)
        XCTAssertEqual((rec["empire"] as? [Any])?.count, 3)
        XCTAssertNotNil(rec["hall"] as? String)
        let card = result(#"{"q":"scorecard"}"#)
        XCTAssertEqual((card["meters"] as? [Any])?.count, 4)
        XCTAssertNil(card["final"], "no final score before the game is over")

        start(#"{"scenario":"cuba1962","seed":"5","rules":"golden"}"#)
        let sc = result(#"{"q":"scorecard"}"#)
        XCTAssertEqual(sc["scenario"] as? String, "cuba1962")
        XCTAssertFalse((sc["lines"] as? [Any] ?? []).isEmpty)
    }

    func testHallOfInfamyRoundTrip() {
        start(#"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#)
        let hall = #"{"nukes":{"value":3,"who":"United States, 1962","gameDate":-229000000,"setAt":1700000000}}"#
        let order = try? JSONSerialization.data(withJSONObject: ["verb": "hallOfInfamy", "hall": hall])
        act(String(decoding: order ?? Data(), as: UTF8.self))
        let infamy = result(#"{"q":"records"}"#)["infamy"] as? [[String: Any]] ?? []
        XCTAssertEqual(infamy.first { $0["id"] as? String == "nukes" }?["who"] as? String, "United States, 1962")
        act(#"{"verb":"hallOfInfamy","hall":"not json"}"#, ok: false)
        act(#"{"verb":"hallOfInfamy","hall":"{}"}"#)
    }

    func testWatchAIvsAIAndTakeTheSeat() {
        start(#"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#)
        act(#"{"verb":"spectate","op":"turn"}"#, ok: false)
        act(#"{"verb":"spectate","op":"watch"}"#)
        XCTAssertEqual(result(#"{"q":"brains"}"#)["spectating"] as? Bool, true)
        let t0 = (json(GTNWBridge.snapshot())["state"] as? [String: Any])?["turn"] as? Int ?? 0
        act(#"{"verb":"spectate","op":"turn"}"#)
        act(#"{"verb":"spectate","op":"turn"}"#)
        XCTAssertEqual((json(GTNWBridge.snapshot())["state"] as? [String: Any])?["turn"] as? Int, t0 + 2)
        act(#"{"verb":"spectate","op":"takeSeat"}"#)
        XCTAssertEqual(result(#"{"q":"brains"}"#)["spectating"] as? Bool, false)
    }

    func testSiteAIBrainsAreAskedBeforeTheTurnAndFallBack() {
        start(#"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#)
        act(#"{"verb":"assignBrain","country":"RUS","brain":"relay"}"#)
        act(#"{"verb":"assignBrain","country":"RUS","brain":"bogus"}"#, ok: false)
        let b = result(#"{"q":"brains","jobs":true}"#)
        XCTAssertEqual(b["relayCount"] as? Int, 1)
        XCTAssertEqual((b["countries"] as? [[String: Any]])?.first { $0["id"] as? String == "RUS" }?["brain"] as? String, "relay")
        let jobs = b["jobs"] as? [[String: Any]] ?? []
        if let job = jobs.first {
            XCTAssertEqual(job["country"] as? String, "RUS")
            XCTAssertTrue((job["legal"] as? [String] ?? []).contains("WAIT"))
            XCTAssertFalse((job["situation"] as? String ?? "").isEmpty)
        }
        act(#"{"verb":"brainMoves","on":true,"moves":{"RUS":{"action":"WAIT"}}}"#)
        XCTAssertEqual(json(GTNWBridge.endTurn())["ok"] as? Bool, true)
        XCTAssertTrue(WebBrains.staged.isEmpty || jobs.isEmpty, "a staged answer is used once")
        // AI off: the brain plays the rule-based AI; the game goes on.
        act(#"{"verb":"brainMoves","on":false}"#)
        XCTAssertEqual(json(GTNWBridge.endTurn())["ok"] as? Bool, true)
    }
}
