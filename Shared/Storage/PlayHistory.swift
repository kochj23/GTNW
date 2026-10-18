//
//  PlayHistory.swift
//  Global Thermal Nuclear War
//
//  Play-session logging for Nova's game reporter: one `play.sessions` row per sitting (new game, scenario, or a
//  loaded save) and a few `play.events` (game start, urgent ticker items, nuclear strikes, game over) in the
//  Nova Games DB, schema `play` (NovaGames deploy/db/play.sql). Rides the store's offline-first queue, so it never
//  blocks or slows a turn, retries with the same backoff, and drops anything the DB rejects.
//  The finished game's `gtnw.game_history` row uses the session id, so the two join.
//

import Foundation

// MARK: - Records

/// One play session as written to `play.sessions` (game `gtnw`, player = the store's player id).
struct PlaySessionRecord: Codable, Equatable, Sendable {
    var id: UUID
    var client: String
    var startedAt: Date
    var lastSeenAt: Date
    var endedAt: Date?
    var outcome: String?
    var score: Double?
    /// Turns played this session.
    var actions: Int
    /// A JSON object (the GTNW summary keys of the play contract).
    var summary: Data
}

/// One notable moment, `play.events` (session_id, seq) is the idempotency key.
struct PlayEventRecord: Codable, Equatable, Sendable {
    var sessionID: UUID
    var seq: Int
    var ts: Date
    var kind: String
    /// A JSON object, at most 4 KB.
    var detail: Data
}

enum PlayHistory {
    static let game = "gtnw"
    #if os(macOS)
    static let client = "mac"
    #else
    static let client = "ios"
    #endif
    static let maxSummaryBytes = 64 * 1024
    static let maxDetailBytes = 4 * 1024
    static let maxActions = 10_000_000
    static let maxSeq = 10_000_000
    /// Ticker items at or above this severity become events (2 urgent, 3 flash).
    static let eventTickerSeverity = 2
    static let maxText = 300

    /// `yyyy-MM-dd` in the game calendar's time zone.
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = GameCalendar.calendar
        f.timeZone = GameCalendar.calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func day(_ d: Date) -> String { dayFormatter.string(from: d) }

    static func text(_ s: String) -> String { StoreValidation.clean(s, max: maxText) }

    /// JSON-safe number (NaN / infinity would make JSONSerialization raise).
    static func num(_ d: Double, places: Double = 10) -> Double { d.isFinite ? (d * places).rounded() / places : 0 }

    /// Serialize a JSON object, or nil if it isn't one (never raises).
    static func json(_ object: [String: Any]) -> Data? {
        guard JSONSerialization.isValidJSONObject(object) else { return nil }
        return try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// Re-read an Encodable as a plain JSON value (budget, aid vectors).
    static func plain<T: Encodable>(_ value: T) -> Any? {
        guard let d = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: d)
    }

    static func isKind(_ s: String) -> Bool {
        guard let first = s.unicodeScalars.first, s.unicodeScalars.count <= 48 else { return false }
        let lower = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
        let rest = lower.union(CharacterSet(charactersIn: "_.-"))
        return lower.contains(first) && s.unicodeScalars.allSatisfy { rest.contains($0) }
    }

    static func isJSONObject(_ d: Data, max: Int) -> Bool {
        !d.isEmpty && d.count <= max && (try? JSONSerialization.jsonObject(with: d)) is [String: Any]
    }
}

// MARK: - Validation (mirrors the CHECK constraints in play.sql)

extension StoreValidation {
    static func check(_ s: PlaySessionRecord) throws {
        guard PlayHistory.isKind(s.client), s.client.count <= 32,
              s.lastSeenAt >= s.startedAt, (s.endedAt.map { $0 >= s.startedAt } ?? true),
              (s.outcome?.count ?? 0) <= 64,
              (s.score.map { $0.isFinite && abs($0) <= 1e12 } ?? true),
              (0...PlayHistory.maxActions).contains(s.actions),
              PlayHistory.isJSONObject(s.summary, max: PlayHistory.maxSummaryBytes)
        else { throw GameStoreError.invalid("play session out of bounds") }
    }

