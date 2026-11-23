//
//  WorldBrief.swift
//  Global Thermal Nuclear War
//
//  Real-world intel in modern games (3.29.0). A Nova job writes a daily digest of the week's news to the Games DB
//  (`play.world_brief`: military and cyber scores per country, and actor → target pairs for wars, tensions and cyber
//  attacks). A game that starts in 2024 or later reads the newest one in the background (never blocking the start;
//  a short timeout; no brief, no table or the public edition simply means none) and applies it on turn 1: relations
//  sour and aggression rises along the real quarrels, the AI prefers those fights (only where it can reach), cyber
//  incidents are attributed to the real actors, and the Situation Room shows a WORLD BRIEF line. The brief is
//  untrusted input: ids are checked against the game's countries, numbers clamped, text stripped of control
//  characters and cut to 140 characters, counts capped.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// One actor → target pair from the brief.
struct WorldBriefPair: Codable, Hashable {
    var a: String
    var b: String
    /// "war", "tension" or "cyber".
    var kind: String
    /// 0–100.
    var weight: Int
    var headline: String
}

/// The applied brief, kept with the game.
struct WorldBriefState: Codable, Equatable {
    /// The brief's day (yyyy-mm-dd).
    var day: String
    /// Cyber score 0–100 by country id.
    var cyber: [String: Int] = [:]
    /// Military score 0–100 by country id.
    var military: [String: Int] = [:]
    /// A real headline per country (sanitized).
    var headlines: [String: String] = [:]
    var pairs: [WorldBriefPair] = []

    /// The three heaviest pairs, for the Situation Room line.
    var topPairs: [WorldBriefPair] { Array(pairs.sorted { ($0.weight, $1.a) > ($1.weight, $0.a) }.prefix(3)) }
}

/// Where a brief comes from: the Games DB in the app, a fixture in tests.
protocol WorldBriefProvider: Sendable {
    func latestBrief() async -> (day: String?, json: Data)?
}

#if !GTNW_CORE
/// The Games DB (private edition only, when configured).
struct GamesDBWorldBriefProvider: WorldBriefProvider {
    func latestBrief() async -> (day: String?, json: Data)? {
        guard !Edition.isPublic, let pg = GameStoreService.shared.remote as? PostgresGameStore else { return nil }
        return try? await pg.latestWorldBrief()
    }
}
#endif

enum WorldBriefModel {
    /// "WORLD BRIEF 2026-11-15: Russia → Ukraine (war) · …": the date and the three heaviest pairs, by current names.
    static func line(_ brief: WorldBriefState, in gs: GameState) -> String {
        let top = brief.topPairs.map { "\(gs.getCountry(id: $0.a)?.name ?? $0.a) → \(gs.getCountry(id: $0.b)?.name ?? $0.b) (\($0.kind))" }
        return "WORLD BRIEF \(brief.day): " + (top.isEmpty ? "quiet week." : top.joined(separator: " · "))
    }

    static let maxBytes = 262_144
    static let maxCountries = 300
    static let maxPairs = 40
    static let maxHeadline = 140
    /// Games starting this year or later use the brief.
    static let firstYear = 2024
    /// Seconds to wait for the Games DB before giving up (the game never waits).
    static let timeout: TimeInterval = 4

