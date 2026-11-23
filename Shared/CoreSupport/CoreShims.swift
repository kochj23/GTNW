//
//  CoreShims.swift
//  GTNWCore
//
//  Stand-ins for the Apple-only frameworks and app-only services the engine files touch, compiled only into the
//  GTNWCore package (`GTNW_CORE`; the Xcode app never sees this file). They keep the shared engine sources free of
//  per-line platform checks. Each has the app type's name and the slice of its API the engine calls; the app's own
//  type is the real implementation (Documentation/WASM-PORT.md, "Platform services"):
//
//  | Stand-in            | App implementation                      | In GTNWCore                                    |
//  |---------------------|-----------------------------------------|------------------------------------------------|
//  | ObservableObject,   | Combine                                 | a plain protocol, a plain stored value         |
//  | @Published          |                                         |                                                |
//  | Logger              | os.Logger (Log.swift)                   | forwards to `CoreLog.sink`                     |
//  | GameAI              | NovaAIKit (AI/AppAI.swift)              | `CoreAI.provider`, or "no AI" (built-in logic) |
//  | GameStoreService    | Games DB + local cache (Storage/)       | no remote; the host keeps saves (bridge)       |
//  | ShadowPack          | sounds + art (ShadowPack/)              | sound cues to `CoreAudio.sink`                 |
//  | SHA256              | CryptoKit                               | FIPS 180-4 in Swift                            |
//  | Int.random(…GameRNG)| the standard library (64-bit Int)       | the same 64-bit draws where Int is 32 bits     |
//  | CoreRunLoop         | the main dispatch queue (EnginePlatform) | deferred work the host drains                  |
//  | UserDefaults        | Foundation (the user's preferences)     | in memory, for the life of the process         |
//

#if GTNW_CORE
import Foundation

/// `UserDefaults` as an in-memory store that lasts as long as the process: the core keeps nothing on its host
/// (the CLI, the package tests and WebAssembly all start from the defaults, and two runs play alike).
final class UserDefaults: @unchecked Sendable {
    static let standard = UserDefaults()
    private var values: [String: Any] = [:]

    init() {}
    init?(suiteName: String?) {}

    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values[key] = nil }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func string(forKey key: String) -> String? { values[key] as? String }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func integer(forKey key: String) -> Int { values[key] as? Int ?? 0 }
    func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
}

/// Combine's `ObservableObject`, without change notification (the core has no views to tell).
protocol ObservableObject: AnyObject {}

/// Combine's `@Published`, as a plain stored value.
@propertyWrapper
struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}

/// Where the core's log lines go: nowhere by default; a host (the CLI, the Wasm bridge) may set a sink.
enum CoreLog {
    nonisolated(unsafe) static var sink: ((_ category: String, _ level: String, _ message: String) -> Void)?
}

/// `os.Logger` with the three levels GTNW uses (`Log.swift`).
struct Logger: Sendable {
    let subsystem: String
    let category: String
    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }
    func trace(_ message: @autoclosure () -> String) { CoreLog.sink?(category, "debug", message()) }
    func note(_ message: @autoclosure () -> String) { CoreLog.sink?(category, "info", message()) }
    func failure(_ message: @autoclosure () -> String) { CoreLog.sink?(category, "error", message()) }
    // os.Logger's levels, for engine code that calls them directly
    func debug(_ message: @autoclosure () -> String) { CoreLog.sink?(category, "debug", message()) }
    func info(_ message: @autoclosure () -> String) { CoreLog.sink?(category, "info", message()) }
    func notice(_ message: @autoclosure () -> String) { CoreLog.sink?(category, "info", message()) }
    func warning(_ message: @autoclosure () -> String) { CoreLog.sink?(category, "error", message()) }
    func error(_ message: @autoclosure () -> String) { CoreLog.sink?(category, "error", message()) }
}

// MARK: - Deferred work (GameScheduler)

/// The work `GameScheduler.after` deferred, oldest deadline first. Time is virtual: a host drains it after every
/// call into the engine, so "retaliation in a second" happens before control returns, every run the same way.
enum CoreRunLoop {
    private nonisolated(unsafe) static var queue: [(due: Double, seq: Int, work: () -> Void)] = []
    private nonisolated(unsafe) static var seq = 0
    private nonisolated(unsafe) static var now = 0.0

    static var isEmpty: Bool { queue.isEmpty }

