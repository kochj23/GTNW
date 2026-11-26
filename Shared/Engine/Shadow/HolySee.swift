//
//  HolySee.swift
//  Global Thermal Nuclear War
//
//  3.37.0: the Holy See's statecraft. When the player leads Vatican City there is no army to send (RegimeCapability
//  asks an ally), so the levers are the ones popes have actually used as heads of state in the last hundred years:
//  mediation, a neutral venue for talks, a quiet back channel, an appeal in a nuclear crisis, envoys before a war,
//  a teaching document on a theme, arms-control treaties, humanitarian work (tracing the missing, sheltering refugees,
//  prisoner exchanges), pastoral visits, an interfaith gathering for peace, a debt relief campaign, patient diplomacy
//  with hostile governments, an address to the United Nations, and a voluntary resignation.
//  Each is one action with a cooldown, odds from the nations' relations with the Holy See, and a visible result; the
//  record (peace brokered, crises defused, lives saved, treaties signed) scores the game and can win it ("Honest
//  Broker"). Everything here is statecraft, diplomacy and humanitarian work: no rite, sacrament or religious act is a
//  game mechanic, every faith is treated as an equal, and no real pope is named or quoted. Each action's text says in
//  one plain sentence what the Holy See did historically.
//  Deterministic: every roll is `gameRoll()` (gs.rng). Nothing here runs, or draws a number, unless the player leads
//  Vatican City.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - The actions

enum HolySeeAction: String, CaseIterable, Codable, Sendable {
    case mediate, hostTalks, backChannel, appealForPeace, sendEnvoys, encyclical, ratifyTreaty
    case tracePrisoners, shelterRefugees, prisonerExchange, pastoralVisit, interfaithGathering, debtRelief
    case openRelations, addressUN, resignOffice

    /// How many nations the action names: none, one, or a pair.
    var targets: Int {
        switch self {
        case .mediate, .hostTalks, .backChannel, .sendEnvoys, .prisonerExchange: return 2
        case .pastoralVisit, .openRelations: return 1
        default: return 0
        }
    }

    var title: String {
        switch self {
        case .mediate: return "MEDIATE A DISPUTE"
        case .hostTalks: return "HOST PEACE TALKS"
        case .backChannel: return "SECRET BACK CHANNEL"
        case .appealForPeace: return "APPEAL FOR PEACE"
        case .sendEnvoys: return "ENVOYS TO BOTH CAPITALS"
        case .encyclical: return "TEACHING DOCUMENT"
        case .ratifyTreaty: return "RATIFY A TREATY"
        case .tracePrisoners: return "TRACE THE MISSING"
        case .shelterRefugees: return "SHELTER REFUGEES"
        case .prisonerExchange: return "PRISONER EXCHANGE"
        case .pastoralVisit: return "PASTORAL VISIT"
        case .interfaithGathering: return "INTERFAITH GATHERING FOR PEACE"
        case .debtRelief: return "DEBT RELIEF CAMPAIGN"
        case .openRelations: return "DIPLOMATIC RELATIONS"
        case .addressUN: return "ADDRESS THE UNITED NATIONS"
        case .resignOffice: return "RESIGN"
        }
    }

    /// What it does, in one line.
    var summary: String {
        switch self {
        case .mediate: return "Offer mediation between two nations in a dispute or at war. Both must accept; success ends it with a treaty signed at the Vatican."
        case .hostTalks: return "Offer the Vatican as the venue for talks between two nations at war. The talks may produce a ceasefire."
        case .backChannel: return "Quietly broker a thaw between two hostile nations. A prisoner release comes with it."
        case .appealForPeace: return "In a nuclear crisis, a broadcast appeal gives the side about to escalate a way to step back with its dignity intact."
        case .sendEnvoys: return "Send envoys to two capitals before a war starts. They may delay it, or avert it."
        case .encyclical: return "Issue a teaching document on a theme. It shifts world opinion and other nations' willingness on that theme for two years."
        case .ratifyTreaty: return "Ratify an arms-control treaty and press other nations to join it."
        case .tracePrisoners: return "An information office traces prisoners of war and missing civilians and tells their families."
        case .shelterRefugees: return "Shelter refugees from a war on the Vatican's extraterritorial properties."
        case .prisonerExchange: return "Help two warring nations exchange prisoners and return children, with an aid convoy."
        case .pastoralVisit: return "Visit a country: civil society grows stronger, an authoritarian government feels peaceful pressure to reform, and a visit to both sides of a war argues for peace."
        case .interfaithGathering: return "Invite the world's faith leaders, as equals, to a gathering for peace, with a call for a day of truce."
        case .debtRelief: return "Press the richest nations to forgive the debts of the poorest."
        case .openRelations: return "Establish diplomatic relations, or patiently negotiate with a government hostile to religion to ease its restrictions."
        case .addressUN: return "Address the General Assembly once: the standing of every peace effort rises for a year."
        case .resignOffice: return "Resign of your own free will. The game ends and is scored on the record built so far."
        }
    }

    /// The historical precedent, in one plain sentence.
    var precedent: String {
        switch self {
        case .mediate: return "Based on the Holy See's 1978-84 mediation of the Beagle Channel dispute between Argentina and Chile, settled by a treaty signed at the Vatican."
        case .hostTalks: return "Based on the Holy See's 2025 offer of the Vatican as a venue for talks between Russia and Ukraine."
        case .backChannel: return "Based on the Holy See's quiet part in the 2014 thaw between the United States and Cuba, which included a prisoner release."
        case .appealForPeace: return "Based on the appeal for peace broadcast over Vatican Radio during the 1962 Cuban Missile Crisis."
        case .sendEnvoys: return "Based on the envoys the Holy See sent to Washington and Baghdad in 2003."
        case .encyclical: return "Based on documents such as Pacem in Terris (1963) and Laudato si' (2015)."
        case .ratifyTreaty: return "Based on the Holy See's ratification of the Treaty on the Prohibition of Nuclear Weapons in 2017, among the first."
        case .tracePrisoners: return "Based on the Vatican Information Office, which traced prisoners of war and missing civilians from 1939 to 1947."
        case .shelterRefugees: return "Based on the refugees sheltered on Vatican extraterritorial properties, including Castel Gandolfo, during the Second World War."
        case .prisonerExchange: return "Based on the Holy See's help with prisoner exchanges, the return of children and aid convoys in Ukraine since 2022."
        case .pastoralVisit: return "Based on papal visits to Poland in 1979, to Britain and Argentina during the 1982 Falklands War, and to South Sudan in 2023."
        case .interfaithGathering: return "Based on the 1986 gathering of faith leaders for peace at Assisi, with its call for a day of truce."
        case .debtRelief: return "Based on the Holy See's support for the Jubilee 2000 campaign to cancel the debts of the poorest nations."
        case .openRelations: return "Based on the Holy See's patient diplomacy with Eastern Bloc governments in the 1960s and 70s; today it has relations with about 180 states."
        case .addressUN: return "Based on the 1965 address to the United Nations General Assembly calling for an end to war."
        case .resignOffice: return "Based on the papal resignation of 2013."
        }
    }

    /// Days before the same action can be taken again.
    var cooldownDays: Int {
        switch self {
        case .mediate, .hostTalks, .sendEnvoys, .shelterRefugees, .prisonerExchange: return 180
        case .backChannel, .tracePrisoners: return 365
        case .appealForPeace, .openRelations: return 90
        case .pastoralVisit: return 60
        case .encyclical, .debtRelief: return 730
        case .interfaithGathering: return 1095
        case .ratifyTreaty: return 30
        case .addressUN, .resignOffice: return 0   // once
        }
    }

    /// The first year it makes sense: Vatican Radio (1931), the United Nations (1945). Treaties carry their own years.
    var fromYear: Int {
        switch self {
        case .appealForPeace: return 1931
        case .addressUN: return 1945
        default: return 0
        }
    }

    /// The teaching theme whose document makes this action more likely to work.
    var theme: TeachingTheme? {
        switch self {
        case .mediate, .hostTalks, .backChannel, .sendEnvoys, .prisonerExchange, .interfaithGathering, .pastoralVisit: return .peace
        case .appealForPeace, .ratifyTreaty: return .nuclear
        case .debtRelief: return .workers
        case .openRelations: return .peace
        default: return nil
        }
    }