    /// Control and format characters out, whitespace collapsed, at most `max` characters.
    static func sanitize(_ raw: String, max: Int = maxHeadline) -> String {
        let scalars = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) || $0 == " " }
        let text = String(String.UnicodeScalarView(scalars)).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return text.count <= max ? text : String(text.prefix(max - 1)) + "…"
    }

    private static func isISO3(_ s: String) -> Bool {
        s.count == 3 && s.unicodeScalars.allSatisfy { $0.value >= 65 && $0.value <= 90 }
    }

    private static func clamp(_ v: Any?) -> Int? {
        #if GTNW_CORE
        // No CFBoolean outside Apple's Foundation: a JSON true/false is the NSNumber whose type is `char` ("c").
        guard let n = v as? NSNumber, String(cString: n.objCType) != "c" else { return nil }
        #else
        guard let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
        #endif
        let d = n.doubleValue
        guard d.isFinite else { return nil }
        return Int(max(0, min(100, d)).rounded())
    }

    /// Parse and validate a brief. `valid` is the set of country ids in this game; anything else is dropped.
    static func parse(_ data: Data, day: String?, valid: Set<String>) -> WorldBriefState? {
        guard data.count <= maxBytes, let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        var generated = sanitize(root["generated"] as? String ?? "", max: 40)
        if generated.count < 10 { generated = day ?? "" }
        let d = sanitize(day ?? String(generated.prefix(10)), max: 10)
        var out = WorldBriefState(day: d)
        if let countries = root["countries"] as? [String: Any] {
            for (id, value) in countries.sorted(by: { $0.key < $1.key }).prefix(maxCountries) {
                guard isISO3(id), valid.contains(id), let row = value as? [String: Any] else { continue }
                if let c = clamp(row["cyber"]) { out.cyber[id] = c }
                if let m = clamp(row["military"]) { out.military[id] = m }
                if let h = row["headline"] as? String {
                    let clean = sanitize(h)
                    if !clean.isEmpty { out.headlines[id] = clean }
                }
            }
        }
        if let pairs = root["pairs"] as? [Any] {
            for case let p as [String: Any] in pairs.prefix(maxPairs * 5) {
                guard out.pairs.count < maxPairs, let a = p["a"] as? String, let b = p["b"] as? String, a != b,
                      isISO3(a), isISO3(b), valid.contains(a), valid.contains(b),
                      let kind = p["kind"] as? String, ["war", "tension", "cyber"].contains(kind), let w = clamp(p["weight"]) else { continue }
                out.pairs.append(WorldBriefPair(a: a, b: b, kind: kind, weight: w, headline: sanitize(p["headline"] as? String ?? "")))
            }
        }
        return out.pairs.isEmpty && out.cyber.isEmpty && out.military.isEmpty ? nil : out
    }

    /// Relation hit (actor → target) from a pair: war weight × 0.6, tension × 0.3, cyber × 0.15, at most 60.
    static func relationHit(_ p: WorldBriefPair) -> Int {
        let k = p.kind == "war" ? 0.6 : (p.kind == "tension" ? 0.3 : 0.15)
        return min(60, Int((Double(p.weight) * k).rounded()))
    }

    /// Extra moves the brief adds to a computer-run nation's choice (PersonalityAI): a war pair it can reach and isn't
    /// already fighting weighs toward attack; a tension pair toward condemnation and covert action; a cyber pair
    /// toward covert action. Weights scale with the pair's weight and the difficulty.
    static func options(for c: Country, in gs: GameState, difficulty: Double) -> [(WorldMove, Double)] {
        guard let brief = gs.shadow.worldBrief else { return [] }
        var out: [(WorldMove, Double)] = []
        for p in brief.pairs where p.a == c.id {
            guard let t = gs.getCountry(id: p.b), !t.isDestroyed, !c.alliances.contains(p.b) else { continue }
            let w = Double(p.weight) / 100
            switch p.kind {
            case "war" where c.atWarWith.isEmpty && Reach.canReach(c.id, p.b, in: gs):
                out.append((.attack(p.b), w * 2 * difficulty))
            case "war", "tension":
                out.append((.condemn(p.b), w * 1.5))
                out.append((.covertAction(p.b), w * difficulty))
            default:
                out.append((.covertAction(p.b), w * 1.5 * difficulty))
            }
        }
        return out
    }

    /// Who a cyber incident against the player is attributed to: the heaviest cyber pair aimed at the player, else
    /// the highest cyber score (≥ 50), never the player.
    static func cyberActor(_ gs: GameState) -> String? {
        guard let b = gs.shadow.worldBrief else { return nil }
        let me = gs.playerCountryID
        if let p = b.pairs.filter({ $0.kind == "cyber" && $0.b == me }).max(by: { $0.weight < $1.weight }) { return p.a }
        return b.cyber.filter { $0.key != me && $0.value >= 50 && gs.getCountry(id: $0.key)?.isDestroyed == false }
            .max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }
}

extension GameEngine {
    /// The brief source; nil under tests (they inject a fixture).
    #if GTNW_CORE
    nonisolated(unsafe) static var worldBriefProvider: WorldBriefProvider? = nil   // a GTNWCore host may plug one in
    #else
    nonisolated(unsafe) static var worldBriefProvider: WorldBriefProvider? = GameStoreService.isTestOrSmokeRun ? nil : GamesDBWorldBriefProvider()
    #endif

