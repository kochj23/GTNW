//
//  NovaCommentary.swift
//  Global Thermal Nuclear War
//
//  Live Nova commentary and the Hall of Infamy (3.15.0).
//
//  Nova comments on the game: at most one line a turn about the turn's biggest news, plus one for each flash event
//  (up to two) and for a broken personal record. A deterministic template line is posted at once; when the setting
//  is on and a local AI backend answers, Nova's own line replaces it. The prompt carries only game facts (headlines,
//  date, country), never anything about the player. Lines go on the ticker, into `shadow.novaLines`, and into play
//  history as `nova_commentary`.
//
//  The Hall of Infamy keeps personal records across sittings (local defaults, plus `record_set` play events).
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum NovaCommentary {
    static let defaultsKey = "GTNW.novaCommentary"
    /// Under XCTest the setting lives in a throwaway suite, never the real defaults.
    static var defaults: UserDefaults = AudioGate.underXCTest ? UserDefaults(suiteName: "GTNW.tests.nova.\(UUID().uuidString)")! : .standard
    static func enabled(_ d: UserDefaults = defaults) -> Bool { d.object(forKey: defaultsKey) as? Bool ?? true }

    /// The live line generator (prompt → line, nil on failure). The app wires it to the AI backends; tests inject
    /// fakes. Nil = templates only.
    static var generator: ((String) async -> String?)?

    static let systemPrompt = """
        You are Nova, a dry, sardonic commentator on a Cold War strategy game. Reply with ONE sentence of at most \
        25 words reacting to the headline. No hashtags, no emoji, no quotation marks, no advice.
        """

    #if os(macOS)
    /// Wire the live generator to the local AI backends (Ollama, MLX, …): two attempts, then the template stands.
    /// Never under XCTest.
    static func wireLiveBackends() {
        guard !AudioGate.underXCTest else { return }
        generator = { prompt in
            await MainActor.run { AIBackendManager.shared.activeBackend } == nil ? nil
                : try? await Retry.run("nova-commentary", policy: .subprocess) {
                    try await AIBackendManager.shared.generate(prompt: prompt, systemPrompt: systemPrompt, temperature: 0.9, maxTokens: 60)
                }
        }
    }
    #endif

    /// Stable string hash (Swift's hashValue changes per launch).
    static func stableHash(_ s: String) -> Int { s.utf8.reduce(5381) { ($0 &* 33 &+ Int($1)) & 0x7fffffff } }

    /// The deterministic line for a headline.
    static func template(_ item: TickerItem, turn: Int) -> String {
        let t = item.text.lowercased()
        let pool: [String]
        if t.contains("nuclear") || t.contains("warhead") || t.contains("detonat") {
            pool = ["Somewhere a Geiger counter just found its purpose in life.", "That's one way to end a news cycle.",
                    "History will be short and very bright."]
        } else if t.contains("impeach") || t.contains("congress") {
            pool = ["Congress has noticed. Congress rarely notices anything.", "The Capitol is sharpening its pencils.",
                    "Approval ratings are a renewable resource, until they aren't."]
        } else if t.contains("territor") || t.contains("claim") || t.contains("levy") || t.contains("annex") || t.contains("producing") {
            pool = ["Another flag, another ledger line.", "The map gets redder; the accountants get happier.",
                    "Empire: it's mostly paperwork and resentment."]
        } else if t.contains("war") || t.contains("invade") || t.contains("attack") {
            pool = ["Diplomacy has left the building.", "The generals are delighted. Nobody else is.",
                    "Wars are easy to start and famously hard to finish."]
        } else if item.severity >= 3 {
            pool = ["Well. That happened.", "Remember this turn. Everyone else will."]
        } else {
            pool = ["Noted, filed, and quietly worried about.", "The world turns; so do your advisers' stomachs.",
                    "A quiet headline. Enjoy it while it lasts."]
        }
        return pool[stableHash(item.text + "\(turn)") % pool.count]
    }

    /// The headlines worth a line this turn: the biggest notable item, plus up to two flash items.
    static func picks(_ fresh: [TickerItem]) -> [TickerItem] {
        let notable = fresh.filter { $0.severity >= 1 && !$0.text.hasPrefix("Nova:") && !$0.text.hasPrefix("Territories paid") }
        let flash = Array(notable.filter { $0.severity >= 3 }.prefix(2))
        if !flash.isEmpty { return flash }
        return notable.max { $0.severity < $1.severity }.map { [$0] } ?? []
    }

    /// The facts-only prompt for a headline.
    static func prompt(_ item: TickerItem, gs: GameState) -> String {
        "Date: \(GameCalendar.format(gs.currentDate)). Playing as: \(gs.getPlayerCountry()?.name ?? gs.playerCountryID). Headline: \(item.text)"
    }

    /// Clean an AI reply to one short, plain line; nil if nothing usable is left.
    static func clean(_ reply: String) -> String? {
        let line = reply.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        var s = line.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"“”'")))
        if s.lowercased().hasPrefix("nova:") { s = String(s.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
        if s.contains("http") || s.contains("@") || s.contains("<") { return nil }
        s = PlayHistory.text(String(s.prefix(200)))
        return s.count >= 3 ? s : nil
    }
}

