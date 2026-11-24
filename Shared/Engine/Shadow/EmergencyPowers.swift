//
//  EmergencyPowers.swift
//  Global Thermal Nuclear War
//
//  3.36.0: emergency powers and the courts. The President may declare a national emergency (one action) and issue
//  emergency orders under it: tariffs first, and through `issueEmergencyOrder` any other order (troop deployments at
//  home, spending freezes). Every order records the authority it rests on. Someone sues the day it is signed; months
//  later the courts rule. The ruling is deterministic: it follows from how strong the authority is for that kind of
//  order, the era's courts, whether an emergency is actually in force, and whether the target is an enemy. An order
//  struck down ends (a tariff's duties are refunded); the President may reissue it under a different authority, at a
//  political cost, and the clock starts again. Congress may end the emergency by joint resolution; a veto holds
//  unless two-thirds of the Senate is against the President.
//
//  The authorities are the statutes U.S. Presidents have used (named by act and year, not by any President); other
//  governments have an emergency decree (courts rarely stop it outside a democracy) and their ordinary trade law.
//  The strengths, delays and court times are DESIGN CHOICES, not legal advice.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// Why a national emergency is declared.
enum EmergencyReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case trade, security, border, publicOrder, energy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .trade: return "an unfair trade imbalance"
        case .security: return "a threat to national security"
        case .border: return "the security of the border"
        case .publicOrder: return "a threat to public order"
        case .energy: return "an energy supply crisis"
        }
    }
}

/// A national emergency in force (or ended).
struct NationalEmergency: Codable, Equatable {
    var reason: EmergencyReason
    var declared: Date
    var ended: Date?
    /// "by the President", "by Congress over the President's veto".
    var endedBy: String?
}

/// What an emergency order does. Other features add kinds here and handle a ruling in `emergencyOrderEnded`.
enum EmergencyOrderKind: String, Codable, CaseIterable, Sendable {
    case tariff, deployment, spendingFreeze, other
    var title: String {
        switch self {
        case .tariff: return "tariffs"
        case .deployment: return "troop deployment"
        case .spendingFreeze: return "spending freeze"
        case .other: return "emergency order"
        }
    }
}

/// Where an emergency order stands.
enum EmergencyOrderStatus: String, Codable, Sendable {
    /// Signed; waiting for the investigation the statute requires before it takes effect.
    case pending
    case inForce
    /// The courts let it stand (final).
    case upheld
    /// The courts struck it down.
    case struckDown
    /// It ran out (a time-limited authority) or its emergency ended.
    case lapsed
    /// The President withdrew it (or reissued it under another authority).
    case rescinded

    var isLive: Bool { self == .pending || self == .inForce || self == .upheld }
    var label: String {
        switch self {
        case .pending: return "PENDING"
        case .inForce: return "IN FORCE · IN COURT"
        case .upheld: return "UPHELD"
        case .struckDown: return "STRUCK DOWN"
        case .lapsed: return "LAPSED"
        case .rescinded: return "WITHDRAWN"
        }
    }
}

/// The authority an emergency order rests on.
enum LegalBasis: String, Codable, CaseIterable, Identifiable, Sendable {
    case article2, tradingWithEnemy, tariffAct338, nationalSecurity232, unfairTrade301, balanceOfPayments122, emergencyEconomic
    case insurrectionAct, impoundment
    case emergencyDecree, tradeLaw

    var id: String { rawValue }

    /// U.S. statutes, or the generic authorities of any other government.
    var american: Bool { self != .emergencyDecree && self != .tradeLaw }

