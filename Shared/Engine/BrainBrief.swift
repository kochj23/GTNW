//
//  BrainBrief.swift
//  Global Thermal Nuclear War
//
//  3.37.0: what a model brain is told when it plays a nation. Before this a brain read a short line of its own
//  numbers and the TRUE strength of the eight biggest armies on earth; it knew nothing of its treasury, its friends,
//  the wars under way, the player, or what it had itself done last turn, and it saw through the fog every other
//  government lives in. The brief now carries, in a compact budget a small local model can read:
//    • its own state, true: economy, the force breakdown, cyber and missile defence, stability and approval;
//    • its friends and rivals by relation, its blocs and treaties;
//    • the nations that matter to it (enemies, the player, rivals, allies, neighbours, the great powers, what it can
//      reach), each as ITS OWN ESTIMATE with the source and the age of the figure, and whether it can strike them;
//    • the world: who is fighting whom, the latest major events, the real-world brief where it touches this nation;
//    • the player: whose seat it is and how that government has behaved (wars, nuclear use, friends attacked,
//      approval, the habits it has shown);
//    • its own last moves and the reasons it gave.
//  Every nation now has its own believed view of every other (`Intelligence.estimate`): which source it reads, how
//  often that source reports and how far off it is, all derived from the game seed and the turn, so nothing new is
//  stored, no generator draw is spent and a replay is identical. The built-in AI keeps reading the figure in general
//  circulation (`Intelligence.believedArmy`), so the golden games do not change.
//  Cadences, the error growth with age and the prompt budget are design choices.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - Memory

/// One move a model brain made, in its own words, and what became of it.
struct BrainMemoryEntry: Codable, Hashable {
    var turn: Int
    var action: String
    var target: String?
    /// hold / build / diplomacy / hostile (`MoveAction.intent`).
    var intent: String
    /// The brain's stated reason, cleaned and cut short (untrusted model text).
    var rationale: String
    /// Nil when it was carried out as ordered; otherwise what happened instead ("council stood down: CONDEMN").
    var outcome: String?
}

enum BrainMemory {
    /// Moves remembered per nation.
    static let keep = 5
    /// Characters kept of a stated reason.
    static let maxRationale = 120

    static func clean(_ raw: String?) -> String {
        WorldBriefModel.sanitize(raw ?? "", max: maxRationale)
    }
}

extension GameEngine {
    /// Remember a model brain's move (newest last, `BrainMemory.keep` per nation).
    func rememberBrainMove(_ id: String, response: MoveResponse, action: MoveAction, outcome: String?) {
        guard let gs = gameState else { return }
        let target = response.target.flatMap { gs.resolveCountry($0, excluding: id)?.id }
        var list = gs.shadow.brainMemory[id] ?? []
        list.append(BrainMemoryEntry(turn: gs.turn, action: action.rawValue, target: action.requiresTarget ? target : nil,
                                     intent: action.intent, rationale: BrainMemory.clean(response.rationale), outcome: outcome))
        if list.count > BrainMemory.keep { list.removeFirst(list.count - BrainMemory.keep) }
        gs.shadow.brainMemory[id] = list
    }
}

// MARK: - Every government's own view

/// What one government believes about a figure of another's: the value, how many turns old it is, and its source.
struct IntelEstimate: Equatable {
    var value: Double
    var age: Int
    var source: IntelSource
}

extension IntelSource {
    /// Turns between fresh reports from this source (design choices).
    var cadence: Int {
        switch self {
        case .spyNetwork: return 1
        case .satellite: return 2
        case .signals, .reconnaissance, .borderInformant: return 3
        case .militaryAttache: return 4
        case .pressReports: return 6
        }
    }

    /// A short tag for the brief.
    var tag: String {
        switch self {
        case .spyNetwork: return "spies"
        case .satellite: return "sat"
        case .signals: return "sigint"
        case .reconnaissance: return "recon"
        case .borderInformant: return "border"
        case .militaryAttache: return "attache"
        case .pressReports: return "press"
        }
    }
}

