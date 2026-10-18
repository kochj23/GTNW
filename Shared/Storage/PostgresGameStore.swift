//
//  PostgresGameStore.swift
//  Global Thermal Nuclear War
//
//  `GameStore` on the dedicated Nova Games Postgres (NOT Nova's nova_ops): database `games`, schema `gtnw`,
//  app role `gtnw` (DML only), migrations run as `gtnw_owner`. SCRAM auth, TLS required with the games-pg CA
//  pinned and the server name verified (verify-full). Every value is a bound parameter; the only SQL text
//  built here is the fixed statements in this file.
//

import Foundation
import PostgresNIO

// MARK: - Migrations

/// Versioned DDL for schema `gtnw`. Append new versions; never edit an applied one.
enum GameStoreMigrations {
    struct Migration {
        let version: Int
        let name: String
        let statements: [String]
    }

    static let schema = "gtnw"
    static var latestVersion: Int { all.map(\.version).max() ?? 0 }

    static let createLedger = """
        CREATE TABLE IF NOT EXISTS gtnw.schema_migrations (
            version    integer PRIMARY KEY CHECK (version > 0),
            name       text NOT NULL CHECK (char_length(name) <= 100),
            applied_at timestamptz NOT NULL DEFAULT now()
        )
        """

    private static let playerCheck = "CHECK (player_id ~ '^[A-Za-z0-9_.-]{1,64}$')"

    static let all: [Migration] = [
        Migration(version: 1, name: "initial: save slots, leaderboard, history, scenario progress, achievements", statements: [
            """
            CREATE TABLE gtnw.save_slots (
                player_id      text NOT NULL \(playerCheck),
                slot           smallint NOT NULL CHECK (slot BETWEEN 0 AND 5),
                schema_version integer NOT NULL CHECK (schema_version BETWEEN 1 AND 1000),
                payload        bytea NOT NULL CHECK (octet_length(payload) BETWEEN 1 AND 8388608),
                payload_sha256 bytea NOT NULL CHECK (octet_length(payload_sha256) = 32),
                label          text NOT NULL DEFAULT '' CHECK (char_length(label) <= 200),
                game_turn      integer NOT NULL CHECK (game_turn BETWEEN 0 AND 1000000),
                updated_at     timestamptz NOT NULL,
                PRIMARY KEY (player_id, slot)
            )
            """,
            """
            CREATE TABLE gtnw.leaderboard (
                id                    uuid PRIMARY KEY,
                player_id             text NOT NULL \(playerCheck),
                player_name           text NOT NULL CHECK (char_length(player_name) <= 64),
                final_score           integer NOT NULL CHECK (final_score BETWEEN 0 AND 100000000),
                base_score            integer NOT NULL CHECK (base_score BETWEEN -100000000 AND 100000000),
                turns_played          integer NOT NULL CHECK (turns_played BETWEEN 0 AND 1000000),
                nuclear_virgin        boolean NOT NULL,
                difficulty_multiplier double precision NOT NULL CHECK (difficulty_multiplier BETWEEN 0 AND 100),
                victory_type          text CHECK (char_length(victory_type) <= 64),
                player_country        text NOT NULL CHECK (char_length(player_country) <= 8),
                achieved_at           timestamptz NOT NULL,
                created_at            timestamptz NOT NULL DEFAULT now()
            )
            """,
            "CREATE INDEX leaderboard_player_score_idx ON gtnw.leaderboard (player_id, final_score DESC, achieved_at)",
            """
            CREATE TABLE gtnw.game_history (
                id              uuid PRIMARY KEY,
                player_id       text NOT NULL \(playerCheck),
                scenario_id     text NOT NULL CHECK (scenario_id ~ '^[A-Za-z0-9_.-]{1,64}$'),
                player_country  text NOT NULL CHECK (char_length(player_country) <= 8),
                won             boolean NOT NULL,
                victory_type    text CHECK (char_length(victory_type) <= 64),
                reason          text NOT NULL CHECK (char_length(reason) <= 500),
                final_score     integer NOT NULL CHECK (final_score BETWEEN 0 AND 100000000),
                turns           integer NOT NULL CHECK (turns BETWEEN 0 AND 1000000),
                game_date       text NOT NULL CHECK (char_length(game_date) <= 64),
                casualties      bigint NOT NULL CHECK (casualties >= 0),
                nuclear_strikes integer NOT NULL CHECK (nuclear_strikes >= 0),
                ended_at        timestamptz NOT NULL,
                created_at      timestamptz NOT NULL DEFAULT now()
            )
            """,
            "CREATE INDEX game_history_player_ended_idx ON gtnw.game_history (player_id, ended_at DESC)",
            "CREATE INDEX game_history_player_scenario_idx ON gtnw.game_history (player_id, scenario_id)",
            """
            CREATE TABLE gtnw.scenario_progress (
                player_id      text NOT NULL \(playerCheck),
                scenario_id    text NOT NULL CHECK (scenario_id ~ '^[A-Za-z0-9_.-]{1,64}$'),
                plays          integer NOT NULL CHECK (plays >= 1),
                wins           integer NOT NULL CHECK (wins BETWEEN 0 AND plays),
                best_score     integer NOT NULL CHECK (best_score >= 0),
                last_won       boolean NOT NULL,
                last_played_at timestamptz NOT NULL,
                PRIMARY KEY (player_id, scenario_id)
            )
            """,
            """
            CREATE TABLE gtnw.achievements (
                player_id      text NOT NULL \(playerCheck),
                achievement_id text NOT NULL CHECK (achievement_id ~ '^[A-Za-z0-9_.-]{1,64}$'),
                unlocked_at    timestamptz NOT NULL,
                PRIMARY KEY (player_id, achievement_id)
            )
            """,
        ]),
    ]
}