    var title: String {
        switch self {
        case .article2: return "Inherent executive power (Article II)"
        case .tradingWithEnemy: return "Trading with the Enemy Act (1917)"
        case .tariffAct338: return "Tariff Act of 1930, section 338"
        case .nationalSecurity232: return "Trade Expansion Act of 1962, section 232 (national security)"
        case .unfairTrade301: return "Trade Act of 1974, section 301 (unfair practices)"
        case .balanceOfPayments122: return "Trade Act of 1974, section 122 (balance of payments)"
        case .emergencyEconomic: return "International Emergency Economic Powers Act (1977)"
        case .insurrectionAct: return "Insurrection Act (1807)"
        case .impoundment: return "Impoundment of appropriated funds"
        case .emergencyDecree: return "Emergency decree"
        case .tradeLaw: return "Existing trade law"
        }
    }

    /// The short name on a card.
    var short: String {
        switch self {
        case .article2: return "Article II"
        case .tradingWithEnemy: return "Trading with the Enemy Act"
        case .tariffAct338: return "section 338"
        case .nationalSecurity232: return "section 232"
        case .unfairTrade301: return "section 301"
        case .balanceOfPayments122: return "section 122"
        case .emergencyEconomic: return "emergency economic powers"
        case .insurrectionAct: return "Insurrection Act"
        case .impoundment: return "impoundment"
        case .emergencyDecree: return "emergency decree"
        case .tradeLaw: return "trade law"
        }
    }

    /// The first year it can be used.
    var since: Int {
        switch self {
        case .article2, .emergencyDecree, .tradeLaw, .impoundment: return 1789
        case .insurrectionAct: return 1807
        case .tradingWithEnemy: return 1917
        case .tariffAct338: return 1930
        case .nationalSecurity232: return 1962
        case .unfairTrade301, .balanceOfPayments122: return 1974
        case .emergencyEconomic: return 1977
        }
    }

    /// The kinds of order it can carry.
    func covers(_ k: EmergencyOrderKind) -> Bool {
        switch self {
        case .article2, .emergencyDecree: return true
        case .tradingWithEnemy, .tariffAct338, .nationalSecurity232, .unfairTrade301, .balanceOfPayments122, .tradeLaw: return k == .tariff
        case .emergencyEconomic: return k == .tariff || k == .other
        case .insurrectionAct: return k == .deployment
        case .impoundment: return k == .spendingFreeze
        }
    }

    /// Needs a national emergency in force to be invoked at all.
    var needsEmergency: Bool { self == .emergencyEconomic || self == .emergencyDecree }

    /// Days of investigation before the order takes effect (0 = at once).
    var investigationDays: Int {
        switch self {
        case .nationalSecurity232: return 120
        case .unfairTrade301: return 90
        default: return 0
        }
    }

    /// A time-limited authority: the order lapses after this many days (0 = no limit).
    var limitDays: Int { self == .balanceOfPayments122 ? 150 : 0 }

    /// Days from signing to the final ruling.
    var courtDays: Int {
        switch self {
        case .article2: return 120
        case .emergencyDecree, .impoundment: return 150
        case .emergencyEconomic: return 180
        case .tradingWithEnemy, .tariffAct338, .insurrectionAct, .tradeLaw: return 210
        case .unfairTrade301: return 270
        case .nationalSecurity232: return 300
        case .balanceOfPayments122: return 240
        }
    }

    /// How well it holds up in court for this kind of order (0…1) before the era and the facts.
    func strength(for k: EmergencyOrderKind, year: Int) -> Double {
        switch (self, k) {
        case (.article2, .tariff): return 0.15
        case (.article2, .deployment): return 0.45
        case (.article2, _): return 0.25
        case (.tradingWithEnemy, _): return 0.55
        case (.tariffAct338, _): return 0.5
        case (.nationalSecurity232, _): return 0.8
        case (.unfairTrade301, _): return 0.75
        case (.balanceOfPayments122, _): return 0.85
        case (.emergencyEconomic, .tariff): return 0.45   // the statute regulates trade; it never says "tariff"
        case (.emergencyEconomic, _): return 0.65
        case (.insurrectionAct, _): return 0.7
        case (.impoundment, _): return year >= 1974 ? 0.2 : 0.6   // the Impoundment Control Act (1974) reins it in
        case (.emergencyDecree, _): return 0.45   // a democracy's courts; see `courtScore` for everyone else
        case (.tradeLaw, _): return 0.75
        }
    }