    static func schedule(after seconds: Double, _ work: @escaping () -> Void) {
        seq += 1
        queue.append((now + max(0, seconds), seq, work))
    }

    /// Run the earliest piece of deferred work, if any (its own deferred work joins the queue). False when idle.
    @discardableResult
    static func runNext() -> Bool {
        guard let i = queue.indices.min(by: { (queue[$0].due, queue[$0].seq) < (queue[$1].due, queue[$1].seq) }) else { return false }
        let item = queue.remove(at: i)
        now = max(now, item.due)
        item.work()
        return true
    }

    /// Forget everything pending (a new game).
    static func reset() { queue.removeAll() }
}

// MARK: - AI (GameAI)

/// What an AI backend answered with, for log lines (`NovaAIBackend` in the app).
struct CoreAIBackend: Equatable, Sendable {
    var rawValue: String
}

/// A text AI a GTNWCore host can plug in (the web build could route it to the games relay). Nil = no AI: every
/// feature runs its built-in logic, as the app does with AI off.
protocol CoreTextAI: Sendable {
    var name: String { get }
    func generate(prompt: String, systemPrompt: String?, temperature: Double, maxTokens: Int) async throws -> String
}

enum CoreAI {
    nonisolated(unsafe) static var provider: CoreTextAI?
    /// The host answers for model brains (`brainTransportOverride`) without a text AI: the web build's site AI.
    nonisolated(unsafe) static var brainsOn = false
}

struct CoreAIUnavailable: Error, Equatable {}

/// The app's `GameAI` (AI/AppAI.swift) as the engine sees it. Replies pass `AIOutputSanitizer`, as in the app.
struct GameAI: Sendable {
    static let shared = GameAI()

    var activeBackend: CoreAIBackend? { CoreAI.provider.map { CoreAIBackend(rawValue: $0.name) } }

    func generate(prompt: String, systemPrompt: String? = nil, temperature: Double = 0.7, maxTokens: Int = 2048) async throws -> String {
        guard let ai = CoreAI.provider else { throw CoreAIUnavailable() }
        let raw = try await ai.generate(prompt: prompt, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens)
        guard let clean = AIOutputSanitizer.clean(raw) else { throw CoreAIUnavailable() }
        return clean
    }
}

// MARK: - Storage (GameStoreService)

/// The app's `GameStoreService` (Games DB + local cache) as the engine sees it. GTNWCore never has a remote store,
/// so every play-history write is skipped; the bridge's `save()` / `load()` hand the game to the host instead.
final class GameStoreService {
    /// The app reads "under XCTest or a smoke run" here, and several world systems stay quiet when it is true
    /// (`ChemicalThreats.enabled`, `CovertAgents.aiEnabled`, …). GTNWCore plays the full game unless the host says
    /// otherwise *before the first game*; the bridge's "rules" option sets those switches directly.
    nonisolated(unsafe) static var isTestOrSmokeRun = false

    struct Records { var leaderboard: [LeaderboardRecord] = [] }
    struct Local { var saves: SaveManager }

    let local: Local
    var remote: GameStore? { nil }
    var records: Records { Records() }

    init(saves: SaveManager) { local = Local(saves: saves) }

    func slotSaved(_ slot: Int) {}
    func recordGameOver(result: GameResultRecord, leaderboard: LeaderboardRecord?) {}
    func playSessionUpdated(_ record: PlaySessionRecord) {}
    func playEvent(_ event: PlayEventRecord) {}
}

// MARK: - Sound (ShadowPack)

/// Where the engine's sound cues go (`sfx.war6`, …); nil = silence.
enum CoreAudio {
    nonisolated(unsafe) static var sink: ((_ id: String, _ volume: Float) -> Void)?
}

/// The app's `ShadowPack` (art and sound from a pack the player installs) as the engine sees it: never installed,
/// sound cues forwarded to the host.
final class ShadowPack {
    static let shared = ShadowPack()
    let isInstalled = false
    let folder = URL(fileURLWithPath: "/ShadowPack", isDirectory: true)

    @discardableResult
    func play(_ id: String, volume: Float = 1) -> Bool {
        guard let sink = CoreAudio.sink else { return false }
        sink(id, volume)
        return true
    }

    static func advisorKey(forTitle title: String) -> String? { Advisor.roleKey(forTitle: title) }
}

// MARK: - Gameplay rolls on 32-bit platforms

