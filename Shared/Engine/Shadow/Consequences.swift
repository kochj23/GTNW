//
//  Consequences.swift
//  Global Thermal Nuclear War
//
//  3.36.0: what happens after. The engine already priced a strike (the nuclear taboo, DEFCON, retaliation) and a
//  banned weapon (the 3.6.0 treaty cost and the 3.17.0 tribunal); this file adds what the world does next:
//    • A strike on a nation that has surrendered to you, is at peace with you under signed terms, or is a friend
//      (relations above +40): the command card says so before EXECUTE; afterwards an international tribunal opens a
//      case (the dirty-tactics tribunal, from 1945), allies distance themselves and approval falls.
//    • Fallout drift: radiation, deaths and unrest carried to nearby nations by distance and the prevailing wind
//      (westerlies at 30–65° of latitude, trade winds nearer the equator). Deterministic; no dice.
//    • Refugees: people flee a struck or invaded nation into its neighbors, and toward the player's own borders when
//      they are close; that reaches the President as a decision (take them in, aid the region, close the border).
//    • Attacking an ally: an emergency alliance council; if the attack goes on past the next turn the alliance
//      expels you and its members turn away. The victim's territories react, and lands the map draws under the
//      victim (Greenland under Denmark) can break away and govern themselves.
//    • After office: when the presidency ends (removed, beaten, or served out) and the record holds such acts, the
//      end screen adds a short trial: the charges as they were written down at the time, and a verdict that
//      follows from them. Neutral words, no embellishment.
//    • 3.37.0: the expelling alliance answers. After the expulsion its members weigh war on the President: the angrier
//      (relations), the nearer and the stronger a member is, the likelier it declares (`allianceRevenge*` constants,
//      one draw from the game's seeded RNG per member, in id order). Most stand aside; the news names who went.
//  Everything is recorded in `ShadowState.consequences`; nothing else here draws from the RNG.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - State

/// What the President did that a court could charge.
enum ConductKind: String, Codable, CaseIterable {
    case nuclearOnSurrendered, nuclearOnPeace, nuclearOnFriend, attackOnSurrendered, attackOnAlly, bannedWeapon

    /// The count as a court would name it.
    var charge: String {
        switch self {
        case .nuclearOnSurrendered: return "War crime: a nuclear attack on a nation that had surrendered"
        case .nuclearOnPeace: return "War crime: a nuclear attack on a nation at peace under signed terms"
        case .nuclearOnFriend: return "War crime: a nuclear attack on a nation not at war with you"
        case .attackOnSurrendered: return "War crime: an armed attack on a nation that had surrendered"
        case .attackOnAlly: return "Crime of aggression: an attack on a treaty ally"
        case .bannedWeapon: return "War crime: the use of a treaty-banned weapon"
        }
    }

    /// How heavily the count weighs in the verdict (design choice).
    var weight: Int {
        switch self {
        case .nuclearOnSurrendered: return 4
        case .nuclearOnPeace, .nuclearOnFriend: return 3
        case .attackOnSurrendered, .attackOnAlly, .bannedWeapon: return 2
        }
    }
}

/// One act on the record, written when it happened.
struct ConductRecord: Codable, Hashable {
    var kind: ConductKind
    var target: String
    var date: Date
    /// The line as it was recorded; the trial quotes it verbatim.
    var text: String
}

/// An emergency council called because the President attacked a member.
struct AllianceCouncil: Codable, Hashable {
    var victim: String
    /// "NATO", "the Warsaw Pact", or "the alliance with Denmark".
    var alliance: String
    var bloc: Bool
    var members: [String]
    var opened: Date
    var turn: Int
    var lastAttack: Date
    var expelled = false
    var closed = false
}

/// People who fled a struck or invaded nation.
struct RefugeeWave: Codable, Hashable, Identifiable {
    var id = UUID()
    var origin: String
    /// Who caused it (the striker or invader).
    var cause: String
    var date: Date
    /// Thousands of people, by receiving nation.
    var receivers: [String: Int]
    /// The President's answer when they reached his border: "accept", "aid" or "close".
    var playerChoice: String?
    var total: Int { receivers.values.reduce(0, +) }
}

/// Everything this file keeps between turns. Lives on `ShadowState.consequences`; older saves load it empty.
struct ConsequenceState: Codable, Hashable {
    var conduct: [ConductRecord] = []
    var councils: [AllianceCouncil] = []
    var waves: [RefugeeWave] = []
    /// Alliances that expelled the player ("NATO").
    var expelledFrom: [String] = []
    /// Lands that broke away from a victim of the player's attack.
    var brokenAway: [String] = []
    static let waveCap = 60

    enum CodingKeys: String, CodingKey { case conduct, councils, waves, expelledFrom, brokenAway }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conduct = (try? c.decodeIfPresent([ConductRecord].self, forKey: .conduct)) ?? []
        councils = (try? c.decodeIfPresent([AllianceCouncil].self, forKey: .councils)) ?? []
        waves = (try? c.decodeIfPresent([RefugeeWave].self, forKey: .waves)) ?? []
        expelledFrom = (try? c.decodeIfPresent([String].self, forKey: .expelledFrom)) ?? []
        brokenAway = (try? c.decodeIfPresent([String].self, forKey: .brokenAway)) ?? []
    }
}