    /// The play-history event kind (Nova's game reports list them; nova_game_report.py ANTIC_KINDS).
    var eventKind: String {
        switch self {
        case .mediate: return "holy_see_mediation"
        case .hostTalks: return "holy_see_peace_talks"
        case .backChannel: return "holy_see_back_channel"
        case .appealForPeace: return "holy_see_appeal"
        case .sendEnvoys: return "holy_see_envoys"
        case .encyclical: return "holy_see_teaching"
        case .ratifyTreaty: return "holy_see_treaty"
        case .tracePrisoners, .shelterRefugees, .prisonerExchange: return "holy_see_humanitarian"
        case .pastoralVisit: return "holy_see_visit"
        case .interfaithGathering: return "holy_see_interfaith"
        case .debtRelief: return "holy_see_debt_relief"
        case .openRelations: return "holy_see_relations"
        case .addressUN: return "holy_see_un_address"
        case .resignOffice: return "holy_see_resignation"
        }
    }

    var verb: CommandVerb? { CommandVerb(rawValue: rawValue) }
}

extension CommandVerb {
    /// 3.37.0: the Holy See's action this verb names (HolySee.swift), or nil.
    var holySeeAction: HolySeeAction? { HolySeeAction(rawValue: rawValue) }
}

/// The theme of a teaching document.
enum TeachingTheme: String, CaseIterable, Codable, Sendable {
    case nuclear, environment, workers, peace

    var title: String {
        switch self {
        case .nuclear: return "nuclear disarmament"
        case .environment: return "care for the environment"
        case .workers: return "workers and the poor"
        case .peace: return "peace among nations"
        }
    }

    /// A real document on the theme, for the card.
    var example: String {
        switch self {
        case .nuclear: return "Pacem in Terris (1963)"
        case .environment: return "Laudato si' (2015)"
        case .workers: return "Laborem Exercens (1981)"
        case .peace: return "Fratelli tutti (2020)"
        }
    }

    /// Words that name the theme in a typed order.
    var keywords: [String] {
        switch self {
        case .nuclear: return ["nuclear", "disarmament", "bomb", "arms"]
        case .environment: return ["environment", "climate", "creation", "planet", "ecology", "earth"]
        case .workers: return ["workers", "labor", "labour", "poor", "poverty", "work", "justice"]
        case .peace: return ["peace", "war", "fraternity", "brotherhood"]
        }
    }
}

/// An arms-control treaty the Holy See can ratify, from the year it opened.
struct ArmsTreaty: Equatable, Sendable {
    var id: String
    var name: String
    var year: Int
    /// The Holy See's real ratification or accession, for the card.
    var holySeeYear: Int
    var nuclear: Bool
    /// Nuclear-armed nations never join it (the prohibition treaty).
    var nonNuclearOnly: Bool
    var keywords: [String]

    static let all: [ArmsTreaty] = [
        ArmsTreaty(id: "npt", name: "Treaty on the Non-Proliferation of Nuclear Weapons", year: 1968, holySeeYear: 1971, nuclear: true,
                   nonNuclearOnly: false, keywords: ["non proliferation", "nonproliferation", "npt"]),
        ArmsTreaty(id: "cwc", name: "Chemical Weapons Convention", year: 1993, holySeeYear: 1999, nuclear: false, nonNuclearOnly: false,
                   keywords: ["chemical"]),
        ArmsTreaty(id: "ctbt", name: "Comprehensive Nuclear-Test-Ban Treaty", year: 1996, holySeeYear: 2001, nuclear: true, nonNuclearOnly: false,
                   keywords: ["test ban", "testban", "ctbt"]),
        ArmsTreaty(id: "mines", name: "Mine Ban Treaty", year: 1997, holySeeYear: 1998, nuclear: false, nonNuclearOnly: false,
                   keywords: ["mine", "mines", "landmine", "landmines", "ottawa"]),
        ArmsTreaty(id: "cluster", name: "Convention on Cluster Munitions", year: 2008, holySeeYear: 2008, nuclear: false, nonNuclearOnly: false,
                   keywords: ["cluster"]),
        ArmsTreaty(id: "tpnw", name: "Treaty on the Prohibition of Nuclear Weapons", year: 2017, holySeeYear: 2017, nuclear: true, nonNuclearOnly: true,
                   keywords: ["prohibition", "nuclear ban", "ban treaty", "tpnw", "nuclear weapons ban"]),
    ]

    static func byID(_ id: String) -> ArmsTreaty? { all.first { $0.id == id } }

    /// The treaty a typed order names ("ratify the nuclear ban treaty"), or nil.
    static func named(_ text: String) -> ArmsTreaty? {
        let t = " " + text + " "
        return all.first { tr in tr.keywords.contains { t.contains(" \($0)") } }
    }
}

// MARK: - State (saved)

struct EnvoyHold: Codable, Equatable {
    var a: String
    var b: String
    var until: Date
    /// True once the hold has stopped a declaration (counted once).
    var held = false
}

struct Teaching: Codable, Equatable {
    var theme: TeachingTheme
    var issued: Date
    var until: Date
    /// World-opinion points already applied (one a turn, up to `HolySeeModel.teachingOpinion`).
    var applied = 0
}

struct Reconciliation: Codable, Equatable {
    var a: String
    var b: String
    var date: Date
}

struct HolySeeEntry: Codable, Equatable, Identifiable {
    var id: Int
    var date: Date
    var action: HolySeeAction
    var text: String
    var success: Bool
}

/// The record a Vatican game is scored on.
struct HolySeeRecord: Codable, Equatable {
    var treatiesAtVatican = 0
    var ceasefires = 0
    var crisesDefused = 0
    var warsAverted = 0
    var warsDelayed = 0
    var thaws = 0
    var traced = 0
    var sheltered = 0
    var returned = 0
    var treatiesRatified = 0
    var treatyJoiners = 0
    var debtRelievedB = 0.0
    var relationsOpened = 0
    var reforms = 0
    var visits = 0
    var teachings = 0
    var gatherings = 0
    var addressedUN = false

    init() {}

    /// People traced, sheltered or brought home.
    var livesSaved: Int { traced + sheltered + returned }
    /// Wars ended or prevented and nuclear crises eased.
    var peaceActs: Int { treatiesAtVatican + ceasefires + crisesDefused + warsAverted }

    /// Peace brokered, crises defused, lives saved and treaties signed, in points (not land held).
    var points: Int {
        var p = treatiesAtVatican * 150 + ceasefires * 120 + crisesDefused * 150 + warsAverted * 120 + warsDelayed * 40 + thaws * 80
        p += min(300, livesSaved / 100)                      // 10 points per 1,000 people
        p += treatiesRatified * 40 + min(100, treatyJoiners * 5)
        p += min(150, Int(debtRelievedB * 2))
        p += relationsOpened * 15 + reforms * 60 + min(50, visits * 5) + teachings * 30 + gatherings * 40 + (addressedUN ? 50 : 0)
        return p
    }

    enum CodingKeys: String, CodingKey {
        case treatiesAtVatican, ceasefires, crisesDefused, warsAverted, warsDelayed, thaws, traced, sheltered, returned
        case treatiesRatified, treatyJoiners, debtRelievedB, relationsOpened, reforms, visits, teachings, gatherings, addressedUN
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func i(_ k: CodingKeys) -> Int { (try? c.decodeIfPresent(Int.self, forKey: k)) ?? 0 }
        treatiesAtVatican = i(.treatiesAtVatican); ceasefires = i(.ceasefires); crisesDefused = i(.crisesDefused)
        warsAverted = i(.warsAverted); warsDelayed = i(.warsDelayed); thaws = i(.thaws); traced = i(.traced)
        sheltered = i(.sheltered); returned = i(.returned); treatiesRatified = i(.treatiesRatified); treatyJoiners = i(.treatyJoiners)
        debtRelievedB = (try? c.decodeIfPresent(Double.self, forKey: .debtRelievedB)) ?? 0
        relationsOpened = i(.relationsOpened); reforms = i(.reforms); visits = i(.visits); teachings = i(.teachings)
        gatherings = i(.gatherings)
        addressedUN = (try? c.decodeIfPresent(Bool.self, forKey: .addressedUN)) ?? false
    }
}

