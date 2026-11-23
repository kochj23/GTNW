//
//  WarRoomTests.swift
//  GTNWCoreTests
//
//  The web War Room, Diplomacy and Budget sheets: their read-only queries (fronts, settlements, fleets, arsenal,
//  manpower, airCampaign, peace, warRecord, messages, coalitions, treaties, groupAction, budget, aid, resources)
//  and the `act` verbs behind their buttons. Queries never change the game; verbs play the app's buttons and keep
//  the game a function of seed and orders.
//

import XCTest
@testable import GTNWCore

final class WarRoomTests: XCTestCase {

    override class func setUp() {
        GTNWCoreTests.setUp()
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
    func act(_ request: String, ok: Bool = true, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        let r = json(GTNWBridge.act(request))
        XCTAssertEqual(r["ok"] as? Bool, ok, "\(request): \(r["error"] ?? "")", file: file, line: line)
        return r
    }

    func startGame(_ request: String = #"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#) {
        XCTAssertEqual(json(GTNWBridge.newGame(request))["ok"] as? Bool, true)
        _ = GTNWBridge.endTurn()
    }

    static let readOnly = [
        #"{"q":"fronts"}"#, #"{"q":"settlements"}"#, #"{"q":"fleets","target":"CUB"}"#,
        #"{"q":"fleets","target":"CUB","fleet":"second","mission":"amphibious","preset":"overwhelming"}"#,
        #"{"q":"arsenal","target":"CUB"}"#, #"{"q":"arsenal","target":"CUB","action":"Ground Invasion","troops":90}"#,
        #"{"q":"arsenal","target":"RUS","action":"Launch Nukes"}"#, #"{"q":"manpower"}"#, #"{"q":"airCampaign","target":"CUB"}"#,
        #"{"q":"peace"}"#, #"{"q":"warRecord"}"#, #"{"q":"messages"}"#, #"{"q":"coalitions","target":"CUB"}"#, #"{"q":"treaties"}"#,
        #"{"q":"groupAction","pick":"region","region":"Europe","kind":"aid","amount":10}"#, #"{"q":"groupAction","pick":"allies","kind":"message"}"#,
        #"{"q":"budget"}"#, #"{"q":"budget","draft":{"defense":12,"personalTax":40}}"#, #"{"q":"aid","id":"EGY"}"#, #"{"q":"resources"}"#,
    ]

    func testRegistriesAreAlphabeticalAndUnknownVerbsFail() {
        XCTAssertEqual(VerbRegistry.byName.count, VerbRegistry.all.count, "two verbs share a name")
        XCTAssertEqual(VerbRegistry.all.map { $0.name }, VerbRegistry.all.map { $0.name }.sorted(), "keep the verb registry alphabetical")
        startGame()
        act(#"{"verb":"nope"}"#, ok: false)
        act(#"{"verb":"commitTroops"}"#, ok: false)
        act(#"{"verb":"recallFleet","id":"not-a-uuid"}"#, ok: false)
    }

    func testTheSheetsQueriesDoNotChangeTheGame() {
        startGame()
        let before = GTNWBridge.save(), snap = GTNWBridge.snapshot()
        for q in Self.readOnly { _ = result(q) }
        XCTAssertEqual(json(GTNWBridge.save()) as NSDictionary, json(before) as NSDictionary, "a query changed the saved game")
        XCTAssertEqual(GTNWBridge.snapshot(), snap)
    }

    /// Invade Cuba at a chosen size, then work the front from the War Room.
    func testAWarFromTheWarRoom() {
        startGame()
        let arsenal = result(#"{"q":"arsenal","target":"CUB","action":"Ground Invasion","troops":80}"#)
        let sizing = arsenal["sizing"] as? [String: Any]
        XCTAssertEqual((sizing?["forces"] as? [[String: Any]])?.first?["amount"] as? Int, 80)
        XCTAssertEqual((sizing?["presets"] as? [Any])?.count, 3)
        XCTAssertNotNil(sizing?["readout"])
        XCTAssertEqual((sizing?["warnings"] as? [Any])?.count, 3)
        XCTAssertTrue((arsenal["lines"] as? [[String: Any]] ?? []).contains { $0["action"] as? String == "Ground Invasion" && $0["arsenal"] != nil })
        // An invasion can fail (no war); the first seed whose invasion lands opens the front.
        var found: [String: Any]?
        for seed in 1...12 where found == nil {
            startGame(#"{"player":"USA","year":1962,"seed":"\#(seed)","rules":"golden"}"#)
            let r = act(#"{"verb":"sizedOrder","action":"Ground Invasion","target":"CUB","troops":100000}"#)
            XCTAssertNotNil(r["report"])
            _ = GTNWBridge.endTurn()   // the War Room opens a front for every war as the turn is played
            let fronts = result(#"{"q":"fronts"}"#)["fronts"] as? [[String: Any]] ?? []
            found = fronts.first { ($0["attacker"] as? String) == "USA" && ($0["defender"] as? String) == "CUB" }
        }
        guard let f = found, let id = f["id"] as? String else { return XCTFail("no invasion of Cuba landed") }
        XCTAssertEqual(f["usBelligerent"] as? Bool, true)
        XCTAssertEqual((f["troops"] as? [Any])?.count, 4)
        if f["status"] as? String == "fighting" {
            XCTAssertEqual(f["peaceVerb"] as? String, "sueForPeace")
            act(#"{"verb":"commitTroops","front":"\#(id)","side":"KOR","thousands":10}"#, ok: false)   // not a side on this front
            let d = act(#"{"verb":"demandSurrender","front":"\#(id)"}"#)
            XCTAssertNotNil((d["report"] as? [String: Any])?["success"])
        }
        let after = result(#"{"q":"fronts"}"#)["fronts"] as? [[String: Any]] ?? []
        if after.first(where: { $0["id"] as? String == id })?["status"] as? String == "fighting" {
            let s = act(#"{"verb":"sueForPeace","front":"\#(id)"}"#)
            XCTAssertEqual((s["report"] as? [String: Any])?["lines"] as? [String], ["Ceasefire signed with Cuba."])
            let cuba = (s["state"] as? [String: Any])?["nations"] as? [[String: Any]]
            XCTAssertFalse((cuba?.first { $0["id"] as? String == "CUB" }?["atWarWith"] as? [String] ?? []).contains("USA"))
        } else {
            // Cuba gave up: the President's terms.
            let waiting = result(#"{"q":"settlements"}"#)["settlements"] as? [[String: Any]] ?? []
            guard let s = waiting.first, let sid = s["id"] as? String else { return XCTFail("a surrender with no terms waiting") }
            XCTAssertEqual((s["governments"] as? [Any])?.count, PostWarGovernment.allCases.count)
            XCTAssertNotNil((s["annex"] as? [String: Any])?["take"])
            act(#"{"verb":"settle","id":"\#(sid)","choice":"annex","name":"\#(String(repeating: "x", count: 60))"}"#, ok: false)
            act(#"{"verb":"settle","id":"\#(sid)","choice":"annex","name":"Isla Nueva"}"#)
            XCTAssertEqual((result(#"{"q":"settlements"}"#)["settlements"] as? [Any])?.count, 0)
            XCTAssertEqual(result(#"{"q":"country","id":"CUB"}"#)["nation"].flatMap { ($0 as? [String: Any])?["name"] as? String }, "Isla Nueva")
        }
        XCTAssertFalse((result(#"{"q":"warRecord"}"#)["chronicle"] as? String ?? "").isEmpty)
    }

    func testFleetsManpowerBudgetAidAndGroups() {
        startGame()
        let fleets = result(#"{"q":"fleets","target":"CUB"}"#)
        XCTAssertNil(fleets["noNavy"])
        guard let chosen = fleets["chosen"] as? String else { return XCTFail("no fleet to send") }
        act(#"{"verb":"orderFleet","fleet":"\#(chosen)","target":"CUB","mission":"showOfForce","preset":"probe"}"#)
        let out = result(#"{"q":"fleets","target":"CUB"}"#)["deployments"] as? [[String: Any]] ?? []
        XCTAssertEqual(out.count, 1)
        act(#"{"verb":"orderFleet","fleet":"\#(chosen)","target":"CUB","mission":"showOfForce"}"#, ok: false)   // already out
        act(#"{"verb":"recallFleet","id":"\#(out[0]["id"] as? String ?? "")"}"#)
        XCTAssertEqual((result(#"{"q":"fleets","target":"CUB"}"#)["deployments"] as? [Any])?.count, 0)
        XCTAssertEqual(result(#"{"q":"fleets","target":"FRA","fleet":"\#(chosen)","mission":"strike"}"#)["mission"] as? String, "strike")

        _ = GTNWBridge.endTurn()
        act(#"{"verb":"callUp","kind":"mobilization"}"#)
        let mp = result(#"{"q":"manpower"}"#)["callUps"] as? [[String: Any]] ?? []
        XCTAssertNotNil(mp.first { $0["kind"] as? String == "mobilization" }?["called"])
        act(#"{"verb":"standDown","kind":"mobilization"}"#)
        act(#"{"verb":"standDown","kind":"mobilization"}"#, ok: false)

        let draft = result(#"{"q":"budget","draft":{"defense":12}}"#)
        XCTAssertEqual((draft["sliders"] as? [[String: Any]])?.first { $0["key"] as? String == "defense" }?["value"] as? Double, 12)
        XCTAssertEqual((draft["projection"] as? [Any])?.count, 8)
        act(#"{"verb":"enactBudget","draft":{"defense":12,"social":99}}"#)
        let now = result(#"{"q":"budget"}"#)["current"] as? [String: Any]
        XCTAssertEqual(now?["defense"] as? Double, 12)
        XCTAssertEqual(now?["social"] as? Double, 25, "clamped to the limit")

        let aid = result(#"{"q":"aid","id":"EGY"}"#)
        XCTAssertEqual((aid["categories"] as? [Any])?.count, 5)
        let sent = act(#"{"verb":"sendAid","target":"EGY","humanitarian":1}"#)
        XCTAssertNotNil((sent["report"] as? [String: Any])?["title"])
        act(#"{"verb":"sendAid","target":"EGY","economic":100000}"#, ok: false)

        act(#"{"verb":"saveGroup","name":"Neighbors","ids":["CAN","MEX"]}"#)
        let g = result(#"{"q":"groupAction","pick":"saved","saved":"Neighbors","kind":"message"}"#)
        XCTAssertEqual(g["saved"] as? [String], ["Neighbors"])
        XCTAssertEqual((g["lines"] as? [Any])?.count, 2)
        act(#"{"verb":"groupAction","pick":"saved","saved":"Neighbors","kind":"message"}"#)
        XCTAssertNotNil(result(#"{"q":"peace"}"#)["paths"])
        XCTAssertNotNil(result(#"{"q":"airCampaign","target":"CUB"}"#)["problem"], "not at war with Cuba")
    }

    func testVerbsKeepTheGameAFunctionOfSeedAndOrders() {
        func play() -> NSDictionary? {
            startGame()
            act(#"{"verb":"callUp","kind":"mobilization"}"#)
            act(#"{"verb":"sendAid","target":"EGY","humanitarian":1}"#)
            act(#"{"verb":"sizedOrder","action":"Air Strike","target":"CUB","aircraft":40}"#)
            _ = GTNWBridge.endTurn()
            if let f = (result(#"{"q":"fronts"}"#)["fronts"] as? [[String: Any]])?.first(where: { $0["canDemandSurrender"] as? Bool == true }),
               let id = f["id"] as? String {
                _ = GTNWBridge.act(#"{"verb":"demandSurrender","front":"\#(id)"}"#)
            }
            _ = GTNWBridge.endTurn()
            return json(GTNWBridge.snapshot())["state"] as? NSDictionary
        }
        XCTAssertEqual(play(), play())
    }
}