// MARK: - Store

actor PostgresGameStore: GameStore {
    let config: GameStoreConfig
    private let credentials: GameStoreCredentials
    private let caPEM: Data
    private var connection: PostgresConnection?
    private var schemaReady = false
    private var nextConnectionID = 1
    private let logger: Logger = {
        var l = Logger(label: "gtnw.gamestore")
        l.logLevel = .critical   // never log queries or bound values
        return l
    }()

    /// - Parameters:
    ///   - caPEM: the games-pg CA certificate (PEM). Only server certs issued by it are accepted.
    init(config: GameStoreConfig, credentials: GameStoreCredentials, caPEM: Data) {
        self.config = config
        self.credentials = credentials
        self.caPEM = caPEM
    }

    deinit {
        let c = connection
        Task { try? await c?.close() }
    }

    // MARK: Connection

    private func makeConfiguration(user: String) throws -> PostgresConnection.Configuration {
        try config.validate()
        guard let password = credentials.password(account: user) else {
            throw GameStoreError.notConfigured("DB credentials not set up yet (Settings › Saves & DB)")
        }
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.minimumTLSVersion = .tlsv12
        tls.certificateVerification = .fullVerification
        do {
            tls.trustRoots = .certificates(try NIOSSLCertificate.fromPEMBytes(Array(caPEM)))
        } catch {
            throw GameStoreError.notConfigured("games-pg CA certificate is not valid PEM")
        }
        let context: NIOSSLContext
        do { context = try NIOSSLContext(configuration: tls) } catch { throw GameStoreError.notConfigured("TLS setup failed") }
        var pg = PostgresConnection.Configuration(host: config.host, port: config.port, username: user,
                                                  password: password, database: config.database, tls: .require(context))
        pg.options.tlsServerName = config.tlsServerName
        pg.options.connectTimeout = .seconds(5)
        return pg
    }

    private func connect(user: String) async throws -> PostgresConnection {
        let pg = try makeConfiguration(user: user)
        nextConnectionID += 1
        do {
            return try await PostgresConnection.connect(configuration: pg, id: nextConnectionID, logger: logger)
        } catch {
            throw Self.map(error)
        }
    }

    /// Run `body` on a live, schema-checked app connection. Any failure drops the connection so the next call reconnects.
    @discardableResult
    private func withConnection<T>(_ body: (PostgresConnection) async throws -> T) async throws -> T {
        do {
            let conn: PostgresConnection
            if let c = connection, !c.isClosed { conn = c } else {
                conn = try await connect(user: config.user)
                connection = conn
                schemaReady = false
            }
            if !schemaReady { try await ensureSchema(conn) }
            return try await body(conn)
        } catch {
            let mapped = Self.map(error)
            if case .invalid = mapped {} else { await dropConnection() }
            throw mapped
        }
    }

    func dropConnection() async {
        let c = connection
        connection = nil
        schemaReady = false
        try? await c?.close()
    }

    // MARK: Schema

    func schemaVersion() async throws -> Int {
        try await withConnection { try await self.readVersion($0) }
    }

    private func readVersion(_ conn: PostgresConnection) async throws -> Int {
        let rows = try await conn.query("SELECT coalesce(max(version), 0)::integer FROM gtnw.schema_migrations", logger: logger)
        for try await v in rows.decode(Int.self) { return v }
        return 0
    }

    /// Check the schema is at `latestVersion`; if it isn't and the owner password is in the Keychain, migrate.
    private func ensureSchema(_ conn: PostgresConnection) async throws {
        let have = (try? await readVersion(conn)) ?? 0
        if have < GameStoreMigrations.latestVersion {
            guard credentials.password(account: config.ownerUser) != nil else {
                throw GameStoreError.schemaNotReady("schema gtnw is at v\(have), need v\(GameStoreMigrations.latestVersion); no owner credentials to migrate")
            }
            try await migrate()
            guard try await readVersion(conn) >= GameStoreMigrations.latestVersion else {
                throw GameStoreError.schemaNotReady("migration did not reach v\(GameStoreMigrations.latestVersion)")
            }
        }
        schemaReady = true
    }

    /// Apply missing migrations as the owner role, one transaction per version, serialized by an advisory lock.
    @discardableResult
    func migrate() async throws -> [Int] {
        let owner = try await connect(user: config.ownerUser)
        defer { Task { try? await owner.close() } }
        do {
            try await owner.query("SELECT pg_advisory_lock(hashtext('gtnw.schema_migrations'))", logger: logger)
            try await owner.query(PostgresQuery(unsafeSQL: GameStoreMigrations.createLedger), logger: logger)
            var applied = Set<Int>()
            for try await v in try await owner.query("SELECT version FROM gtnw.schema_migrations", logger: logger).decode(Int.self) {
                applied.insert(v)
            }
            var ran: [Int] = []
            for m in GameStoreMigrations.all.sorted(by: { $0.version < $1.version }) where !applied.contains(m.version) {
                try await owner.withTransaction(logger: logger) { tx in
                    for statement in m.statements {
                        try await tx.query(PostgresQuery(unsafeSQL: statement), logger: self.logger)
                    }
                    try await tx.query("INSERT INTO gtnw.schema_migrations (version, name) VALUES (\(m.version), \(m.name))", logger: self.logger)
                }
                ran.append(m.version)
            }
            try await owner.query("SELECT pg_advisory_unlock(hashtext('gtnw.schema_migrations'))", logger: logger)
            return ran
        } catch {
            throw Self.map(error)
        }
    }

    // MARK: Slots

    func putSlot(_ r: SaveRecord) async throws {
        try StoreValidation.check(r)
        let player = config.playerID, slot = Int16(r.slot), sha = r.sha256
        try await withConnection { conn in
            try await conn.query("""
                INSERT INTO gtnw.save_slots (player_id, slot, schema_version, payload, payload_sha256, label, game_turn, updated_at)
                VALUES (\(player), \(slot), \(r.schemaVersion), \(r.payload), \(sha), \(r.label), \(r.turn), \(r.updatedAt))
                ON CONFLICT (player_id, slot) DO UPDATE SET
                    schema_version = EXCLUDED.schema_version, payload = EXCLUDED.payload,
                    payload_sha256 = EXCLUDED.payload_sha256, label = EXCLUDED.label,
                    game_turn = EXCLUDED.game_turn, updated_at = EXCLUDED.updated_at
                WHERE gtnw.save_slots.updated_at <= EXCLUDED.updated_at
                """, logger: self.logger)
        }
    }

    func getSlot(_ slot: Int) async throws -> SaveRecord? {
        let player = config.playerID, s = Int16(clamping: slot)
        return try await withConnection { conn in
            let rows = try await conn.query("""
                SELECT schema_version, payload, payload_sha256, label, game_turn, updated_at
                FROM gtnw.save_slots WHERE player_id = \(player) AND slot = \(s)
                """, logger: self.logger)
            for try await (version, payload, sha, label, turn, updated) in rows.decode((Int, Data, Data, String, Int, Date).self) {
                let r = SaveRecord(slot: slot, schemaVersion: version, payload: payload, label: label, turn: turn, updatedAt: updated)
                guard r.sha256 == sha else { throw GameStoreError.invalid("slot \(slot) checksum mismatch") }
                try StoreValidation.check(r)
                return r
            }
            return nil
        }
    }

    func listSlots() async throws -> [SlotSummary] {
        let player = config.playerID
        return try await withConnection { conn in
            let rows = try await conn.query("""
                SELECT slot::integer, label, game_turn, schema_version, octet_length(payload), updated_at
                FROM gtnw.save_slots WHERE player_id = \(player) ORDER BY slot
                """, logger: self.logger)
            var out: [SlotSummary] = []
            for try await (slot, label, turn, version, size, updated) in rows.decode((Int, String, Int, Int, Int, Date).self) {
                out.append(SlotSummary(slot: slot, label: label, turn: turn, schemaVersion: version, size: size, updatedAt: updated))
            }
            return out
        }
    }

    func deleteSlot(_ slot: Int) async throws {
        let player = config.playerID, s = Int16(clamping: slot)
        try await withConnection { conn in
            try await conn.query("DELETE FROM gtnw.save_slots WHERE player_id = \(player) AND slot = \(s)", logger: self.logger)
        }
    }

    // MARK: Leaderboard

    func addLeaderboard(_ r: LeaderboardRecord) async throws {
        try StoreValidation.check(r)
        let player = config.playerID
        try await withConnection { conn in
            try await conn.query("""
                INSERT INTO gtnw.leaderboard (id, player_id, player_name, final_score, base_score, turns_played, nuclear_virgin,
                                              difficulty_multiplier, victory_type, player_country, achieved_at)
                VALUES (\(r.id), \(player), \(r.playerName), \(r.finalScore), \(r.baseScore), \(r.turnsPlayed), \(r.nuclearVirgin),
                        \(r.difficultyMultiplier), \(r.victoryType), \(r.playerCountry), \(r.achievedAt))
                ON CONFLICT (id) DO NOTHING
                """, logger: self.logger)
        }
    }

    func leaderboard(limit: Int) async throws -> [LeaderboardRecord] {
        let player = config.playerID, lim = max(0, min(limit, 1000))
        return try await withConnection { conn in
            let rows = try await conn.query("""
                SELECT id, player_name, final_score, base_score, turns_played, nuclear_virgin, difficulty_multiplier,
                       victory_type, player_country, achieved_at
                FROM gtnw.leaderboard WHERE player_id = \(player)
                ORDER BY final_score DESC, achieved_at ASC LIMIT \(lim)
                """, logger: self.logger)
            var out: [LeaderboardRecord] = []
            for try await (id, name, score, base, turns, virgin, mult, victory, country, at)
                    in rows.decode((UUID, String, Int, Int, Int, Bool, Double, String?, String, Date).self) {
                out.append(LeaderboardRecord(id: id, playerName: name, finalScore: score, baseScore: base, turnsPlayed: turns,
                                             nuclearVirgin: virgin, difficultyMultiplier: mult, victoryType: victory,
                                             playerCountry: country, achievedAt: at))
            }
            return out
        }
    }

    // MARK: History + scenario progress

    func addResult(_ r: GameResultRecord) async throws {
        try StoreValidation.check(r)
        let player = config.playerID
        try await withConnection { conn in
            try await conn.withTransaction(logger: self.logger) { tx in
                let inserted = try await tx.query("""
                    INSERT INTO gtnw.game_history (id, player_id, scenario_id, player_country, won, victory_type, reason,
                                                   final_score, turns, game_date, casualties, nuclear_strikes, ended_at)
                    VALUES (\(r.id), \(player), \(r.scenarioID), \(r.playerCountry), \(r.won), \(r.victoryType), \(r.reason),
                            \(r.finalScore), \(r.turns), \(r.gameDate), \(r.casualties), \(r.nuclearStrikes), \(r.endedAt))
                    ON CONFLICT (id) DO NOTHING
                    RETURNING id
                    """, logger: self.logger)
                var isNew = false
                for try await _ in inserted.decode(UUID.self) { isNew = true }
                guard isNew else { return }   // replay of a result we already counted
                let wins = r.won ? 1 : 0
                try await tx.query("""
                    INSERT INTO gtnw.scenario_progress (player_id, scenario_id, plays, wins, best_score, last_won, last_played_at)
                    VALUES (\(player), \(r.scenarioID), 1, \(wins), \(r.finalScore), \(r.won), \(r.endedAt))
                    ON CONFLICT (player_id, scenario_id) DO UPDATE SET
                        plays = gtnw.scenario_progress.plays + 1,
                        wins = gtnw.scenario_progress.wins + EXCLUDED.wins,
                        best_score = GREATEST(gtnw.scenario_progress.best_score, EXCLUDED.best_score),
                        last_won = EXCLUDED.last_won,
                        last_played_at = GREATEST(gtnw.scenario_progress.last_played_at, EXCLUDED.last_played_at)
                    """, logger: self.logger)
            }
        }
    }

    func history(limit: Int) async throws -> [GameResultRecord] {
        let player = config.playerID, lim = max(0, min(limit, 1000))
        return try await withConnection { conn in
            let rows = try await conn.query("""
                SELECT id, scenario_id, player_country, won, victory_type, reason, final_score, turns, game_date,
                       casualties, nuclear_strikes, ended_at
                FROM gtnw.game_history WHERE player_id = \(player) ORDER BY ended_at DESC LIMIT \(lim)
                """, logger: self.logger)
            var out: [GameResultRecord] = []
            for try await (id, scenario, country, won, victory, reason, score, turns, date, casualties, strikes, ended)
                    in rows.decode((UUID, String, String, Bool, String?, String, Int, Int, String, Int64, Int, Date).self) {
                out.append(GameResultRecord(id: id, scenarioID: scenario, playerCountry: country, won: won, victoryType: victory,
                                            reason: reason, finalScore: score, turns: turns, gameDate: date, casualties: casualties,
                                            nuclearStrikes: strikes, endedAt: ended))
            }
            return out
        }
    }

    func scenarioProgress() async throws -> [ScenarioProgress] {
        let player = config.playerID
        return try await withConnection { conn in
            let rows = try await conn.query("""
                SELECT scenario_id, plays, wins, best_score, last_won, last_played_at
                FROM gtnw.scenario_progress WHERE player_id = \(player) ORDER BY scenario_id
                """, logger: self.logger)
            var out: [ScenarioProgress] = []
            for try await (id, plays, wins, best, lastWon, at) in rows.decode((String, Int, Int, Int, Bool, Date).self) {
                out.append(ScenarioProgress(scenarioID: id, plays: plays, wins: wins, bestScore: best, lastWon: lastWon, lastPlayedAt: at))
            }
            return out
        }
    }

    // MARK: Achievements

    func unlock(_ a: AchievementRecord) async throws {
        try StoreValidation.check(a)
        let player = config.playerID
        try await withConnection { conn in
            try await conn.query("""
                INSERT INTO gtnw.achievements (player_id, achievement_id, unlocked_at) VALUES (\(player), \(a.id), \(a.unlockedAt))
                ON CONFLICT (player_id, achievement_id) DO UPDATE SET unlocked_at = LEAST(gtnw.achievements.unlocked_at, EXCLUDED.unlocked_at)
                """, logger: self.logger)
        }
    }

    func achievements() async throws -> [AchievementRecord] {
        let player = config.playerID
        return try await withConnection { conn in
            let rows = try await conn.query("""
                SELECT achievement_id, unlocked_at FROM gtnw.achievements WHERE player_id = \(player) ORDER BY achievement_id
                """, logger: self.logger)
            var out: [AchievementRecord] = []
            for try await (id, at) in rows.decode((String, Date).self) { out.append(AchievementRecord(id: id, unlockedAt: at)) }
            return out
        }
    }

    // MARK: Play history (schema `play`, shared by every Nova game; RLS keeps us to rows written as `gtnw`)

    func upsertPlaySession(_ r: PlaySessionRecord) async throws {
        try StoreValidation.check(r)
        let player = config.playerID, game = PlayHistory.game, summary = String(decoding: r.summary, as: UTF8.self)
        try await withConnection { conn in
            try await conn.query("""
                INSERT INTO play.sessions (id, game, client, player, started_at, last_seen_at, ended_at, outcome, score, actions, summary)
                VALUES (\(r.id), \(game), \(r.client), \(player), \(r.startedAt), \(r.lastSeenAt), \(r.endedAt), \(r.outcome),
                        \(r.score), \(r.actions), \(summary)::jsonb)
                ON CONFLICT (id) DO UPDATE SET
                    last_seen_at = GREATEST(play.sessions.last_seen_at, EXCLUDED.last_seen_at),
                    actions = GREATEST(play.sessions.actions, EXCLUDED.actions),
                    ended_at = EXCLUDED.ended_at, outcome = EXCLUDED.outcome, score = EXCLUDED.score,
                    summary = EXCLUDED.summary
                WHERE play.sessions.ended_at IS NULL
                """, logger: self.logger)
        }
    }

    func addPlayEvent(_ e: PlayEventRecord) async throws {
        try StoreValidation.check(e)
        let detail = String(decoding: e.detail, as: UTF8.self)
        try await withConnection { conn in
            try await conn.query("""
                INSERT INTO play.events (session_id, seq, ts, kind, detail)
                VALUES (\(e.sessionID), \(e.seq), \(e.ts), \(e.kind), \(detail)::jsonb)
                ON CONFLICT (session_id, seq) DO NOTHING
                """, logger: self.logger)
        }
    }

    func counts() async throws -> StoreCounts {
        let player = config.playerID
        return try await withConnection { conn in
            let rows = try await conn.query("""
                SELECT (SELECT count(*) FROM gtnw.save_slots WHERE player_id = \(player))::integer,
                       (SELECT count(*) FROM gtnw.leaderboard WHERE player_id = \(player))::integer,
                       (SELECT count(*) FROM gtnw.game_history WHERE player_id = \(player))::integer,
                       (SELECT count(*) FROM gtnw.scenario_progress WHERE player_id = \(player))::integer,
                       (SELECT count(*) FROM gtnw.achievements WHERE player_id = \(player))::integer
                """, logger: self.logger)
            for try await (s, l, h, p, a) in rows.decode((Int, Int, Int, Int, Int).self) {
                return StoreCounts(slots: s, leaderboard: l, history: h, scenarios: p, achievements: a)
            }
            return StoreCounts()
        }
    }

    // MARK: Error mapping (never includes passwords, queries or bound values)

    static func map(_ error: Error) -> GameStoreError {
        if let e = error as? GameStoreError { return e }
        if let tx = error as? PostgresTransactionError {
            if let inner = tx.closureError ?? tx.commitError ?? tx.beginError { return map(inner) }
            return .unreachable("transaction failed")
        }
        if let p = error as? PSQLError {
            if p.code == .server {
                let state = p.serverInfo?[.sqlState] ?? ""
                if state.hasPrefix("23") || state.hasPrefix("22") { return .invalid("rejected by the database (\(state))") }
                if ["42P01", "3F000", "42501", "42703"].contains(state) { return .schemaNotReady("database said \(state)") }
                if state.hasPrefix("28") { return .notConfigured("authentication failed (\(state))") }
                return .unreachable("server error \(state)")
            }
            if p.code == .saslError || p.code == .unsupportedAuthMechanism { return .notConfigured("authentication failed") }
            return .unreachable("\(p.code)")
        }
        return .unreachable(String(describing: type(of: error)))
    }
}