/// Saved on `ShadowState.holySee`. Empty (and untouched) unless the player leads Vatican City.
struct HolySeeState: Codable, Equatable {
    var lastUsed: [String: Date] = [:]
    var record = HolySeeRecord()
    var holds: [EnvoyHold] = []
    var teachings: [Teaching] = []
    var reconciled: [Reconciliation] = []
    var ratified: [String] = []
    var accredited: [String] = []
    /// Failed attempts at relations, by nation: patience improves the odds.
    var attempts: [String: Int] = [:]
    var reformPressure: [String: Int] = [:]
    var reformed: [String] = []
    var visited: [String: Date] = [:]
    var unAddress: Date?
    var log: [HolySeeEntry] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case lastUsed, record, holds, teachings, reconciled, ratified, accredited, attempts, reformPressure, reformed, visited, unAddress, log
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastUsed = (try? c.decodeIfPresent([String: Date].self, forKey: .lastUsed)) ?? [:]
        record = (try? c.decodeIfPresent(HolySeeRecord.self, forKey: .record)) ?? HolySeeRecord()
        holds = (try? c.decodeIfPresent([EnvoyHold].self, forKey: .holds)) ?? []
        teachings = (try? c.decodeIfPresent([Teaching].self, forKey: .teachings)) ?? []
        reconciled = (try? c.decodeIfPresent([Reconciliation].self, forKey: .reconciled)) ?? []
        ratified = (try? c.decodeIfPresent([String].self, forKey: .ratified)) ?? []
        accredited = (try? c.decodeIfPresent([String].self, forKey: .accredited)) ?? []
        attempts = (try? c.decodeIfPresent([String: Int].self, forKey: .attempts)) ?? [:]
        reformPressure = (try? c.decodeIfPresent([String: Int].self, forKey: .reformPressure)) ?? [:]
        reformed = (try? c.decodeIfPresent([String].self, forKey: .reformed)) ?? []
        visited = (try? c.decodeIfPresent([String: Date].self, forKey: .visited)) ?? [:]
        unAddress = try? c.decodeIfPresent(Date.self, forKey: .unAddress)
        log = (try? c.decodeIfPresent([HolySeeEntry].self, forKey: .log)) ?? []
    }

    static func pairKey(_ a: String, _ b: String) -> String { a < b ? "\(a)|\(b)" : "\(b)|\(a)" }
}

/// One Holy See order: the action, up to two nations, and a theme or a treaty.
struct HolySeeOrder: Equatable, Sendable {
    var action: HolySeeAction
    var first: String? = nil
    var second: String? = nil
    /// A `TeachingTheme` (teaching document) or an `ArmsTreaty` id (ratify).
    var option: String? = nil

    /// The command box's order: `target` the first nation (or "VAT"), `mission` the action, `detail` the second
    /// nation or the option.
    var gameOrder: GameOrder {
        GameOrder(kind: .holySee, target: first ?? HolySeeModel.id, mission: action.rawValue, detail: second ?? option)
    }

    static func from(_ o: GameOrder) -> HolySeeOrder? {
        guard o.kind == .holySee, let a = o.mission.flatMap(HolySeeAction.init(rawValue:)) else { return nil }
        switch a.targets {
        case 2: return HolySeeOrder(action: a, first: o.target, second: o.detail)
        case 1: return HolySeeOrder(action: a, first: o.target)
        default: return HolySeeOrder(action: a, option: o.detail)
        }
    }
}

/// What a Holy See action did.
struct HolySeeResult: Equatable {
    var success: Bool
    var lines: [String]
}

// MARK: - The model (pure)

enum HolySeeModel {
    static let id = "VAT"
    /// "Honest Broker": the record's points, the peace acts among them, and the years in office.
    static let victoryPoints = 600
    static let victoryActs = 2
    static let victoryYears = 2.0
    /// World-opinion points a teaching document adds, one a turn.
    static let teachingOpinion = 10
    /// A treaty signed at the Vatican keeps the two from war this long.
    static let reconciliationYears = 5
    static let reformThreshold = 30

    /// True when the Holy See's actions are offered: the player leads Vatican City.
    static func isOffered(_ gs: GameState?) -> Bool { gs?.playerCountryID == id && gs?.isMultiplayer == false }