    static func check(_ e: PlayEventRecord) throws {
        guard (0...PlayHistory.maxSeq).contains(e.seq), PlayHistory.isKind(e.kind),
              PlayHistory.isJSONObject(e.detail, max: PlayHistory.maxDetailBytes)
        else { throw GameStoreError.invalid("play event out of bounds") }
    }
}

// MARK: - Summary (GTNW summary keys of the play contract)

enum PlaySummary {
    struct Session {
        var id: UUID
        var startTurn: Int
        var resumedFromTurn: Int?
        var gameDateAtStart: String
    }

    /// Everything the reporter may quote about this session, from the game as it stands now.
    /// `score`/`victory` are set at game over (`historyID` = the game_history row).
    static func build(_ gs: GameState, session: Session, score: GameScore? = nil, victory: VictoryType? = nil,
                      historyID: UUID? = nil) -> Data {
        let sh = gs.shadow
        let player = gs.getPlayerCountry()
        let polls = sh.polls.map(\.popularity).filter(\.isFinite)
        var s: [String: Any] = [
            "scenario": sh.scenarioID.flatMap { StoreValidation.isIdentifier($0) ? $0 : nil } ?? "sandbox",
            "country": String(gs.playerCountryID.prefix(8)),
            "difficulty": gs.difficultyLevel.rawValue,
            "turn_length": gs.turnLength.rawValue,
            "game_date_start": GameCalendar.format(gs.startDate),
            "game_date_end": gs.currentDateLabel,
            "session_game_date_start": session.gameDateAtStart,
            "turns": gs.turn,
            "turns_this_session": max(0, gs.turn - session.startTurn),
            "casualties": max(0, gs.totalCasualties),
            "nuclear_strikes": gs.nuclearStrikes.count,
            "warheads_launched": gs.totalWarheadsLaunched,
            "wars_started": gs.warsStarted,
            "wars_won": gs.warsWon,
            "covert_ops_succeeded": gs.successfulCovertOps,
            "conflicts_mediated": gs.conflictsMediated,
            "sanctions_imposed": gs.sanctionsImposed,
            "defcon": gs.defconLevel.rawValue,
            "global_radiation": gs.globalRadiation,
            "impeachment_stage": sh.impeachmentStage,
            "terms_won": sh.termsWon,
            "popularity_end": PlayHistory.num(sh.popularity),
            "in_progress": !gs.gameOver,
        ]
        if let r = session.resumedFromTurn { s["resumed_from_turn"] = r }
        if let p = sh.startSnapshot?.popularity ?? polls.first { s["popularity_start"] = PlayHistory.num(p) }
        if let peak = (polls + [sh.popularity]).filter(\.isFinite).max() { s["popularity_peak"] = PlayHistory.num(peak) }
        if let player {
            s["congressional_support"] = player.congressionalSupport
            s["war_support"] = player.warSupport
        }
        if gs.gameOver {
            s["won"] = victory != nil
            s["reason"] = StoreValidation.clean(gs.gameOverReason, max: StoreValidation.maxReasonLength)
            if let victory { s["victory_type"] = victory.rawValue }
        }
        if let score {
            s["final_score"] = score.finalScore
            s["base_score"] = score.baseScore
        }
        if let historyID { s["history_id"] = historyID.uuidString.lowercased() }
        if let b = PlayHistory.plain(sh.budget) { s["budget"] = b }
        if !sh.aidSent.isEmpty, let a = PlayHistory.plain(sh.aidSent) { s["aid_sent_billions"] = a }
        s["fronts"] = sh.fronts.suffix(40).map {
            ["attacker": $0.attacker, "defender": $0.defender, "status": $0.status.rawValue, "battles": $0.battles] as [String: Any]
        }
        s["strikes"] = gs.nuclearStrikes.suffix(60).map {
            ["turn": $0.turn, "attacker": $0.attacker, "target": $0.target, "warheads": $0.warheadsUsed,
             "casualties": $0.casualties] as [String: Any]
        }
        // The narrative lists, longest first to go if the whole thing would be over the 64 KB cap.
        var polls60 = Array(sh.polls.suffix(60)), ticker60 = Array(sh.ticker.filter { $0.severity >= 1 }.suffix(60))
        var log40 = Array(sh.warLog.suffix(40))
        while true {
            s["polls"] = polls60.map { ["date": PlayHistory.day($0.date), "popularity": PlayHistory.num($0.popularity)] as [String: Any] }
            s["ticker"] = ticker60.map {
                ["date": PlayHistory.day($0.date), "severity": $0.severity, "text": PlayHistory.text($0.text)] as [String: Any]
            }
            s["war_log"] = log40.map(PlayHistory.text)
            if let d = PlayHistory.json(s), d.count <= PlayHistory.maxSummaryBytes - 1024 { return d }
            if polls60.isEmpty && ticker60.isEmpty && log40.isEmpty { break }
            polls60 = Array(polls60.suffix(polls60.count / 2))
            ticker60 = Array(ticker60.suffix(ticker60.count / 2))
            log40 = Array(log40.suffix(log40.count / 2))
        }
        return PlayHistory.json(["in_progress": !gs.gameOver, "turns": gs.turn]) ?? Data("{}".utf8)
    }
}

