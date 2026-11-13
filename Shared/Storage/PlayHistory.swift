//
//  PlayHistory.swift
//  Global Thermal Nuclear War
//
//  Play-session logging for Nova's game reporter: one `play.sessions` row per sitting (new game, scenario, or a
//  loaded save) and `play.events` (game start, urgent ticker items, nuclear strikes, game over) in the
//  Nova Games DB, schema `play` (NovaGames deploy/db/play.sql). 3.22.0 logs every presidential order with what the
//  cabinet said about it (and whether he overruled them), every crisis decision, election and midterm results, big
//  approval / DEFCON / impeachment / Congress swings, and a post-mortem at game over, so Nova's column has the
//  whole story. Rides the store's offline-first queue, so it never
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
    /// `play.sessions.player`; nil = the store's player id. Watch games (3.26.0) are "AI vs AI", never a person.
    var player: String? = nil
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
    /// 3.22.0: an approval move of at least this many points in one turn is an event.
    static let approvalSwing = 5.0
    /// 3.22.0: a change in congressional support of at least this many points in one turn is an event.
    static let congressSwing = 8
    /// 3.22.0: the orders kept for the game-over post-mortem.
    static let recentOrders = 8
    /// 3.22.0: the outcome lines kept per order.
    static let orderLines = 4

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
    /// `play.sessions.player` for a watch game (WATCH-CONTRACT v2): never a person, never in a human's stats.
    static let spectatorPlayer = "AI vs AI"

    static func json(_ object: [String: Any]) -> Data? {
        guard JSONSerialization.isValidJSONObject(object) else { return nil }
        return try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// An event detail as JSON under the 4 KB cap: if it is over, every string is cut shorter (120, then 40
    /// characters) rather than the whole event being dropped by validation (3.22.0: long cabinet warnings and
    /// outcome lines on one order could push it over).
    static func fitted(_ detail: [String: Any]) -> Data? {
        if let d = json(detail), d.count <= maxDetailBytes { return d }
        for limit in [120, 40] {
            if let d = json(shortened(detail, to: limit) as? [String: Any] ?? [:]), d.count <= maxDetailBytes { return d }
        }
        return nil
    }

    private static func shortened(_ v: Any, to limit: Int) -> Any {
        switch v {
        case let s as String: return s.count > limit ? String(s.prefix(limit - 1)) + "…" : s
        case let a as [Any]: return a.prefix(8).map { shortened($0, to: limit) }
        case let o as [String: Any]: return o.mapValues { shortened($0, to: limit) }
        default: return v
        }
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

    /// 3.22.0: what moved since last turn: approval, DEFCON, the impeachment track and Congress. Updates the
    /// tracker's baselines; returns the events to log (in the order they read best).
    static func swings(_ gs: GameState, _ t: PlaySessionTracker) -> [(String, [String: Any])] {
        var out: [(String, [String: Any])] = []
        let date = day(gs.currentDate)
        let pop = gs.shadow.popularity
        if pop.isFinite, t.lastPopularity.isFinite {
            let delta = pop - t.lastPopularity
            if abs(delta) >= approvalSwing {
                if delta < 0 { t.stats.biggestApprovalDrop = max(t.stats.biggestApprovalDrop, -delta) }
                out.append(("approval_swing", ["from": num(t.lastPopularity), "to": num(pop), "change": num(delta),
                                               "game_date": date, "turn": gs.turn]))
            }
        }
        if pop.isFinite { t.lastPopularity = pop }
        let defcon = gs.defconLevel.rawValue
        if defcon != t.lastDefcon {
            out.append(("defcon_change", ["from": t.lastDefcon, "to": defcon, "game_date": date, "turn": gs.turn]))
            t.lastDefcon = defcon
        }
        let stage = gs.shadow.impeachmentStage
        if stage != t.lastImpeachmentStage {
            out.append(("impeachment_track", ["from": t.lastImpeachmentStage, "to": stage, "approval": num(pop),
                                              "game_date": date, "turn": gs.turn]))
            t.lastImpeachmentStage = stage
        }
        if let c = gs.getPlayerCountry()?.congressionalSupport {
            if let last = t.lastCongress, abs(c - last) >= congressSwing {
                out.append(("congress_swing", ["from": last, "to": c, "game_date": date, "turn": gs.turn]))
            }
            t.lastCongress = c
        }
        return out
    }

    static func isJSONObject(_ d: Data, max: Int) -> Bool {
        !d.isEmpty && d.count <= max && (try? JSONSerialization.jsonObject(with: d)) is [String: Any]
    }
}

// MARK: - Session stats (3.22.0)

/// Running tallies for one sitting: how often he overruled the cabinet, ignored a danger warning, backed down,
/// and how his crisis calls went. In memory only (a resumed save starts a new sitting, and a new tally).
struct PlayStats: Equatable {
    var orders = 0
    var ordersFailed = 0
    var hostileOrders = 0
    var advisorsOverruled = 0
    var dangerWarningsIgnored = 0
    var backedDown = 0
    var recommendationsTaken = 0
    var recommendationsRejected = 0
    var crisesDecided = 0
    var crisesFailed = 0
    var advisorsResigned = 0
    var biggestApprovalDrop = 0.0
    /// "Air Strike -> Cuba (overruled Secretary of Defense; FAILED)", newest last.
    var lastOrders: [String] = []

    mutating func noteOrder(_ line: String) {
        lastOrders.append(PlayHistory.text(line))
        if lastOrders.count > PlayHistory.recentOrders { lastOrders.removeFirst(lastOrders.count - PlayHistory.recentOrders) }
    }

    var json: [String: Any] {
        ["orders_given": orders, "orders_failed": ordersFailed, "hostile_orders": hostileOrders,
         "advisors_overruled": advisorsOverruled, "danger_warnings_ignored": dangerWarningsIgnored,
         "backed_down_after_advice": backedDown, "recommendations_taken": recommendationsTaken,
         "recommendations_rejected": recommendationsRejected, "crises_decided": crisesDecided,
         "crises_failed": crisesFailed, "advisors_resigned": advisorsResigned,
         "biggest_one_turn_approval_drop": PlayHistory.num(biggestApprovalDrop), "last_orders": lastOrders]
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
              PlayHistory.isJSONObject(s.summary, max: PlayHistory.maxSummaryBytes),
              (s.player.map { (1...64).contains($0.count) } ?? true)
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
        var stats = PlayStats()
    }

    /// The U.S. president the player chose to be (3.22.3), e.g. "Donald Trump" for a 2025 game.
    static func president(_ gs: GameState) -> String? {
        guard let id = gs.presidentsPlayed.last else { return nil }
        return administrations[id]
    }
    private static let administrations: [String: String] =
        Dictionary(Advisor.allAdministrations().map { ($0.id, $0.president) }, uniquingKeysWith: { a, _ in a })

    /// Everything the reporter may quote about this session, from the game as it stands now.
    /// `score`/`victory` are set at game over (`historyID` = the game_history row).
    static func build(_ gs: GameState, session: Session, score: GameScore? = nil, victory: VictoryType? = nil,
                      historyID: UUID? = nil, extra: [String: Any] = [:]) -> Data {
        let sh = gs.shadow
        let player = gs.getPlayerCountry()
        let polls = sh.polls.map(\.popularity).filter(\.isFinite)
        var s: [String: Any] = [
            "scenario": sh.scenarioID.flatMap { StoreValidation.isIdentifier($0) ? $0 : nil } ?? "sandbox",
            "country": String(gs.playerCountryID.prefix(8)),
            // 3.11.0: the nation played and its leader, so the column can say who ran what.
            "country_name": PlayHistory.text(player?.name ?? gs.playerCountryID),
            "leader": PlayHistory.text(gs.playerCountryID == "USA" ? (PlaySummary.president(gs) ?? "")
                                       : (player.map { NationModel.leader(for: $0, on: gs.startDate).display } ?? "")),
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
        // 3.27.0: the gameplay RNG seed, so a run can be told apart and reproduced (after Doom's P_Random seed).
        s["rng_seed"] = String(format: "%016llx", gs.rng.seed)
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
        s["session_stats"] = session.stats.json
        if let b = PlayHistory.plain(sh.budget) { s["budget"] = b }
        if !sh.aidSent.isEmpty, let a = PlayHistory.plain(sh.aidSent) { s["aid_sent_billions"] = a }
        s["fronts"] = sh.fronts.suffix(40).map {
            ["attacker": $0.attacker, "defender": $0.defender, "status": $0.status.rawValue, "battles": $0.battles] as [String: Any]
        }
        s["strikes"] = gs.nuclearStrikes.suffix(60).map {
            ["turn": $0.turn, "attacker": $0.attacker, "target": $0.target, "warheads": $0.warheadsUsed,
             "casualties": $0.casualties] as [String: Any]
        }
        s.merge(extra) { $1 }
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
        return PlayHistory.json(["in_progress": !gs.gameOver, "turns": gs.turn].merging(extra) { $1 }) ?? Data("{}".utf8)
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
    var stats = PlayStats()
    /// 3.26.0 watch game (AI vs AI): recorded as player "AI vs AI" with `summary.spectator`, `matchup`, `fallbacks`.
    var spectator = false
    /// Times a brain's move was missing or invalid and the built-in AI played instead, by country id.
    var fallbacks: [String: Int] = [:]
    /// Use AI was on at the last turn (off: every model brain played rule-based).
    var aiEnabled = true
    /// Last turn's readings, for the swing events (3.22.0).
    var lastPopularity: Double
    var lastDefcon: Int
    var lastImpeachmentStage: Int
    var lastCongress: Int?

    init(id: UUID, startedAt: Date, gs: GameState, resumedFromTurn: Int?) {
        self.id = id
        self.game = gs
        self.startedAt = startedAt
        self.startTurn = gs.turn
        self.resumedFromTurn = resumedFromTurn
        self.gameDateAtStart = gs.currentDateLabel
        self.seenTicker = Set(gs.shadow.ticker.map(\.id))
        self.strikesSeen = gs.nuclearStrikes.count
        self.lastPopularity = gs.shadow.popularity
        self.lastDefcon = gs.defconLevel.rawValue
        self.lastImpeachmentStage = gs.shadow.impeachmentStage
        self.lastCongress = gs.getPlayerCountry()?.congressionalSupport
    }

    func takeSeq() -> Int { defer { nextSeq += 1 }; return nextSeq }

    var summarySession: PlaySummary.Session {
        PlaySummary.Session(id: id, startTurn: startTurn, resumedFromTurn: resumedFromTurn, gameDateAtStart: gameDateAtStart,
                            stats: stats)
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
        t.spectator = spectating
        playSession = t
        guard store?.remote != nil else { return }
        sendPlaySession(gs, t, now: now)
        var detail: [String: Any] = ["scenario": gs.shadow.scenarioID ?? "sandbox", "country": gs.playerCountryID,
                                     "country_name": PlayHistory.text(gs.getPlayerCountry()?.name ?? gs.playerCountryID),
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
            // 3.22.0 post-mortem: what he did last, where approval went, and how often he ignored the room.
            "last_orders": t.stats.lastOrders,
            "approval_last_polls": gs.shadow.polls.suffix(6).map { PlayHistory.num($0.popularity) },
            "approval_end": PlayHistory.num(gs.shadow.popularity),
            "impeachment_stage": gs.shadow.impeachmentStage, "defcon": gs.defconLevel.rawValue,
            "advisors_overruled": t.stats.advisorsOverruled, "danger_warnings_ignored": t.stats.dangerWarningsIgnored,
            "advisors_resigned": t.stats.advisorsResigned,
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

    /// A decision worth its own event the moment it happens (3.3.0: `claimed_land`, `renamed_territory`).
    func logPlayEvent(_ kind: String, detail: [String: Any], now: Date = Date()) {
        guard let gs = gameState, let t = playSession, t.game === gs, !t.ended, store?.remote != nil else { return }
        sendPlayEvent(t, kind: kind, detail: detail, now: now)
    }

    // MARK: 3.22.0 — the whole story, for Nova's column

    /// One presidential order: what he ordered, against whom, what the responsible advisor said (and whether he
    /// overruled them), the cabinet's danger warnings he clicked past, what happened, and what it did to approval.
    func logPresidentialOrder(_ action: PresidentialAction, targetID: String, advice: ActionAdvice?,
                              warnings: [AdvisorWarning], size: AttackSize?, warhead: WarheadType?,
                              popularityBefore: Double, report: ActionReport?, resignation: String?, now: Date = Date()) {
        guard let gs = gameState, let t = playSession, t.game === gs, !t.ended else { return }
        let target = PlayHistory.text(gs.getCountry(id: targetID)?.name ?? targetID)
        let overruled = advice?.stance == .oppose
        let danger = warnings.filter { $0.level >= 2 }
        let failed = report?.success == false
        t.stats.orders += 1
        if failed { t.stats.ordersFailed += 1 }
        if action.isHostile { t.stats.hostileOrders += 1 }
        if overruled { t.stats.advisorsOverruled += 1 }
        if !danger.isEmpty { t.stats.dangerWarningsIgnored += 1 }
        if resignation != nil { t.stats.advisorsResigned += 1 }
        var note = "\(action.rawValue) -> \(target)"
        var tags: [String] = []
        if overruled, let a = advice { tags.append("overruled \(a.advisorTitle)") }
        if !danger.isEmpty { tags.append("ignored \(danger.count) danger warning\(danger.count == 1 ? "" : "s")") }
        if let ok = report?.success { tags.append(ok ? "worked" : "FAILED") }
        if !tags.isEmpty { note += " (\(tags.joined(separator: "; ")))" }
        t.stats.noteOrder(note)
        guard store?.remote != nil else { return }
        var d: [String: Any] = [
            "action": action.rawValue, "category": String(describing: action.category), "hostile": action.isHostile,
            "rung": String(describing: action.rung), "target": PlayHistory.text(targetID), "target_name": target,
            "game_date": PlayHistory.day(gs.currentDate), "turn": gs.turn,
            "approval_before": PlayHistory.num(popularityBefore), "approval_after": PlayHistory.num(gs.shadow.popularity),
            "overruled_advisor": overruled, "order_number_this_session": t.stats.orders,
        ]
        if let a = advice {
            d["advisor"] = PlayHistory.text("\(a.advisorTitle) \(a.advisorName)")
            d["advisor_stance"] = a.stance.rawValue
            d["advisor_said"] = PlayHistory.text(a.reason)
            d["advisor_odds"] = PlayHistory.num(a.successEstimate, places: 100)
        }
        if !warnings.isEmpty {
            d["cabinet_warnings"] = warnings.prefix(3).map { ["who": PlayHistory.text($0.who), "level": $0.level,
                                                               "said": PlayHistory.text($0.text)] as [String: Any] }
            d["danger_warnings_ignored"] = danger.count
        }
        if let size { d["size"] = ["troops_k": PlayHistory.num(size.troops), "aircraft": size.aircraft, "warheads": size.warheads] }
        if let warhead { d["warhead"] = String(describing: warhead) }
        if let r = report {
            if let ok = r.success { d["worked"] = ok }
            d["result"] = r.lines.prefix(PlayHistory.orderLines).map(PlayHistory.text)
        }
        if let resignation { d["resignation"] = PlayHistory.text(resignation) }
        sendPlayEvent(t, kind: "president_order", detail: d, now: now)
    }

    /// He heard an advisor out and cancelled (a rare moment of restraint).
    func logBackedDown(_ action: PresidentialAction?, targetID: String?, advice: ActionAdvice, now: Date = Date()) {
        guard let gs = gameState, let t = playSession, t.game === gs, !t.ended else { return }
        t.stats.backedDown += 1
        guard store?.remote != nil else { return }
        var d: [String: Any] = ["advisor": PlayHistory.text("\(advice.advisorTitle) \(advice.advisorName)"),
                                "advisor_stance": advice.stance.rawValue, "advisor_said": PlayHistory.text(advice.reason),
                                "game_date": PlayHistory.day(gs.currentDate)]
        if let action { d["action"] = action.rawValue }
        if let targetID { d["target_name"] = PlayHistory.text(gs.getCountry(id: targetID)?.name ?? targetID) }
        sendPlayEvent(t, kind: "backed_down", detail: d, now: now)
    }

    /// An advisor's standing recommendation, taken or turned down.
    func logRecommendation(_ advisor: Advisor, accepted: Bool, resignation: String? = nil, now: Date = Date()) {
        guard let gs = gameState, let t = playSession, t.game === gs, !t.ended else { return }
        if accepted { t.stats.recommendationsTaken += 1 } else { t.stats.recommendationsRejected += 1 }
        if resignation != nil { t.stats.advisorsResigned += 1 }
        guard store?.remote != nil else { return }
        var d: [String: Any] = ["advisor": PlayHistory.text("\(advisor.title) \(advisor.name)"), "accepted": accepted,
                                "recommended": advisor.recommendedAction ?? "", "advice": PlayHistory.text(advisor.currentAdvice ?? ""),
                                "game_date": PlayHistory.day(gs.currentDate)]
        if let r = advisor.recommendedTarget { d["target_name"] = PlayHistory.text(gs.getCountry(id: r)?.name ?? r) }
        if let resignation { d["resignation"] = PlayHistory.text(resignation) }
        sendPlayEvent(t, kind: "recommendation", detail: d, now: now)
    }

    /// A crisis / decision card resolved (world watch, election cards, emergencies): what was on the desk, what he
    /// picked, what else he could have done, and whether it worked.
    func logCrisisDecision(_ crisis: CrisisEvent, option index: Int, worked: Bool, now: Date = Date()) {
        guard let gs = gameState, let t = playSession, t.game === gs, !t.ended,
              crisis.options.indices.contains(index) else { return }
        t.stats.crisesDecided += 1
        if !worked { t.stats.crisesFailed += 1 }
        guard store?.remote != nil else { return }
        let chosen = crisis.options[index]
        var d: [String: Any] = [
            "title": PlayHistory.text(crisis.title), "situation": PlayHistory.text(crisis.description),
            "type": crisis.type.rawValue, "severity": crisis.severity.rawValue,
            "chose": PlayHistory.text(chosen.title), "chose_why": PlayHistory.text(chosen.description),
            "odds": PlayHistory.num(chosen.successChance, places: 100), "worked": worked,
            "other_options": crisis.options.enumerated().filter { $0.offset != index }.prefix(4).map { PlayHistory.text($0.element.title) },
            "game_date": PlayHistory.day(gs.currentDate),
        ]
        if let who = chosen.advisorRecommendation { d["recommended_by"] = PlayHistory.text(who) }
        let advised = crisis.options.enumerated().filter { $0.element.advisorRecommendation != nil && $0.offset != index }
        if !advised.isEmpty { d["passed_over_advised"] = advised.prefix(3).map { PlayHistory.text("\($0.element.title) (\($0.element.advisorRecommendation ?? ""))") } }
        sendPlayEvent(t, kind: "crisis_decision", detail: d, now: now)
    }

    // MARK: Helpers

    private func logNewPlayEvents(_ gs: GameState, _ t: PlaySessionTracker, now: Date) {
        let fresh = gs.shadow.ticker.filter { !t.seenTicker.contains($0.id) }
        t.seenTicker = Set(gs.shadow.ticker.map(\.id))   // pruned to what's still in the (capped) ticker
        if gs.nuclearStrikes.count < t.strikesSeen { t.strikesSeen = gs.nuclearStrikes.count }
        let strikes = gs.nuclearStrikes.dropFirst(t.strikesSeen)
        t.strikesSeen = gs.nuclearStrikes.count
        let swings = PlayHistory.swings(gs, t)
        guard store?.remote != nil else { return }
        for (kind, detail) in swings { sendPlayEvent(t, kind: kind, detail: detail, now: now) }
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
        let watch: [String: Any] = t.spectator
            ? ["spectator": true, "matchup": watchMatchup(gs, aiEnabled: t.aiEnabled), "fallbacks": t.fallbacks] : [:]
        let summary = PlaySummary.build(gs, session: t.summarySession, score: ended?.1, victory: ended?.2,
                                        historyID: ended == nil ? nil : t.id, extra: watch)
        let finished = ended != nil || closing != nil
        let r = PlaySessionRecord(id: t.id, client: PlayHistory.client, startedAt: t.startedAt,
                                  lastSeenAt: max(now, t.startedAt), endedAt: finished ? max(now, t.startedAt) : nil,
                                  outcome: ended?.0 ?? closing,
                                  score: ended.map { Double($0.1.finalScore) },
                                  actions: min(max(0, gs.turn - t.startTurn), PlayHistory.maxActions), summary: summary,
                                  player: t.spectator ? PlayHistory.spectatorPlayer : nil)
        store?.playSessionUpdated(r)
    }

    private func sendPlayEvent(_ t: PlaySessionTracker, kind: String, detail: [String: Any], now: Date) {
        guard let d = PlayHistory.fitted(detail) else { return }
        store?.playEvent(PlayEventRecord(sessionID: t.id, seq: t.takeSeq(), ts: now, kind: kind, detail: d))
    }
}
