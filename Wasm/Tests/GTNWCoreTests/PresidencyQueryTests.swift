//
//  PresidencyQueryTests.swift
//  GTNWCoreTests
//
//  The 3.36 features on the web (NovaGames gtnw-lite): the record of the presidency and its epilogue, states and
//  provinces with the state-by-state election, renames with the content check, power plays abroad and at home,
//  Antarctica and consequences. Every query leaves the game untouched; every verb does what the app's button does.
//

import XCTest
@testable import GTNWCore

final class PresidencyQueryTests: XCTestCase {

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
    func act(_ order: String, ok: Bool = true, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        let r = json(GTNWBridge.act(order))
        XCTAssertEqual(r["ok"] as? Bool, ok, "\(order): \(r["error"] ?? "")", file: file, line: line)
        return r
    }

    func start(_ request: String = #"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#) {
        XCTAssertEqual(json(GTNWBridge.newGame(request))["ok"] as? Bool, true)
    }

    func actions() -> Int { (json(GTNWBridge.snapshot())["state"] as? [String: Any])?["actionsRemaining"] as? Int ?? -1 }

    static let queries = [
        #"{"q":"presidency"}"#, #"{"q":"provinces"}"#, #"{"q":"provinces","nation":"CAN"}"#, #"{"q":"provinces","nation":"FRA"}"#,
        #"{"q":"renames"}"#, #"{"q":"renames","id":"US-TX","name":"Lone Star"}"#, #"{"q":"powerPlays"}"#, #"{"q":"powerPlays","target":"CUB"}"#,
        #"{"q":"powerPlays","target":"DNK"}"#, #"{"q":"homeFront"}"#, #"{"q":"antarctica"}"#, #"{"q":"consequences","target":"GBR"}"#,
    ]

    func testQueriesDoNotChangeTheGame() {
        for game in [#"{"player":"USA","year":1962,"seed":"7aa","rules":"golden"}"#, #"{"player":"CHN","year":2025,"seed":"7e9","rules":"full"}"#] {
            start(game)
            _ = GTNWBridge.endTurn(); _ = GTNWBridge.endTurn()
            let before = GTNWBridge.save()
            for q in Self.queries { _ = result(q) }
            XCTAssertEqual(json(GTNWBridge.save()) as NSDictionary, json(before) as NSDictionary, "a query changed the saved game")
            _ = GTNWBridge.endTurn(); _ = GTNWBridge.endTurn()
            let withQueries = json(GTNWBridge.snapshot())["state"] as? NSDictionary
            start(game)
            for _ in 0..<4 { _ = GTNWBridge.endTurn() }
            XCTAssertEqual(json(GTNWBridge.snapshot())["state"] as? NSDictionary, withQueries)
        }
    }

    func testRegistered() {
        for q in ["presidency", "provinces", "renames", "powerPlays", "homeFront", "antarctica", "consequences"] {
            XCTAssertNotNil(QueryRegistry.byName[q], q)
        }
        for v in ["powerPlay", "antarcticOrder", "renameTarget", "presidencyCareer"] { XCTAssertNotNil(VerbRegistry.byName[v], v) }
        let queries = QueryRegistry.all.map { $0.name }, verbs = VerbRegistry.all.map { $0.name }
        XCTAssertEqual(queries, queries.sorted())
        XCTAssertEqual(verbs, verbs.sorted())
    }