    /// At the start of a modern game: fetch the newest brief in the background and apply it when it lands (turn 0
    /// or 1 of the same game). Never blocks; gives up after `WorldBriefModel.timeout` seconds.
    func requestWorldBrief(provider: WorldBriefProvider? = GameEngine.worldBriefProvider, timeout: TimeInterval = WorldBriefModel.timeout) {
        guard let gs = gameState, let provider, gs.eraStartYear >= WorldBriefModel.firstYear, gs.shadow.worldBrief == nil else { return }
        Task { @MainActor [weak self] in
            let result = await withTaskGroup(of: (day: String?, json: Data)?.self) { group -> (day: String?, json: Data)? in
                group.addTask { await provider.latestBrief() }
                group.addTask { try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000)); return nil }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
            guard let self, let r = result, let now = self.gameState, now === gs, now.turn <= 1 else { return }
            self.applyWorldBrief(r.json, day: r.day)
        }
    }

    /// Validate and apply a brief: relations and aggression along its war / tension pairs, and the WORLD BRIEF
    /// line. Returns false when the brief is unusable or one is already applied.
    @discardableResult
    func applyWorldBrief(_ data: Data, day: String?) -> Bool {
        guard let gs = gameState, gs.shadow.worldBrief == nil,
              let brief = WorldBriefModel.parse(data, day: day, valid: Set(gs.countries.filter { !$0.isDestroyed }.map(\.id))) else { return false }
        gs.shadow.worldBrief = brief
        for p in brief.pairs {
            modifyDiplomaticRelation(from: p.a, to: p.b, by: -WorldBriefModel.relationHit(p))
            modifyDiplomaticRelation(from: p.b, to: p.a, by: -WorldBriefModel.relationHit(p) / 2)
            if p.kind != "cyber", let i = gs.countries.firstIndex(where: { $0.id == p.a }) {
                gs.countries[i].aggressionLevel = min(100, gs.countries[i].aggressionLevel + min(15, p.weight / 7))
            }
        }
        gs.shadow.post(WorldBriefModel.line(brief, in: gs), date: gs.currentDate, severity: 1)
        logPlayEvent("world_brief_applied", detail: ["day": brief.day, "pairs": brief.pairs.count, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return true
    }

    /// Each turn: cyber incidents attributed to the brief's real actors (cyber pairs, high cyber scores), with the
    /// real headline as flavour. About six a year across the world. `roll` for tests.
    func processWorldBrief(roll: Double? = nil) {
        guard let gs = gameState, let brief = gs.shadow.worldBrief else { return }
        let cyberPairs = brief.pairs.filter { $0.kind == "cyber" }
        let hackers = brief.cyber.filter { $0.value >= 60 }.keys.sorted()
        guard !cyberPairs.isEmpty || !hackers.isEmpty else { return }
        let r = roll ?? Double.random(in: 0..<1, using: &gs.rng)
        guard r < gs.scale.probability(annual: 6) else { return }
        let pick = Int(r * 1_000_003) % max(1, cyberPairs.count + hackers.count)
        let actor: String, target: String?, headline: String?
        if pick < cyberPairs.count {
            let p = cyberPairs[pick]
            actor = p.a; target = p.b; headline = p.headline.isEmpty ? brief.headlines[p.a] : p.headline
        } else {
            actor = hackers[pick - cyberPairs.count]; target = nil; headline = brief.headlines[actor]
        }
        guard let a = gs.getCountry(id: actor), !a.isDestroyed else { return }
        let victim = target.flatMap { gs.getCountry(id: $0)?.name }
        let line = "💻 CYBER: \(a.name) hackers strike\(victim.map { " \($0)" } ?? " foreign networks")." + (headline.map { " (\($0))" } ?? "")
        gs.shadow.post(WorldBriefModel.sanitize(line, max: 240), date: gs.currentDate, severity: target == gs.playerCountryID ? 2 : 1)
        if let t = target, let j = gs.countries.firstIndex(where: { $0.id == t }) {
            gs.countries[j].cyberAttacksReceived += 1
            modifyDiplomaticRelation(from: t, to: actor, by: -3)
        }
        self.gameState = gs
    }
}