    /// One line for the card: what it is good and bad at.
    var note: String {
        switch self {
        case .article2: return "No statute behind it. Fast, and weak in court."
        case .tradingWithEnemy: return "Wartime powers; after 1977 only against a nation at war with us."
        case .tariffAct338: return "Never tested in court."
        case .nationalSecurity232: return "Strong in court; needs a \(investigationDays)-day investigation. Thin against an ally."
        case .unfairTrade301: return "Strong in court; needs a \(investigationDays)-day investigation."
        case .balanceOfPayments122: return "Strongest, but lapses after \(limitDays) days."
        case .emergencyEconomic: return "Immediate and broad. Needs a national emergency; weak for tariffs."
        case .insurrectionAct: return "For troops at home."
        case .impoundment: return "Withholding money Congress appropriated."
        case .emergencyDecree: return "Needs a declared emergency."
        case .tradeLaw: return "Slower, and solid."
        }
    }
}

/// One emergency order and its fate.
struct EmergencyOrder: Codable, Equatable, Identifiable {
    var id: Int
    var kind: EmergencyOrderKind
    /// A nation id, or for orders at home a subject id the issuing feature owns.
    var target: String
    /// "tariffs on Canada".
    var subject: String
    var basis: LegalBasis
    var issued: Date
    var status: EmergencyOrderStatus
    /// The first order of a chain of reissues (its own id when it is the first).
    var root: Int
    /// Authorities already struck down in this chain (a reissue can't use them again).
    var struckBases: [LegalBasis] = []
    var ruled: Date?
    /// Tariff duties collected so far ($B), refunded if the courts strike the order down.
    var collected: Double = 0

    /// The order's id as a command-box target ("EO12").
    var targetToken: String { "EO\(id)" }
    static func id(fromTarget s: String) -> Int? { s.hasPrefix("EO") ? Int(s.dropFirst(2)) : nil }

    func days(to now: Date) -> Int { GameCalendar.days(from: issued, to: now) }
}

enum EmergencyPowers {
    /// The National Emergencies Act (14 Sep 1976) lets Congress end an emergency by joint resolution.
    static let nationalEmergenciesAct = 1976
    /// A ruling at or above this score lets the order stand.
    static let passMark = 0.5

    /// The era's courts (design choice): deferential from 1937 to 1980, wary of big delegated powers from 2020.
    static func eraAdjustment(year: Int) -> Double {
        switch year {
        case ..<1937: return -0.05
        case ..<1980: return 0.1
        case ..<2020: return 0
        default: return -0.1
        }
    }

    /// Duties a tariff order collects per month ($B): a share of the target's trade with us.
    static func monthlyDuties(targetGDPTrillions g: Double) -> Double { max(0.05, min(8, g * 1.5)) }

    /// Can a government's courts stop the head of government at all? Outside a democracy, hardly.
    static func courtsBite(_ g: GovernmentType) -> Bool { g == .democracy || g == .republic || g == .monarchy }
}

// MARK: - Engine

extension GameEngine {

    /// The authorities open to the player for this kind of order now, strongest (in court) first.
    func legalBases(for kind: EmergencyOrderKind, target: String? = nil) -> [LegalBasis] {
        guard let gs = gameState else { return [] }
        let us = gs.playerCountryID == "USA"
        return LegalBasis.allCases.filter { b in
            b.american == us && b.covers(kind) && gs.currentYear >= b.since && basisBlocked(b, kind: kind, target: target) == nil
        }.sorted { a, b in
            let sa = courtScore(a, kind: kind, target: target), sb = courtScore(b, kind: kind, target: target)
            return sa != sb ? sa > sb : a.rawValue < b.rawValue
        }
    }