extension Intelligence {
    /// What `observer` believes `subject`'s `field` to be: its best source that can see that field this year, the
    /// age of that source's last report (its cadence, phased per pair from the game seed), and the figure off by
    /// that source's error, growing with the age. Never exactly the truth. Nil when no source it has can see the
    /// field (a fleet nobody has photographed). Pure: no generator draw, nothing stored.
    static func estimate(_ field: IntelField, of subject: Country, for observer: Country, in gs: GameState) -> IntelEstimate? {
        let neighbours = Reach.landNeighbors(observer.id, in: gs).contains(subject.id)
        guard let source = sources(observer, about: subject, year: gs.currentYear, neighbours: neighbours)
            .filter({ $0.sees.contains(field) }).min(by: { $0.error < $1.error }) else { return nil }
        let pair = "\(gs.rng.seed)|\(observer.id)|\(subject.id)"
        let every = source.cadence
        let age = (max(0, gs.turn) + Int(CountryProfile.stableUnit(pair, salt: 7) * Double(every))) % every
        let u = CountryProfile.stableUnit("\(pair)|\(field.rawValue)|\(gs.turn - age)", salt: 11)
        let size = (0.3 + 0.7 * abs(u - 0.5) * 2) * source.error * (1 + 0.15 * Double(age))
        return IntelEstimate(value: max(0, truth(field, of: subject) * (1 + (u < 0.5 ? -size : size))), age: age, source: source)
    }
}

// MARK: - The council's alternative

extension WarCouncil {
    /// The move a model brain makes when its council stands a war down, by the instrument the council preferred:
    /// backing a colony's independence arms rebels, buying land opens a trade negotiation, and the rest (pressure
    /// short of war, a claim campaign elsewhere) is a public condemnation.
    static func brainAlternative(_ chose: String, target: String) -> (move: WorldMove, verb: String) {
        switch chose {
        case "independence": return (.supportRebels(target), MoveAction.backRebels.rawValue)
        case "buy_land", "buy_colony": return (.tradeTies(target), MoveAction.tradeDeal.rawValue)
        default: return (.condemn(target), MoveAction.condemn.rawValue)
        }
    }
}

// MARK: - The brief

enum BrainBrief {
    /// Hard cap on the situation text, in characters.
    static let maxChars = 6_000
    /// The token budget for the whole prompt (system + user), estimated at `charsPerToken`.
    static let tokenCap = 2_500
    /// A conservative characters-per-token figure for numbers, ids and short words.
    static let charsPerToken = 3.2

    static func tokens(_ s: String) -> Int { Int((Double(s.count) / charsPerToken).rounded(.up)) }

    /// How many of each list the brief carries; shrunk until the brief fits `maxChars`.
    struct Caps: Equatable {
        var nations = 12
        var wars = 8
        var events = 4
        var friends = 4
        var treaties = 5
        var memory = 5
        var brief = 4

        mutating func shrink() -> Bool {
            if nations > 6 { nations -= 2; return true }
            if events > 1 { events -= 1; return true }
            if wars > 3 { wars -= 2; return true }
            if brief > 1 { brief -= 1; return true }
            if memory > 2 { memory -= 1; return true }
            if friends > 2 { friends -= 1; treaties = max(2, treaties - 1); return true }
            if nations > 4 { nations -= 1; return true }
            return false
        }
    }

    /// The situation for `country`'s brain, within `maxChars`. Pure: reads the state only.
    static func summary(for country: Country, in gs: GameState, spectating: Bool = false) -> String {
        var caps = Caps()
        var text = compose(country, gs, caps, spectating: spectating)
        while text.count > maxChars, caps.shrink() { text = compose(country, gs, caps, spectating: spectating) }
        return text.count > maxChars ? String(text.prefix(maxChars - 1)) + "…" : text
    }

    static func signed(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }

    static func money(billions b: Double) -> String {
        b >= 1000 ? String(format: "$%.1fT", b / 1000) : String(format: "$%.0fB", b)
    }

    static func label(_ id: String, _ gs: GameState) -> String { "\(gs.getCountry(id: id)?.name ?? id) [\(id)]" }

