//
//  ReportBooks.swift
//  Global Thermal Nuclear War
//
//  3.36.0: bugs found in Nova's game reports, fixed at the root.
//  - Land that develops: claimed land always paid after a two-year ramp-up, but its first "now producing" line and the
//    play history reported the first week's sliver ($0), and nothing said when it would pay. A territory now shows
//    "develops in N months" with its full-output income, and an INVEST order (one action, era-priced) brings it six
//    months closer. Science is prestige, not money; Antarctica pays no money after the whaling era unless developed.
//  - Approval with a reason: crisis and election cards were authored when their approval effects were no-ops
//    (3.18.14 made them land), so two good cards could add 45 points in a month (1923: 48.3 → 94.8). One card now
//    moves approval at most ±10 and good news never lifts it past 90; every poll that moves more than 10 points says
//    its main cause.
//  - War books: "wars started" counted only alliance call-ups, so seven wars won read as none started. Declarations
//    by the President count, and wars won as attacker, as defender and lost are kept for the report.
//  - Lands in a region and lands by name: "claim all of Africa" takes every free land there, "buy all of Africa" every
//    colony, and "Greenland" resolves to the nation whose map it is part of (Denmark), said plainly.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// Bookkeeping the game reports need (saved; every field decodes from older saves).
struct ReportBooks: Codable, Equatable {
    /// Years of development bought by investment, by land.
    var developed: [String: Double] = [:]
    /// Approval moved since the last poll, by cause.
    var approvalCauses: [String: Double] = [:]
    /// The President's wars won as the side that attacked, as the side attacked, and lost.
    var warsWonAttacking = 0
    var warsWonDefending = 0
    var warsLost = 0

    init() {}

    enum CodingKeys: String, CodingKey { case developed, approvalCauses, warsWonAttacking, warsWonDefending, warsLost }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        developed = (try? c.decodeIfPresent([String: Double].self, forKey: .developed)) ?? [:]
        approvalCauses = (try? c.decodeIfPresent([String: Double].self, forKey: .approvalCauses)) ?? [:]
        warsWonAttacking = (try? c.decodeIfPresent(Int.self, forKey: .warsWonAttacking)) ?? 0
        warsWonDefending = (try? c.decodeIfPresent(Int.self, forKey: .warsWonDefending)) ?? 0
        warsLost = (try? c.decodeIfPresent(Int.self, forKey: .warsLost)) ?? 0
    }
}

// MARK: - Land that develops

enum LandDevelopment {
    /// Years from claim to full output (ExpansionModel.rampUp: nothing for six months, full at two years).
    static let fullYears = 2.0
    /// What one INVEST order buys: six months of development.
    static let investYears = 0.5

    /// Years of development bought for a land.
    static func bought(_ id: String, in gs: GameState) -> Double { max(0, gs.shadow.books.developed[id] ?? 0) }

    /// Lands whose own yield (fishery, harbour, farmland) pays only once developed: Antarctica, where nobody lives
    /// and the Treaty years leave nothing but science.
    static func needsInvestment(_ id: String) -> Bool { id == Antarctica.id }

    /// Whether the land's own yield pays yet.
    static func landYieldPays(_ id: String, in gs: GameState) -> Bool {
        !needsInvestment(id) || bought(id, in: gs) > 0
    }

    /// Money a deposit pays a year: science is prestige, not income.
    static func money(_ d: ResourceDeposit) -> Double { d.kind == .science ? 0 : d.value }

    /// Years a land counts as developed: years held plus years bought.
    static func years(_ id: String, in gs: GameState) -> Double {
        let held = gs.shadow.claimDates[id].map { GameCalendar.years(from: $0, to: gs.currentDate) } ?? 10
        return held + bought(id, in: gs)
    }

    /// Whole months until full output (0 = developed).
    static func monthsToDevelop(_ id: String, in gs: GameState) -> Int {
        let left = fullYears - years(id, in: gs)
        return left <= 0 ? 0 : Int((left * 12).rounded(.up))
    }