    /// Why an authority can't be invoked for this order now, or nil.
    func basisBlocked(_ b: LegalBasis, kind: EmergencyOrderKind, target: String?) -> String? {
        guard let gs = gameState else { return "No game." }
        if (b.american) != (gs.playerCountryID == "USA") { return "\(b.title) is not your law." }
        if gs.currentYear < b.since { return "\(b.title) does not exist until \(b.since)." }
        if !b.covers(kind) { return "\(b.title) does not cover \(kind.title)." }
        if b.needsEmergency && gs.shadow.powerPlays.emergency == nil { return "\(b.title) needs a national emergency in force. Declare one first." }
        if b == .tradingWithEnemy, gs.currentYear >= 1977 {
            let atWar = target.map { gs.getPlayerCountry()?.atWarWith.contains($0) ?? false } ?? false
            if !atWar { return "Since 1977 the Trading with the Enemy Act needs a nation at war with you." }
        }
        if b == .tradingWithEnemy, gs.currentYear < 1977, gs.shadow.powerPlays.emergency == nil,
           !(target.map { gs.getPlayerCountry()?.atWarWith.contains($0) ?? false } ?? false) {
            return "The Trading with the Enemy Act needs a war or a declared emergency."
        }
        return nil
    }

    /// The ruling's score: the authority's strength for the order, the era's courts, the facts. Pure given the state.
    func courtScore(_ b: LegalBasis, kind: EmergencyOrderKind, target: String?, emergency: Bool? = nil) -> Double {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return 0 }
        if b == .emergencyDecree, !EmergencyPowers.courtsBite(me.government) { return 1 }
        var s = b.strength(for: kind, year: gs.currentYear) + EmergencyPowers.eraAdjustment(year: gs.currentYear)
        let inForce = emergency ?? (gs.shadow.powerPlays.emergency != nil)
        if b.needsEmergency && !inForce { s -= 0.4 }
        if inForce && !b.needsEmergency { s += 0.05 }   // the record shows a real emergency
        if let t = target, gs.getCountry(id: t) != nil {
            if me.atWarWith.contains(t) { s += 0.2 }
            else if (me.diplomaticRelations[t] ?? 0) < -50 { s += 0.05 }
            if b == .nationalSecurity232, me.alliances.contains(t) { s -= 0.25 }   // "national security" against an ally
        }
        return (s * 100).rounded() / 100
    }

    /// Will the courts let it stand? Deterministic.
    func courtUpholds(_ o: EmergencyOrder) -> Bool {
        courtScore(o.basis, kind: o.kind, target: o.kind == .tariff ? o.target : nil) >= EmergencyPowers.passMark
    }

    // MARK: The emergency

    func emergencyDeclareProblem(_ reason: EmergencyReason) -> String? {
        guard let gs = gameState else { return "No game." }
        if gs.gameOver { return "The game is over." }
        if gs.shadow.powerPlays.emergency != nil { return "A national emergency is already in force." }
        if gs.actionsRemaining < 1 { return "No actions left." }
        return nil
    }

    /// Declare a national emergency (one action): approval dips a little and Congress takes note.
    @discardableResult
    func declareNationalEmergency(_ reason: EmergencyReason) -> Bool {
        guard emergencyDeclareProblem(reason) == nil, let gs = gameState, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return false }
        gs.shadow.powerPlays.emergency = NationalEmergency(reason: reason, declared: gs.currentDate)
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 1)
        gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport - 2)
        let who = gs.playerCountryID == "USA" ? "The President" : "The government"
        gs.shadow.post("\(who) declares a national emergency over \(reason.title). Emergency powers are in force.", date: gs.currentDate, severity: 2)
        addLog("🚨 National emergency declared: \(reason.title).", type: .warning)
        logPlayEvent("emergency_declared", detail: ["reason": reason.rawValue, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return true
    }

    /// End the national emergency (no action). Orders that needed it lapse.
    @discardableResult
    func endNationalEmergency(by: String = "by the President") -> Bool {
        guard let gs = gameState, var e = gs.shadow.powerPlays.emergency else { return false }
        e.ended = gs.currentDate
        e.endedBy = by
        gs.shadow.powerPlays.emergency = nil
        gs.shadow.powerPlays.pastEmergencies.append(e)
        gs.shadow.post("The national emergency over \(e.reason.title) is ended \(by).", date: gs.currentDate, severity: 2)
        self.gameState = gs
        for o in gs.shadow.powerPlays.orders where o.status.isLive && o.status != .upheld && o.basis.needsEmergency {
            endEmergencyOrder(o.id, status: .lapsed, why: "its emergency is over")
        }
        return true
    }

    // MARK: Orders

    /// The generic hook: record an emergency order under an authority and start its court clock. The caller carries
    /// out the order itself (H's deployments, a spending freeze) and reads `emergencyOrderInForce` later; tariffs use
    /// `emergencyTariffs`. Spends no action (the caller's order does). Nil when the authority can't be invoked.
    @discardableResult
    func issueEmergencyOrder(kind: EmergencyOrderKind, target: String, subject: String, basis: LegalBasis,
                             chain: EmergencyOrder? = nil) -> EmergencyOrder? {
        guard let gs = gameState, basisBlocked(basis, kind: kind, target: kind == .tariff ? target : nil) == nil else { return nil }
        let pp = gs.shadow.powerPlays
        let o = EmergencyOrder(id: pp.nextOrderID, kind: kind, target: target, subject: String(subject.prefix(80)), basis: basis,
                               issued: gs.currentDate, status: basis.investigationDays > 0 ? .pending : .inForce,
                               root: chain?.root ?? pp.nextOrderID, struckBases: chain?.struckBases ?? [])
        gs.shadow.powerPlays.nextOrderID += 1
        gs.shadow.powerPlays.orders.append(o)
        if gs.playerCountryID == "USA" || EmergencyPowers.courtsBite(gs.getPlayerCountry()?.government ?? .democracy) {
            gs.shadow.post("A suit is filed against the \(o.subject) the day the order is signed (\(basis.short)).", date: gs.currentDate)
        }
        logPlayEvent("emergency_order", detail: ["id": o.id, "kind": kind.rawValue, "target": target, "basis": basis.rawValue,
                                                 "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return o
    }

    /// Is the order still in force (signed and not ended)? Pending orders are not yet in force.
    func emergencyOrderInForce(_ id: Int) -> Bool {
        guard let o = gameState?.shadow.powerPlays.orders.first(where: { $0.id == id }) else { return false }
        return o.status == .inForce || o.status == .upheld
    }

    /// The live order for a target and kind, if any.
    func liveEmergencyOrder(_ kind: EmergencyOrderKind, target: String) -> EmergencyOrder? {
        gameState?.shadow.powerPlays.orders.last { $0.kind == kind && $0.target == target && $0.status.isLive }
    }

    func emergencyTariffProblem(_ target: String, basis: LegalBasis) -> String? {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return "No game." }
        if gs.gameOver { return "The game is over." }
        guard let t = gs.getCountry(id: target), !t.isDestroyed else { return "No nation to aim it at." }
        if t.id == me.id || t.territoryOf == me.id { return "That is your own." }
        if t.isTerritory { return "\(t.name) trades through \(gs.getCountry(id: t.territoryOf ?? "")?.name ?? "its owner"). Aim the tariffs there." }
        if liveEmergencyOrder(.tariff, target: target) != nil { return "Emergency tariffs on \(t.name) are already in force." }
        return basisBlocked(basis, kind: .tariff, target: target)
    }

    /// Emergency tariffs on a nation under an authority (one action, unless `spendAction` is false for a campaign
    /// that already paid). Returns the order.
    @discardableResult
    func emergencyTariffs(on target: String, basis: LegalBasis, spendAction: Bool = true, chain: EmergencyOrder? = nil) -> EmergencyOrder? {
        guard emergencyTariffProblem(target, basis: basis) == nil, let gs = gameState, !spendAction || gs.actionsRemaining > 0,
              let t = gs.getCountry(id: target) else { return nil }
        guard let o = issueEmergencyOrder(kind: .tariff, target: target, subject: "tariffs on \(t.name)", basis: basis, chain: chain) else { return nil }
        if o.status == .inForce { applyTariffEffect(target, on: true) }
        else { gs.shadow.post("An investigation opens under \(basis.short): tariffs on \(t.name) in \(basis.investigationDays) days.", date: gs.currentDate) }
        addLog("📜 Emergency tariffs on \(t.name) under \(basis.title).", type: .info)
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 0.5)   // prices at home
        self.gameState = gs
        if spendAction {
            recordPlayerAction(rung: .economic, hostile: true, detected: false)
            completePlayerAction()
        }
        return o
    }

    /// Tariffs bite (or are lifted): relations both ways and the target's economy.
    func applyTariffEffect(_ target: String, on: Bool) {
        guard let gs = gameState, let ti = gs.countries.firstIndex(where: { $0.id == target }) else { return }
        let me = gs.playerCountryID
        modifyDiplomaticRelation(from: target, to: me, by: on ? -12 : 6)
        modifyDiplomaticRelation(from: me, to: target, by: on ? -8 : 4)
        if on {
            gs.countries[ti].gdp = max(0.001, gs.countries[ti].gdp * 0.996)
            gs.countries[ti].economicStrength = max(1, gs.countries[ti].economicStrength - 1)
        }
        self.gameState = gs
    }

    func reissueProblem(_ id: Int, basis: LegalBasis) -> String? {
        guard let gs = gameState else { return "No game." }
        guard let o = gs.shadow.powerPlays.orders.first(where: { $0.id == id }) else { return "No such order." }
        guard o.status == .struckDown || o.status == .lapsed else { return "Order \(id) is not struck down." }
        if gs.shadow.powerPlays.orders.contains(where: { $0.root == o.root && $0.status.isLive }) { return "It has already been reissued." }
        if o.struckBases.contains(basis) || basis == o.basis && o.status == .struckDown { return "The courts already struck it down under \(basis.short). Choose another authority." }
        if gs.actionsRemaining < 1 { return "No actions left." }
        if o.kind == .tariff { return emergencyTariffProblem(o.target, basis: basis) }
        return basisBlocked(basis, kind: o.kind, target: nil)
    }

    /// Reissue a struck-down order under another authority (one action): Congress and the public like it less each time.
    @discardableResult
    func reissueEmergencyOrder(_ id: Int, basis: LegalBasis) -> EmergencyOrder? {
        guard reissueProblem(id, basis: basis) == nil, let gs = gameState, let old = gs.shadow.powerPlays.orders.first(where: { $0.id == id }),
              let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return nil }
        var chain = old
        if old.status == .struckDown, !chain.struckBases.contains(old.basis) { chain.struckBases.append(old.basis) }
        let tries = gs.shadow.powerPlays.orders.filter { $0.root == old.root }.count
        let new: EmergencyOrder?
        if old.kind == .tariff {
            new = emergencyTariffs(on: old.target, basis: basis, spendAction: false, chain: chain)
        } else {
            new = issueEmergencyOrder(kind: old.kind, target: old.target, subject: old.subject, basis: basis, chain: chain)
        }
        guard let n = new else { return nil }
        gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport - 3 * tries)
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - Double(tries))
        gs.shadow.post("The \(old.subject) are reissued under \(basis.title) after the courts' ruling.", date: gs.currentDate, severity: 2)
        self.gameState = gs
        completePlayerAction()
        return n
    }

    /// Withdraw a live order (no action): the President backs down.
    @discardableResult
    func rescindEmergencyOrder(_ id: Int) -> Bool {
        guard let o = gameState?.shadow.powerPlays.orders.first(where: { $0.id == id }), o.status.isLive else { return false }
        endEmergencyOrder(id, status: .rescinded, why: "withdrawn by the President")
        return true
    }

    /// End an order (struck down, lapsed, withdrawn) and undo what it did.
    func endEmergencyOrder(_ id: Int, status: EmergencyOrderStatus, why: String) {
        guard let gs = gameState, let i = gs.shadow.powerPlays.orders.firstIndex(where: { $0.id == id }) else { return }
        let wasInForce = gs.shadow.powerPlays.orders[i].status == .inForce || gs.shadow.powerPlays.orders[i].status == .upheld
        gs.shadow.powerPlays.orders[i].status = status
        gs.shadow.powerPlays.orders[i].ruled = gs.currentDate
        let o = gs.shadow.powerPlays.orders[i]
        if status == .struckDown, !gs.shadow.powerPlays.orders[i].struckBases.contains(o.basis) { gs.shadow.powerPlays.orders[i].struckBases.append(o.basis) }
        self.gameState = gs
        if o.kind == .tariff && wasInForce { applyTariffEffect(o.target, on: false) }
        emergencyOrderEnded(o, why: why)
    }

    /// What ending an order means beyond the tariff itself: refunds, and the news. Other order kinds' features read
    /// `emergencyOrderInForce` to stop what they do.
    func emergencyOrderEnded(_ o: EmergencyOrder, why: String) {
        guard let gs = gameState else { return }
        switch o.status {
        case .struckDown:
            if o.kind == .tariff && o.collected > 0 { spendFunds(o.collected) }
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 2)
            if let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) {
                gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport - 2)
            }
            let refund = o.kind == .tariff && o.collected > 0 ? " $\(ChatTools.round1(o.collected))B in duties must be refunded." : ""
            gs.shadow.post("\(court(gs.currentYear)) strikes down the \(o.subject): \(o.basis.short) does not reach that far.\(refund) The President may reissue under another authority.",
                           date: gs.currentDate, severity: 2)
            addLog("⚖️ Struck down: \(o.subject) (\(o.basis.short)).", type: .warning)
        case .lapsed:
            gs.shadow.post("The \(o.subject) lapse: \(why).", date: gs.currentDate, severity: 1)
        case .rescinded:
            gs.shadow.post("The \(o.subject) are withdrawn.", date: gs.currentDate, severity: 1)
        default: break
        }
        logPlayEvent("emergency_order_ended", detail: ["id": o.id, "kind": o.kind.rawValue, "target": o.target, "basis": o.basis.rawValue,
                                                       "status": o.status.rawValue, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
    }

    /// The court that rules in the player's country and year.
    func court(_ year: Int) -> String {
        guard gameState?.playerCountryID == "USA" else { return "The high court" }
        return year >= 1891 ? "The Supreme Court" : "The federal courts"
    }

    /// Days until an order's ruling (nil once ruled, or for orders no court reviews).
    func daysToRuling(_ o: EmergencyOrder) -> Int? {
        guard let gs = gameState, o.status == .pending || o.status == .inForce else { return nil }
        if o.basis.limitDays > 0 && o.basis.limitDays <= o.basis.courtDays { return nil }
        return max(0, o.basis.courtDays - o.days(to: gs.currentDate))
    }

    /// Each turn: investigations finish, duties are collected, time limits run out, the courts rule, Congress weighs
    /// ending the emergency.
    func processEmergencyOrders() {
        guard let gs = gameState else { return }
        let months = gs.scale.yearFraction * 12
        let bite = gs.playerCountryID == "USA" || EmergencyPowers.courtsBite(gs.getPlayerCountry()?.government ?? .democracy)
        for o in gs.shadow.powerPlays.orders where o.status.isLive {
            guard let i = gs.shadow.powerPlays.orders.firstIndex(where: { $0.id == o.id }) else { continue }
            let days = o.days(to: gs.currentDate)
            if o.status == .pending && days >= o.basis.investigationDays {
                gs.shadow.powerPlays.orders[i].status = .inForce
                if o.kind == .tariff {
                    self.gameState = gs
                    applyTariffEffect(o.target, on: true)
                }
                gs.shadow.post("The investigation is done: the \(o.subject) take effect.", date: gs.currentDate, severity: 1)
                continue
            }
            if o.kind == .tariff, o.status == .inForce || o.status == .upheld, let t = gs.getCountry(id: o.target) {
                gs.shadow.powerPlays.orders[i].collected += EmergencyPowers.monthlyDuties(targetGDPTrillions: t.gdp) * months
            }
            if o.basis.limitDays > 0 && days >= o.basis.limitDays {
                self.gameState = gs
                endEmergencyOrder(o.id, status: .lapsed, why: "the \(o.basis.limitDays)-day limit of \(o.basis.short) ran out")
                continue
            }
            if o.status == .inForce && days >= o.basis.courtDays {
                if !bite || courtUpholds(o) {
                    gs.shadow.powerPlays.orders[i].status = .upheld
                    gs.shadow.powerPlays.orders[i].ruled = gs.currentDate
                    if bite {
                        gs.shadow.post("\(court(gs.currentYear)) upholds the \(o.subject) under \(o.basis.short).", date: gs.currentDate, severity: 1)
                    }
                } else {
                    self.gameState = gs
                    endEmergencyOrder(o.id, status: .struckDown, why: "struck down")
                }
            }
        }
        self.gameState = gs
        congressWeighsEmergency()
    }

    /// From the National Emergencies Act (1976): a Congress that has turned on the President votes to end the
    /// emergency; the President vetoes; two-thirds of the Senate overrides. Deterministic.
    func congressWeighsEmergency() {
        guard let gs = gameState, gs.playerCountryID == "USA", gs.currentYear >= EmergencyPowers.nationalEmergenciesAct,
              let e = gs.shadow.powerPlays.emergency, let me = gs.getPlayerCountry(),
              GameCalendar.days(from: e.declared, to: gs.currentDate) >= 60 else { return }
        let house = CongressModel.house(congress: me.congressionalSupport, popularity: gs.shadow.popularity)
        let senate = CongressModel.senate(congress: me.congressionalSupport, popularity: gs.shadow.popularity)
        guard house < 40 && senate < 50 else { return }
        if senate < 34 {
            endNationalEmergency(by: "by Congress over the President's veto")
        } else if !gs.shadow.ticker.suffix(40).contains(where: { $0.text.hasPrefix("Congress votes to end the national emergency") }) {
            gs.shadow.post("Congress votes to end the national emergency; the President vetoes it and the veto holds.", date: gs.currentDate, severity: 2)
            self.gameState = gs
        }
    }
}

