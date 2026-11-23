//
//  Essentials.swift
//  GTNWCore
//
//  The WebAssembly core links FoundationEssentials, not Foundation (Package.swift: `GTNW_ESSENTIALS`, and a module
//  alias so `import Foundation` means FoundationEssentials). Foundation's ICU data was 35 MB of the 49 MB module.
//  This file supplies the handful of Foundation APIs the engine calls that live outside FoundationEssentials:
//
//  | API the engine calls                     | Here                                                            |
//  |------------------------------------------|-----------------------------------------------------------------|
//  | String(format:)                          | `CoreText.format`: the C library's printf, one directive at a time |
//  | Int.formatted()                          | `CoreText.grouped`: en_US digit grouping ("1,234,567")          |
//  | String.capitalized                       | `CoreText.capitalized`: NSString's rules (see below)            |
//  | replacingOccurrences(of:with:)           | the standard library's `replacing(_:with:)`                     |
//  | DateFormatter                            | `GameCalendar.format`, `PlayHistory.day` format by hand         |
//  | replacingOccurrences(…, .regularExpression) | `CoreText.replacingWords`: the two whole-word patterns the engine uses |
//  | localizedCaseInsensitiveContains, folding | lower-casing; for folding, accents dropped from Latin letters  |
//  | JSONSerialization                        | `CoreJSON`: read via JSONDecoder, write with sorted keys        |
//  | UserDefaults                             | an in-memory store (every GTNWCore build, see CoreShims)        |
//  | CharacterSet, trimmingCharacters, components(separatedBy:) | by Unicode general category (`CoreText.is*`) |
//  | range(of:options:range:)                 | a plain search, case-insensitive and backwards as asked          |
//  | NSLock, NSNull                           | a no-op lock (WebAssembly runs the engine on one thread); null  |
//
//  `CoreText` and `CoreJSON` compile in every GTNWCore build, so the package tests check them natively against
//  Foundation's own answers (GTNWCoreTests.testEssentials*); the extensions that put them behind Foundation's names
//  compile only under GTNW_ESSENTIALS. Native builds (the app, the CLI) keep using Foundation.
//