    /// $B a year the land pays now, and at full development (same garrison, stability and extraction).
    static func income(_ c: Country, in gs: GameState) -> (now: Double, full: Double) {
        (ExpansionModel.annualIncome(c, in: gs), ExpansionModel.annualIncome(c, in: gs, developed: true))
    }

    /// What an INVEST order costs ($B): half a year's full output, at least five landings' worth for the era
    /// (0.1 before 1900, 0.5 before 1950, 2.5 after). Design choice.
    static func investCost(_ c: Country, in gs: GameState) -> Double {
        let full = ExpansionModel.annualIncome(c, in: gs, developed: true)
        return (max(5 * ClaimCampaigns.landingCost(year: gs.currentYear), 0.5 * full) * 100).rounded() / 100
    }

    /// Whether an INVEST order would do anything for this land.
    static func canDevelop(_ id: String, in gs: GameState) -> Bool {
        monthsToDevelop(id, in: gs) > 0 || (needsInvestment(id) && bought(id, in: gs) == 0)
    }

    /// The line under a territory's yield: when it develops and what it will pay, or plainly that it pays nothing.
    static func note(_ c: Country, in gs: GameState) -> String? {
        guard c.territoryOf != nil, !c.isDestroyed else { return nil }
        let inc = income(c, in: gs)
        let m = monthsToDevelop(c.id, in: gs)
        if needsInvestment(c.id) && bought(c.id, in: gs) == 0 {
            let invest = "INVEST builds stations, a harbour and fisheries."
            guard inc.full >= 0.005 else { return "Pays no money unless developed: science brings prestige, not income. \(invest)" }
            let when = m > 0 ? " in \(m) month\(m == 1 ? "" : "s")" : ""
            return String(format: "Whaling and sealing pay $%.2fB a year at full output%@ (now $%.2fB), until they end; beyond that it pays no money unless developed. %@",
                          inc.full, when, inc.now, invest)
        }
        guard m > 0 else { return nil }
        return String(format: "Develops in %d month%@: $%.2fB a year at full output (now $%.2fB). INVEST brings it 6 months closer.",
                      m, m == 1 ? "" : "s", inc.full, inc.now)
    }

    /// Why the President can't invest in a land now, or nil.
    static func problem(_ id: String, in gs: GameState) -> String? {
        guard let c = gs.getCountry(id: id), !c.isDestroyed, c.territoryOf == gs.playerCountryID else {
            return "Only land you hold can be developed."
        }
        guard canDevelop(id, in: gs) else { return "\(c.name) is already fully developed." }
        if gs.actionsRemaining < 1 { return "No actions left this \(gs.turnLength.displayName.lowercased())." }
        let cost = investCost(c, in: gs)
        // Paid from the funds, or up to 2% of national output from the treasury (design choice).
        let gdp = gs.getPlayerCountry()?.gdp ?? 0
        guard gs.shadow.aidRemaining >= cost || gdp * 1000 * 0.02 >= cost else { return String(format: "Not enough money: it costs $%.2fB.", cost) }
        return nil
    }
}