// MARK: - Rules (pure)

enum Consequences {
    /// Why a target is protected from attack.
    enum Protection: Equatable {
        case surrendered, peace, friend(Int)
    }

    /// 3.37.0: how readily an expelling alliance's members go to war on the President (1 = as designed, 0 = never).
    static let allianceRevengeScale = 1.0
    /// At most this many members declare war after one expulsion.
    static let allianceRevengeMaxWars = 8
    /// Distance (km) at which nearness counts half.
    static let allianceRevengeReachKm = 3000.0

    /// 3.37.0: the chance (0…0.9) a member of the alliance that expelled the President declares war on him: hostility
    /// (relations below zero), nearness, and its strength against his. Pure.
    static func revengeChance(relations: Int, distanceKm: Double, strength: Int, playerStrength: Int) -> Double {
        let hostility = min(1, max(0, Double(-relations) / 100))
        let near = 1 / (1 + max(0, distanceKm.isFinite ? distanceKm : 20_000) / allianceRevengeReachKm)
        let capacity = min(1, Double(max(0, strength)) / Double(max(1, playerStrength)))
        let p = allianceRevengeScale * (0.1 + 0.6 * hostility) * (0.4 + 0.6 * near) * (0.3 + 0.7 * capacity)
        return min(0.9, max(0, p))
    }

    /// Relations above this make a nation a friend whose bombing is a crime, not a war.
    static let friendRelation = 40
    /// How far fallout carries beyond a land border, km.
    static let falloutReachKm = 1500.0
    /// How close a struck nation must be for its refugees to head for the President's own borders, km.
    static let refugeeReachKm = 2500.0
    /// The first year an international court can hear the case (Nuremberg and Tokyo).
    static let courtsFrom = 1945

    /// Has the target surrendered to the player, signed a peace with the player, or is it a friend? nil = none of
    /// these (or the two are at war again).
    static func protection(of target: String, in gs: GameState) -> Protection? {
        let me = gs.playerCountryID
        guard target != me, let t = gs.getCountry(id: target), let p = gs.getPlayerCountry(), t.territoryOf != me else { return nil }
        let sh = gs.shadow
        if sh.pendingSettlements.contains(where: { $0.loser == target && $0.victor == me })
            || sh.peaceTerms.contains(where: { $0.victor == me && $0.loser == target && !$0.broken && !$0.negotiated })
            || (!p.atWarWith.contains(target)
                && sh.fronts.contains { $0.defender == target && $0.status == .attackerWon && ($0.attacker == me || $0.usSide == $0.attacker) }) {
            return .surrendered
        }
        if p.atWarWith.contains(target) { return nil }
        if sh.peaceTerms.contains(where: { !$0.broken && Set([$0.victor, $0.loser]) == [me, target] })
            || gs.treaties.contains(where: { $0.type == .nonAggression && Set($0.signatories) == [me, target] }) {
            return .peace
        }
        let rel = p.diplomaticRelations[target] ?? 0
        return rel > friendRelation ? .friend(rel) : nil
    }

    /// The alliance an attack on `target` would betray, and its other members on the board. nil = not an ally.
    static func alliance(with target: String, in gs: GameState) -> (name: String, bloc: Bool, members: [String])? {
        let me = gs.playerCountryID, year = gs.currentYear
        guard target != me, let t = gs.getCountry(id: target), t.territoryOf != me, let p = gs.getPlayerCountry() else { return nil }
        let live = Set(gs.countries.filter { !$0.isDestroyed && $0.territoryOf == nil }.map(\.id))
        let expelled = Set(gs.shadow.consequences.expelledFrom)
        for (name, set) in [("NATO", MilitaryAllianceSystem.natoMembers(year: year)),
                            ("the Warsaw Pact", MilitaryAllianceSystem.warsawPactMembers(year: year))]
        where set.contains(me) && set.contains(target) && !expelled.contains(name) {
            return (name, true, set.intersection(live).subtracting([me]).sorted())
        }
        if p.alliances.contains(target) || t.alliances.contains(me) {
            return ("the alliance with \(t.name)", false, [target])
        }
        return nil
    }

    /// Lands the map draws under a nation without a government of their own in the game, which govern themselves
    /// when that nation is attacked by an ally (3.36.0). Keep it short and factual.
    static let dependentLands: [String: [CountryTemplate]] = [
        "DNK": [CountryTemplate("GRL", "Greenland", flag: "🇬🇱", capital: "Nuuk", lat: 64.18, lon: -51.72, region: .northAmerica,
                                gov: .democracy, align: .independent, gdp: 3.0, pop: 0.056, mil: 1, aggr: 5, stab: 80)],
    ]

