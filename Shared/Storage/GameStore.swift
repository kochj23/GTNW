//
//  GameStore.swift
//  Global Thermal Nuclear War
//
//  Durable game state: save slots + autosave, leaderboard, game history, scenario progress and achievements.
//  `GameStore` is the storage protocol. Implementations:
//    - `PostgresGameStore`  — the dedicated Nova Games Postgres (schema `gtnw`, TLS verify-full, Keychain credentials)
//    - `LocalGameStore`     — the on-device cache (works offline, holds the pending-sync queue)
//    - `InMemoryGameStore`  — a fake for tests
//  `GameStoreService` ties them together (write local first, sync to Postgres, retry with backoff when offline).
//  Settings / preferences (skin, sound, window, AI backend) are NOT here; they stay in UserDefaults.
//

import Foundation
import CryptoKit
import Security

// MARK: - Records

/// One save slot. Slot 0 is the autosave. `payload` is the JSON-encoded `GameState`.
struct SaveRecord: Equatable, Sendable {
    var slot: Int
    var schemaVersion: Int
    var payload: Data
    var label: String
    var turn: Int
    var updatedAt: Date

    var sha256: Data { Data(SHA256.hash(data: payload)) }
}

/// Slot metadata without the payload (cheap listing).
struct SlotSummary: Equatable, Sendable {
    var slot: Int
    var label: String
    var turn: Int
    var schemaVersion: Int
    var size: Int
    var updatedAt: Date
}

struct LeaderboardRecord: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var playerName: String
    var finalScore: Int
    var baseScore: Int
    var turnsPlayed: Int
    var nuclearVirgin: Bool
    var difficultyMultiplier: Double
    var victoryType: String?
    var playerCountry: String
    var achievedAt: Date
}

/// One finished game.
struct GameResultRecord: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    /// Scenario id (`world1990`, …) or `sandbox` for a free game.
    var scenarioID: String
    var playerCountry: String
    var won: Bool
    var victoryType: String?
    var reason: String
    var finalScore: Int
    var turns: Int
    var gameDate: String
    var casualties: Int64
    var nuclearStrikes: Int
    var endedAt: Date
}

/// Per-scenario aggregate, derived from game results.
struct ScenarioProgress: Codable, Equatable, Sendable {
    var scenarioID: String
    var plays: Int
    var wins: Int
    var bestScore: Int
    var lastWon: Bool
    var lastPlayedAt: Date

    /// Fold one result into the aggregate (`nil` = first play of this scenario).
    static func applying(_ r: GameResultRecord, to p: ScenarioProgress?) -> ScenarioProgress {
        ScenarioProgress(scenarioID: r.scenarioID,
                         plays: (p?.plays ?? 0) + 1,
                         wins: (p?.wins ?? 0) + (r.won ? 1 : 0),
                         bestScore: max(p?.bestScore ?? 0, r.finalScore),
                         lastWon: r.won,
                         lastPlayedAt: max(p?.lastPlayedAt ?? .distantPast, r.endedAt))
    }
}

struct AchievementRecord: Codable, Equatable, Sendable {
    var id: String
    var unlockedAt: Date
}

struct StoreCounts: Equatable, Sendable, CustomStringConvertible {
    var slots = 0, leaderboard = 0, history = 0, scenarios = 0, achievements = 0
    var description: String {
        "slots=\(slots) leaderboard=\(leaderboard) history=\(history) scenarios=\(scenarios) achievements=\(achievements)"
    }
}

// MARK: - Protocol

protocol GameStore: AnyObject, Sendable {
    func putSlot(_ record: SaveRecord) async throws
    func getSlot(_ slot: Int) async throws -> SaveRecord?
    func listSlots() async throws -> [SlotSummary]
    func deleteSlot(_ slot: Int) async throws

    /// Idempotent: re-adding the same id is a no-op.
    func addLeaderboard(_ record: LeaderboardRecord) async throws
    func leaderboard(limit: Int) async throws -> [LeaderboardRecord]

    /// Idempotent per id; also folds the result into scenario progress (once).
    func addResult(_ record: GameResultRecord) async throws
    func history(limit: Int) async throws -> [GameResultRecord]
    func scenarioProgress() async throws -> [ScenarioProgress]

    /// Idempotent; keeps the earliest unlock time.
    func unlock(_ achievement: AchievementRecord) async throws
    func achievements() async throws -> [AchievementRecord]

    /// Play history (schema `play`). Idempotent per id; an ended session is never changed again.
    func upsertPlaySession(_ record: PlaySessionRecord) async throws
    /// Idempotent per (session, seq).
    func addPlayEvent(_ event: PlayEventRecord) async throws