extension GameEngine {
    /// INVEST in a territory (one action, era-priced): six months of development at once; Antarctica starts paying.
    @discardableResult
    func investInLand(_ id: String) -> Bool {
        guard let gs = gameState, LandDevelopment.problem(id, in: gs) == nil, let c = gs.getCountry(id: id) else { return false }
        let cost = LandDevelopment.investCost(c, in: gs)
        let first = LandDevelopment.bought(id, in: gs) == 0
        spendFunds(cost)
        gs.shadow.books.developed[id, default: 0] += LandDevelopment.investYears
        let m = LandDevelopment.monthsToDevelop(id, in: gs)
        let full = ExpansionModel.annualIncome(c, in: gs, developed: true)
        let line: String
        if LandDevelopment.needsInvestment(id) && first {
            line = String(format: "Stations, a harbour and fisheries go up in %@ ($%.2fB). It will pay $%.2fB a year at full output%@.",
                          c.name, cost, full, m > 0 ? " in \(m) month\(m == 1 ? "" : "s")" : "")
        } else {
            line = String(format: "Investment in %@ ($%.2fB): roads, a port and survey parties. %@", c.name, cost,
                          m > 0 ? "Full output ($\(String(format: "%.2f", full))B a year) in \(m) month\(m == 1 ? "" : "s")."
                                : "It is fully developed: $\(String(format: "%.2f", full))B a year.")
        }
        gs.shadow.post(line, date: gs.currentDate, severity: 1)
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(c.name) developed ($\(String(format: "%.2f", cost))B).")
        logPlayEvent("territory_invested", detail: ["land": id, "name": PlayHistory.text(c.name), "cost_b": PlayHistory.num(cost, places: 100),
                                                    "income_full_b": PlayHistory.num(full, places: 100), "develops_months": m,
                                                    "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return true
    }
}

// MARK: - Approval with a reason

extension PopularityModel {
    /// The most one crisis or election card moves approval, either way.
    static let cardSwingCap = 10.0
    /// Good news never lifts approval past this (the record is 90, after 11 September 2001).
    static let rallyCeiling = 90.0
    /// A poll move bigger than this names its main cause.
    static let explainedPollMove = 10.0

    /// A card's approval change as it lands: at most ±10, and no rise above 90 (a rise never turns into a fall).
    static func cardEffect(_ change: Double, current: Double) -> Double {
        let c = min(cardSwingCap, max(-cardSwingCap, change))
        return c > 0 ? max(0, min(c, rallyCeiling - current)) : c
    }

    /// The mood's own drift toward where the economy, wars and ruthlessness put it.
    static let driftCause = "the public mood (economy, wars, ruthlessness)"
}

extension ShadowState {
    /// Move approval and remember why (for the next poll's explanation).
    mutating func moveApproval(_ delta: Double, because cause: String) {
        guard delta.isFinite else { return }
        let before = popularity
        popularity = PopularityModel.clamp(popularity + delta)
        noteApproval(popularity - before, because: cause)
    }

    /// Remember an approval move made elsewhere.
    mutating func noteApproval(_ delta: Double, because cause: String) {
        guard delta.isFinite, delta != 0 else { return }
        books.approvalCauses[String(cause.prefix(80)), default: 0] += delta
    }

    /// The main cause of a poll-to-poll change: the biggest recorded move in the same direction; what nothing recorded
    /// explains is "other events".
    func pollCause(change: Double) -> String {
        var causes = books.approvalCauses
        let unexplained = change - causes.values.reduce(0, +)
        if abs(unexplained) >= 1 { causes["other events", default: 0] += unexplained }
        let same = causes.filter { change >= 0 ? $0.value > 0 : $0.value < 0 }
        let pool = same.isEmpty ? causes : same
        return pool.max { (abs($0.value), $1.key) < (abs($1.value), $0.key) }?.key ?? PopularityModel.driftCause
    }
}

extension GameEngine {
    /// A crisis or election card's approval change, capped, recorded with its title.
    func applyCardApproval(_ change: Int, title: String) {
        guard change != 0, let gs = gameState else { return }
        gs.shadow.moveApproval(PopularityModel.cardEffect(Double(change), current: gs.shadow.popularity), because: "the decision on \"\(title)\"")
        self.gameState = gs
    }
}

extension GameState {
    /// A crisis card's approval change, capped and recorded (CrisisManager works on the state directly).
    func applyCardApproval(_ change: Int, title: String) {
        guard change != 0 else { return }
        shadow.moveApproval(PopularityModel.cardEffect(Double(change), current: shadow.popularity), because: "the decision on \"\(title)\"")
    }
}

// MARK: - War books

extension GameEngine {
    /// A front the President was in has ended: count it and tell the play history, matching the war log.
    func recordPlayerWarEnd(attacker: String, defender: String, usSide: String?, attackerWon: Bool) {
        guard let gs = gameState else { return }
        let p = gs.playerCountryID
        let side: String
        if attacker == p { side = "attacker" } else if defender == p { side = "defender" } else if usSide == attacker { side = "ally_of_attacker" }
        else if usSide == defender { side = "ally_of_defender" } else { return }
        let won = (side == "attacker" || side == "ally_of_attacker") == attackerWon
        if won {
            if side.hasSuffix("attacker") { gs.shadow.books.warsWonAttacking += 1 } else { gs.shadow.books.warsWonDefending += 1 }
        } else {
            gs.shadow.books.warsLost += 1
        }
        let enemy = side.hasSuffix("attacker") ? defender : attacker
        logPlayEvent("war_ended", detail: ["enemy": enemy, "enemy_name": PlayHistory.text(gs.getCountry(id: enemy)?.name ?? enemy),
                                           "side": side, "won": won, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
    }
}

extension GameState {
    /// Wars the President started (declarations, seizures, the alliances they called in); older saves counted only
    /// the call-ups, so the larger of the two counts.
    var playerWarsStartedTotal: Int { max(warsStarted, shadow.playerWarsStarted) }
}

// MARK: - Lands in a region, lands by name

extension CommandTargets {
    /// 3.36.0: what a region name means for a land verb: every free land there for a claim, every colony another
    /// power holds there to buy or free. The region is the land's own template's (data, not a list).
    static func regionLands(_ r: WorldRegion, verb: CommandVerb, in gs: GameState, engine: GameEngine) -> [ResolvedTarget] {
        switch verb {
        case .claim:
            let indigenous = gs.indigenousLandIDs
            return gs.claimableLandIDs.filter { ClaimCampaigns.region(of: $0) == r }.sorted()
                .map { indigenous.contains($0) ? .indigenous($0) : .unclaimed($0) }
        case .buy, .liberate:
            let held = gs.countries.filter { $0.territoryOf != nil && $0.territoryOf != gs.playerCountryID && !$0.isDestroyed }.map(\.id)
            return gs.colonyLandIDs.union(held)
                .filter { (gs.getCountry(id: $0)?.region ?? ClaimCampaigns.region(of: $0)) == r && engine.colonyTarget($0) != nil }
                .sorted().map { .colony($0) }
        case .develop:
            return gs.countries.filter { $0.territoryOf == gs.playerCountryID && !$0.isDestroyed && $0.region == r
                && LandDevelopment.canDevelop($0.id, in: gs) }.map(\.id).sorted().map { .nation($0) }
        default:
            return []
        }
    }

    /// A map outline that is part of another nation this year ("Greenland" → Denmark): its name, and the nation.
    static func partOf(_ raw: String, in gs: GameState) -> (name: String, owner: String)? {
        let n = CommandParser.normalize(raw)
        guard !n.isEmpty, let shape = WorldMapData.shared.shapes.first(where: { CommandParser.normalizedName($0.name) == n }),
              gs.getCountry(id: shape.id) == nil, gs.preState(shape.id) == nil, !gs.unclaimedLandIDs.contains(shape.id) else { return nil }
        let present = Set(gs.countries.filter { !$0.isDestroyed }.map(\.id))
        guard let owner = WorldMapData.owner(of: shape.id, in: present, year: gs.currentYear), owner != shape.id else { return nil }
        return (shape.name, owner)
    }

    /// One plain line on who holds a land, so nobody (and no model) has to guess: "Greenland: part of Denmark in 2025."
    static func ownershipLine(_ t: ResolvedTarget, in gs: GameState, engine: GameEngine) -> String {
        let name = label(t, in: gs)
        let year = gs.currentYear
        switch t {
        case .nation(let id):
            guard let c = gs.getCountry(id: id) else { return "\(name): not on the board in \(year)." }
            if id == gs.playerCountryID { return "\(c.name): your own nation." }
            if let o = c.territoryOf {
                return o == gs.playerCountryID ? "\(c.name): your territory." : "\(c.name): territory of \(gs.getCountry(id: o)?.name ?? o) in \(year)."
            }
            return "\(c.name): an independent nation in \(year)."
        case .colony(let land):
            return "\(name): colony of \(engine.colonyTarget(land)?.owner.name ?? "another power") in \(year)."
        case .indigenous:
            return "\(name): held by the people who live there, not by any state, in \(year). You can claim it; they will resist."
        case .unclaimed(let land):
            let antarctic = land == Antarctica.id ? " It pays no money unless developed; science brings prestige, not income." : ""
            return "\(name): unclaimed land, no government in \(year). You can claim it.\(antarctic)"
        }
    }
}
