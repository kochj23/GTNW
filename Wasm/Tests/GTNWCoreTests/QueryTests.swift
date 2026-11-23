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
                  #"{"q":"nations","year":1914}"#, #"{"q":"scenarios"}"#, #"{"q":"administrations"}"#,
                  #"{"q":"crisis"}"#, #"{"q":"news"}"#, #"{"q":"command","schema":true}"#,
                  #"{"q":"command","text":"attack France with all air, naval and army forces that are non-nuclear"}"#,
                  #"{"q":"command","text":"nuke Russia with 5 warheads"}"#, #"{"q":"command","text":"who can reach me with ICBMs?"}"#,
                  #"{"q":"command","text":"sanction isr"}"#, #"{"q":"command","text":"make the moon cheese"}"#,
                  #"{"q":"command","model":{"kind":"order","verb":"sanction","targets":["Cuba"],"ground":false,"air":false,"naval":false,"nuclear":"unspecified","all":false,"topic":"none","field":"none"}}"#] {
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

    // MARK: Advisors, crisis, news, command box (screens A)

    func testAdvisorPostsProfilesAndFiring() {
        startGame()
        let r = result(#"{"q":"advisors"}"#)
        let posts = r["posts"] as? [[String: Any]] ?? []
        XCTAssertEqual(posts.map { $0["role"] as? String ?? "" }, AdviceEngine.roleOrder)
        XCTAssertEqual(posts.first?["title"] as? String, "Chief of Staff")
        let list = r["advisors"] as? [[String: Any]] ?? []
        XCTAssertNotNil(list.first?["bio"])
        XCTAssertNotNil(list.first?["expertise"])
        guard let victim = list.first(where: { $0["canFire"] as? Bool == true && $0["status"] as? String == "active" && $0["role"] as? String != nil }),
              let id = victim["id"] as? String, let role = victim["role"] as? String else { return XCTFail("nobody to fire") }
        let fired = json(GTNWBridge.act(#"{"verb":"fireAdvisor","id":"\#(id)"}"#))
        XCTAssertEqual(fired["ok"] as? Bool, true)
        let after = result(#"{"q":"advisors"}"#)
        let post = (after["posts"] as? [[String: Any]])?.first { $0["role"] as? String == role }
        XCTAssertNotEqual(post?["advisorId"] as? String, id, "an acting replacement holds the post")
        XCTAssertEqual((post?["former"] as? [[String: Any]])?.first?["name"] as? String, victim["name"] as? String)
        XCTAssertEqual(json(GTNWBridge.act(#"{"verb":"fireAdvisor","id":"\#(id)"}"#))["ok"] as? Bool, false, "already gone")
        guard let other = (after["advisors"] as? [[String: Any]])?.first(where: { $0["canFire"] as? Bool == true && $0["status"] as? String == "active" }),
              let oid = other["id"] as? String else { return XCTFail("nobody to dismiss") }
        XCTAssertEqual(json(GTNWBridge.act(#"{"verb":"dismissAdvisor","id":"\#(oid)"}"#))["ok"] as? Bool, true)
        let status = (result(#"{"q":"advisors"}"#)["advisors"] as? [[String: Any]])?.first { $0["id"] as? String == oid }?["status"] as? String
        XCTAssertEqual(status, "fired")
    }

    func testCrisisAndNews() {
        XCTAssertEqual(json(GTNWBridge.newGame(#"{"scenario":"cuba1962","seed":"5","rules":"golden"}"#))["ok"] as? Bool, true)
        var crisis: [String: Any]?
        for _ in 0..<40 {
            crisis = result(#"{"q":"crisis"}"#)["crisis"] as? [String: Any]
            if crisis != nil { break }
            _ = GTNWBridge.endTurn()
        }
        guard let c = crisis else { return XCTFail("no crisis in 40 turns") }
        XCTAssertNotNil(c["severityLabel"] as? String)
        XCTAssertFalse((c["options"] as? [Any] ?? []).isEmpty)
        let ep = c["epigraph"] as? [String: Any]
        XCTAssertFalse((ep?["text"] as? String ?? "").isEmpty)
        XCTAssertEqual(result(#"{"q":"crisis"}"#)["crisis"] as? NSDictionary, c as NSDictionary, "stable: the same crisis, the same card")
        XCTAssertEqual(json(GTNWBridge.act(#"{"crisisOption":0}"#))["ok"] as? Bool, true)
        let news = result(#"{"q":"news"}"#)
        XCTAssertFalse((news["items"] as? [Any] ?? []).isEmpty)
        XCTAssertNotNil(news["scenario"] as? String)
        XCTAssertNotNil((news["epigraph"] as? [String: Any])?["source"])
    }

    func command(_ text: String) -> [String: Any] {
        let body = String(decoding: try! JSONSerialization.data(withJSONObject: ["q": "command", "text": text]), as: UTF8.self)
        return result(body)
    }

    func testCommandBoxPlansAsTheAppDoes() {
        startGame()
        // The parser and planner the app runs: the same plan the engine would build itself.
        let r = command("attack France with all air, naval and army forces that are non-nuclear")
        XCTAssertEqual(r["kind"] as? String, "plan")
        let plan = r["plan"] as? [String: Any] ?? [:]
        let intent = CommandParser.parse("attack France with all air, naval and army forces that are non-nuclear")!
        guard case .plan(let native) = GTNWBridge.engine!.planCommand(intent, source: .parser) else { return XCTFail("no native plan") }
        XCTAssertEqual(plan["committed"] as? [String], native.committed)
        XCTAssertEqual(plan["heldBack"] as? [String], native.heldBack)
        XCTAssertEqual((plan["orders"] as? [Any])?.count, native.orders.count)
        XCTAssertEqual(plan["nuclear"] as? Bool, false)
        // Questions, help, the unknown, the ambiguous.
        XCTAssertEqual(command("who can reach me with ICBMs?")["kind"] as? String, "answer")
        XCTAssertEqual(command("help")["lines"] as? [String], CommandHelp.lines)
        XCTAssertEqual(command("make the moon cheese")["kind"] as? String, "unparsed")
        let nuke = command("nuke Russia with 5 warheads")
        XCTAssertEqual((nuke["plan"] as? [String: Any])?["nuclear"] as? Bool, true)
        XCTAssertEqual(((nuke["plan"] as? [String: Any])?["warnings"] as? [[String: Any]])?.first?["text"] as? String,
                       "NUCLEAR RELEASE. A second confirmation is required.")
        XCTAssertEqual(json(GTNWBridge.query(#"{"q":"command","text":"   "}"#))["ok"] as? Bool, false)
    }

    func testCommandClarificationRoundTrip() {
        startGame()
        var r = command("sanction guin")
        if r["kind"] as? String != "clarify" { r = command("sanction kor") }
        guard r["kind"] as? String == "clarify", let opt = ((r["clarify"] as? [String: Any])?["options"] as? [[String: Any]])?.first,
              let intent = opt["intent"] else { return XCTFail("no clarification: \(r)") }
        let body = String(decoding: try! JSONSerialization.data(withJSONObject: ["q": "command", "intent": intent, "source": "parser"]), as: UTF8.self)
        XCTAssertEqual(result(body)["kind"] as? String, "plan")
    }

    func testModelTranslationIsCheckedAgainstTheClosedLists() {
        startGame()
        func model(_ fields: String) -> [String: Any] { result(#"{"q":"command","model":{\#(fields)}}"#) }
        let base = #""targets":["Cuba"],"ground":false,"air":true,"naval":false,"nuclear":"no","all":false,"topic":"none","field":"none""#
        XCTAssertEqual(model(#""kind":"order","verb":"airStrike","# + base)["kind"] as? String, "plan")
        XCTAssertEqual(model(#""kind":"order","verb":"launchEverything","# + base)["kind"] as? String, "rejected", "a verb off the list")
        XCTAssertEqual(model(#""kind":"unknown","verb":"none","# + base)["kind"] as? String, "rejected")
        XCTAssertEqual(model(#""kind":"question","verb":"none","targets":[],"ground":false,"air":false,"naval":false,"nuclear":"unspecified","all":false,"topic":"wars","field":"none""#)["kind"] as? String, "answer")
        XCTAssertEqual(model(#""kind":"order","verb":"airStrike","targets":["Cuba"],"ground":false,"air":true,"naval":false,"nuclear":"no","all":false,"troops":-5,"topic":"none","field":"none""#)["kind"] as? String, "rejected", "numbers are bounded")
        let schema = result(#"{"q":"command","schema":true}"#)["schema"] as? [String: Any]
        XCTAssertEqual(schema?["verbs"] as? [String], CommandVerb.allCases.map(\.rawValue))
    }

    func testCommandOrdersExecuteThroughAct() {
        startGame()
        let r = command("sanction Cuba")
        guard let plan = r["plan"] as? [String: Any], let orders = plan["orders"] else { return XCTFail("no plan: \(r)") }
        let before = (json(GTNWBridge.snapshot())["state"] as? [String: Any])?["actionsRemaining"] as? Int ?? 0
        let body = String(decoding: try! JSONSerialization.data(withJSONObject: ["verb": "executeCommand", "orders": orders, "source": "parser"]), as: UTF8.self)
        let done = json(GTNWBridge.act(body))
        XCTAssertEqual(done["ok"] as? Bool, true)
        let cmd = (done["report"] as? [String: Any])?["command"] as? [String: Any]
        XCTAssertEqual((cmd?["carried"] as? [Any])?.count, 1)
        XCTAssertFalse((cmd?["lines"] as? [String] ?? []).isEmpty)
        let after = (done["state"] as? [String: Any])?["actionsRemaining"] as? Int ?? 0
        XCTAssertTrue(after == before - 1 || ((done["state"] as? [String: Any])?["turn"] as? Int ?? 0) > 2)
        XCTAssertEqual(GTNWBridge.engine?.gameState?.shadow.commandLog.last?.orders.first?.action, PresidentialAction.sanctions.rawValue)
        // A tampered order is checked again and refused (no action spent).
        let bad = json(GTNWBridge.act(#"{"verb":"executeCommand","orders":[{"kind":"action","target":"CUB","action":"Assassinate Leader"}],"source":"model"}"#))
        let badCmd = (bad["report"] as? [String: Any])?["command"] as? [String: Any]
        XCTAssertEqual((badCmd?["carried"] as? [Any])?.count, 0)
        XCTAssertEqual(((badCmd?["refused"] as? [Any])?.count ?? 0) + ((badCmd?["notReached"] as? [Any])?.count ?? 0), 1)
        XCTAssertEqual(json(GTNWBridge.act(#"{"verb":"executeCommand","orders":[],"source":"parser"}"#))["ok"] as? Bool, false)
    }
}