    func counts() async throws -> StoreCounts
}

// MARK: - Errors

enum GameStoreError: Error, Equatable, CustomStringConvertible {
    /// Not configured (no credentials / CA / disabled). Play continues locally.
    case notConfigured(String)
    /// Network / TLS / server down. Retry later.
    case unreachable(String)
    /// The DB schema is missing or older than this build needs and we can't migrate it.
    case schemaNotReady(String)
    /// The data was rejected (too big, corrupt, hostile, constraint violation). Never retried.
    case invalid(String)

    var isRetryable: Bool {
        switch self {
        case .unreachable: return true
        case .notConfigured, .schemaNotReady, .invalid: return false
        }
    }

    var description: String {
        switch self {
        case .notConfigured(let s): return "not configured: \(s)"
        case .unreachable(let s): return "unreachable: \(s)"
        case .schemaNotReady(let s): return "schema not ready: \(s)"
        case .invalid(let s): return "invalid: \(s)"
        }
    }
}

// MARK: - Validation

/// Size caps and sanity checks applied to everything we write and everything we load (local or remote).
enum StoreValidation {
    static let slotRange = 0...SaveManager.slotCount
    static let maxPayloadBytes = 8 * 1024 * 1024
    static let maxLabelLength = 200
    static let maxNameLength = 64
    static let maxReasonLength = 500
    static let maxScore = 100_000_000
    static let maxCountries = 400
    static let maxTurn = 1_000_000

    /// Strip control characters and cap length (labels, names, reasons).
    static func clean(_ s: String, max: Int) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }).prefix(max))
    }

    static func isIdentifier(_ s: String, max: Int = 64) -> Bool {
        !s.isEmpty && s.count <= max && s.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "-" || $0 == "."
        } && s.allSatisfy(\.isASCII)
    }

    static func check(_ r: SaveRecord) throws {
        guard slotRange.contains(r.slot) else { throw GameStoreError.invalid("slot \(r.slot) out of range") }
        guard (1...SaveCodec.currentSchemaVersion).contains(r.schemaVersion) else {
            throw GameStoreError.invalid("unsupported save schema \(r.schemaVersion)")
        }
        guard !r.payload.isEmpty, r.payload.count <= maxPayloadBytes else {
            throw GameStoreError.invalid("save payload \(r.payload.count) bytes (cap \(maxPayloadBytes))")
        }
        guard r.label.count <= maxLabelLength, (0...maxTurn).contains(r.turn) else { throw GameStoreError.invalid("bad slot metadata") }
    }

    static func check(_ r: LeaderboardRecord) throws {
        guard (0...maxScore).contains(r.finalScore), (0...maxTurn).contains(r.turnsPlayed),
              r.playerName.count <= maxNameLength, r.playerCountry.count <= 8,
              r.difficultyMultiplier.isFinite, (0...100).contains(r.difficultyMultiplier),
              (r.victoryType?.count ?? 0) <= 64 else { throw GameStoreError.invalid("leaderboard entry out of bounds") }
    }

    static func check(_ r: GameResultRecord) throws {
        guard isIdentifier(r.scenarioID), (0...maxScore).contains(r.finalScore), (0...maxTurn).contains(r.turns),
              r.playerCountry.count <= 8, r.reason.count <= maxReasonLength, r.gameDate.count <= 64,
              r.casualties >= 0, r.nuclearStrikes >= 0, (r.victoryType?.count ?? 0) <= 64
        else { throw GameStoreError.invalid("game result out of bounds") }
    }

    static func check(_ a: AchievementRecord) throws {
        guard isIdentifier(a.id) else { throw GameStoreError.invalid("bad achievement id") }
    }
}

// MARK: - Save codec

/// Encodes / decodes / validates save payloads. Every load (file or Postgres) goes through `decode`,
/// so a corrupt or hostile save is rejected instead of crashing or poisoning the game.
enum SaveCodec {
    /// Bump when `GameState`'s JSON changes incompatibly (and teach `decode` the old shape).
    static let currentSchemaVersion = 1