// MARK: - The ordinary tariff action

extension GameEngine {
    /// 3.36.0: the Situation Room's Impose Tariffs goes on the record as an order under the strongest authority
    /// open to it (in force at once, as before), so it can be challenged in court like an emergency tariff; Remove
    /// Tariffs withdraws it.
    func noteTariffOrder(_ action: PresidentialAction, target: String) {
        guard let gs = gameState, gs.getCountry(id: target) != nil else { return }
        if action == .removeTariffs {
            if let o = liveEmergencyOrder(.tariff, target: target) { endEmergencyOrder(o.id, status: .rescinded, why: "withdrawn") }
            return
        }
        guard liveEmergencyOrder(.tariff, target: target) == nil, let basis = legalBases(for: .tariff, target: target).first,
              var o = issueEmergencyOrder(kind: .tariff, target: target, subject: "tariffs on \(gs.getCountry(id: target)?.name ?? target)", basis: basis),
              let i = gs.shadow.powerPlays.orders.firstIndex(where: { $0.id == o.id }) else { return }
        o.status = .inForce   // the action has already taken effect
        gs.shadow.powerPlays.orders[i] = o
        self.gameState = gs
    }
}

/// What an emergency order on the command box does (`GameOrder.mission`).
enum EmergencyStep: String, Codable, CaseIterable, Sendable {
    case declare, end, tariff, reissue
}