    static func rel(_ gs: GameState, _ x: String) -> Int { gs.getCountry(id: x)?.diplomaticRelations[id] ?? 0 }
    static func mutual(_ gs: GameState, _ a: String, _ b: String) -> Int {
        min(gs.getCountry(id: a)?.diplomaticRelations[b] ?? 0, gs.getCountry(id: b)?.diplomaticRelations[a] ?? 0)
    }
    static func atWar(_ gs: GameState, _ a: String, _ b: String) -> Bool { gs.getCountry(id: a)?.atWarWith.contains(b) ?? false }

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }

    /// The willingness a teaching document (or the United Nations address, for peace) adds to an action's odds.
    static func bonus(_ gs: GameState, _ theme: TeachingTheme?) -> Double {
        guard let theme else { return 0 }
        var b = gs.shadow.holySee.teachings.contains { $0.theme == theme && gs.currentDate < $0.until } ? 0.15 : 0
        if theme == .peace, let d = gs.shadow.holySee.unAddress, GameCalendar.days(from: d, to: gs.currentDate) < 365 { b += 0.1 }
        return b
    }

    /// One side's acceptance of mediation.
    static func acceptOdds(_ gs: GameState, _ x: String) -> Double { clamp(0.3 + Double(rel(gs, x)) / 200 + bonus(gs, .peace), 0.1, 0.9) }

    /// The headline odds of an action between two nations (the card and the query show it).
    static func pairOdds(_ gs: GameState, _ action: HolySeeAction, _ a: String, _ b: String) -> Double {
        let r = Double(rel(gs, a) + rel(gs, b)) / 400 + bonus(gs, action.theme)
        switch action {
        case .mediate: return acceptOdds(gs, a) * acceptOdds(gs, b)
        case .hostTalks: return clamp(0.3 + r, 0.1, 0.85)
        case .backChannel: return clamp(0.35 + r, 0.1, 0.85)
        case .sendEnvoys: return clamp(0.3 + r, 0.1, 0.85)
        case .prisonerExchange: return clamp(0.4 + r, 0.15, 0.9)
        default: return 0
        }
    }

    /// The nation about to escalate in a nuclear crisis: the nuclear-armed nation at war with the most aggression
    /// (ties on warheads, then id); with no such war, the largest arsenal.
    static func escalatingSide(_ gs: GameState) -> Country? {
        let armed = gs.liveCountries.filter { $0.id != id && $0.nuclearWarheads > 0 }
        let fighting = armed.filter { !$0.atWarWith.isEmpty }
        let pool = fighting.isEmpty ? armed : fighting
        return pool.max { a, b in
            if a.aggressionLevel != b.aggressionLevel { return a.aggressionLevel < b.aggressionLevel }
            if a.nuclearWarheads != b.nuclearWarheads { return a.nuclearWarheads < b.nuclearWarheads }
            return a.id > b.id
        }
    }

    static func appealOdds(_ gs: GameState, _ side: Country) -> Double {
        clamp(0.35 + Double(side.diplomaticRelations[id] ?? 0) / 250 + bonus(gs, .nuclear), 0.15, 0.85)
    }

    /// Pairs for the pickers: wars first, then the most hostile pairs not at war (relations −30 or worse).
    static func pairs(_ gs: GameState, wars: Bool, disputes: Bool, limit: Int = 12) -> [(Country, Country)] {
        let live = gs.liveCountries.filter { $0.id != id }.sorted { $0.id < $1.id }
        var war: [(Country, Country)] = [], dispute: [(Country, Country, Int)] = []
        for (i, a) in live.enumerated() {
            for b in live[(i + 1)...] {
                if a.atWarWith.contains(b.id) { if wars { war.append((a, b)) } }
                else if disputes {
                    let m = mutual(gs, a.id, b.id)
                    if m <= -30 { dispute.append((a, b, m)) }
                }
            }
        }
        dispute.sort { $0.2 != $1.2 ? $0.2 < $1.2 : ($0.0.id, $0.1.id) < ($1.0.id, $1.1.id) }
        return Array((war + dispute.map { ($0.0, $0.1) }).prefix(limit))
    }

    /// A government the game treats as hostile to religion (Ostpolitik's counterparts).
    static func hostileToReligion(_ c: Country) -> Bool { c.government == .communist }

    static func isAuthoritarian(_ c: Country) -> Bool { [.authoritarian, .communist, .military].contains(c.government) }

    /// Relations already in place: an agreement made this game, or a nation not hostile to religion that is not hostile
    /// to the Holy See.
    static func hasRelations(_ gs: GameState, _ c: Country) -> Bool {
        gs.shadow.holySee.accredited.contains(c.id) || (!hostileToReligion(c) && (c.diplomaticRelations[id] ?? 0) >= 0)
    }

    static func relationsOdds(_ gs: GameState, _ c: Country) -> Double {
        let patience = 0.1 * Double(gs.shadow.holySee.attempts[c.id] ?? 0)
        let r = Double(c.diplomaticRelations[id] ?? 0) / 200 + patience + bonus(gs, .peace)
        return hostileToReligion(c) ? clamp(0.25 + r, 0.1, 0.8) : clamp(0.5 + r, 0.2, 0.95)
    }

    /// The richest nations (creditors) and the poorest (debtors) for a debt relief campaign.
    static func creditors(_ gs: GameState) -> [Country] {
        Array(gs.liveCountries.filter { $0.id != id }.sorted { $0.gdp != $1.gdp ? $0.gdp > $1.gdp : $0.id < $1.id }.prefix(5))
    }

    static func debtors(_ gs: GameState) -> [Country] {
        func perHead(_ c: Country) -> Double { c.gdp / Double(max(1, c.population)) }
        return Array(gs.liveCountries.filter { $0.id != id && $0.population >= 1 }
            .sorted { perHead($0) != perHead($1) ? perHead($0) < perHead($1) : $0.id < $1.id }.prefix(8))
    }

    static func debtOdds(_ gs: GameState, _ c: Country) -> Double { clamp(0.25 + Double(c.diplomaticRelations[id] ?? 0) / 200 + bonus(gs, .workers), 0.1, 0.85) }

    /// The treaties open for ratification this year that the Holy See has not ratified.
    static func openTreaties(_ gs: GameState) -> [ArmsTreaty] {
        ArmsTreaty.all.filter { $0.year <= gs.currentYear && !gs.shadow.holySee.ratified.contains($0.id) }
    }

    /// Nations a treaty's ratification may draw in, by id.
    static func treatyCandidates(_ gs: GameState, _ t: ArmsTreaty) -> [Country] {
        gs.liveCountries.filter { $0.id != id && ($0.diplomaticRelations[id] ?? 0) >= 20 && !(t.nonNuclearOnly && $0.nuclearWarheads > 0) }
            .sorted { $0.id < $1.id }
    }

    static func treatyJoinOdds(_ gs: GameState, _ t: ArmsTreaty, _ c: Country) -> Double {
        clamp(0.1 + Double(c.diplomaticRelations[id] ?? 0) / 300 + bonus(gs, t.nuclear ? .nuclear : .peace), 0.02, 0.6)
    }

    /// An envoy hold or a recent treaty signed at the Vatican keeps these two from war.
    static func holds(_ gs: GameState, _ a: String, _ b: String) -> Bool {
        let h = gs.shadow.holySee
        guard !h.holds.isEmpty || !h.reconciled.isEmpty else { return false }
        let key = HolySeeState.pairKey(a, b), now = gs.currentDate
        if h.holds.contains(where: { HolySeeState.pairKey($0.a, $0.b) == key && now < $0.until }) { return true }
        return h.reconciled.contains { HolySeeState.pairKey($0.a, $0.b) == key
            && GameCalendar.years(from: $0.date, to: now) < Double(reconciliationYears) }
    }

    /// The date the action can be taken again, or nil when it can now.
    static func readyOn(_ gs: GameState, _ a: HolySeeAction) -> Date? {
        guard a.cooldownDays > 0, let last = gs.shadow.holySee.lastUsed[a.rawValue] else { return nil }
        let next = GameCalendar.calendar.date(byAdding: .day, value: a.cooldownDays, to: last) ?? last
        return gs.currentDate < next ? next : nil
    }

    // MARK: Score and victory

    static func points(_ gs: GameState) -> Int { gs.playerCountryID == id ? gs.shadow.holySee.record.points : 0 }

    /// Added to the peace bonus (PeaceModel.scoreBonus). Zero for any other nation.
    static func scoreBonus(_ gs: GameState) -> Int { points(gs) }

    /// What still stands between the Holy See and "Honest Broker" (nil when met).
    static func victoryProblem(_ gs: GameState) -> String? {
        guard gs.playerCountryID == id, let me = gs.getPlayerCountry() else { return "Only the Holy See." }
        let r = gs.shadow.holySee.record
        if r.points < victoryPoints { return "\(r.points) of \(victoryPoints) points on the record" }
        if r.peaceActs < victoryActs { return "\(r.peaceActs) of \(victoryActs) wars ended, averted or crises defused" }
        if gs.nuclearStrikes.contains(where: { $0.attacker == me.id }) { return "Nuclear weapons were used in the Holy See's name." }
        if !me.atWarWith.isEmpty { return "The Holy See is at war." }
        if gs.elapsedYears < victoryYears - 1e-6 { return String(format: "%.1f of %.0f years in office", gs.elapsedYears, victoryYears) }
        return nil
    }

    static func victory(_ gs: GameState) -> VictoryType? { victoryProblem(gs) == nil ? .honestBroker : nil }

    // MARK: Awards

    static let awards: [PresidencyAward] = [
        PresidencyAward(id: "signed_at_the_vatican", name: "Signed at the Vatican",
                        description: "Two nations signed a treaty at the Vatican after the Holy See mediated their dispute", icon: "signature", rarity: "Rare"),
        PresidencyAward(id: "back_from_the_brink", name: "Back from the Brink",
                        description: "An appeal for peace helped ease a nuclear crisis", icon: "dot.radiowaves.left.and.right", rarity: "Epic"),
        PresidencyAward(id: "the_war_that_never_was", name: "The War That Never Was",
                        description: "Envoys to both capitals averted a war before it started", icon: "envelope.open", rarity: "Rare"),
        PresidencyAward(id: "ten_thousand_families", name: "Ten Thousand Families",
                        description: "Traced, sheltered or brought home 10,000 people in one game", icon: "person.3", rarity: "Rare"),
        PresidencyAward(id: "honest_broker", name: "Honest Broker",
                        description: "Won a game as the Holy See on its record of peace", icon: "hands.sparkles", rarity: "Legendary"),
    ]

    static func earnedAwards(_ gs: GameState, victory: VictoryType?) -> [String] {
        guard gs.playerCountryID == id else { return [] }
        let r = gs.shadow.holySee.record
        var out: [String] = []
        if r.treatiesAtVatican > 0 { out.append("signed_at_the_vatican") }
        if r.crisesDefused > 0 { out.append("back_from_the_brink") }
        if r.warsAverted > 0 { out.append("the_war_that_never_was") }
        if r.livesSaved >= 10_000 { out.append("ten_thousand_families") }
        if victory == .honestBroker || victoryProblem(gs) == nil { out.append("honest_broker") }
        return out
    }

    // MARK: The history books

    /// The record in one sentence for the epilogue, or nil when there is nothing on it.
    static func epilogueLine(_ gs: GameState) -> String? {
        guard gs.playerCountryID == id else { return nil }
        let r = gs.shadow.holySee.record
        var parts: [String] = []
        func n(_ k: Int, _ one: String, _ many: String) -> String { "\(k) \(k == 1 ? one : many)" }
        if r.treatiesAtVatican > 0 { parts.append("mediated \(n(r.treatiesAtVatican, "dispute", "disputes")) to a treaty signed at the Vatican") }
        if r.ceasefires > 0 { parts.append("helped bring about \(n(r.ceasefires, "ceasefire", "ceasefires"))") }
        if r.crisesDefused > 0 { parts.append("helped ease \(n(r.crisesDefused, "nuclear crisis", "nuclear crises"))") }
        if r.warsAverted > 0 { parts.append("averted \(n(r.warsAverted, "war", "wars")) before it began") }
        if r.livesSaved > 0 { parts.append("traced, sheltered or brought home \(r.livesSaved) people") }
        if r.treatiesRatified > 0 { parts.append("ratified \(n(r.treatiesRatified, "arms treaty", "arms treaties"))") }
        guard !parts.isEmpty else { return nil }
        let list = parts.count == 1 ? parts[0] : parts.dropLast().joined(separator: ", ") + " and " + parts.last!
        return "The Holy See " + list + "."
    }
}

// MARK: - The engine