// MARK: - Engine side

/// Bookkeeping for the current play session. The id and wall-clock start also live on the game
/// (`ShadowState.playSessionID` / `playSessionStartedAt`), so saves carry them.
final class PlaySessionTracker {
    let id: UUID
    /// The game this session is about (a new game replaces `GameEngine.gameState` before the old session closes).
    let game: GameState
    let startedAt: Date
    let startTurn: Int
    let resumedFromTurn: Int?
    let gameDateAtStart: String
    private(set) var nextSeq = 0
    /// Ticker items already logged or present when the session began.
    var seenTicker: Set<UUID>
    /// Strikes already logged or present when the session began.
    var strikesSeen: Int
    var ended = false

    init(id: UUID, startedAt: Date, gs: GameState, resumedFromTurn: Int?) {
        self.id = id
        self.game = gs
        self.startedAt = startedAt
        self.startTurn = gs.turn
        self.resumedFromTurn = resumedFromTurn
        self.gameDateAtStart = gs.currentDateLabel
        self.seenTicker = Set(gs.shadow.ticker.map(\.id))
        self.strikesSeen = gs.nuclearStrikes.count
    }

    func takeSeq() -> Int { defer { nextSeq += 1 }; return nextSeq }

    var summarySession: PlaySummary.Session {
        PlaySummary.Session(id: id, startTurn: startTurn, resumedFromTurn: resumedFromTurn, gameDateAtStart: gameDateAtStart)
    }
}

extension GameEngine {

    /// Start a play session for the game now in `gameState` (new game, scenario, or a loaded save to continue).
    /// An open session for a previous game is closed as `abandoned` first.
    func beginPlaySession(resumedFromTurn: Int? = nil, now: Date = Date()) {
        endPlaySession(outcome: "abandoned", now: now)
        guard let gs = gameState, !gs.gameOver else { playSession = nil; return }   // a finished save: nothing to play
        let id = UUID()
        gs.shadow.playSessionID = id
        gs.shadow.playSessionStartedAt = now
        let t = PlaySessionTracker(id: id, startedAt: now, gs: gs, resumedFromTurn: resumedFromTurn)
        playSession = t
        guard store?.remote != nil else { return }
        sendPlaySession(gs, t, now: now)
        var detail: [String: Any] = ["scenario": gs.shadow.scenarioID ?? "sandbox", "country": gs.playerCountryID,
                                     "difficulty": gs.difficultyLevel.rawValue, "turn_length": gs.turnLength.rawValue,
                                     "game_date": gs.currentDateLabel, "turn": gs.turn]
        if let resumedFromTurn { detail["resumed_from_turn"] = resumedFromTurn }
        sendPlayEvent(t, kind: "game_start", detail: detail, now: now)
    }