    static func encode(_ gs: GameState) throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(gs)
        guard data.count <= StoreValidation.maxPayloadBytes else {
            throw GameStoreError.invalid("save is \(data.count) bytes (cap \(StoreValidation.maxPayloadBytes))")
        }
        return data
    }

    static func record(_ gs: GameState, slot: Int, updatedAt: Date = Date()) throws -> SaveRecord {
        SaveRecord(slot: slot, schemaVersion: currentSchemaVersion, payload: try encode(gs),
                   label: label(for: gs), turn: max(0, gs.turn), updatedAt: updatedAt)
    }

    static func label(for gs: GameState) -> String {
        StoreValidation.clean("\(gs.currentDateLabel), turn \(gs.turn)", max: StoreValidation.maxLabelLength)
    }

    /// Size cap → schema version → JSON → sanity checks.
    static func decode(_ data: Data, schemaVersion: Int = currentSchemaVersion) throws -> GameState {
        guard !data.isEmpty, data.count <= StoreValidation.maxPayloadBytes else {
            throw GameStoreError.invalid("save payload \(data.count) bytes (cap \(StoreValidation.maxPayloadBytes))")
        }
        guard (1...currentSchemaVersion).contains(schemaVersion) else {
            throw GameStoreError.invalid("save schema \(schemaVersion) is newer than this build (\(currentSchemaVersion))")
        }
        let gs: GameState
        do { gs = try SaveManager.decodeUnchecked(data) } catch { throw GameStoreError.invalid("save is not a valid game: \(type(of: error))") }
        try validate(gs)
        return gs
    }

    static func validate(_ gs: GameState) throws {
        guard !gs.countries.isEmpty, gs.countries.count <= StoreValidation.maxCountries else {
            throw GameStoreError.invalid("save has \(gs.countries.count) countries")
        }
        guard (0...StoreValidation.maxTurn).contains(gs.turn) else { throw GameStoreError.invalid("save turn \(gs.turn) out of range") }
        guard Set(gs.countries.map(\.id)).count == gs.countries.count else { throw GameStoreError.invalid("duplicate country ids") }
        guard gs.countries.contains(where: { $0.id == gs.playerCountryID }) else { throw GameStoreError.invalid("player country missing") }
    }
}

// MARK: - Configuration (non-secret; overridable in Settings)

/// Where the Games DB lives. Non-secret, stored in UserDefaults like any other preference.
/// The password never lives here: it comes from the Keychain (`GameStoreCredentials`).
struct GameStoreConfig: Equatable, Sendable {
    var enabled: Bool
    var host: String
    var port: Int
    /// Name the server certificate is verified against (verify-full). The cert's SANs are
    /// `games-pg`, `nova-core3`, `192.168.1.5`; NIO can't verify an IP literal, so we connect to `host`
    /// and verify against this DNS name.
    var tlsServerName: String
    var database: String
    var user: String
    var ownerUser: String
    /// Every game row is scoped by this id (one player today; the column keeps room for more).
    var playerID: String

    static let defaults = GameStoreConfig(enabled: true, host: "192.168.1.5", port: 5433, tlsServerName: "nova-core3",
                                          database: "games", user: "gtnw", ownerUser: "gtnw_owner", playerID: "default")

    static let keyPrefix = "GTNW.store."

    static func load(_ d: UserDefaults = .standard) -> GameStoreConfig {
        var c = defaults
        if let v = d.object(forKey: keyPrefix + "enabled") as? Bool { c.enabled = v }
        if let v = d.string(forKey: keyPrefix + "host"), !v.isEmpty { c.host = v }
        if let v = d.object(forKey: keyPrefix + "port") as? Int { c.port = v }
        if let v = d.string(forKey: keyPrefix + "tlsServerName"), !v.isEmpty { c.tlsServerName = v }
        return c
    }

    func save(_ d: UserDefaults = .standard) {
        d.set(enabled, forKey: Self.keyPrefix + "enabled")
        d.set(host, forKey: Self.keyPrefix + "host")
        d.set(port, forKey: Self.keyPrefix + "port")
        d.set(tlsServerName, forKey: Self.keyPrefix + "tlsServerName")
    }

    /// Reject anything that isn't a plain host name / IP, a sane port, or that points at Nova's own DB.
    func validate() throws {
        let hostOK = { (h: String) in
            !h.isEmpty && h.count <= 253 && h.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }
        }
        guard hostOK(host), hostOK(tlsServerName) else { throw GameStoreError.notConfigured("invalid host name") }
        guard (1...65535).contains(port) else { throw GameStoreError.notConfigured("invalid port") }
        guard database == "games", StoreValidation.isIdentifier(user), StoreValidation.isIdentifier(ownerUser),
              StoreValidation.isIdentifier(playerID) else { throw GameStoreError.notConfigured("invalid database/role") }
    }
}

// MARK: - Credentials (Keychain only)