extension GameEngine {
    /// Why this Holy See order can't be given now, or nil.
    func holySeeProblem(_ o: HolySeeOrder) -> String? {
        guard let gs = gameState else { return "No game in progress." }
        guard HolySeeModel.isOffered(gs) else {
            return "Only the Holy See can do that. You lead \(gs.getPlayerCountry()?.name ?? gs.playerCountryID)."
        }
        if gs.gameOver { return "The game is over." }
        let a = o.action, year = gs.currentYear
        if year < a.fromYear { return "\(a.title.capitalized) is possible from \(a.fromYear)." }
        if let d = HolySeeModel.readyOn(gs, a) { return "The Secretariat of State is still following up the last one; again from \(GameCalendar.format(d))." }
        let h = gs.shadow.holySee
        func nation(_ x: String?) -> Country? {
            guard let x, x != HolySeeModel.id, let c = gs.getCountry(id: x), !c.isDestroyed, !c.isTerritory else { return nil }
            return c
        }
        if a.targets == 2 {
            guard let ca = nation(o.first), let cb = nation(o.second) else { return "Name two nations." }
            if ca.id == cb.id { return "Name two different nations." }
            let war = ca.atWarWith.contains(cb.id), m = HolySeeModel.mutual(gs, ca.id, cb.id)
            switch a {
            case .mediate where !war && m > -30:
                return "\(ca.name) and \(cb.name) have no dispute to mediate (relations \(m))."
            case .hostTalks where !war, .prisonerExchange where !war:
                return "\(ca.name) and \(cb.name) are not at war."
            case .backChannel where war, .sendEnvoys where war:
                return "\(ca.name) and \(cb.name) are already at war."
            case .backChannel where m > -20:
                return "\(ca.name) and \(cb.name) are not hostile enough to need a back channel."
            case .sendEnvoys where m > -30:
                return "No war is coming between \(ca.name) and \(cb.name) (relations \(m))."
            default: break
            }
        }
        if a.targets == 1 {
            guard let c = nation(o.first) else { return "Name a nation." }
            if a == .openRelations, HolySeeModel.hasRelations(gs, c) { return "The Holy See already has relations with \(c.name)." }
        }
        switch a {
        case .appealForPeace:
            if gs.defconLevel.rawValue > 2 { return "An appeal is for a nuclear crisis (\(gs.defconName) 2 or 1); it is \(gs.defconName) \(gs.defconLevel.rawValue)." }
            if HolySeeModel.escalatingSide(gs) == nil { return "No nuclear-armed nation to appeal to." }
        case .encyclical:
            guard o.option.flatMap(TeachingTheme.init(rawValue:)) != nil else { return "Choose a theme: nuclear, environment, workers or peace." }
        case .ratifyTreaty:
            guard let t = o.option.flatMap(ArmsTreaty.byID) else { return "Choose a treaty." }
            if t.year > year { return "The \(t.name) does not exist until \(t.year)." }
            if h.ratified.contains(t.id) { return "The Holy See has already ratified the \(t.name)." }
        case .tracePrisoners, .shelterRefugees:
            if gs.activeWars.isEmpty { return "There is no war with prisoners or refugees to help." }
        case .addressUN:
            if h.record.addressedUN { return "The Holy See has already addressed the General Assembly." }
        default: break
        }
        if a != .resignOffice, gs.actionsRemaining == 0 { return "No actions left this \(gs.turnLength.displayName.lowercased())." }
        return nil
    }

    func holySeeProblem(_ o: GameOrder) -> String? {
        guard let h = HolySeeOrder.from(o) else { return "Not an order of the Holy See." }
        return holySeeProblem(h)
    }

    /// Carry out a Holy See order (one action; resigning ends the game). `roll` replaces every roll (tests).
    @discardableResult
    func runHolySee(_ o: HolySeeOrder, roll: Double? = nil) -> HolySeeResult? {
        guard holySeeProblem(o) == nil, let gs = gameState else { return nil }
        func r() -> Double { roll ?? gameRoll() }
        let me = HolySeeModel.id
        let a = o.action
        let now = gs.currentDate
        func name(_ x: String?) -> String { x.flatMap { gs.getCountry(id: $0)?.name } ?? (x ?? "") }
        func toVAT(_ x: String, _ by: Int) { modifyDiplomaticRelation(from: x, to: me, by: by) }
        func both(_ x: String, _ y: String, _ by: Int) { modifyDiplomaticRelation(from: x, to: y, by: by); modifyDiplomaticRelation(from: y, to: x, by: by) }
        func approval(_ d: Double) { gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + d) }
        var success = true
        var lines: [String] = []
        var detail: [String: Any] = ["action": a.rawValue, "game_date": PlayHistory.day(now)]
        if let x = o.first { detail["first"] = x; detail["first_name"] = PlayHistory.text(name(x)) }
        if let y = o.second { detail["second"] = y; detail["second_name"] = PlayHistory.text(name(y)) }
        let A = o.first ?? "", B = o.second ?? ""
        let nA = name(o.first), nB = name(o.second)