    /// End of a turn: log new urgent ticker items and nuclear strikes, bump last_seen_at / actions.
    func playSessionTurnEnded(now: Date = Date()) {
        guard let gs = gameState, let t = playSession, t.game === gs, !t.ended, !gs.gameOver else { return }
        logNewPlayEvents(gs, t, now: now)
        guard store?.remote != nil else { return }
        sendPlaySession(gs, t, now: now)
    }

    /// Game over: final events and the closing upsert. Returns the session id to use for game_history.
    @discardableResult
    func finishPlaySession(score: GameScore, victory: VictoryType?, now: Date = Date()) -> UUID? {
        guard let gs = gameState, let t = playSession, t.game === gs else { return nil }
        guard !t.ended else { return t.id }   // a replay of the same game over: same history id, logged once
        logNewPlayEvents(gs, t, now: now)
        t.ended = true
        guard store?.remote != nil else { return t.id }
        sendPlayEvent(t, kind: "game_over", detail: [
            "won": victory != nil, "victory_type": victory?.rawValue ?? "", "reason": PlayHistory.text(gs.gameOverReason),
            "turns": gs.turn, "game_date": gs.currentDateLabel, "final_score": score.finalScore,
            "casualties": max(0, gs.totalCasualties), "nuclear_strikes": gs.nuclearStrikes.count,
        ], now: now)
        sendPlaySession(gs, t, now: now, ended: (victory != nil ? "victory" : "defeat", score, victory))
        return t.id
    }

    /// Close the open session without a result (app quit, a new game started over this one).
    func endPlaySession(outcome: String, now: Date = Date()) {
        guard let t = playSession, !t.ended else { return }
        t.ended = true
        guard store?.remote != nil else { return }
        let gs = t.game
        logNewPlayEvents(gs, t, now: now)
        sendPlaySession(gs, t, now: now, closing: outcome)
    }

    // MARK: Helpers

    private func logNewPlayEvents(_ gs: GameState, _ t: PlaySessionTracker, now: Date) {
        let fresh = gs.shadow.ticker.filter { !t.seenTicker.contains($0.id) }
        t.seenTicker = Set(gs.shadow.ticker.map(\.id))   // pruned to what's still in the (capped) ticker
        if gs.nuclearStrikes.count < t.strikesSeen { t.strikesSeen = gs.nuclearStrikes.count }
        let strikes = gs.nuclearStrikes.dropFirst(t.strikesSeen)
        t.strikesSeen = gs.nuclearStrikes.count
        guard store?.remote != nil else { return }
        for item in fresh where item.severity >= PlayHistory.eventTickerSeverity {
            sendPlayEvent(t, kind: "ticker", detail: ["game_date": PlayHistory.day(item.date), "severity": item.severity,
                                                      "text": PlayHistory.text(item.text)], now: now)
        }
        for s in strikes {
            sendPlayEvent(t, kind: "nuclear_strike", detail: ["turn": s.turn, "attacker": s.attacker, "target": s.target,
                                                              "warheads": s.warheadsUsed, "casualties": s.casualties], now: now)
        }
    }

    private func sendPlaySession(_ gs: GameState, _ t: PlaySessionTracker, now: Date,
                                 ended: (String, GameScore, VictoryType?)? = nil, closing: String? = nil) {
        let summary = PlaySummary.build(gs, session: t.summarySession, score: ended?.1, victory: ended?.2,
                                        historyID: ended == nil ? nil : t.id)
        let finished = ended != nil || closing != nil
        let r = PlaySessionRecord(id: t.id, client: PlayHistory.client, startedAt: t.startedAt,
                                  lastSeenAt: max(now, t.startedAt), endedAt: finished ? max(now, t.startedAt) : nil,
                                  outcome: ended?.0 ?? closing,
                                  score: ended.map { Double($0.1.finalScore) },
                                  actions: min(max(0, gs.turn - t.startTurn), PlayHistory.maxActions), summary: summary)
        store?.playSessionUpdated(r)
    }

    private func sendPlayEvent(_ t: PlaySessionTracker, kind: String, detail: [String: Any], now: Date) {
        guard let d = PlayHistory.json(detail) else { return }
        store?.playEvent(PlayEventRecord(sessionID: t.id, seq: t.takeSeq(), ts: now, kind: kind, detail: d))
    }
}