    /// The dependent lands of `victim` the map currently draws under it.
    static func breakawayLands(of victim: String, in gs: GameState) -> [CountryTemplate] {
        guard gs.getCountry(id: victim).map({ !$0.isDestroyed }) == true else { return [] }
        let present = Set(gs.countries.filter { !$0.isDestroyed }.map(\.id))
        return (dependentLands[victim] ?? []).filter { land in
            gs.getCountry(id: land.id) == nil && WorldMapData.owner(of: land.id, in: present, year: gs.currentYear) == victim
        }
    }

    /// Longitude difference b − a, wrapped to −180…180.
    static func deltaLon(_ a: Double, _ b: Double) -> Double {
        var d = b - a
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    /// Wind factor for fallout carried from `from` toward `to`: the westerlies (30–65° of latitude) carry it east,
    /// the trade winds nearer the equator carry it west, and little reaches upwind.
    static func windFactor(from: Coordinates, to: Coordinates) -> Double {
        let east = deltaLon(from.lon, to.lon) > 0
        let westerlies = abs(from.lat) >= 30 && abs(from.lat) <= 65
        let downwind = westerlies ? east : !east
        return downwind ? 1.5 : 0.6
    }

    /// Where the fallout of a strike on `target` with `radiation` points lands: up to eight nations, most first.
    static func drift(from target: String, radiation: Int, in gs: GameState) -> [(id: String, radiation: Int)] {
        guard radiation > 0, let t = gs.getCountry(id: target) else { return [] }
        let neighbors = Reach.landNeighbors(target, in: gs)
        var out: [(String, Int)] = []
        for c in gs.countries where c.id != target && !c.isDestroyed {
            let km = Reach.distanceKm(t.coordinates, c.coordinates)
            let land = neighbors.contains(c.id)
            guard land || km <= falloutReachKm else { continue }
            let near = max(land ? 0.25 : 0, 1 - km / falloutReachKm) * 0.4
            let amount = Int((Double(radiation) * near * windFactor(from: t.coordinates, to: c.coordinates)).rounded())
            if amount >= 1 { out.append((c.id, amount)) }
        }
        return out.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }.prefix(8).map { (id: $0.0, radiation: $0.1) }
    }

    /// Where refugees from `origin` go: its land neighbors (or, for an island, the nearest nations within reach),
    /// and the player's nation when it is close. Thousands of people each, an even share.
    static func refugeeShares(from origin: String, thousands: Int, in gs: GameState) -> [String: Int] {
        guard thousands > 0, let o = gs.getCountry(id: origin) else { return [:] }
        let me = gs.playerCountryID
        var to = Reach.landNeighbors(origin, in: gs).filter { id in gs.getCountry(id: id).map { !$0.isDestroyed } ?? false }.sorted()
        if to.isEmpty {
            let others = gs.countries.filter { $0.id != origin && !$0.isDestroyed && $0.territoryOf == nil }
            var near: [(id: String, km: Double)] = others.map { c in (id: c.id, km: Reach.distanceKm(o.coordinates, c.coordinates)) }
            near = near.filter { $0.km <= 2000 }
            near.sort { a, b in a.km != b.km ? a.km < b.km : a.id < b.id }
            to = near.prefix(3).map { $0.id }
        }
        if origin != me, !to.contains(me), Reach.nearestKm(origin, me, in: gs) <= refugeeReachKm { to.append(me) }
        guard !to.isEmpty else { return [:] }
        let each = max(1, thousands / to.count)
        return Dictionary(uniqueKeysWithValues: to.map { ($0, each) })
    }

    /// "1,200 thousand" reads badly: people as "about 1.2 million" or "45,000".
    static func people(thousands k: Int) -> String {
        if k >= 1000 {
            let tenths = (k + 50) / 100
            return "about \(tenths / 10).\(tenths % 10) million"
        }
        return "about \((k * 1000).formatted())"
    }

    /// Names joined for a sentence: "A", "A and B", "A, B and C".
    static func list(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }

    // MARK: The trial

    /// Endings that put a former President before a court: removed, beaten at the polls, or out at the end of a term.
    static let trialEndings: Set<DomesticEnding> = [.impeached, .lostElection, .termLimited, .retired, .deniedRenomination,
                                                    .noConfidence, .coup, .revolution, .partyCongress, .juntaDecision, .royalDismissal,
                                                    .removedByCouncil, .resigned, .abdicated]

    /// The counts on the record: what was written down at the time, plus treaty-banned tactics used openly or
    /// traced back. Oldest first.
    static func counts(_ gs: GameState) -> [ConductRecord] {
        var out = gs.shadow.consequences.conduct
        for u in gs.shadow.tacticUses where !u.covert || u.discovered {
            guard let t = DirtyTactics.tactic(u.tactic), t.status(in: GameCalendar.year(of: u.date)) == .treatyBanned else { continue }
            let whom = u.target.flatMap { gs.getCountry(id: $0)?.name }.map { " against \($0)" } ?? ""
            out.append(ConductRecord(kind: .bannedWeapon, target: u.target ?? "", date: u.date,
                                     text: "\(GameCalendar.format(u.date)): \(t.name)\(whom) (\(u.covert ? "covert, traced back" : "open"), treaty-banned)."))
        }
        return out.sorted { $0.date < $1.date }
    }