extension GameEngine {
    /// After the Shadow turn: comment on what's new since `seen` (ticker ids from before the turn).
    func processCommentary(seen: Set<UUID>) {
        guard let gs = gameState, NovaCommentary.enabled() else { return }
        for item in NovaCommentary.picks(gs.shadow.ticker.filter { !seen.contains($0.id) }) {
            comment(NovaCommentary.template(item, turn: gs.turn), about: item)
        }
    }

    /// Post a line now; ask the live generator for a better one.
    func comment(_ text: String, about item: TickerItem) {
        guard let gs = gameState else { return }
        let line = TickerItem(date: gs.currentDate, text: "Nova: " + text, severity: 0)
        gs.shadow.ticker.append(line)
        if gs.shadow.ticker.count > 120 { gs.shadow.ticker.removeFirst(gs.shadow.ticker.count - 120) }
        gs.shadow.novaLines.append(line)
        if gs.shadow.novaLines.count > 30 { gs.shadow.novaLines.removeFirst(gs.shadow.novaLines.count - 30) }
        self.gameState = gs
        guard let generate = NovaCommentary.generator else { return logCommentary(line, source: "template") }
        let prompt = NovaCommentary.prompt(item, gs: gs)
        Task { @MainActor in
            guard let reply = await generate(prompt).flatMap(NovaCommentary.clean), let g = self.gameState, g === gs else {
                return self.logCommentary(line, source: "template")
            }
            var live = line
            live.text = "Nova: " + reply
            if let i = g.shadow.ticker.firstIndex(where: { $0.id == line.id }) { g.shadow.ticker[i] = live }
            if let i = g.shadow.novaLines.firstIndex(where: { $0.id == line.id }) { g.shadow.novaLines[i] = live }
            self.gameState = g
            self.logCommentary(live, source: "nova")
        }
    }

    private func logCommentary(_ line: TickerItem, source: String) {
        logPlayEvent("nova_commentary", detail: ["text": PlayHistory.text(line.text), "source": source,
                                                 "game_date": PlayHistory.day(line.date)])
    }
}

// MARK: - Hall of Infamy

enum InfamyRecord: String, Codable, CaseIterable, Identifiable {
    case territories, territoryCash, nukes, ruthlessness, warsAtOnce, turnsSurvived, lowestApproval
    var id: String { rawValue }
    var title: String {
        switch self {
        case .territories: return "Most territories held"
        case .territoryCash: return "Most territory cash"
        case .nukes: return "Most nuclear strikes ordered"
        case .ruthlessness: return "Most ruthless"
        case .warsAtOnce: return "Most wars at once"
        case .turnsSurvived: return "Longest time in office (turns)"
        case .lowestApproval: return "Lowest approval survived"
        }
    }
    var lowerIsWorse: Bool { self == .lowestApproval }
    func format(_ v: Double) -> String {
        switch self {
        case .territoryCash: return String(format: "$%.1fB", v)
        case .lowestApproval: return String(format: "%.0f%%", v)
        default: return String(format: "%.0f", v)
        }
    }
    /// This game's value.
    func value(_ gs: GameState) -> Double {
        let me = gs.playerCountryID
        switch self {
        case .territories: return Double(gs.countries.filter { $0.territoryOf == me && !$0.isDestroyed }.count)
        case .territoryCash: return gs.shadow.resourceEarnings
        case .nukes: return Double(gs.nuclearStrikes.filter { $0.attacker == me }.count)
        case .ruthlessness: return gs.shadow.ruthlessness
        case .warsAtOnce: return Double(gs.getPlayerCountry()?.atWarWith.count ?? 0)
        case .turnsSurvived: return Double(gs.turn)
        case .lowestApproval: return gs.shadow.popularity
        }
    }
    /// The least a value must be to count as a record at all (nobody wants "0 wars").
    func counts(_ v: Double) -> Bool { lowerIsWorse ? v < 35 : v >= (self == .territoryCash ? 1 : (self == .turnsSurvived ? 12 : 1)) }
}