    func testPresidencyAwardsCareerAndEpilogue() {
        start()
        var p = result(#"{"q":"presidency"}"#)
        XCTAssertEqual((p["awards"] as? [Any])?.count, PresidencyAwards.all.count)
        XCTAssertNil(p["epilogue"], "the epilogue is for the end screen")
        // The career the front end kept comes back; unknown awards are dropped.
        act(#"{"verb":"presidencyCareer","career":"{\"games\":4,\"antarcticaGames\":2,\"warsStarted\":10,\"warsWon\":1,\"awards\":[\"served_full_term\",\"nope\"]}"}"#)
        p = result(#"{"q":"presidency"}"#)
        let career = p["career"] as? [String: Any]
        XCTAssertEqual(career?["games"] as? Int, 4)
        XCTAssertEqual(career?["line"] as? String, "10 wars, 1 win")
        XCTAssertFalse((p["stored"] as? String ?? "").contains("nope"))
        act(#"{"verb":"presidencyCareer","career":"not json"}"#, ok: false)
        // Game over: the epilogue (verdict, library) appears.
        GTNWBridge.engine?.gameState?.gameOver = true
        p = result(#"{"q":"presidency"}"#)
        let e = p["epilogue"] as? [String: Any]
        XCTAssertFalse((e?["verdict"] as? String ?? "").isEmpty)
        XCTAssertTrue((e?["library"] as? String ?? "").contains("Library"))
        PresidencyCareer.save(PresidencyCareer())
    }

    func testProvincesAndStateElections() {
        start()
        let p = result(#"{"q":"provinces"}"#)
        let rows = p["rows"] as? [[String: Any]] ?? []
        XCTAssertGreaterThanOrEqual(rows.count, 50, "50 states in 1962, and the District")
        XCTAssertTrue(rows.contains { $0["name"] as? String == "Texas" && $0["renamable"] as? Bool == true && ($0["electors"] as? Int ?? 0) > 0 })
        XCTAssertGreaterThan(p["electors"] as? Int ?? 0, 500)
        XCTAssertTrue((p["nations"] as? [[String: Any]] ?? []).contains { $0["id"] as? String == "CAN" })
        XCTAssertNotNil(result(#"{"q":"provinces","nation":"DEU"}"#)["undivided"], "Germany's Länder from 1990")
        start(#"{"player":"USA","year":1800,"seed":"7aa","rules":"golden"}"#)
        let early = result(#"{"q":"provinces"}"#)["rows"] as? [[String: Any]] ?? []
        XCTAssertTrue(early.contains { $0["name"] as? String == "Virginia" })
        XCTAssertFalse(early.contains { $0["name"] as? String == "Hawaii" })
    }

    func testRenameCheckAndRename() {
        start()
        let r = result(#"{"q":"renames"}"#)
        let groups = r["groups"] as? [[String: Any]] ?? []
        XCTAssertTrue(groups.contains { $0["title"] as? String == "States and provinces" })
        let ok = result(#"{"q":"renames","id":"US-TX","name":"Lone Star"}"#)["check"] as? [String: Any]
        XCTAssertNil(ok?["problem"])
        XCTAssertEqual(ok?["name"] as? String, "Lone Star")
        XCTAssertFalse((ok?["warnings"] as? [Any] ?? []).isEmpty)
        let empty = result(#"{"q":"renames","id":"US-TX","name":""}"#)["check"] as? [String: Any]
        XCTAssertNotNil(empty?["problem"])
        let long = result(#"{"q":"renames","id":"US-TX","name":"\#(String(repeating: "x", count: 60))"}"#)["check"] as? [String: Any]
        XCTAssertNotNil(long?["problem"], "too long")
        let n = actions()
        act(#"{"verb":"renameTarget","id":"US-TX","name":"Lone Star"}"#)
        XCTAssertEqual(actions(), n, "no action spent")
        let tx = (result(#"{"q":"provinces"}"#)["rows"] as? [[String: Any]] ?? []).first { $0["id"] as? String == "US-TX" }
        XCTAssertEqual(tx?["name"] as? String, "Lone Star")
        XCTAssertEqual(tx?["realName"] as? String, "Texas")
        act(#"{"verb":"renameTarget","id":"US-TX","name":""}"#, ok: false)
        act(#"{"verb":"renameTarget","id":"FRA","name":"Gaul"}"#, ok: false)
        act(#"{"verb":"renameTarget","id":"USA","name":"Freedonia"}"#)
        XCTAssertEqual(GTNWBridge.engine?.gameState?.getPlayerCountry()?.name, "Freedonia")
    }

    func testPowerPlaysAbroad() {
        start()
        let p = result(#"{"q":"powerPlays","target":"CUB"}"#)
        XCTAssertEqual(p["foreign"] as? Bool, true)
        XCTAssertEqual((p["strikes"] as? [Any])?.count, StrikeKind.allCases.count)
        XCTAssertNotNil(p["raid"])
        XCTAssertNotNil(p["tariffs"])
        let home = result(#"{"q":"powerPlays"}"#)
        XCTAssertEqual(home["foreign"] as? Bool, false)
        let reasons = (home["emergency"] as? [String: Any])?["reasons"] as? [[String: Any]] ?? []
        XCTAssertEqual(reasons.count, EmergencyReason.allCases.count)
        act(#"{"verb":"powerPlay","op":"declare","reason":"trade"}"#)
        XCTAssertNotNil(GTNWBridge.engine?.gameState?.shadow.powerPlays.emergency)
        XCTAssertEqual((result(#"{"q":"powerPlays"}"#)["emergency"] as? [String: Any])?["inForce"] as? Bool, true)
        let bases = ((result(#"{"q":"powerPlays","target":"CAN"}"#)["tariffs"] as? [String: Any])?["bases"] as? [[String: Any]]) ?? []
        if let b = bases.first?["id"] as? String {
            act(#"{"verb":"powerPlay","op":"tariff","target":"CAN","basis":"\#(b)"}"#)
            let orders = result(#"{"q":"powerPlays"}"#)["orders"] as? [[String: Any]] ?? []
            XCTAssertEqual(orders.first?["live"] as? Bool, true)
            if let id = orders.first?["id"] as? Int { act(#"{"verb":"powerPlay","op":"rescind","order":\#(id)}"#) }
        }
        act(#"{"verb":"powerPlay","op":"end"}"#)
        act(#"{"verb":"powerPlay","op":"end"}"#, ok: false)
        act(#"{"verb":"powerPlay","op":"strike","target":"CUB","kind":"laser"}"#, ok: false)
        act(#"{"verb":"powerPlay","op":"bogus"}"#, ok: false)
    }

    func testHomeFrontPlansThroughTheCommandBox() {
        start()
        let h = result(#"{"q":"homeFront"}"#)
        let panels = h["panels"] as? [[String: Any]] ?? []
        XCTAssertEqual(panels.map { $0["id"] as? String ?? "" }, ["troops", "numbers", "bank", "stakes", "power", "shield", "tests"])
        XCTAssertFalse((h["states"] as? [Any] ?? []).isEmpty)
        XCTAssertFalse((h["industries"] as? [Any] ?? []).isEmpty)
        let fire = panels[1]["orders"] as? [[String: Any]] ?? []
        let intent = String(decoding: try! JSONSerialization.data(withJSONObject: fire.first?["intent"] ?? [:]), as: UTF8.self)
        let c = result(#"{"q":"command","intent":"# + intent + "}")
        guard let plan = c["plan"] as? [String: Any], let orders = plan["orders"] else { return XCTFail("no plan: \(c)") }
        let body = String(decoding: try! JSONSerialization.data(withJSONObject: ["verb": "executeCommand", "orders": orders, "source": "parser"]), as: UTF8.self)
        act(body)
        XCTAssertEqual(result(#"{"q":"homeFront"}"#)["cooked"] as? Bool, true)
    }

    func testAntarctica() {
        start()
        let a = result(#"{"q":"antarctica"}"#)
        XCTAssertEqual(a["standing"] as? String, "party")
        let ops = (a["orders"] as? [[String: Any]] ?? []).map { $0["op"] as? String ?? "" }
        XCTAssertEqual(ops, ["station", "leave", "renegotiate"])
        let n = actions()
        act(#"{"verb":"antarcticOrder","op":"station"}"#)
        XCTAssertEqual(actions(), n - 1)
        XCTAssertEqual((result(#"{"q":"antarctica"}"#)["stations"] as? [Any])?.count, 1)
        act(#"{"verb":"antarcticOrder","op":"join"}"#, ok: false)
        act(#"{"verb":"antarcticOrder","op":"igloo"}"#, ok: false)
        start(#"{"player":"USA","year":1900,"seed":"7aa","rules":"golden"}"#)
        XCTAssertEqual(result(#"{"q":"antarctica"}"#)["standing"] as? String, "none")
        XCTAssertEqual((result(#"{"q":"antarctica"}"#)["orders"] as? [Any])?.count, 0, "no stations before 1904, no treaty before 1959")
    }

    func testConsequences() {
        start()
        let c = result(#"{"q":"consequences","target":"GBR"}"#)
        XCTAssertEqual((c["counts"] as? [Any])?.count, 0)
        let prot = c["protection"] as? [String: Any]
        XCTAssertEqual(prot?["status"] as? String, "friend")
        XCTAssertFalse((prot?["warnings"] as? [Any] ?? []).isEmpty, "Britain is an ally and a friend")
    }
}