        switch a {
        case .mediate:
            let war = HolySeeModel.atWar(gs, A, B)
            let pa = HolySeeModel.acceptOdds(gs, A), pb = HolySeeModel.acceptOdds(gs, B)
            let okA = r() < pa, okB = r() < pb
            detail["accepted_a"] = okA; detail["accepted_b"] = okB
            if okA && okB {
                if war { makePeace(A, B) }
                both(A, B, 35)
                gs.treaties.append(Treaty(type: .nonAggression, signatories: [A, B], turn: gs.turn))
                gs.shadow.holySee.reconciled.append(Reconciliation(a: A, b: B, date: now))
                gs.shadow.holySee.record.treatiesAtVatican += 1
                gs.conflictsMediated += 1
                toVAT(A, 10); toVAT(B, 10)
                approval(3)
                lines.append("Meeting at the Vatican, \(nA) and \(nB) sign a treaty settling their \(war ? "war" : "dispute") after the Holy See's mediation.")
            } else {
                success = false
                let refusers = [(okA, A, nA), (okB, B, nB)].filter { !$0.0 }
                for x in refusers { toVAT(x.1, -2) }
                lines.append("\(refusers.map(\.2).joined(separator: " and ")) decline\(refusers.count == 1 ? "s" : "") the Holy See's offer of mediation.")
            }
        case .hostTalks:
            let odds = HolySeeModel.pairOdds(gs, a, A, B)
            detail["odds"] = PlayHistory.num(odds, places: 100)
            if r() < odds {
                makePeace(A, B)
                both(A, B, 15)
                gs.shadow.holySee.reconciled.append(Reconciliation(a: A, b: B, date: now))
                gs.shadow.holySee.record.ceasefires += 1
                gs.conflictsMediated += 1
                toVAT(A, 6); toVAT(B, 6)
                approval(2)
                lines.append("Talks hosted at the Vatican end in a ceasefire between \(nA) and \(nB).")
            } else {
                success = false
                toVAT(A, -1); toVAT(B, -1)
                lines.append("Delegations from \(nA) and \(nB) meet at the Vatican, but the talks end without a ceasefire.")
            }
        case .backChannel:
            let odds = HolySeeModel.pairOdds(gs, a, A, B)
            detail["odds"] = PlayHistory.num(odds, places: 100)
            if r() < odds {
                both(A, B, 25)
                let released = 1 + Int(r() * 5)
                gs.shadow.holySee.record.thaws += 1
                gs.shadow.holySee.record.returned += released
                toVAT(A, 6); toVAT(B, 6)
                approval(1)
                detail["prisoners_released"] = released
                lines.append("After talks the Holy See quietly brokered, \(nA) and \(nB) announce a thaw and release \(released) prisoner\(released == 1 ? "" : "s").")
            } else {
                success = false
                lines.append("The quiet channel between \(nA) and \(nB) stays open, but neither side is ready to move.")
            }
        case .appealForPeace:
            guard let side = HolySeeModel.escalatingSide(gs) else { return nil }
            let odds = HolySeeModel.appealOdds(gs, side)
            detail["side"] = side.id; detail["odds"] = PlayHistory.num(odds, places: 100)
            if r() < odds {
                gs.defconLevel = DefconLevel(rawValue: min(5, gs.defconLevel.rawValue + 1)) ?? .defcon5
                let enemies = side.atWarWith.sorted()
                for e in enemies { both(side.id, e, 10) }
                if let e = enemies.first {
                    gs.shadow.holySee.holds.append(EnvoyHold(a: side.id, b: e, until: GameCalendar.calendar.date(byAdding: .year, value: 1, to: now) ?? now))
                }
                gs.shadow.holySee.record.crisesDefused += 1
                toVAT(side.id, 5)
                approval(3)
                lines.append("The Holy See broadcasts an appeal for peace. \(side.name) takes the opening to step back; \(gs.defconName) eases to \(gs.defconLevel.rawValue).")
            } else {
                success = false
                lines.append("The Holy See broadcasts an appeal for peace. \(side.name) does not answer it.")
            }
        case .sendEnvoys:
            let odds = HolySeeModel.pairOdds(gs, a, A, B)
            let roll = r()
            detail["odds"] = PlayHistory.num(odds, places: 100)
            if roll < odds / 2 {
                gs.shadow.holySee.holds.append(EnvoyHold(a: A, b: B, until: GameCalendar.calendar.date(byAdding: .year, value: 3, to: now) ?? now))
                both(A, B, 20)
                gs.shadow.holySee.record.warsAverted += 1
                approval(2)
                detail["result"] = "averted"
                lines.append("Envoys of the Holy See reach \(nA) and \(nB). Both governments step back; the war that seemed coming is averted.")
            } else if roll < odds {
                gs.shadow.holySee.holds.append(EnvoyHold(a: A, b: B, until: GameCalendar.calendar.date(byAdding: .year, value: 1, to: now) ?? now))
                gs.shadow.holySee.record.warsDelayed += 1
                approval(1)
                detail["result"] = "delayed"
                lines.append("Envoys of the Holy See reach \(nA) and \(nB). Both agree to hold off for a year while talks continue.")
            } else {
                success = false
                detail["result"] = "no_change"
                lines.append("Envoys of the Holy See are received politely in \(nA) and \(nB); neither government commits to anything.")
            }
        case .encyclical:
            guard let theme = o.option.flatMap(TeachingTheme.init(rawValue:)) else { return nil }
            let until = GameCalendar.calendar.date(byAdding: .year, value: 2, to: now) ?? now
            gs.shadow.holySee.teachings.append(Teaching(theme: theme, issued: now, until: until))
            gs.shadow.holySee.record.teachings += 1
            approval(2)
            detail["theme"] = theme.rawValue
            lines.append("The Holy See issues a teaching document on \(theme.title), in the tradition of \(theme.example).")
            lines.append("For two years, world opinion shifts and nations are readier to act on \(theme.title).")
        case .ratifyTreaty:
            guard let t = o.option.flatMap(ArmsTreaty.byID) else { return nil }
            var joined: [String] = []
            for c in HolySeeModel.treatyCandidates(gs, t) where joined.count < 12 {
                if r() < HolySeeModel.treatyJoinOdds(gs, t, c) { joined.append(c.id) }
            }
            gs.shadow.holySee.ratified.append(t.id)
            if t.nuclear { gs.treaties.append(Treaty(type: .nuclearDisarmament, signatories: [me] + joined, turn: gs.turn)) }
            for x in joined { toVAT(x, 3) }
            gs.shadow.holySee.record.treatiesRatified += 1
            gs.shadow.holySee.record.treatyJoiners += joined.count
            approval(1)
            detail["treaty"] = t.id; detail["joined"] = joined.count
            lines.append("The Holy See ratifies the \(t.name) and presses other nations to join.")
            lines.append(joined.isEmpty ? "No other government joins it yet."
                         : "\(joined.count) nation\(joined.count == 1 ? "" : "s") join\(joined.count == 1 ? "s" : ""): " + joined.prefix(6).map(name).joined(separator: ", ") + (joined.count > 6 ? " and others." : "."))
        case .tracePrisoners:
            let wars = gs.activeWars.count
            let traced = 1500 * min(4, wars) + Int(r() * 3000)
            spendFunds(0.005)
            gs.shadow.holySee.record.traced += traced
            for w in gs.activeWars { toVAT(w.aggressor, 1); toVAT(w.defender, 1) }
            detail["people"] = traced
            lines.append("The Holy See's information office traces \(traced) prisoners of war and missing civilians and tells their families.")
        case .shelterRefugees:
            let sheltered = 500 + Int(r() * 2500)
            spendFunds(0.01)
            let fighting = Set(gs.activeWars.flatMap { [$0.aggressor, $0.defender] })
            let from = gs.liveCountries.filter { fighting.contains($0.id) }.max { $0.refugeeCount != $1.refugeeCount ? $0.refugeeCount < $1.refugeeCount : $0.id > $1.id }
            if let f = from, let i = gs.countries.firstIndex(where: { $0.id == f.id }) {
                gs.countries[i].refugeeCount = max(0, gs.countries[i].refugeeCount - sheltered)
                toVAT(f.id, 4)
            }
            gs.shadow.holySee.record.sheltered += sheltered
            approval(2)
            detail["people"] = sheltered
            lines.append("The Vatican's extraterritorial properties open their doors to \(sheltered) refugees\(from.map { " from \($0.name)" } ?? "").")
        case .prisonerExchange:
            let odds = HolySeeModel.pairOdds(gs, a, A, B)
            detail["odds"] = PlayHistory.num(odds, places: 100)
            if r() < odds {
                let returned = 100 + Int(r() * 900)
                spendFunds(0.005)
                both(A, B, 5)
                toVAT(A, 5); toVAT(B, 5)
                gs.shadow.holySee.record.returned += returned
                approval(2)
                detail["people"] = returned
                lines.append("With the Holy See's help, \(nA) and \(nB) exchange prisoners and return children: \(returned) people go home, and an aid convoy gets through.")
            } else {
                success = false
                lines.append("\(nA) and \(nB) exchange lists of prisoners through the Holy See, but no transfer is agreed yet.")
            }
        case .pastoralVisit:
            guard let c = gs.getCountry(id: A) else { return nil }
            spendFunds(0.005)
            gs.shadow.holySee.record.visits += 1
            if HolySeeModel.isAuthoritarian(c) {
                gs.shadow.holySee.reformPressure[A, default: 0] += 12
                toVAT(A, -3)
                lines.append("A pastoral visit to \(c.name) draws great crowds. Civil society finds its voice, and peaceful pressure for reform grows (\(gs.shadow.holySee.reformPressure[A] ?? 0) of \(HolySeeModel.reformThreshold)).")
            } else {
                if let i = gs.countries.firstIndex(where: { $0.id == A }) { gs.countries[i].stability = min(100, gs.countries[i].stability + 3) }
                toVAT(A, 8)
                lines.append("A pastoral visit to \(c.name) draws great crowds and strengthens civil society.")
            }
            // A visit to both sides of a war argues for peace (1982, 2023).
            for enemy in c.atWarWith.sorted() {
                guard let seen = gs.shadow.holySee.visited[enemy], GameCalendar.days(from: seen, to: now) <= 730 else { continue }
                let odds = HolySeeModel.clamp(0.25 + Double(HolySeeModel.rel(gs, A) + HolySeeModel.rel(gs, enemy)) / 400 + HolySeeModel.bonus(gs, .peace), 0.1, 0.8)
                if r() < odds {
                    makePeace(A, enemy)
                    gs.shadow.holySee.record.ceasefires += 1
                    lines.append("Having visited both sides, the Holy See argues for peace; \(c.name) and \(name(enemy)) agree a ceasefire.")
                    detail["ceasefire_with"] = enemy
                } else {
                    both(A, enemy, 10)
                    lines.append("Having visited both sides, the Holy See argues for peace between \(c.name) and \(name(enemy)); the guns are not yet silent.")
                }
                break
            }
            gs.shadow.holySee.visited[A] = now
            approval(1)
        case .interfaithGathering:
            var ended: [String] = []
            for w in gs.activeWars.sorted(by: { ($0.aggressor, $0.defender) < ($1.aggressor, $1.defender) }) {
                if r() < HolySeeModel.clamp(0.08 + HolySeeModel.bonus(gs, .peace), 0.05, 0.4) {
                    makePeace(w.aggressor, w.defender)
                    ended.append("\(name(w.aggressor)) and \(name(w.defender))")
                } else if let i = gs.activeWars.firstIndex(where: { $0.id == w.id }) {
                    gs.activeWars[i].intensity = max(1, gs.activeWars[i].intensity - 1)
                }
            }
            for c in gs.liveCountries where c.id != me { toVAT(c.id, 2) }
            gs.shadow.holySee.record.gatherings += 1
            gs.shadow.holySee.record.ceasefires += ended.count
            approval(3)
            detail["truces_kept"] = ended.count
            lines.append("Leaders of the world's faiths gather for peace as equals at the Holy See's invitation, and call for a day of truce.")
            lines.append(ended.isEmpty ? (gs.activeWars.isEmpty ? "The day passes in peace." : "The guns fall quieter for a day; the wars go on.")
                         : "The truce holds and becomes a ceasefire between " + ended.joined(separator: "; ") + ".")
        case .debtRelief:
            var agreed: [Country] = []
            for c in HolySeeModel.creditors(gs) where r() < HolySeeModel.debtOdds(gs, c) { agreed.append(c) }
            let relieved = agreed.reduce(0.0) { $0 + min(10, max(1, $1.gdp * 0.5)) }
            if !agreed.isEmpty {
                for d in HolySeeModel.debtors(gs) {
                    if let i = gs.countries.firstIndex(where: { $0.id == d.id }) {
                        gs.countries[i].debtLevel = max(0, gs.countries[i].debtLevel - 5)
                        gs.countries[i].stability = min(100, gs.countries[i].stability + 2)
                    }
                    toVAT(d.id, 4)
                }
                for c in agreed { toVAT(c.id, 1) }
                gs.shadow.holySee.record.debtRelievedB += relieved
                lines.append(String(format: "The Holy See's campaign for debt relief succeeds: %@ forgive $%.1fB owed by the poorest nations.",
                                    agreed.map(\.name).joined(separator: ", "), relieved))
            } else {
                success = false
                lines.append("The Holy See's campaign for debt relief gathers support, but no creditor government commits yet.")
            }
            approval(1)
            detail["creditors_agreed"] = agreed.count; detail["relieved_b"] = PlayHistory.num(relieved)
        case .openRelations:
            guard let c = gs.getCountry(id: A) else { return nil }
            let odds = HolySeeModel.relationsOdds(gs, c)
            detail["odds"] = PlayHistory.num(odds, places: 100)
            let hostile = HolySeeModel.hostileToReligion(c)
            detail["hostile_to_religion"] = hostile
            if r() < odds {
                gs.shadow.holySee.accredited.append(A)
                gs.shadow.holySee.attempts[A] = nil
                toVAT(A, 12)
                gs.shadow.holySee.record.relationsOpened += 1
                lines.append(hostile ? "After patient negotiation, \(c.name) establishes relations with the Holy See and eases its restrictions on religious life."
                                     : "The Holy See and \(c.name) establish diplomatic relations.")
            } else {
                success = false
                gs.shadow.holySee.attempts[A, default: 0] += 1
                lines.append("Talks with \(c.name) on relations make slow progress; patience will count next time.")
            }
        case .addressUN:
            for c in gs.liveCountries where c.id != me { toVAT(c.id, 4) }
            gs.shadow.holySee.unAddress = now
            gs.shadow.holySee.record.addressedUN = true
            approval(3)
            lines.append("The Holy See addresses the United Nations General Assembly and calls for an end to war. For a year, every peace effort stands higher.")
        case .resignOffice:
            gs.shadow.holySee.lastUsed[a.rawValue] = now
            noteHolySee(a, success: true, lines: ["The Holy See's record stands at \(gs.shadow.holySee.record.points) points."], detail: detail)
            self.gameState = gs
            endPresidency(.steppedDown)
            return HolySeeResult(success: true, lines: [DomesticEnding.steppedDown.headline])
        }
        gs.shadow.holySee.lastUsed[a.rawValue] = now
        detail["success"] = success
        noteHolySee(a, success: success, lines: lines, detail: detail)
        self.gameState = gs
        completePlayerAction()
        return HolySeeResult(success: success, lines: lines)
    }

    /// The ticker, the log, the sheet's record and the play history for one action.
    private func noteHolySee(_ a: HolySeeAction, success: Bool, lines: [String], detail: [String: Any]) {
        guard let gs = gameState else { return }
        gs.shadow.presidency.orders += 1   // the record's count of orders given (the epilogue, the awards)
        for (i, l) in lines.enumerated() { gs.shadow.post(l, date: gs.currentDate, severity: i == 0 && success ? 2 : 1) }
        addLog("🕊️ " + lines.joined(separator: " "), type: success ? .info : .warning)
        let next = (gs.shadow.holySee.log.last?.id ?? 0) + 1
        gs.shadow.holySee.log.append(HolySeeEntry(id: next, date: gs.currentDate, action: a, text: lines.joined(separator: " "), success: success))
        if gs.shadow.holySee.log.count > 40 { gs.shadow.holySee.log.removeFirst(gs.shadow.holySee.log.count - 40) }
        var d = detail
        d["result_text"] = PlayHistory.text(lines.joined(separator: " "))
        d["points"] = gs.shadow.holySee.record.points
        logPlayEvent(a.eventKind, detail: d)
    }

    @discardableResult
    func runHolySee(_ o: GameOrder) -> Bool {
        guard let h = HolySeeOrder.from(o) else { return false }
        return runHolySee(h) != nil
    }

    /// True when the Holy See's envoys (or a treaty signed at the Vatican) keep `aggressor` from declaring war on
    /// `defender` now. Counts the first time a hold stops a war. Never true outside a Vatican game.
    func holySeeHoldsWar(_ aggressor: String, _ defender: String) -> Bool {
        guard let gs = gameState, gs.playerCountryID == HolySeeModel.id, aggressor != gs.playerCountryID,
              HolySeeModel.holds(gs, aggressor, defender) else { return false }
        let key = HolySeeState.pairKey(aggressor, defender)
        if let i = gs.shadow.holySee.holds.firstIndex(where: { HolySeeState.pairKey($0.a, $0.b) == key && gs.currentDate < $0.until && !$0.held }) {
            gs.shadow.holySee.holds[i].held = true
            let na = gs.getCountry(id: aggressor)?.name ?? aggressor, nd = gs.getCountry(id: defender)?.name ?? defender
            gs.shadow.post("\(na) holds back from war with \(nd) while the Holy See's envoys keep talking.", date: gs.currentDate, severity: 1)
            logPlayEvent("holy_see_war_held", detail: ["aggressor": aggressor, "defender": defender, "game_date": PlayHistory.day(gs.currentDate)])
        }
        return true
    }

    /// Each turn (Vatican City only; no RNG): envoy holds lapse, teaching documents move world opinion a point a turn,
    /// and peaceful pressure for reform that has built up is answered.
    func processHolySee() {
        guard let gs = gameState, gs.playerCountryID == HolySeeModel.id else { return }
        let now = gs.currentDate
        gs.shadow.holySee.holds.removeAll { $0.until <= now }
        for i in gs.shadow.holySee.teachings.indices where now < gs.shadow.holySee.teachings[i].until
            && gs.shadow.holySee.teachings[i].applied < HolySeeModel.teachingOpinion {
            let theme = gs.shadow.holySee.teachings[i].theme
            for c in teachingAudience(theme, gs) { modifyDiplomaticRelation(from: c, to: HolySeeModel.id, by: 1) }
            gs.shadow.holySee.teachings[i].applied += 1
        }
        for (id, p) in gs.shadow.holySee.reformPressure.sorted(by: { $0.key < $1.key })
        where p >= HolySeeModel.reformThreshold && !gs.shadow.holySee.reformed.contains(id) {
            guard let c = gs.getCountry(id: id), !c.isDestroyed else { continue }
            gs.shadow.holySee.reformed.append(id)
            gs.shadow.holySee.record.reforms += 1
            for d in gs.liveCountries where [.democracy, .republic].contains(d.government) && d.id != id {
                modifyDiplomaticRelation(from: d.id, to: id, by: 5)
            }
            gs.shadow.post("Under peaceful pressure from its own people, \(c.name) eases restrictions and opens talks with its opposition.", date: now, severity: 2)
            logPlayEvent("holy_see_reform", detail: ["country": id, "name": PlayHistory.text(c.name), "game_date": PlayHistory.day(now)])
        }
        self.gameState = gs
    }

    /// Who a teaching document's theme speaks to most (world opinion moves among them).
    private func teachingAudience(_ theme: TeachingTheme, _ gs: GameState) -> [String] {
        let live = gs.liveCountries.filter { $0.id != HolySeeModel.id }
        switch theme {
        case .nuclear: return live.filter { $0.nuclearWarheads == 0 }.map(\.id)
        case .environment: return live.map(\.id)
        case .workers: return HolySeeModel.debtors(gs).map(\.id) + live.filter { $0.government == .democracy }.map(\.id)
        case .peace: return live.filter { !$0.atWarWith.isEmpty }.map(\.id)
        }
    }
}