#if GTNW_CORE
import Foundation
#if GTNW_ESSENTIALS
// Foundation re-exports the C library (pow, sin, log, …); FoundationEssentials does not, so the core does.
@_exported import WASILibc
#elseif canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum CoreText {

    // MARK: printf

    /// `String(format:)` for the directives the engine uses: the C library formats each number (so rounding is
    /// printf's, as Foundation's is), `%@` and `%s` print the argument's description. Integers go through `%lld`,
    /// so Int is 64-bit on wasm32 too.
    static func format(_ format: String, _ args: [Any]) -> String {
        let f = Array(format.utf8)
        var out: [UInt8] = []
        out.reserveCapacity(f.count + 16)
        var next = 0, i = 0
        func arg() -> Any? {
            defer { next += 1 }
            return next < args.count ? args[next] : nil
        }
        while i < f.count {
            guard f[i] == UInt8(ascii: "%") else { out.append(f[i]); i += 1; continue }
            var j = i + 1
            var flags: [UInt8] = [], width: [UInt8] = [], precision: [UInt8]? = nil
            while j < f.count, "-+ #0'".utf8.contains(f[j]) { flags.append(f[j]); j += 1 }
            while j < f.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(f[j]) { width.append(f[j]); j += 1 }
            if j < f.count, f[j] == UInt8(ascii: ".") {
                j += 1
                var p: [UInt8] = []
                while j < f.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(f[j]) { p.append(f[j]); j += 1 }
                precision = p
            }
            while j < f.count, "hlqLzjt".utf8.contains(f[j]) { j += 1 }   // length: the argument's type decides
            guard j < f.count else { out += f[i...]; break }
            let conversion = f[j]
            let spec = [UInt8(ascii: "%")] + flags + width + (precision.map { [UInt8(ascii: ".")] + $0 } ?? [])
            i = j + 1
            switch conversion {
            case UInt8(ascii: "%"):
                out.append(conversion)
            case UInt8(ascii: "@"), UInt8(ascii: "s"):
                let text = arg().map { String(describing: $0) } ?? "(null)"
                out += spec.count == 1 ? Array(text.utf8) : Array(cFormat(spec + [UInt8(ascii: "s")], text: text).utf8)
            case UInt8(ascii: "d"), UInt8(ascii: "i"):
                out += Array(cFormat(spec + Array("lld".utf8), int: signed(arg())).utf8)
            case UInt8(ascii: "u"), UInt8(ascii: "x"), UInt8(ascii: "X"), UInt8(ascii: "o"):
                out += Array(cFormat(spec + Array("ll".utf8) + [conversion], uint: unsigned(arg())).utf8)
            case UInt8(ascii: "f"), UInt8(ascii: "F"), UInt8(ascii: "e"), UInt8(ascii: "E"), UInt8(ascii: "g"),
                 UInt8(ascii: "G"), UInt8(ascii: "a"), UInt8(ascii: "A"):
                out += Array(cFormat(spec + [conversion], double: real(arg())).utf8)
            case UInt8(ascii: "c"):
                if let s = signed(arg()) as Int64?, let u = Unicode.Scalar(UInt32(truncatingIfNeeded: s)) { out += Array(String(u).utf8) }
            default:
                out += f[(j - (spec.count - 1) - 1)...j]
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    private static func signed(_ v: Any?) -> Int64 {
        switch v {
        case let x as Int: return Int64(x)
        case let x as Int64: return x
        case let x as Int32: return Int64(x)
        case let x as Int16: return Int64(x)
        case let x as Int8: return Int64(x)
        case let x as UInt: return Int64(truncatingIfNeeded: x)
        case let x as UInt64: return Int64(truncatingIfNeeded: x)
        case let x as UInt32: return Int64(x)
        case let x as UInt16: return Int64(x)
        case let x as UInt8: return Int64(x)
        case let x as Bool: return x ? 1 : 0
        case let x as Double: return Int64(exactly: x.rounded(.towardZero)) ?? 0
        default: return 0
        }
    }

    private static func unsigned(_ v: Any?) -> UInt64 {
        switch v {
        case let x as UInt64: return x
        case let x as UInt: return UInt64(x)
        case let x as UInt32: return UInt64(x)
        case let x as UInt16: return UInt64(x)
        case let x as UInt8: return UInt64(x)
        default: return UInt64(bitPattern: signed(v))
        }
    }

    private static func real(_ v: Any?) -> Double {
        switch v {
        case let x as Double: return x
        case let x as Float: return Double(x)
        default: return Double(signed(v))
        }
    }

    private static func cFormat(_ spec: [UInt8], int: Int64) -> String { vformat(spec, [int]) }
    private static func cFormat(_ spec: [UInt8], uint: UInt64) -> String { vformat(spec, [uint]) }
    private static func cFormat(_ spec: [UInt8], double: Double) -> String { vformat(spec, [double]) }
    private static func cFormat(_ spec: [UInt8], text: String) -> String {
        text.withCString { vformat(spec, [$0]) }
    }

    private static func vformat(_ spec: [UInt8], _ args: [CVarArg]) -> String {
        let fmt = spec.map { CChar(bitPattern: $0) } + [0]
        var size = 128
        while true {
            var buffer = [CChar](repeating: 0, count: size)
            let n = withVaList(args) { va in buffer.withUnsafeMutableBufferPointer { vsnprintf($0.baseAddress, size, fmt, va) } }
            guard n >= 0 else { return "" }
            if Int(n) < size { return String(decoding: buffer.prefix(Int(n)).map { UInt8(bitPattern: $0) }, as: UTF8.self) }
            size = Int(n) + 1
        }
    }

    // MARK: Numbers

    /// `Int.formatted()` in English: "-1,234,567".
    static func grouped<T: BinaryInteger>(_ n: T) -> String {
        let digits = Array(String(n.magnitude))
        var out = ""
        for (k, d) in digits.enumerated() {
            if k > 0, (digits.count - k) % 3 == 0 { out.append(",") }
            out.append(d)
        }
        return n < 0 ? "-" + out : out
    }

    // MARK: Case

    /// `String.capitalized` as Foundation does it: each word's first letter in title case, the rest in lower case.
    /// A word starts at a letter that follows anything but a letter (a digit, a space, a hyphen, an underscore, a
    /// slash, punctuation), except that an apostrophe inside a word does not end it ("Don't", "O'neil").
    static func capitalized<S: StringProtocol>(_ s: S) -> String {
        var out = ""
        var inWord = false, afterApostrophe = false
        for ch in s {
            if ch.isLetter {
                if inWord || afterApostrophe {
                    out += ch.lowercased()
                } else {
                    var scalars = ch.unicodeScalars.makeIterator()
                    if let first = scalars.next() { out += first.properties.titlecaseMapping }
                    while let rest = scalars.next() { out += rest.properties.lowercaseMapping }
                }
                inWord = true
                afterApostrophe = false
            } else {
                afterApostrophe = inWord && (ch == "'" || ch == "’")
                inWord = false
                out.append(ch)
            }
        }
        return out
    }

    /// Case- and diacritic-insensitive form of Latin text (`folding([.diacriticInsensitive, .caseInsensitive])`):
    /// lower case, accents dropped from Latin letters, ß spelled ss.
    static func folded(_ s: String) -> String {
        var out = ""
        for scalar in s.lowercased().unicodeScalars {
            if let base = latinBase[scalar] { out += base; continue }
            if scalar.properties.generalCategory == .nonspacingMark { continue }
            out.unicodeScalars.append(scalar)
        }
        return out
    }

    private static let latinBase: [Unicode.Scalar: String] = {
        // Letters that decompose canonically into a base letter and accents (ł, ø, æ do not, and keep their shape).
        let rows: [(String, String)] = [
            ("àáâãäåāăą", "a"), ("çćĉċč", "c"), ("ď", "d"), ("èéêëēĕėęě", "e"), ("ĝğġģ", "g"), ("ĥ", "h"),
            ("ìíîïĩīĭį", "i"), ("ĵ", "j"), ("ķ", "k"), ("ĺļľ", "l"), ("ñńņň", "n"), ("òóôõöōŏő", "o"),
            ("ŕŗř", "r"), ("śŝşšș", "s"), ("ţťț", "t"), ("ùúûüũūŭůűų", "u"), ("ŵ", "w"), ("ýÿŷ", "y"), ("źżž", "z"),
            ("ß", "ss"),
        ]
        var map: [Unicode.Scalar: String] = [:]
        for (letters, base) in rows { for u in letters.unicodeScalars { map[u] = base } }
        return map
    }()

    // MARK: Character classes (Foundation's CharacterSet constants)

    /// `whitespaces`: tab, the space separators (Zs) and, as Apple's Foundation has it, the zero-width space.
    static func isWhitespace(_ u: Unicode.Scalar) -> Bool {
        u == "\t" || u == "\u{200B}" || u.properties.generalCategory == .spaceSeparator
    }
    /// `newlines`: U+000A–U+000D, U+0085, U+2028, U+2029.
    static func isNewline(_ u: Unicode.Scalar) -> Bool { (0x0A...0x0D).contains(u.value) || [0x85, 0x2028, 0x2029].contains(u.value) }
    /// `controlCharacters`: Cc and Cf.
    static func isControl(_ u: Unicode.Scalar) -> Bool { [.control, .format].contains(u.properties.generalCategory) }
    /// `illegalCharacters`: unassigned code points (Cn), noncharacters included.
    static func isIllegal(_ u: Unicode.Scalar) -> Bool { u.properties.generalCategory == .unassigned }
    /// `alphanumerics`: letters (L*), marks (M*) and numbers (N*).
    static func isAlphanumeric(_ u: Unicode.Scalar) -> Bool {
        switch u.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .letterNumber, .otherNumber: return true
        default: return false
        }
    }
    /// `punctuationCharacters`: P*.
    static func isPunctuation(_ u: Unicode.Scalar) -> Bool {
        switch u.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation,
             .finalPunctuation, .otherPunctuation: return true
        default: return false
        }
    }

    // MARK: Searching and splitting

    /// `trimmingCharacters(in:)`: drop leading and trailing scalars in the set.
    static func trimming(_ s: String, _ isIn: (Unicode.Scalar) -> Bool) -> String {
        let u = Array(s.unicodeScalars)
        guard let first = u.firstIndex(where: { !isIn($0) }), let last = u.lastIndex(where: { !isIn($0) }) else { return "" }
        return String(String.UnicodeScalarView(u[first...last]))
    }

    /// `components(separatedBy:)` with a string separator: empty pieces kept.
    static func components(_ s: String, separatedBy separator: String) -> [String] {
        guard !separator.isEmpty else { return [s] }
        return s.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
    }

    /// `range(of:options:range:)` for the options the engine passes (`.caseInsensitive`, `.backwards`).
    static func range(of target: String, in s: String, options: String.CompareOptions = [],
                      range: Range<String.Index>? = nil) -> Range<String.Index>? {
        let whole = range ?? s.startIndex..<s.endIndex
        let needle = Array(target)
        guard !needle.isEmpty else { return nil }
        let fold = options.contains(.caseInsensitive)
        func matches(at i: String.Index) -> String.Index? {
            var j = i
            for c in needle {
                guard j < whole.upperBound else { return nil }
                guard fold ? s[j].lowercased() == c.lowercased() : s[j] == c else { return nil }
                j = s.index(after: j)
            }
            return j
        }
        var starts: [String.Index] = []
        var i = whole.lowerBound
        while i < whole.upperBound { starts.append(i); i = s.index(after: i) }
        for start in options.contains(.backwards) ? starts.reversed() : starts {
            if let end = matches(at: start) { return start..<end }
        }
        return nil
    }

    // MARK: Whole words

    /// ICU's `\w`: letters, marks, decimal digits, connector punctuation, ZWNJ/ZWJ.
    static func isWordScalar(_ u: Unicode.Scalar) -> Bool {
        if u.value == 0x200C || u.value == 0x200D { return true }
        let p = u.properties
        if p.isAlphabetic { return true }
        switch p.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .connectorPunctuation: return true
        default: return false
        }
    }

    /// Replace every whole-word occurrence of `word`, left to right: the regular expressions
    /// `\b<word>\b` (`followedBy: .boundary`) and `\b<word>(?![\w.])` (`.notWordOrDot`) with a literal replacement.
    enum Tail { case boundary, notWordOrDot }
    static func replacingWords(in text: String, _ word: String, with replacement: String, tail: Tail) -> String {
        let t = Array(text.unicodeScalars), w = Array(word.unicodeScalars)
        guard !w.isEmpty, t.count >= w.count else { return text }
        let firstIsWord = isWordScalar(w[0]), lastIsWord = isWordScalar(w[w.count - 1])
        var out = String.UnicodeScalarView()
        var i = 0
        while i < t.count {
            if i + w.count <= t.count, t[i] == w[0], Array(t[i..<(i + w.count)]) == w {
                let before = i > 0 && isWordScalar(t[i - 1])
                let after: Unicode.Scalar? = i + w.count < t.count ? t[i + w.count] : nil
                let tailOK: Bool
                switch tail {
                case .boundary: tailOK = lastIsWord != (after.map(isWordScalar) ?? false)
                case .notWordOrDot: tailOK = after.map { !isWordScalar($0) && $0 != "." } ?? true
                }
                if before != firstIsWord, tailOK {
                    out.append(contentsOf: replacement.unicodeScalars)
                    i += w.count
                    continue
                }
            }
            out.append(t[i])
            i += 1
        }
        return String(out)
    }
}