struct InfamyEntry: Codable, Hashable {
    var value: Double
    /// "United States, 1897" — the country and era, nothing about the player.
    var who: String
    var gameDate: Date
    var setAt: Date
}

enum HallOfInfamy {
    static let defaultsKey = "GTNW.hallOfInfamy"
    /// When this sitting began (records set before it count as "earlier").
    static let launched = Date()
    /// Under XCTest the hall lives in a throwaway suite, never the real defaults.
    static var defaults: UserDefaults = AudioGate.underXCTest ? UserDefaults(suiteName: "GTNW.tests.hall.\(UUID().uuidString)")! : .standard

    static func load(_ d: UserDefaults = defaults) -> [InfamyRecord: InfamyEntry] {
        guard let data = d.data(forKey: defaultsKey),
              let raw = try? JSONDecoder().decode([String: InfamyEntry].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in
            InfamyRecord(rawValue: k).flatMap { v.value.isFinite ? ($0, v) : nil }
        })
    }

    static func save(_ hall: [InfamyRecord: InfamyEntry], _ d: UserDefaults = defaults) {
        let raw = Dictionary(uniqueKeysWithValues: hall.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) { d.set(data, forKey: defaultsKey) }
    }

    /// Records this game beats, with the previous value (nil = first ever).
    static func broken(_ gs: GameState, hall: [InfamyRecord: InfamyEntry]) -> [(InfamyRecord, Double, Double?)] {
        InfamyRecord.allCases.compactMap { r in
            let v = r.value(gs)
            guard v.isFinite, r.counts(v) else { return nil }
            if let old = hall[r]?.value, r.lowerIsWorse ? v >= old : v <= old { return nil }
            return (r, v, hall[r]?.value)
        }
    }
}

extension GameEngine {
    /// After the Shadow turn: update the Hall of Infamy; one ticker line (and a Nova remark) for what was broken.
    func processHallOfInfamy() {
        guard let gs = gameState, !gs.isMultiplayer else { return }
        var hall = HallOfInfamy.load()
        let before = hall
        let broken = HallOfInfamy.broken(gs, hall: hall)
        guard !broken.isEmpty else { return }
        let who = "\(gs.getPlayerCountry()?.name ?? gs.playerCountryID), \(GameCalendar.calendar.component(.year, from: gs.currentDate))"
        for (r, v, old) in broken {
            hall[r] = InfamyEntry(value: v, who: who, gameDate: gs.currentDate, setAt: Date())
            var detail: [String: Any] = ["record": r.rawValue, "value": PlayHistory.num(v), "game_date": PlayHistory.day(gs.currentDate)]
            if let old { detail["previous"] = PlayHistory.num(old) }
            logPlayEvent("record_set", detail: detail)
        }
        HallOfInfamy.save(hall)
        // Announce only records from an earlier sitting being beaten (first-ever marks, and a record this game keeps
        // pushing, are set quietly).
        let since = gs.shadow.playSessionStartedAt ?? HallOfInfamy.launched
        let beaten = broken.filter { b in b.2 != nil && (before[b.0]?.setAt ?? .distantPast) < since }
        guard let top = beaten.first else { return }
        let text = "Hall of Infamy: new record, \(top.0.title.lowercased()) (\(top.0.format(top.1)))"
            + (beaten.count > 1 ? " and \(beaten.count - 1) more." : ".")
        gs.shadow.post(text, date: gs.currentDate, severity: 1)
        self.gameState = gs
        if NovaCommentary.enabled() { comment("A new low, and I mean that as a compliment.", about: gs.shadow.ticker.last!) }
    }
}