    /// The sentence for a weight of proven counts (design choice).
    static func sentence(weight: Int) -> String {
        weight >= 8 ? "life imprisonment" : weight >= 4 ? "20 years' imprisonment" : "10 years' imprisonment"
    }

    /// The court that hears the case in the year the presidency ended.
    static func court(year: Int) -> String {
        year < 1993 ? "an international military tribunal" : year < 2002 ? "an international criminal tribunal" : "the International Criminal Court"
    }

    /// The trial the end screen shows, or nil when the presidency did not end that way or the record is clean.
    static func trial(_ gs: GameState) -> DebriefLine? {
        guard let ending = gs.shadow.domesticEnding, trialEndings.contains(ending) else { return nil }
        let all = counts(gs)
        guard !all.isEmpty else { return nil }
        let year = gs.currentYear
        let who = gs.playerCountryID == "USA" ? "the former President" : "the former leader of \(gs.getPlayerCountry()?.name ?? gs.playerCountryID)"
        let triable = all.filter { GameCalendar.year(of: $0.date) >= courtsFrom }
        var lines = all.enumerated().map { "Count \($0.offset + 1). \($0.element.kind.charge). The record: \($0.element.text)" }
        if year < courtsFrom || triable.isEmpty {
            lines.insert("No international court sits in \(year) to hear these counts against \(who). They stand on the record without a verdict.", at: 0)
            return DebriefLine(title: "THE RECORD BEFORE ANY COURT", body: lines.joined(separator: "\n"))
        }
        lines.insert("After leaving office, \(who) is tried before \(court(year: year)) on \(all.count) count\(all.count == 1 ? "" : "s").", at: 0)
        let weight = triable.reduce(0) { $0 + $1.kind.weight }
        let untried = all.count - triable.count
        var verdict = "Verdict: guilty on \(triable.count) count\(triable.count == 1 ? "" : "s")"
        if untried > 0 { verdict += "; \(untried) predate\(untried == 1 ? "s" : "") any international court and \(untried == 1 ? "is" : "are") not tried" }
        verdict += ". Sentence: \(sentence(weight: weight))."
        lines.append(verdict)
        return DebriefLine(title: "THE TRIAL", body: lines.joined(separator: "\n"))
    }
}

// MARK: - Engine

extension GameEngine {

    /// The warnings the command card adds before a hostile order (3.36.0).
    func consequenceWarnings(_ target: Country, in gs: GameState, nuclear: Bool) -> [CommandWarning] {
        var out: [CommandWarning] = []
        let court = gs.currentYear >= Consequences.courtsFrom ? "an international war-crimes case, " : ""
        switch Consequences.protection(of: target.id, in: gs) {
        case .surrendered?:
            out.append(CommandWarning(text: "\(target.name) has already surrendered to you. Attacking it now means \(court)a fall in approval, and your allies distancing themselves.", level: 2))
        case .peace? where nuclear:
            out.append(CommandWarning(text: "\(target.name) is at peace with you under signed terms. A nuclear strike on it means \(court)a fall in approval, and your allies distancing themselves.", level: 2))
        case .friend(let rel)? where nuclear:
            out.append(CommandWarning(text: "\(target.name) is a friend (relations +\(rel)). A nuclear strike on it means \(court)a fall in approval, and your allies distancing themselves.", level: 2))
        default:
            break
        }
        if let a = Consequences.alliance(with: target.id, in: gs) {
            let council = a.bloc ? "\(a.name) calls an emergency council; if the attack goes on, \(a.name) expels you and its members turn against you."
                : "\(target.name) will end the alliance if the attack goes on."
            out.append(CommandWarning(text: "\(target.name) is your ally. \(council)", level: 2))
            let lands = Consequences.breakawayLands(of: target.id, in: gs).map(\.name)
                + gs.countries.filter { $0.territoryOf == target.id && !$0.isDestroyed }.map(\.name).sorted()
            if !lands.isEmpty {
                out.append(CommandWarning(text: "\(target.name)'s territories will turn against you: \(Consequences.list(Array(lands.prefix(4)))).", level: 1))
            }
        }
        if nuclear {
            let drift = Consequences.drift(from: target.id, radiation: 50, in: gs).compactMap { gs.getCountry(id: $0.id)?.name }
            if !drift.isEmpty {
                out.append(CommandWarning(text: "Fallout will drift over \(Consequences.list(Array(drift.prefix(4)))), and they will hold you responsible.", level: 1))
            }
            let shares = Consequences.refugeeShares(from: target.id, thousands: 100, in: gs)
            if shares[gs.playerCountryID] != nil {
                out.append(CommandWarning(text: "Refugees from \(target.name) will reach your own borders.", level: 1))
            }
        }
        return out
    }