// `Int.random(in:using:)`, `randomElement(using:)` and `shuffled(using:)` draw through `next(upperBound:)` at the
// width of `Int`: 64 bits on the Mac, 32 on WebAssembly, so the same GameRNG would roll different numbers there.
// These overloads (picked over the generic ones for a `GameRNG`) always draw at 64 bits, exactly as the standard
// library does on a 64-bit platform, so a seed plays the same game everywhere. GameRNG's vectors and the golden
// games check it (Wasm/Tests, Wasm/parity.sh).
extension Int {
    static func random(in range: ClosedRange<Int>, using generator: inout GameRNG) -> Int {
        let lower = UInt64(truncatingIfNeeded: Int64(range.lowerBound))
        let delta = UInt64(truncatingIfNeeded: Int64(range.upperBound) &- Int64(range.lowerBound))
        if delta == UInt64.max { return Int(truncatingIfNeeded: generator.next()) }
        return Int(truncatingIfNeeded: Int64(bitPattern: lower &+ generator.next(upperBound: delta + 1)))
    }

    static func random(in range: Range<Int>, using generator: inout GameRNG) -> Int {
        precondition(!range.isEmpty, "Can't get random value with an empty range")
        let lower = UInt64(truncatingIfNeeded: Int64(range.lowerBound))
        let delta = UInt64(truncatingIfNeeded: Int64(range.upperBound) &- Int64(range.lowerBound))
        return Int(truncatingIfNeeded: Int64(bitPattern: lower &+ generator.next(upperBound: delta)))
    }
}

extension Collection {
    func randomElement(using generator: inout GameRNG) -> Element? {
        guard !isEmpty else { return nil }
        return self[index(startIndex, offsetBy: Int.random(in: 0..<count, using: &generator))]
    }
}

extension Sequence {
    func shuffled(using generator: inout GameRNG) -> [Element] {
        var result = Array(self)
        var amount = result.count
        var current = 0
        while amount > 1 {
            let random = Int.random(in: 0..<amount, using: &generator)
            amount -= 1
            result.swapAt(current, current + random)
            current += 1
        }
        return result
    }
}

// MARK: - SHA256 (CryptoKit)

/// CryptoKit's `SHA256.hash(data:)` (FIPS 180-4), for the few stable ids and checksums the engine derives.
enum SHA256 {
    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]

    static func hash(data: Data) -> [UInt8] {
        var h: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
        var msg = [UInt8](data)
        let bitLength = UInt64(msg.count) &* 8
        msg.append(0x80)
        while msg.count % 64 != 56 { msg.append(0) }
        for i in (0..<8).reversed() { msg.append(UInt8(truncatingIfNeeded: bitLength >> (UInt64(i) * 8))) }
        var w = [UInt32](repeating: 0, count: 64)
        for chunk in stride(from: 0, to: msg.count, by: 64) {
            for i in 0..<16 {
                let b = chunk + i * 4
                w[i] = UInt32(msg[b]) << 24 | UInt32(msg[b + 1]) << 16 | UInt32(msg[b + 2]) << 8 | UInt32(msg[b + 3])
            }
            for i in 16..<64 {
                let s0 = w[i - 15].rotatedRight(7) ^ w[i - 15].rotatedRight(18) ^ (w[i - 15] >> 3)
                let s1 = w[i - 2].rotatedRight(17) ^ w[i - 2].rotatedRight(19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }
            var (a, b, c, d, e, f, g, hh) = (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7])
            for i in 0..<64 {
                let s1 = e.rotatedRight(6) ^ e.rotatedRight(11) ^ e.rotatedRight(25)
                let ch = (e & f) ^ (~e & g)
                let t1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = a.rotatedRight(2) ^ a.rotatedRight(13) ^ a.rotatedRight(22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let t2 = s0 &+ maj
                (hh, g, f, e, d, c, b, a) = (g, f, e, d &+ t1, c, b, a, t1 &+ t2)
            }
            h = [h[0] &+ a, h[1] &+ b, h[2] &+ c, h[3] &+ d, h[4] &+ e, h[5] &+ f, h[6] &+ g, h[7] &+ hh]
        }
        return h.flatMap { v in (0..<4).map { UInt8(truncatingIfNeeded: v >> (24 - $0 * 8)) } }
    }
}

private extension UInt32 {
    func rotatedRight(_ n: UInt32) -> UInt32 { (self >> n) | (self << (32 - n)) }
}
#endif