// MARK: - JSON objects

/// `JSONSerialization` for [String: Any] trees: numbers read as Double, booleans as Bool, null as NSNull.
enum CoreJSON {
    private enum Value: Decodable {
        case null, bool(Bool), number(Double), string(String), array([Value]), object([String: Value])

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() { self = .null }
            else if let b = try? c.decode(Bool.self) { self = .bool(b) }
            else if let d = try? c.decode(Double.self) { self = .number(d) }
            else if let s = try? c.decode(String.self) { self = .string(s) }
            else if let a = try? c.decode([Value].self) { self = .array(a) }
            else { self = .object(try c.decode([String: Value].self)) }
        }

        var any: Any {
            switch self {
            case .null: return NSNull()
            case .bool(let b): return b
            case .number(let d): return d
            case .string(let s): return s
            case .array(let a): return a.map(\.any)
            case .object(let o): return o.mapValues(\.any)
            }
        }
    }

    static func object(with data: Data) throws -> Any {
        try JSONDecoder().decode(Value.self, from: data).any
    }

    static func isValid(_ object: Any) -> Bool {
        switch object {
        case is String, is Bool, is Int, is Int64, is Int32, is UInt64, is UInt, is NSNull: return true
        case let d as Double: return d.isFinite
        case let a as [Any]: return a.allSatisfy(isValid)
        case let o as [String: Any]: return o.values.allSatisfy(isValid)
        default: return false
        }
    }

    /// Compact JSON with sorted keys and `/` escaped, as JSONSerialization writes it.
    static func data(_ object: Any) throws -> Data {
        var out = ""
        func write(_ v: Any) throws {
            switch v {
            case is NSNull: out += "null"
            case let s as String: string(s)
            case let b as Bool: out += b ? "true" : "false"
            case let i as Int: out += String(i)
            case let i as Int64: out += String(i)
            case let i as Int32: out += String(i)
            case let i as UInt64: out += String(i)
            case let i as UInt: out += String(i)
            case let d as Double:
                guard d.isFinite else { throw CoreJSONError.invalid }
                out += d == d.rounded() && abs(d) < 1e15 ? String(Int64(d)) : String(d)
            case let a as [Any]:
                out += "["
                for (k, e) in a.enumerated() { if k > 0 { out += "," }; try write(e) }
                out += "]"
            case let o as [String: Any]:
                out += "{"
                for (k, key) in o.keys.sorted().enumerated() {
                    if k > 0 { out += "," }
                    string(key)
                    out += ":"
                    try write(o[key]!)
                }
                out += "}"
            default: throw CoreJSONError.invalid
            }
        }
        func string(_ s: String) {
            out += "\""
            for u in s.unicodeScalars {
                switch u {
                case "\"": out += "\\\""
                case "\\": out += "\\\\"
                case "/": out += "\\/"
                case "\n": out += "\\n"
                case "\r": out += "\\r"
                case "\t": out += "\\t"
                case "\u{08}": out += "\\b"
                case "\u{0C}": out += "\\f"
                default:
                    if u.value < 0x20 {
                        let hex = String(u.value, radix: 16)
                        out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
                    } else {
                        out.unicodeScalars.append(u)
                    }
                }
            }
            out += "\""
        }
        try write(object)
        return Data(out.utf8)
    }
}

