//
//  GTNWCoreTests.swift
//  GTNWCoreTests
//
//  The core's own pieces: the stand-ins (SHA256, 64-bit RNG draws, CoreRunLoop), the JSON bridge, and the golden
//  games (determinism here; the byte-for-byte check against the app's fixtures is Wasm/parity.sh). No network.
//

import XCTest
@testable import GTNWCore

final class GTNWCoreTests: XCTestCase {

    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../..").standardized

    override class func setUp() {
        for (name, dir) in [("nation_cabinets", "Shared/Resources"), ("nation_characters", "Shared/Resources"),
                            ("world_countries", "Shared/Resources"), ("base_rates", "Documentation/wars"), ("open_wars", "Documentation/wars")] {
            if let data = try? Data(contentsOf: root.appendingPathComponent("\(dir)/\(name).json")) { GTNWBridge.setResource(name, data) }
        }
    }

    func json(_ s: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any] ?? [:]
    }

    // MARK: Stand-ins

    func testSHA256KnownVectors() {
        let hex = { (s: String) in SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(hex(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    /// The core's GameRNG draws equal the standard library's on a 64-bit host, so wasm32 plays the app's game.
    func testRNGOverloadsMatchStandardLibraryOn64Bit() {
        func std<G: RandomNumberGenerator>(_ g: inout G) -> [Int] {
            (0..<200).map { i in i % 2 == 0 ? Int.random(in: 1...100, using: &g) : Int.random(in: -5..<i + 1, using: &g) }
        }
        func stdPick<G: RandomNumberGenerator>(_ g: inout G) -> ([Int], Int?) { ((0..<50).shuffled(using: &g), [3, 4, 5].randomElement(using: &g)) }
        var a = GameRNG(seed: 99), b = GameRNG(seed: 99)
        let core = (0..<200).map { i in i % 2 == 0 ? Int.random(in: 1...100, using: &a) : Int.random(in: -5..<i + 1, using: &a) }
        XCTAssertEqual(core, std(&b))
        let corePick = ((0..<50).shuffled(using: &a), [3, 4, 5].randomElement(using: &a))
        let stdP = stdPick(&b)
        XCTAssertEqual(corePick.0, stdP.0)
        XCTAssertEqual(corePick.1, stdP.1)
        XCTAssertEqual(a.state, b.state)
    }

    func testCoreRunLoopRunsInTimeThenScheduleOrder() {
        CoreRunLoop.reset()
        var order: [String] = []
        CoreRunLoop.schedule(after: 1.0) { order.append("b") }
        CoreRunLoop.schedule(after: 0) { order.append("a") }
        CoreRunLoop.schedule(after: 1.0) { order.append("c") }
        while CoreRunLoop.runNext() {}
        XCTAssertEqual(order, ["a", "b", "c"])
        XCTAssertTrue(CoreRunLoop.isEmpty)
    }

    // MARK: Bridge

    func testBridgePlaysSavesAndLoads() {
        let start = json(GTNWBridge.newGame(#"{"year":1962,"seed":"7aa","rules":"golden"}"#))
        XCTAssertEqual(start["ok"] as? Bool, true)
        let state = start["state"] as? [String: Any]
        XCTAssertEqual(state?["turn"] as? Int, 0)
        XCTAssertEqual(state?["player"] as? String, "USA")
        XCTAssertEqual(state?["date"] as? String, "Jan 20, 1962")
        let target = ((state?["nations"] as? [[String: Any]]) ?? []).first { ($0["id"] as? String) != "USA" && ($0["destroyed"] as? Bool) == false }?["id"] as? String
        XCTAssertNotNil(target)
        XCTAssertEqual(json(GTNWBridge.act(#"{"action":"Send Ambassador","target":"\#(target ?? "")"}"#))["ok"] as? Bool, true)
        let turn = json(GTNWBridge.endTurn())
        XCTAssertEqual((turn["state"] as? [String: Any])?["turn"] as? Int, 1)
        XCTAssertFalse((turn["events"] as? [Any] ?? []).isEmpty)

        let saved = GTNWBridge.save()
        let before = GTNWBridge.snapshot()
        _ = GTNWBridge.endTurn()
        XCTAssertNotEqual(GTNWBridge.snapshot(), before)
        XCTAssertEqual(json(GTNWBridge.load(saved))["ok"] as? Bool, true)
        XCTAssertEqual(GTNWBridge.snapshot(), before)
    }

    func testBridgeRejectsBadInput() {
        XCTAssertEqual(json(GTNWBridge.newGame("not json"))["ok"] as? Bool, false)
        XCTAssertEqual(json(GTNWBridge.newGame(#"{"seed":"xyz"}"#))["ok"] as? Bool, false)
        XCTAssertEqual(json(GTNWBridge.newGame(#"{"player":"../etc"}"#))["ok"] as? Bool, false)
        XCTAssertEqual(json(GTNWBridge.load(#"{"nope":1}"#))["ok"] as? Bool, false)
        _ = GTNWBridge.newGame(#"{"year":2025,"seed":"1","rules":"golden"}"#)
        XCTAssertEqual(json(GTNWBridge.act(#"{"action":"No Such Thing","target":"FRA"}"#))["ok"] as? Bool, false)
        XCTAssertEqual(json(GTNWBridge.act(#"{"action":"Send Ambassador","target":"ZZZ"}"#))["ok"] as? Bool, false)
        XCTAssertEqual(json(GTNWBridge.act(#"{"crisisOption":0}"#))["ok"] as? Bool, false)
    }

    // MARK: Golden games

    func testGoldenGameIsDeterministic() {
        let a = GTNWBridge.golden(year: 1962, seed: 0x7aa, turns: 4)
        let b = GTNWBridge.golden(year: 1962, seed: 0x7aa, turns: 4)
        XCTAssertEqual(a, b)
        XCTAssertEqual((json(a)["turns"] as? [Any])?.count, 4)
        XCTAssertNotEqual(a, GTNWBridge.golden(year: 1962, seed: 0x7ab, turns: 4))
    }
}