// MARK: - The command box

enum HolySeeCommands {
    /// Phrases at the start of an order (longest first).
    static let phrases: [(String, HolySeeAction)] = {
        let table: [(HolySeeAction, [String])] = [
            (.mediate, ["offer to mediate between", "offer mediation between", "mediate the dispute between", "mediate a dispute between",
                        "mediate between", "mediate", "offer mediation to"]),
            (.hostTalks, ["host peace talks between", "host peace talks for", "host talks between", "offer the vatican for talks between",
                          "host peace talks", "invite to peace talks", "host talks for"]),
            (.backChannel, ["open a back channel between", "open a secret back channel between", "back channel between", "broker a thaw between",
                            "secret back channel between", "secretly broker a thaw between"]),
            (.appealForPeace, ["appeal for peace", "broadcast an appeal for peace", "make an appeal for peace", "radio appeal for peace",
                               "broadcast a peace appeal", "appeal for calm"]),
            (.sendEnvoys, ["send envoys to", "send envoys between", "send an envoy to", "send envoys to both", "dispatch envoys to"]),
            (.encyclical, ["issue an encyclical on", "write an encyclical on", "issue an encyclical", "publish an encyclical on",
                           "issue a teaching document on", "issue a teaching on", "encyclical on"]),
            (.ratifyTreaty, ["ratify the", "ratify", "sign the treaty on", "join the treaty on"]),
            (.tracePrisoners, ["trace prisoners", "trace the missing", "trace missing prisoners", "open an information office",
                               "open a prisoner of war information office", "trace prisoners of war"]),
            (.shelterRefugees, ["shelter refugees", "take in refugees", "open the doors to refugees", "house refugees"]),
            (.prisonerExchange, ["arrange a prisoner exchange between", "broker a prisoner exchange between", "prisoner exchange between",
                                 "arrange a prisoner swap between", "exchange prisoners between", "arrange prisoner exchanges between"]),
            (.pastoralVisit, ["make a pastoral visit to", "pastoral visit to", "make an apostolic journey to", "apostolic journey to"]),
            (.interfaithGathering, ["convene an interfaith gathering", "hold an interfaith gathering", "interfaith gathering",
                                    "invite faith leaders", "call an interfaith gathering for peace", "call a day of truce"]),
            (.debtRelief, ["campaign for debt relief", "press for debt relief", "debt relief", "forgive the debts of the poor",
                           "cancel the debts of the poorest", "campaign for debt forgiveness"]),
            (.openRelations, ["establish diplomatic relations with", "establish relations with", "open diplomatic relations with",
                              "open relations with"]),
            (.addressUN, ["address the united nations", "address the un", "speak to the united nations", "address the general assembly",
                          "speak at the un"]),
            (.resignOffice, ["resign the papacy", "resign", "step down", "abdicate the papacy"]),
        ]
        return table.flatMap { a, list in list.map { ($0, a) } }.sorted { $0.0.count > $1.0.count }
    }()