enum CoreJSONError: Error { case invalid }

// MARK: - Foundation's names, in the FoundationEssentials build

#if GTNW_ESSENTIALS
extension String {
    init(format: String, _ args: Any...) { self = CoreText.format(format, args) }
    func range(of target: String, options: CompareOptions = [], range: Range<Index>? = nil) -> Range<Index>? {
        CoreText.range(of: target, in: self, options: options, range: range)
    }
}

extension StringProtocol {
    var capitalized: String { CoreText.capitalized(self) }
    func replacingOccurrences<T: StringProtocol, R: StringProtocol>(of target: T, with replacement: R) -> String {
        String(self).replacing(String(target), with: String(replacement))
    }
    func localizedCaseInsensitiveContains<T: StringProtocol>(_ other: T) -> Bool {
        lowercased().contains(other.lowercased())
    }
    func folding(options: String.CompareOptions = [], locale: Locale?) -> String { CoreText.folded(String(self)) }
}

extension BinaryInteger {
    func formatted() -> String { CoreText.grouped(self) }
}

enum JSONSerialization {
    struct ReadingOptions: OptionSet {
        let rawValue: Int
    }
    struct WritingOptions: OptionSet {
        let rawValue: Int
        static let sortedKeys = WritingOptions(rawValue: 1)
    }
    static func jsonObject(with data: Data, options: ReadingOptions = []) throws -> Any { try CoreJSON.object(with: data) }
    static func isValidJSONObject(_ object: Any) -> Bool { CoreJSON.isValid(object) }
    static func data(withJSONObject object: Any, options: WritingOptions = []) throws -> Data { try CoreJSON.data(object) }
}