/// Where passwords come from. Production: the app's Data Protection keychain. Tests: a stub.
/// Never UserDefaults, files or logs.
protocol GameStoreCredentials: Sendable {
    func password(account: String) -> String?
}

/// The Games DB passwords in GTNW's own **Data Protection keychain** (`kSecUseDataProtectionKeychain`, service
/// `nova-games-pg`, account = role name), per NovaGames CONTRACT §11. Items there are bound to the team-signed app
/// (keychain-access-groups entitlement), so rebuilds never put up a "wants to use your keychain" dialog. The login
/// keychain is never read. The password gets there once, through `GameStoreSetup` (first-launch setup in
/// Settings › Saves & DB).
struct KeychainGameStoreCredentials: GameStoreCredentials {
    static let service = "nova-games-pg"
    let service: String

    init(service: String = KeychainGameStoreCredentials.service) { self.service = service }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecUseDataProtectionKeychain as String: true,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func password(account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data, let pw = String(data: data, encoding: .utf8), !pw.isEmpty else { return nil }
        return pw
    }

    /// Store (or replace) a password. Throws the OSStatus as `notConfigured` text, never the value.
    func store(_ password: String, account: String) throws {
        guard GameStoreSetup.isPlausiblePassword(password) else { throw GameStoreError.invalid("password format") }
        let data = Data(password.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        var st = SecItemUpdate(query(account) as CFDictionary, update as CFDictionary)
        if st == errSecItemNotFound {
            var add = query(account)
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            add[kSecAttrLabel as String] = "GTNW Games DB (\(account))"
            st = SecItemAdd(add as CFDictionary, nil)
        }
        guard st == errSecSuccess else {
            throw GameStoreError.notConfigured(st == errSecMissingEntitlement
                ? "this build has no keychain entitlement (unsigned build)" : "Keychain error \(st)")
        }
    }

    func remove(account: String) { SecItemDelete(query(account) as CFDictionary) }
}

/// One-time credential hand-off (CONTRACT §11): fetch the role passwords from core3 over SSH
/// (`remote.sh getpw <role>`, BatchMode so it can never prompt), or accept a pasted one
/// (`deploy/deploy.sh macpw gtnw | pbcopy`). Values go straight into the Keychain; nothing is printed or logged.
enum GameStoreSetup {
    static let sshTarget = "kochj@192.168.1.5"
    static let remoteCommand = "sudo bash /srv/games/repo/deploy/remote.sh getpw"

    /// One line, printable ASCII, no spaces, 8...256 chars.
    static func isPlausiblePassword(_ s: String) -> Bool {
        (8...256).contains(s.count) && s.allSatisfy { $0.isASCII && !$0.isWhitespace && !$0.isNewline && ($0.asciiValue ?? 0) >= 0x21 }
    }

    /// Normalise SSH / clipboard output: strip one trailing newline and surrounding whitespace.
    static func clean(_ raw: String) -> String { raw.trimmingCharacters(in: .whitespacesAndNewlines) }

    #if os(macOS)
    /// Runs `ssh -o BatchMode=yes <target> sudo bash …/remote.sh getpw <role>` and stores the result.
    /// Roles are restricted to the two GTNW roles. Returns the roles stored.
    @discardableResult
    static func fetchFromCore3(roles: [String] = [GameStoreConfig.defaults.user, GameStoreConfig.defaults.ownerUser],
                               credentials: KeychainGameStoreCredentials = KeychainGameStoreCredentials(),
                               timeout: TimeInterval = 20) throws -> [String] {
        var stored: [String] = []
        for role in roles {
            guard role == "gtnw" || role == "gtnw_owner" else { throw GameStoreError.invalid("role") }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            p.arguments = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8", sshTarget, "\(remoteCommand) \(role)"]
            let out = Pipe(), err = Pipe()
            p.standardOutput = out; p.standardError = err; p.standardInput = FileHandle.nullDevice
            try p.run()
            let deadline = Date().addingTimeInterval(timeout)
            while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
            if p.isRunning { p.terminate(); throw GameStoreError.unreachable("ssh to core3 timed out") }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            guard p.terminationStatus == 0, data.count <= 1024 else {
                throw GameStoreError.notConfigured("ssh getpw \(role) failed (exit \(p.terminationStatus))")
            }
            let pw = clean(String(decoding: data, as: UTF8.self))
            guard isPlausiblePassword(pw) else { throw GameStoreError.notConfigured("getpw \(role) returned no usable password") }
            try credentials.store(pw, account: role)
            stored.append(role)
        }
        return stored
    }
    #endif
}