    /// After every nuclear detonation (called by `launchNuclearStrike`): fallout drifts, people flee, and when the
    /// player struck a protected nation or an ally, the world answers.
    func nuclearAftermath(attacker: String, target: String, radiation: Int, casualties: Int) {
        guard let gs = gameState, gs.getCountry(id: target) != nil else { return }
        let me = gs.playerCountryID
        if attacker == me {
            if let p = Consequences.protection(of: target, in: gs) { punishProtectedAttack(target, protection: p, nuclear: true) }
            if Consequences.alliance(with: target, in: gs) != nil { attackOnAlly(target, how: "a nuclear strike") }
        }
        driftFallout(from: target, attacker: attacker, radiation: radiation)
        if let t = gs.getCountry(id: target) {
            let fled = min(t.population * 300, max(1, casualties / 1000 * 2))   // thousands: twice the dead, ≤ 30%
            sendRefugees(from: target, cause: attacker, thousands: fled, why: "after the nuclear strike")
        }
    }

    /// A war the player declares (called by `declareWar` before the war is recorded).
    func playerWarConsequences(on defender: String) {
        guard let gs = gameState, let d = gs.getCountry(id: defender) else { return }
        if Consequences.protection(of: defender, in: gs) == .surrendered {
            punishProtectedAttack(defender, protection: .surrendered, nuclear: false)
        }
        if Consequences.alliance(with: defender, in: gs) != nil { attackOnAlly(defender, how: "a war") }
        sendRefugees(from: defender, cause: gs.playerCountryID, thousands: max(1, d.population * 30), why: "as war comes")
    }

    /// A treaty-banned chemical or biological weapon used by the player (called by `executeWMD`).
    func noteBannedWeapon(_ kindTitle: String, target: String) {
        guard let gs = gameState else { return }
        let name = gs.getCountry(id: target)?.name ?? target
        gs.shadow.consequences.conduct.append(ConductRecord(kind: .bannedWeapon, target: target, date: gs.currentDate,
            text: "\(GameCalendar.format(gs.currentDate)): \(kindTitle) weapons used against \(name) (treaty-banned)."))
        self.gameState = gs
    }

    /// The 3.17.0 war-crimes tribunal: ruthlessness, approval, articles of impeachment and a headline. Shared by
    /// the dirty-tactics exposure and the 3.36.0 strikes on protected nations.
    func openWarCrimesTribunal(_ headline: String, event: String, detail: [String: Any]) {
        guard let g = gameState else { return }
        g.shadow.ruthlessness += 20
        g.shadow.popularity = PopularityModel.clamp(g.shadow.popularity - 10)
        g.shadow.impeachmentStage = max(g.shadow.impeachmentStage, 2)
        g.shadow.post(headline, date: g.currentDate, severity: 3)
        var d = detail
        d["game_date"] = PlayHistory.day(g.currentDate)
        logPlayEvent(event, detail: d)
        self.gameState = g
    }