/// The named character sets the engine uses, by Unicode general category (`CoreText.is*`).
struct CharacterSet {
    private let test: (Unicode.Scalar) -> Bool

    init(_ test: @escaping (Unicode.Scalar) -> Bool) { self.test = test }
    init(charactersIn string: String) {
        let set = Set(string.unicodeScalars)
        test = { set.contains($0) }
    }

    func contains(_ scalar: Unicode.Scalar) -> Bool { test(scalar) }
    func union(_ other: CharacterSet) -> CharacterSet { CharacterSet { self.test($0) || other.test($0) } }

    static let whitespaces = CharacterSet(CoreText.isWhitespace)
    static let newlines = CharacterSet(CoreText.isNewline)
    static let whitespacesAndNewlines = CharacterSet { CoreText.isWhitespace($0) || CoreText.isNewline($0) }
    static let controlCharacters = CharacterSet(CoreText.isControl)
    static let illegalCharacters = CharacterSet(CoreText.isIllegal)
    static let alphanumerics = CharacterSet(CoreText.isAlphanumeric)
    static let punctuationCharacters = CharacterSet(CoreText.isPunctuation)
}

extension StringProtocol {
    func trimmingCharacters(in set: CharacterSet) -> String { CoreText.trimming(String(self), set.contains) }

    func components<T: StringProtocol>(separatedBy separator: T) -> [String] {
        CoreText.components(String(self), separatedBy: String(separator))
    }
}

/// JSON's null.
final class NSNull: Equatable {
    static func == (_: NSNull, _: NSNull) -> Bool { true }
}

/// WebAssembly runs the engine on one thread.
final class NSLock {
    func lock() {}
    func unlock() {}
}
#endif
#endif