    /// A normalized order body → a Holy See intent, or nil.
    static func parse(_ body: String) -> CommandIntent? {
        guard let (phrase, action) = phrases.first(where: { body == $0.0 || body.hasPrefix($0.0 + " ") }),
              let verb = action.verb else { return nil }
        let rest = String(body.dropFirst(phrase.count)).trimmingCharacters(in: .whitespaces)
        switch action {
        case .encyclical:
            let theme = TeachingTheme.allCases.first { t in t.keywords.contains { (" " + rest + " ").contains(" \($0) ") } }
            return CommandIntent(verb: verb, detail: theme?.rawValue ?? "")
        case .ratifyTreaty:
            guard let t = ArmsTreaty.named(rest) else { return nil }   // "ratify the Antarctic Treaty" is not ours
            return CommandIntent(verb: verb, detail: t.id)
        default:
            return CommandIntent(verb: verb, targets: action.targets == 0 ? [] : names(rest))
        }
    }

    /// "chile and argentina", "russia, ukraine" → two names (leading "the" / "both" kept for the resolver).
    static func names(_ rest: String) -> [String] {
        var s = " " + rest + " "
        for w in [" between ", " both ", " for "] where s.hasPrefix(w) { s = " " + String(s.dropFirst(w.count)) }
        let parts = s.replacingOccurrences(of: ",", with: " and ").components(separatedBy: " and ")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return Array(parts.prefix(2))
    }

    /// For the chief of staff's actions tool (Vatican City only): "mediate (two nations)", with the date it can be used
    /// again; `full` adds what each does (the diplomatic category), short otherwise so the reply stays under its cap.
    static func toolRows(_ gs: GameState, full: Bool) -> [String] {
        HolySeeAction.allCases.map { a in
            var row = a.rawValue
            switch a.targets {
            case 2: row += " (two nations)"
            case 1: row += " (one nation)"
            default:
                if a == .encyclical { row += " (theme: nuclear, environment, workers or peace)" }
                if a == .ratifyTreaty { row += " (treaty: " + HolySeeModel.openTreaties(gs).map(\.id).joined(separator: ", ") + ")" }
            }
            if let p = HolySeeModel.readyOn(gs, a) { row += ": again from \(GameCalendar.format(p))" }
            return full ? row + ". " + a.summary : row
        }
    }
}

extension GameEngine {
    /// The command box's card for a Holy See order (HolySee.swift). Refuses outside a Vatican game.
    func planHolySee(_ a: HolySeeAction, intent: CommandIntent, source: CommandSource) -> CommandOutcome {
        guard let gs = gameState else { return .rejected("Start a game first.") }
        guard HolySeeModel.isOffered(gs) else {
            return .rejected("Only the Holy See can do that. You lead \(gs.getPlayerCountry()?.name ?? gs.playerCountryID).")
        }
        var ids: [String] = []
        if let c = intent.confirmedTargets { ids = c }
        else {
            for raw in intent.targets.prefix(2) {
                switch CommandTargets.resolve(raw, in: gs) {
                case .one(let t, _): ids.append(t.id)
                case .many(let opts):
                    return .rejected("Which one: " + opts.map { CommandTargets.label($0, in: gs) }.joined(separator: ", ") + "?")
                case .none: return .rejected("No nation called \"\(String(CommandParser.sanitize(raw).prefix(40)))\" in \(gs.currentYear).")
                }
            }
        }
        // "host peace talks for Ukraine": the one enemy it is at war with is the other side.
        if a.targets == 2, ids.count == 1, let c = gs.getCountry(id: ids[0]), c.atWarWith.count == 1, let other = c.atWarWith.first { ids.append(other) }
        if a.targets > 0, ids.count < a.targets { return .rejected(a.targets == 2 ? "Name the two nations." : "Name the nation.") }
        var o = HolySeeOrder(action: a)
        if a.targets >= 1 { o.first = ids[0] }
        if a.targets == 2 { o.second = ids[1] }
        if a == .encyclical || a == .ratifyTreaty { o.option = intent.detail }
        if let p = holySeeProblem(o) { return .rejected(p) }
        let shown = [o.first, o.second].compactMap { $0 }.compactMap { gs.getCountry(id: $0)?.name }.joined(separator: " and ")
        var plan = CommandPlan(title: a.title, target: (shown.isEmpty ? "The Holy See" : shown) + ", \(gs.currentYear)", orders: [o.gameOrder],
                               committed: [a.summary], heldBack: [], warnings: [], actionsNeeded: a == .resignOffice ? 0 : 1,
                               actionsLeft: gs.actionsRemaining, source: source)
        if let x = o.first, let y = o.second {
            plan.committed.append("Odds: about \(Int((HolySeeModel.pairOdds(gs, a, x, y) * 100).rounded()))%, from both nations' relations with the Holy See.")
        }
        if a == .appealForPeace, let side = HolySeeModel.escalatingSide(gs) {
            plan.committed.append("Aimed at \(side.name). Odds: about \(Int((HolySeeModel.appealOdds(gs, side) * 100).rounded()))%.")
        }
        if a == .encyclical, let t = o.option.flatMap(TeachingTheme.init(rawValue:)) { plan.committed.append("Theme: \(t.title), in the tradition of \(t.example).") }
        if a == .ratifyTreaty, let t = o.option.flatMap(ArmsTreaty.byID) { plan.committed.append("Treaty: the \(t.name) (the Holy See ratified it in \(t.holySeeYear)).") }
        plan.warnings.append(CommandWarning(text: a.precedent, level: 0))
        if a == .resignOffice { plan.warnings.append(CommandWarning(text: "This ends the game. It is scored on the record built so far.", level: 2)) }
        return .plan(plan)
    }
}

extension VictoryType {
    /// The ending's line for this game: a pope who resigns has not served a constitutional term.
    func description(for gs: GameState) -> String {
        if self == .servedFullTerm, gs.shadow.domesticEnding == .steppedDown {
            return "Resigned of your own free will, with the Holy See's record of peace intact"
        }
        return description
    }

    /// The ending's name for this game ("A Dignified Farewell" for a pope who resigns; the regime's words otherwise).
    func title(for gs: GameState) -> String {
        if self == .servedFullTerm, gs.shadow.domesticEnding == .steppedDown { return "A Dignified Farewell" }
        return gs.say(rawValue)
    }
}

extension ChatTools {
    /// 3.37.0: a Holy See step: `targets` (none, one or two nations), and `theme` or `treaty` where the action takes one.
    static func holySeeIntent(_ verb: CommandVerb, _ a: HolySeeAction, _ o: [String: Any]) throws -> CommandIntent {
        var targets: [String] = []
        if let t = o["targets"] as? [Any] { targets = t.compactMap { $0 as? String } }
        else if let t = o["targets"] as? String { targets = HolySeeCommands.names(CommandParser.normalize(t)) }
        else if let t = o["target"] as? String { targets = [t] }
        targets = targets.prefix(2).map { String(CommandParser.sanitize($0).prefix(maxArgString)) }.filter { !$0.isEmpty }
        if a.targets > 0, targets.isEmpty { throw ChatToolError(message: "name the nation\(a.targets == 2 ? "s (two)" : "").") }
        var detail: String?
        if a == .encyclical {
            let raw = CommandParser.normalize(((o["theme"] ?? o["option"]) as? String) ?? "")
            guard let t = TeachingTheme(rawValue: raw) ?? TeachingTheme.allCases.first(where: { $0.keywords.contains { (" " + raw + " ").contains(" \($0) ") } }) else {
                throw ChatToolError(message: "theme must be nuclear, environment, workers or peace.")
            }
            detail = t.rawValue
        }
        if a == .ratifyTreaty {
            let raw = CommandParser.normalize(((o["treaty"] ?? o["option"]) as? String) ?? "")
            guard let t = ArmsTreaty.byID(raw) ?? ArmsTreaty.named(raw) else {
                throw ChatToolError(message: "treaty must be one of " + ArmsTreaty.all.map(\.id).joined(separator: ", ") + ".")
            }
            detail = t.id
        }
        return CommandIntent(verb: verb, targets: a.targets == 0 ? [] : targets, detail: detail)
    }
}