    /// Striking a nation that surrendered, signed a peace or is a friend: on the record, a tribunal (from 1945), an
    /// approval hit, and allies distancing themselves.
    func punishProtectedAttack(_ target: String, protection: Consequences.Protection, nuclear: Bool) {
        guard let gs = gameState, let me = gs.getPlayerCountry(), let t = gs.getCountry(id: target) else { return }
        let date = GameCalendar.format(gs.currentDate)
        let what = nuclear ? "nuclear strike on" : "attack on"
        let kind: ConductKind
        let why: String
        switch protection {
        case .surrendered: kind = nuclear ? .nuclearOnSurrendered : .attackOnSurrendered; why = "which had surrendered to \(me.name)"
        case .peace: kind = .nuclearOnPeace; why = "which was at peace with \(me.name) under signed terms"
        case .friend(let r): kind = .nuclearOnFriend; why = "which was not at war with \(me.name) (relations +\(r))"
        }
        gs.shadow.consequences.conduct.append(ConductRecord(kind: kind, target: target, date: gs.currentDate,
                                                            text: "\(date): \(me.name) ordered a \(what) \(t.name), \(why)."))
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 8)
        let allies = gs.countries.filter { c in
            c.id != me.id && c.id != target && !c.isDestroyed && c.territoryOf == nil
                && (me.alliances.contains(c.id) || MilitaryAllianceSystem.areAllied(country1: me.id, country2: c.id, year: gs.currentYear))
        }.sorted { $0.id < $1.id }
        for a in allies { gs.modifyRelation(from: a.id, to: me.id, by: -15) }
        if !allies.isEmpty {
            gs.shadow.post("\(Consequences.list(allies.prefix(4).map(\.name)))\(allies.count > 4 ? " and other allies" : "") distance themselves from \(me.name) after the \(what) \(t.name).",
                           date: gs.currentDate, severity: 2)
        }
        self.gameState = gs
        if gs.currentYear >= Consequences.courtsFrom {
            openWarCrimesTribunal("An international tribunal opens a case over \(me.name)'s \(what) \(t.name), \(why). Articles of impeachment are drafted.",
                                  event: "consequence_tribunal", detail: ["kind": kind.rawValue, "target": target])
        }
    }

    /// An ally attacked: the emergency council opens (or, already open, notes the attack goes on); the victim's
    /// territories turn away.
    func attackOnAlly(_ victim: String, how: String) {
        guard let gs = gameState, let me = gs.getPlayerCountry(), let v = gs.getCountry(id: victim),
              let a = Consequences.alliance(with: victim, in: gs) else { return }
        if let i = gs.shadow.consequences.councils.firstIndex(where: { $0.victim == victim && !$0.closed && !$0.expelled }) {
            gs.shadow.consequences.councils[i].lastAttack = gs.currentDate
            self.gameState = gs
            return
        }
        let date = gs.currentDate
        gs.shadow.consequences.councils.append(AllianceCouncil(victim: victim, alliance: a.name, bloc: a.bloc, members: a.members,
                                                               opened: date, turn: gs.turn, lastAttack: date))
        gs.shadow.consequences.conduct.append(ConductRecord(kind: .attackOnAlly, target: victim, date: date,
            text: "\(GameCalendar.format(date)): \(me.name) opened \(how) against \(v.name), a member of \(a.name)."))
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 5)
        gs.modifyRelation(from: victim, to: me.id, by: -30)
        for m in a.members where m != victim { gs.modifyRelation(from: m, to: me.id, by: -15) }
        if a.bloc {
            gs.shadow.post("\(a.name) calls an emergency council after \(me.name) attacks \(v.name), a member. Continue, and \(me.name) is expelled.",
                           date: date, severity: 3)
        } else {
            gs.shadow.post("\(v.name) appeals to the world after \(me.name), its ally, attacks it.", date: date, severity: 3)
        }
        for i in gs.countries.indices where gs.countries[i].territoryOf == victim && !gs.countries[i].isDestroyed {
            gs.countries[i].stability = max(0, gs.countries[i].stability - 10)
            gs.modifyRelation(from: gs.countries[i].id, to: me.id, by: -30)
            gs.shadow.post("\(gs.countries[i].name) stands with \(v.name) and turns away from \(me.name).", date: date, severity: 1)
        }
        logPlayEvent("ally_council", detail: ["victim": victim, "alliance": PlayHistory.text(a.name), "game_date": PlayHistory.day(date)])
        self.gameState = gs
    }

    /// Fallout carried to nearby nations: radiation, deaths, unrest, and their anger at whoever fired.
    func driftFallout(from target: String, attacker: String, radiation: Int) {
        guard let gs = gameState, let t = gs.getCountry(id: target) else { return }
        let drift = Consequences.drift(from: target, radiation: radiation, in: gs)
        guard !drift.isEmpty else { return }
        var deaths = 0
        var names: [String] = []
        for d in drift {
            guard let i = gs.countries.firstIndex(where: { $0.id == d.id }) else { continue }
            gs.countries[i].radiationLevel = min(100, gs.countries[i].radiationLevel + d.radiation)
            let dead = min(gs.countries[i].population * 20_000, d.radiation * max(1, gs.countries[i].population) * 100)
            deaths += dead
            gs.countries[i].stability = max(0, gs.countries[i].stability - min(15, d.radiation / 2 + 1))
            gs.countries[i].profile.outcry = min(100, gs.countries[i].profile.outcry + Double(d.radiation))
            if d.id != attacker { gs.modifyRelation(from: d.id, to: attacker, by: -min(40, 10 + d.radiation)) }
            names.append("\(gs.countries[i].name) (+\(d.radiation))")
        }
        gs.totalCasualties += deaths
        gs.shadow.post("Fallout from the strike on \(t.name) drifts over \(Consequences.list(Array(names.prefix(5)))): radiation rises and an estimated \(deaths.formatted()) more die.",
                       date: gs.currentDate, severity: 2)
        self.gameState = gs
    }

    /// People flee `origin`; neighbors absorb them (unrest), and the President decides at his own border.
    func sendRefugees(from origin: String, cause: String, thousands: Int, why: String) {
        guard let gs = gameState, let o = gs.getCountry(id: origin) else { return }
        let shares = Consequences.refugeeShares(from: origin, thousands: thousands, in: gs)
        guard !shares.isEmpty else { return }
        let wave = RefugeeWave(origin: origin, cause: cause, date: gs.currentDate, receivers: shares)
        gs.shadow.consequences.waves.append(wave)
        if gs.shadow.consequences.waves.count > ConsequenceState.waveCap {
            gs.shadow.consequences.waves.removeFirst(gs.shadow.consequences.waves.count - ConsequenceState.waveCap)
        }
        if let oi = gs.countries.firstIndex(where: { $0.id == origin }) { gs.countries[oi].refugeeCount += wave.total * 1000 }
        let me = gs.playerCountryID
        for (id, k) in shares.sorted(by: { $0.key < $1.key }) where id != me {
            guard let i = gs.countries.firstIndex(where: { $0.id == id }) else { continue }
            gs.countries[i].acceptedRefugees += k * 1000
            let pressure = Double(k) / Double(max(1, gs.countries[i].population) * 1000)
            gs.countries[i].stability = max(0, gs.countries[i].stability - min(10, max(1, Int(pressure * 400))))
        }
        let neighbors = shares.keys.filter { $0 != me }.sorted().compactMap { gs.getCountry(id: $0)?.name }
        let into = neighbors.isEmpty ? "" : " into \(Consequences.list(Array(neighbors.prefix(4))))\(neighbors.count > 4 ? " and beyond" : "")"
        gs.shadow.post("\(Consequences.people(thousands: wave.total).prefix(1).uppercased())\(Consequences.people(thousands: wave.total).dropFirst()) people flee \(o.name) \(why)\(into).",
                       date: gs.currentDate, severity: 2)
        self.gameState = gs
        if let k = shares[me] { crisisManager.presentCrisis(refugeeCard(wave, thousands: k, in: gs)) }
    }

    /// The decision at the President's own border: take them in, aid the region, or close the border.
    func refugeeCard(_ wave: RefugeeWave, thousands k: Int, in gs: GameState) -> CrisisEvent {
        let o = gs.getCountry(id: wave.origin)
        let name = o?.name ?? wave.origin
        let mine = wave.cause == gs.playerCountryID
        let others = wave.receivers.keys.filter { $0 != gs.playerCountryID }.sorted()
        func opt(_ title: String, _ desc: String, _ advisor: String, _ k: CrisisConsequences, _ choice: String) -> CrisisOption {
            var k = k
            k.shadowChoice = choice
            return CrisisOption(title: title, description: desc, advisorRecommendation: advisor, consequences: k)
        }
        let aid = WorldWatch.aidBillions(gs, scale: 1)
        let options = [
            opt("Take them in", "Open the border and resettle them. Costly and unpopular with some voters; respected abroad.",
                "Secretary of State",
                CrisisConsequences(approvalChange: -2, message: "The border opens; \(Consequences.people(thousands: k)) people from \(name) are taken in.",
                                   mutualRelations: [wave.origin: 10]),
                "refugees|\(wave.id.uuidString)|accept|0"),
            opt("Aid the region", "Camps, food and doctors where they are, paid for by Washington. $\(aid)B.",
                "National Security Advisor",
                CrisisConsequences(approvalChange: 0, message: "Aid flows to the camps around \(name).",
                                   mutualRelations: Dictionary(uniqueKeysWithValues: ([wave.origin] + others).map { ($0, 5) }),
                                   countryStability: Dictionary(uniqueKeysWithValues: others.map { ($0, 2) })),
                "refugees|\(wave.id.uuidString)|aid|\(aid)"),
            opt("Close the border", "Turn them back. Popular with some at home; remembered abroad.",
                "Chief of Staff",
                CrisisConsequences(approvalChange: 1, message: "The border is closed to refugees from \(name).",
                                   mutualRelations: Dictionary(uniqueKeysWithValues: ([wave.origin] + others).map { ($0, $0 == wave.origin ? -10 : -5) })),
                "refugees|\(wave.id.uuidString)|close|0"),
        ]
        return CrisisEvent(type: .worldDisaster, severity: .serious, title: "REFUGEES FROM \(name.uppercased())",
                           description: "\(Consequences.people(thousands: k).prefix(1).uppercased())\(Consequences.people(thousands: k).dropFirst()) people fleeing \(name)\(mine ? ", after your own attack," : "") are at the border. The cabinet is divided.",
                           affectedCountries: [gs.playerCountryID], turn: gs.turn, options: options)
    }

    /// Each turn: alliance councils decide — expel the player if the attack went on, or close with a reprimand.
    func processConsequenceTurn() {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return }
        for i in gs.shadow.consequences.councils.indices {
            let c = gs.shadow.consequences.councils[i]
            guard !c.closed, !c.expelled, gs.turn > c.turn else { continue }
            let goesOn = me.atWarWith.contains(c.victim) || c.lastAttack > c.opened
                || gs.shadow.fronts.contains { $0.status == .fighting && $0.defender == c.victim && ($0.attacker == me.id || $0.usSide == $0.attacker) }
            if goesOn {
                expel(councilIndex: i)
            } else {
                gs.shadow.consequences.councils[i].closed = true
                gs.shadow.post("The \(c.alliance) council closes with a formal reprimand of \(me.name).", date: gs.currentDate, severity: 1)
                self.gameState = gs
            }
        }
    }

    /// The alliance expels the player: alliance links and treaties with its members end, members turn away, and the
    /// victim's dependent lands govern themselves.
    func expel(councilIndex i: Int) {
        guard let gs = gameState, gs.shadow.consequences.councils.indices.contains(i), let me = gs.getPlayerCountry() else { return }
        var c = gs.shadow.consequences.councils[i]
        c.expelled = true
        c.closed = true
        gs.shadow.consequences.councils[i] = c
        if c.bloc, !gs.shadow.consequences.expelledFrom.contains(c.alliance) { gs.shadow.consequences.expelledFrom.append(c.alliance) }
        let members = Set(c.members)
        if let pi = gs.countries.firstIndex(where: { $0.id == me.id }) { gs.countries[pi].alliances.subtract(members) }
        for j in gs.countries.indices where members.contains(gs.countries[j].id) { gs.countries[j].alliances.remove(me.id) }
        gs.treaties.removeAll { $0.type == .alliance && $0.signatories.contains(me.id) && !members.isDisjoint(with: $0.signatories) }
        gs.alliancesBroken += 1
        for m in c.members.sorted() where m != c.victim { gs.modifyRelation(from: m, to: me.id, by: -20) }
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 8)
        let vName = gs.getCountry(id: c.victim)?.name ?? c.victim
        gs.shadow.post(c.bloc ? "\(c.alliance) expels \(me.name): the attack on \(vName) went on after the emergency council."
                              : "\(vName) ends its alliance with \(me.name).", date: gs.currentDate, severity: 3)
        logPlayEvent("ally_expelled", detail: ["victim": c.victim, "alliance": PlayHistory.text(c.alliance), "game_date": PlayHistory.day(gs.currentDate)])
        for land in Consequences.breakawayLands(of: c.victim, in: gs) {
            var n = land.toCountry()
            n.diplomaticRelations[me.id] = -60
            n.diplomaticRelations[c.victim] = 60
            for j in gs.countries.indices { gs.countries[j].diplomaticRelations[n.id] = 0 }
            gs.countries.append(n)
            gs.setRelation(from: me.id, to: n.id, value: -60)
            gs.setRelation(from: c.victim, to: n.id, value: 60)
            gs.shadow.consequences.brokenAway.append(n.id)
            gs.shadow.post("\(n.name) takes charge of its own affairs while \(vName) is under attack, and closes its ports and airfields to \(me.name).",
                           date: gs.currentDate, severity: 2)
            // 3.37.0: a new nation on the board is news for the column, like every other founding.
            logPlayEvent("nation_founded", detail: ["country": n.id, "name": PlayHistory.text(n.name), "reason": "broke_away", "from": c.victim,
                                                    "game_date": PlayHistory.day(gs.currentDate)])
        }
        self.gameState = gs
        allianceRevenge(c)   // 3.37.0
    }

    /// 3.37.0: the members of the alliance that expelled the President decide whether to go to war with him. Each
    /// member not already at war with him draws once (in id order) against `Consequences.revengeChance`; the victim is
    /// already fighting. Declarations go through `declareWar` (the `war_declared` play event, DEFCON, the war record).
    func allianceRevenge(_ c: AllianceCouncil) {
        guard c.bloc, let gs = gameState, let me = gs.getPlayerCountry() else { return }
        let vName = gs.getCountry(id: c.victim)?.name ?? c.victim
        var going: [String] = [], staying: [String] = []
        for id in c.members.sorted() where id != c.victim && id != me.id {
            guard let m = gs.getCountry(id: id), !m.isDestroyed, m.territoryOf == nil, !m.atWarWith.contains(me.id) else { continue }
            let p = Consequences.revengeChance(relations: m.diplomaticRelations[me.id] ?? 0, distanceKm: Reach.nearestKm(id, me.id, in: gs),
                                               strength: m.militaryStrength, playerStrength: me.militaryStrength)
            let roll = Double.random(in: 0..<1, using: &gs.rng)
            if roll < p, going.count < Consequences.allianceRevengeMaxWars { going.append(id) } else { staying.append(m.name) }
        }
        self.gameState = gs
        for id in going {
            guard let m = gameState?.getCountry(id: id) else { continue }
            declareWar(aggressor: id, defender: me.id, scripted: true)
            gameState?.shadow.post("\(m.name) declares war on \(me.name) over the attack on \(vName), a fellow member of \(c.alliance).",
                                   date: gs.currentDate, severity: 3)
        }
        let names = going.compactMap { gameState?.getCountry(id: $0)?.name }
        let line: String
        if names.isEmpty {
            line = "\(c.alliance)'s members condemn \(me.name); none goes to war over \(vName)."
        } else {
            line = "Of \(c.alliance)'s members, \(Consequences.list(names)) \(names.count == 1 ? "goes" : "go") to war with \(me.name)"
                + (staying.isEmpty ? "." : "; the rest stand aside.")
        }
        gameState?.shadow.post(line, date: gs.currentDate, severity: names.isEmpty ? 1 : 3)
        addLog("⚔️ \(line)", type: .warning)
        logPlayEvent("alliance_revenge", detail: ["alliance": PlayHistory.text(c.alliance), "victim": c.victim, "declared": going,
                                                  "stood_aside": staying.count, "game_date": PlayHistory.day(gs.currentDate)])
    }

}

extension Consequences {
    /// A refugee decision from the crisis card (`ShadowChoice` "refugees|<wave>|<choice>|<$B>").
    static func applyRefugeeChoice(wave id: String, choice: String, cost: Double, to gs: GameState) {
        guard let i = gs.shadow.consequences.waves.firstIndex(where: { $0.id.uuidString == id }) else { return }
        gs.shadow.consequences.waves[i].playerChoice = choice
        let k = gs.shadow.consequences.waves[i].receivers[gs.playerCountryID] ?? 0
        if let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) {
            switch choice {
            case "accept":
                gs.countries[pi].acceptedRefugees += k * 1000
                gs.countries[pi].stability = max(0, gs.countries[pi].stability - 1)
            case "close":
                gs.shadow.ruthlessness += 3
            default:
                break
            }
        }
        if cost > 0 { gs.shadow.aidRemaining = max(0, gs.shadow.aidRemaining - cost) }
    }
}
