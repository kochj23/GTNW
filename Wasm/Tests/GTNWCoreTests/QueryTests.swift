//
//  QueryTests.swift
//  GTNWCoreTests
//
//  The bridge's read-only `query` op and the Situation Room verbs `act` gained for the web front end (advised
//  orders, backing off, standing recommendations, scenarios and one-sitting games). Queries must never change the
//  game: a save after every query equals the save before.
//

import XCTest
@testable import GTNWCore

final class QueryTests: XCTestCase {

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

    /// A 1962 U.S. game, two turns in, so the world has moved.
    func startGame(_ request: String = #"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#) {
        XCTAssertEqual(json(GTNWBridge.newGame(request))["ok"] as? Bool, true)
        _ = GTNWBridge.endTurn()
        _ = GTNWBridge.endTurn()
    }

    func testEveryQueryIsRegisteredOnceAndUnknownOnesFail() {
        XCTAssertEqual(QueryRegistry.byName.count, QueryRegistry.all.count, "two queries share a name")
        XCTAssertEqual(QueryRegistry.all.map { $0.name }, QueryRegistry.all.map { $0.name }.sorted(), "keep the registry alphabetical")
        let r = json(GTNWBridge.query(#"{"q":"nope"}"#))
        XCTAssertEqual(r["ok"] as? Bool, false)
        XCTAssertEqual(json(GTNWBridge.query("not json"))["ok"] as? Bool, false)
        XCTAssertEqual(json(GTNWBridge.query(#"{"q":"country"}"#))["ok"] as? Bool, false, "missing id")
    }

    func testQueriesDoNotChangeTheGame() {
        startGame()
        let before = GTNWBridge.save()
        let snap = GTNWBridge.snapshot()
        for q in [#"{"q":"map"}"#, #"{"q":"topbar"}"#, #"{"q":"advisors","country":"RUS"}"#, #"{"q":"advisors"}"#,
                  #"{"q":"country","id":"RUS"}"#, #"{"q":"country","id":"USA"}"#, #"{"q":"actions","target":"CUB"}"#,
                  #"{"q":"advice","action":"Air Strike","target":"CUB"}"#, #"{"q":"advice","action":"Launch Nukes","target":"RUS"}"#,
                  #"{"q":"nations","year":1914}"#, #"{"q":"scenarios"}"#, #"{"q":"administrations"}"#] {
            _ = result(q)
        }
        // Compared as JSON values: the save's encoder does not sort keys, so equal dictionaries may print in another order.
        XCTAssertEqual(json(GTNWBridge.save()) as NSDictionary, json(before) as NSDictionary, "a query changed the saved game")
        XCTAssertEqual(GTNWBridge.snapshot(), snap)
        // …and the game goes on exactly as it would have: a fresh game with no queries reaches the same turn 4.
        _ = GTNWBridge.endTurn(); _ = GTNWBridge.endTurn()
        let withQueries = json(GTNWBridge.snapshot())["state"] as? NSDictionary
        startGame()
        _ = GTNWBridge.endTurn(); _ = GTNWBridge.endTurn()
        XCTAssertEqual(json(GTNWBridge.snapshot())["state"] as? NSDictionary, withQueries)
    }

    func testNationsByYearAndNoGameNeeded() {
        let y1914 = result(#"{"q":"nations","year":1914}"#)
        let ids = (y1914["nations"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        XCTAssertTrue(ids.contains("USA"))
        XCTAssertGreaterThan(ids.count, 20)
        let usa = (y1914["nations"] as? [[String: Any]])?.first { $0["id"] as? String == "USA" }
        XCTAssertEqual(usa?["leader"] as? String, "President Woodrow Wilson")
        XCTAssertEqual(json(GTNWBridge.query(#"{"q":"nations","year":1500}"#))["ok"] as? Bool, false)
        let s = result(#"{"q":"scenarios"}"#)
        XCTAssertGreaterThanOrEqual((s["scenarios"] as? [Any])?.count ?? 0, 10)
        XCTAssertGreaterThanOrEqual((s["sittings"] as? [Any])?.count ?? 0, 8)
        let a = result(#"{"q":"administrations"}"#)["administrations"] as? [[String: Any]] ?? []
        XCTAssertEqual(a.first?["startYear"] as? Int, 1789)
    }

    func testMapOwnersColoniesAndIslandsIn1850() {
        XCTAssertEqual(json(GTNWBridge.newGame(#"{"player":"USA","year":1850,"seed":"1","rules":"golden"}"#))["ok"] as? Bool, true)
        let m = result(#"{"q":"map"}"#)
        let lands = m["lands"] as? [String: [String: Any]] ?? [:]
        XCTAssertGreaterThan(lands.count, 200)
        XCTAssertEqual(lands["USA"]?["kind"] as? String, "nation")
        // Russian America: Alaska is Russia's colony before 1867.
        XCTAssertEqual(lands["USA_AK"]?["kind"] as? String, "colony")
        XCTAssertEqual(lands["USA_AK"]?["owner"] as? String, "RUS")
        let kinds = Set(lands.values.compactMap { $0["kind"] as? String })
        XCTAssertTrue(kinds.contains("colony"))
        XCTAssertTrue(kinds.contains("indigenous") || kinds.contains("unclaimed"))
        XCTAssertFalse((m["dots"] as? [Any] ?? []).isEmpty, "island and micro-state dots")
        // Every outline that selects something selects a country or land the dossier knows.
        for (id, land) in lands {
            guard let sel = land["selects"] as? String else { continue }
            XCTAssertEqual(json(GTNWBridge.query(#"{"q":"country","id":"\#(sel)"}"#))["ok"] as? Bool, true, "\(id) selects \(sel)")
        }
    }

    func testDossierShowsEstimatesForForeignForces() {
        startGame()
        let rus = result(#"{"q":"country","id":"RUS"}"#)["nation"] as? [String: Any]
        XCTAssertNotNil(rus?["relationToPlayer"])
        XCTAssertNotNil((rus?["military"] as? [String: Any])?["tag"])
        let usa = result(#"{"q":"country","id":"USA"}"#)["nation"] as? [String: Any]
        XCTAssertEqual(usa?["isPlayer"] as? Bool, true)
        XCTAssertEqual((usa?["military"] as? [String: Any])?["tag"] as? String, "CONFIRMED")
    }

    func testActionsAdviceAndAnAdvisedOrder() {
        startGame()
        let ladder = result(#"{"q":"actions","target":"FRA"}"#)
        XCTAssertEqual((ladder["rungs"] as? [Any])?.count, 5)
        let acts = ladder["actions"] as? [[String: Any]] ?? []
        XCTAssertTrue(acts.contains { $0["id"] as? String == "Send Ambassador" })
        XCTAssertEqual(ladder["usable"] as? Bool, true)
        let adv = result(#"{"q":"advice","action":"Send Ambassador","target":"FRA"}"#)
        XCTAssertNotNil((adv["advice"] as? [String: Any])?["stance"])
        let strike = result(#"{"q":"advice","action":"Air Strike","target":"CUB"}"#)
        XCTAssertEqual((strike["warnings"] as? [Any])?.count, 3, "a major order gets three warnings")

        let before = (json(GTNWBridge.snapshot())["state"] as? [String: Any])?["actionsRemaining"] as? Int ?? 0
        let r = json(GTNWBridge.act(#"{"action":"Send Ambassador","target":"FRA","advised":true}"#))
        XCTAssertEqual(r["ok"] as? Bool, true)
        XCTAssertNotNil(r["report"])
        let after = (r["state"] as? [String: Any])?["actionsRemaining"] as? Int ?? 0
        XCTAssertTrue(after == before - 1 || (r["state"] as? [String: Any])?["turn"] as? Int ?? 0 > 2, "the order used an action (or ended the turn)")
        XCTAssertEqual(json(GTNWBridge.act(#"{"action":"Air Strike","target":"CUB","decline":true}"#))["ok"] as? Bool, true)
        XCTAssertEqual(json(GTNWBridge.act(#"{"action":"Send Ambassador","target":"USA","advised":true}"#))["ok"] as? Bool, false)
    }

    func testAdvisorsAndRecommendations() {
        startGame()
        let list = result(#"{"q":"advisors","country":"RUS"}"#)["advisors"] as? [[String: Any]] ?? []
        XCTAssertGreaterThanOrEqual(list.count, 5)
        XCTAssertNotNil(list.first?["briefing"])
        guard let withRec = list.first(where: { $0["recommendation"] != nil }), let id = withRec["id"] as? String else {
            return XCTFail("no advisor has a recommendation")
        }
        XCTAssertEqual(json(GTNWBridge.act(#"{"advisor":"\#(id)","recommendation":"alternative"}"#))["ok"] as? Bool, true)
        XCTAssertEqual(json(GTNWBridge.act(#"{"advisor":"\#(id)","recommendation":"reject"}"#))["ok"] as? Bool, true)
        XCTAssertEqual(json(GTNWBridge.act(#"{"advisor":"\#(id)","recommendation":"maybe"}"#))["ok"] as? Bool, false)
    }

    func testScenarioAndSittingGames() {
        let r = json(GTNWBridge.newGame(#"{"scenario":"cuba1962","seed":"5","rules":"golden"}"#))
        XCTAssertEqual(r["ok"] as? Bool, true)
        XCTAssertEqual(result(#"{"q":"topbar"}"#)["scenario"] as? String, "cuba1962")
        let s = json(GTNWBridge.newGame(#"{"sitting":"sit_cuba","seed":"5","rules":"golden"}"#))
        XCTAssertEqual(s["ok"] as? Bool, true)
        let bar = result(#"{"q":"topbar"}"#)
        XCTAssertEqual(bar["sitting"] as? String, "Thirteen Days")
        XCTAssertEqual(bar["turnLength"] as? String, "day")
        XCTAssertEqual(json(GTNWBridge.newGame(#"{"scenario":"nope"}"#))["ok"] as? Bool, false)
        // Same seed, same scenario, same game.
        let a = json(GTNWBridge.newGame(#"{"scenario":"ablearcher1983","seed":"9","rules":"golden"}"#))["state"] as? NSDictionary
        let b = json(GTNWBridge.newGame(#"{"scenario":"ablearcher1983","seed":"9","rules":"golden"}"#))["state"] as? NSDictionary
        XCTAssertEqual(a, b)
    }

    func testAnyNationAnyYear() {
        for (player, year) in [("FRA", 1789), ("GBR", 1850), ("JPN", 1941), ("IND", 1990), ("BRA", 2025)] {
            let r = json(GTNWBridge.newGame(#"{"player":"\#(player)","year":\#(year),"seed":"3","rules":"golden"}"#))
            XCTAssertEqual(r["ok"] as? Bool, true, "\(player) \(year): \(r["error"] ?? "")")
            XCTAssertEqual(result(#"{"q":"topbar"}"#)["year"] as? Int, year)
        }
        XCTAssertEqual(json(GTNWBridge.newGame(#"{"player":"USA","year":1700}"#))["ok"] as? Bool, false)
    }
}
