//
//  EssentialsTests.swift
//  GTNWCoreTests
//
//  The WebAssembly core links FoundationEssentials and takes String(format:), .formatted(), .capitalized, the
//  whole-word regular expressions, CharacterSet and JSONSerialization from Shared/CoreSupport/Essentials.swift. These
//  tests run natively, where Foundation is the real thing, and check that the stand-ins give Foundation's answers on
//  what the engine feeds them. (Wasm/parity.sh and the soak then check whole games.)
//

import XCTest
@testable import GTNWCore

final class EssentialsTests: XCTestCase {

    static let shared = GTNWCoreTests.root.appendingPathComponent("Shared")

    /// Every Swift file under the core folders.
    static func coreSources() -> [String] {
        let fm = FileManager.default
        var out: [String] = []
        for dir in ["Engine", "Models", "Storage", "Events", "CoreSupport", "AI"] {
            guard let walk = fm.enumerator(atPath: shared.appendingPathComponent(dir).path) else { continue }
            for case let rel as String in walk where rel.hasSuffix(".swift") {
                if let s = try? String(contentsOf: shared.appendingPathComponent(dir).appendingPathComponent(rel), encoding: .utf8) { out.append(s) }
            }
        }
        return out
    }

    /// Every `String(format: "…"` literal in the engine, each played with numbers that stress printf's rounding.
    func testEssentialsFormatMatchesFoundation() throws {
        let literal = try NSRegularExpression(pattern: #"String\(format: "((?:[^"\\]|\\.)*)""#)
        var formats = Set<String>()
        for src in Self.coreSources() {
            for m in literal.matches(in: src, range: NSRange(src.startIndex..., in: src)) {
                let raw = String(src[Range(m.range(at: 1), in: src)!])
                formats.insert(raw.replacingOccurrences(of: #"\""#, with: "\"").replacingOccurrences(of: #"\\"#, with: "\\"))
            }
        }
        XCTAssertGreaterThan(formats.count, 40, "the engine's format strings")
        formats.formUnion(["%016llx", "%02x", "%04d-%02d-%02d", "%5.2f|%-6d|%x|%%", "%+.1f", "%.0f%%"])
        let doubles: [Double] = [0, 0.5, 1.5, 2.5, -0.4, -0.04, 2.25, 99.5, 99.95, 0.125, 1e-7, 123456.789, -1234.5, 1e12, 0.045, 3.14159]
        let ints: [Int] = [0, 7, -3, 42, 100, 2_147_483_647, -1_000_000]
        let words = ["Cuba", "the Soviet Union", "décidé", "won", ""]
        var checked = 0
        for f in formats.sorted() {
            let directives = Self.directives(f)
            for k in 0..<doubles.count {
                let args: [Any] = directives.enumerated().map { i, d in
                    switch d {
                    case "@", "s": return words[(k + i) % words.count]
                    case "d", "i": return ints[(k + i) % ints.count]
                    case "x", "X", "u": return UInt64(ints[(k + i) % ints.count].magnitude)
                    default: return doubles[(k + i) % doubles.count]
                    }
                }
                let cv: [CVarArg] = args.map { a -> CVarArg in
                    switch a {
                    case let s as String: return s as NSString
                    case let i as Int: return i
                    case let u as UInt64: return u
                    default: return a as! Double
                    }
                }
                XCTAssertEqual(CoreText.format(f, args), String(format: f, arguments: cv), "format \(f) with \(args)")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 500)
    }

    /// The conversion characters of a printf format, in order ("%%" is not one).
    static func directives(_ f: String) -> [Character] {
        var out: [Character] = []
        var i = f.startIndex
        while i < f.endIndex {
            if f[i] == "%" {
                var j = f.index(after: i)
                while j < f.endIndex, "-+ #0'.0123456789hlqLzjt".contains(f[j]) { j = f.index(after: j) }
                if j < f.endIndex, f[j] != "%" { out.append(f[j]) }
                i = j < f.endIndex ? f.index(after: j) : j
            } else {
                i = f.index(after: i)
            }
        }
        return out
    }

    func testEssentialsGroupingMatchesFoundation() {
        let en = Locale(identifier: "en_US")
        for n in [0, 7, 999, 1000, 12_345, -1_234_567, 1_000_000_000, Int.max, Int.min] {
            XCTAssertEqual(CoreText.grouped(n), n.formatted(.number.locale(en)))
        }
        for n: Int64 in [3_000_000_000, -9_876_543_210] { XCTAssertEqual(CoreText.grouped(n), n.formatted(.number.locale(en))) }
    }

    func testEssentialsCapitalizedMatchesFoundation() {
        var corpus = ["hello-world", "don't stop", "o'neil", "1st place", "new_york", "iowa caucuses", "SOUTH carolina",
                      "état major", "a.b.c", "x/y z", "foo(bar)", "déjà vu", "hello\tworld\nnext", "mid–dash", "3rd-party",
                      "rock&roll", "ÆSIR", "straße", "  lead", "e-mail's", "in 1962a", "x:y", "a“b”c", "nation’s pride",
                      "secretary_of_state", "minister of the interior", "new hampshire primary", "super tuesday", ""]
        corpus += PresidentialAction.allCases.map(\.rawValue).map { $0.lowercased() }
        for s in corpus { XCTAssertEqual(CoreText.capitalized(s), s.capitalized, s) }
    }

    func testEssentialsWholeWordsMatchRegularExpressions() {
        let texts = ["UN troops RUN to the UN. The UN's vote; UNICEF and (UN) and UN-backed, UN", "the United States.",
                     "Washington, Washingtonian, Washington.", "AMERICANS! Americans and American citizens.", "UN\nUN",
                     "Évian UN Évian", "DEFCON 2, defcon, DEFCON-1", "nuclear war, Nuclear warfare, NUCLEAR WAR.", "NSA_NSA NSA"]
        let words = ["UN", "the United States", "Washington", "Americans", "American citizens", "AMERICANS", "DEFCON",
                     "nuclear war", "NUCLEAR WAR", "NSA", "Évian"]
        for t in texts {
            for w in words {
                let escaped = NSRegularExpression.escapedPattern(for: w)
                XCTAssertEqual(CoreText.replacingWords(in: t, w, with: "<x>", tail: .boundary),
                               t.replacingOccurrences(of: "\\b" + escaped + "\\b", with: "<x>", options: .regularExpression), "\(w) in \(t)")
                XCTAssertEqual(CoreText.replacingWords(in: t, w, with: "<x>", tail: .notWordOrDot),
                               t.replacingOccurrences(of: "\\b" + escaped + "(?![\\w.])", with: "<x>", options: .regularExpression), "\(w) in \(t)")
            }
        }
    }

    /// Every scalar in the Basic Multilingual Plane, against Foundation's sets.
    func testEssentialsCharacterClassesMatchFoundation() {
        let sets: [(String, CharacterSet, (Unicode.Scalar) -> Bool)] = [
            ("whitespaces", .whitespaces, CoreText.isWhitespace), ("newlines", .newlines, CoreText.isNewline),
            ("controlCharacters", .controlCharacters, CoreText.isControl), ("alphanumerics", .alphanumerics, CoreText.isAlphanumeric),
            ("punctuationCharacters", .punctuationCharacters, CoreText.isPunctuation),
        ]
        for (name, set, mine) in sets {
            var differ: [String] = []
            for v in UInt32(0)...0xFFFF {
                // Characters assigned since Unicode 13 are left out: the OS's tables and the standard library's
                // need not have caught up with each other.
                guard let u = Unicode.Scalar(v), let age = u.properties.age, age.major <= 13 else { continue }
                if set.contains(u) != mine(u) { differ.append(String(v, radix: 16)) }
            }
            XCTAssertEqual(differ, [], name)
            for v: UInt32 in [0x09, 0x0A, 0x20, 0x41, 0x30, 0x2E, 0x5F, 0xA0, 0xE9, 0x200B, 0x2028, 0x3000, 0xFEFF] {
                XCTAssertEqual(set.contains(Unicode.Scalar(v)!), mine(Unicode.Scalar(v)!), "\(name) U+\(String(v, radix: 16))")
            }
        }
        for s in ["  hi \n", "\t\u{3000}x\u{2028}", "", "   ", "nova: hi"] {
            XCTAssertEqual(CoreText.trimming(s, CoreText.isWhitespace), s.trimmingCharacters(in: .whitespaces))
            XCTAssertEqual(CoreText.trimming(s) { CoreText.isWhitespace($0) || CoreText.isNewline($0) },
                           s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        for (s, sep) in [("a|b||c|", "|"), ("ACTION: x y", " "), ("", "|"), ("abc", "|")] {
            XCTAssertEqual(CoreText.components(s, separatedBy: sep), s.components(separatedBy: sep))
        }
    }

    func testEssentialsRangeMatchesFoundation() {
        let s = "pre <THINK>a</think> mid <think>b</Think> post </think> end"
        for (needle, opts) in [("<think>", String.CompareOptions.caseInsensitive), ("</think>", [.caseInsensitive, .backwards]),
                               ("</think>", []), ("nope", .caseInsensitive), ("end", .backwards)] {
            XCTAssertEqual(CoreText.range(of: needle, in: s, options: opts), s.range(of: needle, options: opts), needle)
        }
        let open = s.range(of: "<think>", options: .caseInsensitive)!
        XCTAssertEqual(CoreText.range(of: "</think>", in: s, options: .caseInsensitive, range: open.upperBound..<s.endIndex),
                       s.range(of: "</think>", options: .caseInsensitive, range: open.upperBound..<s.endIndex))
    }

    func testEssentialsJSONMatchesFoundation() throws {
        let text = #"{"generated":"2026-11-23","countries":{"FRA":{"cyber":40,"military":12.5,"headline":"a/b \"q\""}},"pairs":[{"a":"FRA","b":"DEU","weight":3,"ok":true,"none":null}]}"#
        let mine = try CoreJSON.object(with: Data(text.utf8)) as? [String: Any]
        let theirs = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        XCTAssertEqual(mine.map { NSDictionary(dictionary: $0) }, theirs.map { NSDictionary(dictionary: $0) })
        let object: [String: Any] = ["b": 1, "a": "x/y\n\"z\"", "c": [1.5, 2, true, "é"], "d": ["k": -3.25], "e": NSNull()]
        XCTAssertEqual(String(decoding: try CoreJSON.data(object), as: UTF8.self),
                       String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), as: UTF8.self))
        XCTAssertEqual(CoreJSON.isValid(object), JSONSerialization.isValidJSONObject(object))
        XCTAssertFalse(CoreJSON.isValid(["x": Double.nan]))
    }

    func testEssentialsFoldingMatchesFoundation() {
        for s in ["Côte d'Ivoire", "São Tomé", "Curaçao", "Zürich", "Łódź", "Ærøskøbing", "Straße", "ÉIRE"] {
            XCTAssertEqual(CoreText.folded(s), s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US")), s)
        }
    }

    // MARK: GameMath

    /// Distance in units in the last place.
    static func ulps(_ a: Double, _ b: Double) -> UInt64 {
        if a == b || (a.isNaN && b.isNaN) { return 0 }
        func key(_ x: Double) -> Int64 { let i = Int64(bitPattern: x.bitPattern); return i < 0 ? Int64.min - i : i }
        return key(a) > key(b) ? UInt64(key(a) - key(b)) : UInt64(key(b) - key(a))
    }

    /// GameMath stays within two units in the last place of the C library across the ranges the game uses.
    func testGameMathTracksTheCLibrary() {
        var g = GameRNG(seed: 0x6a3e)
        func u() -> Double { Double.random(in: 0..<1, using: &g) }
        var worst: [String: UInt64] = [:]
        func check(_ name: String, _ mine: Double, _ libm: Double, _ input: String) {
            let d = Self.ulps(mine, libm)
            worst[name] = max(worst[name] ?? 0, d)
            XCTAssertLessThanOrEqual(d, 2, "\(name)(\(input)): \(mine) vs \(libm)")
        }
        for _ in 0..<20_000 {
            let x = 0.5 + u(), gr = (u() - 0.3) * 0.2, yf = [1.0 / 12, 0.25, 0.5, 1.0 / 52, 1][Int(u() * 5)]
            check("pow", GameMath.pow(x, yf / 0.5), Foundation.pow(x, yf / 0.5), "\(x), \(yf / 0.5)")
            check("pow", GameMath.pow(1 + gr, yf), Foundation.pow(1 + gr, yf), "\(1 + gr), \(yf)")
            let b = u() * 4
            check("pow", GameMath.pow(b, 1.6), Foundation.pow(b, 1.6), "\(b), 1.6")
            let z = u() * 20 - 10, p = u() * 1e9 + 1e-3, a = u() * 7 - 3.5
            check("exp", GameMath.exp(z), Foundation.exp(z), "\(z)")
            check("log", GameMath.log(p), Foundation.log(p), "\(p)")
            check("log10", GameMath.log10(p), Foundation.log10(p), "\(p)")
            check("log2", GameMath.log2(p), Foundation.log2(p), "\(p)")
            check("sin", GameMath.sin(a), Foundation.sin(a), "\(a)")
            check("cos", GameMath.cos(a), Foundation.cos(a), "\(a)")
            check("atan2", GameMath.atan2(a, z), Foundation.atan2(a, z), "\(a), \(z)")
            let s = u() * 2 - 1
            check("asin", GameMath.asin(s), Foundation.asin(s), "\(s)")
            check("hypot", GameMath.hypot(a, z), Foundation.hypot(a, z), "\(a), \(z)")
        }
        // Exact where it matters: integer powers, powers of ten and two, the special values.
        for p in -6...12 { XCTAssertEqual(GameMath.pow(10, Double(p)), Foundation.pow(10, Double(p)), "10^\(p)") }
        for k in -20...20 { XCTAssertEqual(GameMath.log2(Foundation.pow(2, Double(k))), Double(k)) }
        for k in 0...15 { XCTAssertEqual(GameMath.log10(Foundation.pow(10, Double(k))), Double(k)) }
        XCTAssertEqual(GameMath.pow(0.3, 2), 0.3 * 0.3)
        XCTAssertEqual(GameMath.pow(2, 0.5), 2.0.squareRoot())
        XCTAssertEqual(GameMath.pow(0, 2), 0)
        XCTAssertTrue(GameMath.pow(-2, 0.5).isNaN)
        XCTAssertEqual(GameMath.sin(0), 0)
        XCTAssertEqual(GameMath.cos(0), 1)
        XCTAssertEqual(GameMath.asin(1), Double.pi / 2)
        XCTAssertEqual(GameMath.atan2(0, -1), Double.pi)
        XCTAssertEqual(GameMath.hypot(3, 4), 5)
        XCTAssertEqual(GameMath.exp(0), 1)
        XCTAssertEqual(GameMath.log(1), 0)
        XCTAssertEqual(GameMath.log10(0), -.infinity)
        XCTAssertTrue(GameMath.log(-1).isNaN)
        print("GameMath worst ulps vs the C library: \(worst.sorted { $0.key < $1.key })")
    }

    /// Files under Engine/ and Models/ that are not simulation: dead code, and app-only views' models.
    static let notSimulation: Set<String> = ["AIPersonalityEngine.swift", "AIWarRoom.swift", "NarrativeEngine.swift",
        "NuclearClubProgression.swift", "WhatIfSimulator.swift", "WorldCountriesDatabase_Complete.swift", "AppSettings.swift",
        "KeyBindings.swift", "ModernDesignSystem.swift", "WidgetSync.swift"]

    /// Simulation code calls GameMath, never the C library's elementary functions (they differ across platforms).
    func testEngineUsesGameMath() throws {
        let bare = try NSRegularExpression(pattern: #"(?<![A-Za-z_.])(pow|exp|exp2|expm1|log|log10|log2|log1p|sin|cos|tan|asin|acos|atan|atan2|sinh|cosh|tanh|hypot|cbrt)\("#)
        let fm = FileManager.default
        var offenders: [String] = []
        for dir in ["Engine", "Models"] {
            let base = Self.shared.appendingPathComponent(dir)
            for case let rel as String in fm.enumerator(atPath: base.path)! where rel.hasSuffix(".swift") && rel != "GameMath.swift"
                && !Self.notSimulation.contains(rel) {
                let src = try String(contentsOf: base.appendingPathComponent(rel), encoding: .utf8)
                for (n, line) in src.components(separatedBy: "\n").enumerated() where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    let hits = bare.matches(in: line, range: NSRange(line.startIndex..., in: line))
                    // `log(` is also EventLog's method and its callers.
                    if hits.contains(where: { line[Range($0.range(at: 1), in: line)!] != "log" }) { offenders.append("\(dir)/\(rel):\(n + 1)") }
                }
            }
        }
        XCTAssertEqual(offenders, [], "use GameMath")
    }
}