    /// The nations that matter to `c`, most pressing first: its enemies, the player, its rivals, its allies, its
    /// neighbours, the great powers, then whatever it can reach that it feels strongly about.
    static func relevant(_ c: Country, in gs: GameState, cap: Int) -> [Country] {
        let others = gs.countries.filter { $0.id != c.id && !$0.isDestroyed && !$0.isTerritory }
        let rel = { (o: Country) in c.diplomaticRelations[o.id] ?? 0 }
        var picked: [String] = []
        func add(_ list: [Country]) { for o in list where !picked.contains(o.id) { picked.append(o.id) } }
        add(others.filter { c.atWarWith.contains($0.id) }.sorted { $0.id < $1.id })
        add(others.filter { $0.id == gs.playerCountryID })
        add(Array(others.filter { rel($0) < 0 }.sorted { (rel($0), $0.id) < (rel($1), $1.id) }.prefix(3)))
        add(others.filter { c.alliances.contains($0.id) }.sorted { (rel($0), $1.id) > (rel($1), $0.id) })
        let near = Reach.landNeighbors(c.id, in: gs)
        add(others.filter { near.contains($0.id) }.sorted { (abs(rel($0)), $1.id) > (abs(rel($1)), $0.id) })
        add(Array(others.sorted { ($0.gdp, $1.id) > ($1.gdp, $0.id) }.prefix(5)))
        // Reach checks are the costly part: only the thirty it feels most strongly about, and stop once full.
        for o in others.sorted(by: { (abs(rel($0)), $1.id) > (abs(rel($1)), $0.id) }).prefix(30) where picked.count < cap && !picked.contains(o.id) {
            if Reach.canReach(c.id, o.id, in: gs) { picked.append(o.id) }
        }
        let byID = Dictionary(others.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return picked.prefix(cap).compactMap { byID[$0] }
    }

    /// One line per relevant nation: relation, what it is to us, our estimates and whether we can reach it.
    static func nationLine(_ o: Country, for c: Country, in gs: GameState) -> String {
        var tags: [String] = []
        if o.id == gs.playerCountryID { tags.append("PLAYER") }
        if c.atWarWith.contains(o.id) { tags.append("AT WAR with you") }
        if c.alliances.contains(o.id) { tags.append("ally") }
        if Reach.landNeighbors(c.id, in: gs).contains(o.id) { tags.append("neighbor") }
        if !o.atWarWith.isEmpty, !c.atWarWith.contains(o.id) { tags.append("at war") }
        func est(_ f: IntelField, _ name: String) -> String {
            guard let e = Intelligence.estimate(f, of: o, for: c, in: gs) else { return "\(name) ?" }
            let v = f == .economy ? money(billions: e.value) : "\(Int(e.value.rounded()))"
            return "\(name)~\(v)[\(e.source.tag),\(e.age)t]"
        }
        let reach = Reach.how(c.id, o.id, in: gs).map(\.rawValue) ?? "none"
        return "- \(o.name) [\(o.id)] rel \(signed(c.diplomaticRelations[o.id] ?? 0))\(tags.isEmpty ? "" : ", " + tags.joined(separator: ", "))"
            + "; \(est(.army, "army")) \(est(.fleet, "fleet")) \(est(.nuclear, "nukes")); reach \(reach)"
    }

    /// The blocs `c` belongs to this year.
    static func blocs(_ c: Country, year: Int) -> [String] {
        let all: [(String, Set<String>)] = [
            ("NATO", MilitaryAllianceSystem.natoMembers(year: year)),
            ("Warsaw Pact", MilitaryAllianceSystem.warsawPactMembers(year: year)),
            ("CSTO", MilitaryAllianceSystem.cstoMembers(year: year)),
            ("SCO", MilitaryAllianceSystem.scoMembers(year: year)),
            ("AUKUS", MilitaryAllianceSystem.aukusMembers(year: year)),
            ("Arab League", MilitaryAllianceSystem.arabLeagueMembers(year: year)),
            ("ASEAN", MilitaryAllianceSystem.aseanMembers(year: year)),
            ("African Union", MilitaryAllianceSystem.africanUnionMembers(year: year)),
        ]
        return all.filter { $0.1.contains(c.id) }.map(\.0)
    }

    /// How the player's government has behaved (nil when `c` holds the player's seat).
    static func playerLine(_ c: Country, in gs: GameState, spectating: Bool) -> String? {
        let id = gs.playerCountryID
        guard id != c.id, let p = gs.getCountry(id: id) else { return nil }
        let r = gs.shadow.presidency
        func names(_ ids: [String]) -> String {
            ids.isEmpty ? "none" : ids.suffix(3).map { gs.getCountry(id: $0)?.name ?? $0 }.joined(separator: ", ")
        }
        let polls = gs.shadow.polls.suffix(4)
        let trend = polls.count >= 2 ? Int((polls.last!.popularity - polls.first!.popularity).rounded()) : 0
        let habits = gs.shadow.doctrines.filter { $0.key.hasPrefix(id + ":") && $0.value.wins > 0 }
            .sorted { ($0.value.wins, $1.key) > ($1.value.wins, $0.key) }.prefix(3)
            .map { "\($0.key.dropFirst(id.count + 1)) (\($0.value.wins) win\($0.value.wins == 1 ? "" : "s"))" }
        let who = spectating ? "The player's seat (the computer plays it in this watched game)" : "The human player"
        return "\(who): \(label(id, gs)), at war with \(p.atWarWith.isEmpty ? "nobody" : p.atWarWith.sorted().joined(separator: ", ")). "
            + "Record: \(gs.shadow.playerWarsStarted) wars started, \(gs.nukesLaunched) nuclear strikes, friends attacked: \(names(r.friendsAttacked)), "
            + "friends struck with nuclear weapons: \(names(r.friendsNuked)). Approval \(Int(gs.shadow.popularity.rounded()))% "
            + "(\(trend == 0 ? "steady" : signed(trend) + " lately")). Habits: \(habits.isEmpty ? "none shown" : habits.joined(separator: ", "))."
    }

    /// The ticker is written to the player ("your presidency ends…"); those lines are his desk, not world news.
    static func addressesThePlayer(_ text: String) -> Bool {
        text.lowercased().split { !$0.isLetter }.contains { $0 == "you" || $0 == "your" || $0 == "mr" }
    }

    static func compose(_ c: Country, _ gs: GameState, _ caps: Caps, spectating: Bool) -> String {
        var out: [String] = []
        let year = gs.currentYear
        out.append("You are \(c.name) [\(c.id)] in \(year). Alignment: \(c.alignment.rawValue). Government: \(c.government.rawValue).")
        out.append(NationCharacterTable.shared.character(for: c, difficulty: gs.difficultyLevel).brief(c.profile))

        // Own state (true).
        let sdi = c.hasSDI ? "\(c.sdiCoverage)% coverage" : "none"
        out.append("Your forces (true): military \(c.militaryStrength)/100 (ground \(c.groundForces), naval \(c.navalForces), air \(c.airForces)); "
                   + "warheads \(c.nuclearWarheads) (ICBM \(c.icbmCount), SLBM \(c.submarineLaunchedMissiles), bombers \(c.bombers)); "
                   + "cyber offense \(c.cyberOffenseLevel)/100, defense \(c.cyberDefenseLevel); missile defense \(sdi). "
                   + "Stability \(c.stability)/100, approval \(c.publicApproval)/100, aggression \(c.aggressionLevel)/100.")
        let sanctions = c.economicSanctions.sorted()
        out.append("Your economy: GDP \(money(billions: c.gdp * 1000)), treasury \(money(billions: Double(c.treasury) / 1e9)), "
                   + "debt \(c.debtLevel)% of GDP, trade deals \(c.tradeAgreements.count), "
                   + "sanctioned by \(sanctions.isEmpty ? "nobody" : sanctions.prefix(4).joined(separator: ", ")).")

        // Relations.
        let live = Set(gs.liveCountries.map(\.id))
        let rels = c.diplomaticRelations.filter { k, _ in live.contains(k) }
        let friends = rels.filter { $0.value > 0 }.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(caps.friends)
        let rivals = rels.filter { $0.value < 0 }.sorted { ($0.value, $0.key) < ($1.value, $1.key) }.prefix(caps.friends)
        out.append("Friends: \(friends.isEmpty ? "none" : friends.map { "\($0.key) \(signed($0.value))" }.joined(separator: ", ")). "
                   + "Rivals: \(rivals.isEmpty ? "none" : rivals.map { "\($0.key) \($0.value)" }.joined(separator: ", ")).")
        let treaties = gs.treaties.filter { $0.signatories.contains(c.id) }.suffix(caps.treaties)
            .map { "\($0.type.rawValue) with \($0.signatories.filter { $0 != c.id }.joined(separator: "/"))" }
        let bl = blocs(c, year: year)
        out.append("Allies: \(c.alliances.isEmpty ? "none" : c.alliances.sorted().joined(separator: ", ")). "
                   + "Blocs: \(bl.isEmpty ? "none" : bl.joined(separator: ", ")). Treaties: \(treaties.isEmpty ? "none" : treaties.joined(separator: "; ")).")
        out.append("At war with: \(c.atWarWith.isEmpty ? "nobody" : c.atWarWith.sorted().joined(separator: ", ")).")

        // Other nations, as this government sees them.
        let list = relevant(c, in: gs, cap: caps.nations)
        if !list.isEmpty {
            out.append("Other nations (rel = relation -100..100; your ESTIMATES ~value[source,turns old], not the truth; reach = how you could strike them):")
            out.append(contentsOf: list.map { nationLine($0, for: c, in: gs) })
        }

        // The world.
        let wars = gs.activeWars.map { "\($0.aggressor)>\($0.defender)" }
        out.append("World: \(gs.defconName) \(gs.defconLevel.rawValue). Wars (\(wars.count)): "
                   + (wars.isEmpty ? "none" : wars.prefix(caps.wars).joined(separator: ", ") + (wars.count > caps.wars ? ", …" : "")) + ".")
        let events = gs.shadow.ticker.filter { $0.severity >= 2 && !addressesThePlayer($0.text) }.suffix(caps.events)
            .map { WorldBriefModel.sanitize($0.text, max: 110) }
        if !events.isEmpty { out.append("Recent events: " + events.joined(separator: " | ")) }
        if let b = gs.shadow.worldBrief {
            let mine = b.pairs.filter { $0.a == c.id || $0.b == c.id }.sorted { ($0.weight, $1.a) > ($1.weight, $0.a) }.prefix(caps.brief)
            let head = b.headlines[c.id].map { " Headline: \(WorldBriefModel.sanitize($0, max: 100))" } ?? ""
            if !mine.isEmpty || !head.isEmpty {
                out.append("Real-world brief \(b.day): " + (mine.isEmpty ? "nothing about you." : mine.map { "\($0.a)>\($0.b) \($0.kind) \($0.weight)" }.joined(separator: ", ")) + head)
            }
        }

        // The player.
        if let p = playerLine(c, in: gs, spectating: spectating) { out.append(p) } else { out.append("You hold the player's seat.") }

        // Memory.
        let memory = (gs.shadow.brainMemory[c.id] ?? []).suffix(caps.memory)
        if memory.isEmpty {
            out.append("Your last moves: none yet.")
        } else {
            out.append("Your last moves (oldest first): " + memory.map { m in
                "turn \(m.turn) \(m.action)\(m.target.map { " " + $0 } ?? "")"
                    + (m.rationale.isEmpty ? "" : " \"\(m.rationale)\"") + (m.outcome.map { " (\($0))" } ?? "")
            }.joined(separator: "; ") + ". Current intent: \(memory.last!.intent).")
        }
        if let h = HistoricalWars.line(year: year) { out.append("History: \(h)") }
        return out.joined(separator: "\n")
    }
}
