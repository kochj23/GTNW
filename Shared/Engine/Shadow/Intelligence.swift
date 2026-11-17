//
//  Intelligence.swift
//  Global Thermal Nuclear War
//
//  3.32.1: nobody sees everything, and nothing anyone sees is new. Every figure a government reads about another
//  nation comes as a REPORT with an age, a source, and the limits of that source: a border informant counts
//  regiments and has never seen the fleet; the press prints a mood and no order of battle; an attaché is told what
//  the host wants him to know. Governments — the President and every computer-run power alike — decide on the last
//  report they have, which may be months old and may describe a garrison that has since moved. The deliberation
//  record (WarCouncil.swift) therefore holds what was believed next to what was true, so a war opened on stale
//  information is visible afterwards and counts in the debrief.
//  For the President there is also a FOG PANEL that says the absence out loud — "no reports from the Pacific in
//  four turns" — in the manner of the unclaimed-land list, rather than showing a calm, blank map.
//  And before the telegraph (1844) and radio, orders to distant squadrons and colonies could go out and come back
//  with no word at all: a third outcome beside success and failure. Those orders do not cost the President his
//  action (the 3.28.2 rule) and resolve when the dispatch finally arrives.
//  Collection rates, reach and staleness thresholds are design choices.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// What a report can be about.
enum IntelField: String, Codable, CaseIterable, Identifiable {
    case army, fleet, nuclear, economy, mood
    var id: String { rawValue }
    var label: String {
        switch self {
        case .army: return "field army"
        case .fleet: return "fleet"
        case .nuclear: return "nuclear arsenal"
        case .economy: return "economy"
        case .mood: return "temper of the country"
        }
    }
}

/// Where a figure came from, and what that source can and cannot see.
enum IntelSource: String, Codable, CaseIterable, Identifiable {
    case borderInformant, militaryAttache, pressReports, signals, reconnaissance, satellite, spyNetwork
    var id: String { rawValue }

    var title: String {
        switch self {
        case .borderInformant: return "a border informant"
        case .militaryAttache: return "our military attaché"
        case .pressReports: return "the foreign press"
        case .signals: return "signals intercepts"
        case .reconnaissance: return "reconnaissance flights"
        case .satellite: return "satellite photography"
        case .spyNetwork: return "our own network"
        }
    }

    /// The first year a government could have it.
    var from: Int {
        switch self {
        case .signals: return 1914
        case .reconnaissance: return 1915
        case .satellite: return 1960
        default: return 0
        }
    }

    /// What this source is able to report.
    var sees: Set<IntelField> {
        switch self {
        case .borderInformant: return [.army, .mood]
        case .militaryAttache: return [.army, .nuclear]
        case .pressReports: return [.mood, .economy]
        case .signals: return [.army, .fleet, .nuclear]
        case .reconnaissance: return [.army, .fleet]
        case .satellite: return [.army, .fleet, .nuclear, .economy]
        case .spyNetwork: return Set(IntelField.allCases)
        }
    }

    /// What it cannot see, said plainly.
    var blindSpot: String {
        switch self {
        case .borderInformant: return "he counts regiments at the frontier; he has never seen the fleet"
        case .militaryAttache: return "he is shown what his hosts want him to see"
        case .pressReports: return "a newspaper prints a mood, not an order of battle"
        case .signals: return "traffic says who is talking, not how many are in the field"
        case .reconnaissance: return "a photograph is one morning, not a month"
        case .satellite: return "it counts what is outdoors"
        case .spyNetwork: return "an agent can be turned"
        }
    }

    /// Roughly how far off a source's figure is, as a share (design choices).
    var error: Double {
        switch self {
        case .satellite: return 0.03
        case .spyNetwork: return 0.05
        case .reconnaissance: return 0.08
        case .signals: return 0.1
        case .militaryAttache: return 0.15
        case .borderInformant: return 0.2
        case .pressReports: return 0.3
        }
    }
}

/// One figure, as of the turn it was reported.
struct IntelReport: Codable, Identifiable, Hashable {
    var id = UUID()
    /// Who it is about.
    var subject: String
    var field: IntelField
    /// What the source said at the time.
    var value: Double
    var asOfTurn: Int
    var asOfDate: Date
    var source: IntelSource

    func line(name: String, now: Int) -> String {
        let age = max(0, now - asOfTurn)
        return "\(name)'s \(field.label): \(Int(value.rounded())) — \(source.title), \(age == 0 ? "this turn" : "\(age) turn\(age == 1 ? "" : "s") old"). \(source.blindSpot.prefix(1).capitalized + source.blindSpot.dropFirst())."
    }
}

enum Intelligence {
    /// Reports kept per nation (the latest of each field, and the last few besides).
    static let keepPerSubject = 8
    /// Turns without a report before the fog panel says so.
    static let silenceTurns = 3
    /// A war opened on a report this old is an attack on stale intelligence.
    static let staleTurns = 3
    /// Nations sampled for new reports each turn (keeps a 190-nation board cheap).
    static let sampleSize = 14

    /// What a nation can read about another this year: era sources, plus its own network where it has one.
    /// `neighbours` is whether the two share a land border (a border informant needs a border).
    static func sources(_ observer: Country, about subject: Country, year: Int, neighbours: Bool) -> [IntelSource] {
        var out: [IntelSource] = [.pressReports]
        if neighbours { out.append(.borderInformant) }
        if (observer.diplomaticRelations[subject.id] ?? 0) > -40 { out.append(.militaryAttache) }
        if (observer.spyNetworks[subject.id] ?? 0) >= 30 { out.append(.spyNetwork) }
        for s in [IntelSource.signals, .reconnaissance, .satellite] where year >= s.from && observer.militaryStrength >= 40 {
            out.append(s)
        }
        return out
    }

    /// The truth a field would report right now.
    static func truth(_ field: IntelField, of c: Country) -> Double {
        switch field {
        case .army: return Double(c.militaryStrength)
        case .fleet: return Double(c.navalForces)
        case .nuclear: return Double(c.nuclearWarheads)
        case .economy: return c.gdp * 1000
        case .mood: return c.profile.outcry
        }
    }

    /// A source's figure: the truth, off by about its error, in a direction set by `roll`.
    static func observe(_ field: IntelField, of c: Country, by source: IntelSource, roll: Double) -> Double {
        let drift = (min(max(roll, 0), 1) - 0.5) * 2 * source.error
        return max(0, truth(field, of: c) * (1 + drift))
    }

    /// The latest report a nation holds about a field.
    static func latest(_ field: IntelField, about subject: String, in reports: [IntelReport]) -> IntelReport? {
        reports.filter { $0.subject == subject && $0.field == field }.max { $0.asOfTurn < $1.asOfTurn }
    }

    /// Turns since the last report of any kind about a nation; nil when there has never been one.
    static func age(about subject: String, in reports: [IntelReport], now: Int) -> Int? {
        reports.filter { $0.subject == subject }.map { max(0, now - $0.asOfTurn) }.min()
    }

    /// What a government believes another's field army to be: the figure in circulation, off by its own source's
    /// error, with the age of that figure. Without one, it has the truth in front of it.
    static func believedArmy(of subject: Country, for observer: Country, in gs: GameState) -> (value: Double, age: Int, source: IntelSource) {
        let neighbours = Reach.landNeighbors(observer.id, in: gs).contains(subject.id)
        let best = sources(observer, about: subject, year: gs.currentYear, neighbours: neighbours)
            .min { $0.error < $1.error } ?? .pressReports
        guard let r = gs.shadow.worldIntel[subject.id] else { return (truth(.army, of: subject), 0, best) }
        let drift = (CountryProfile.stableUnit(observer.id + subject.id) - 0.5) * 2 * best.error
        return (max(0, r.value * (1 + drift)), max(0, gs.turn - r.asOfTurn), best)
    }

    /// Regions the President has heard nothing from, said out loud.
    static func silence(_ gs: GameState) -> [String] {
        var worst: [WorldRegion: Int] = [:]
        var counted: Set<WorldRegion> = []
        for c in gs.liveCountries where c.id != gs.playerCountryID {
            guard let r = WorldCountriesDatabase.template(id: c.id)?.region ?? ClaimCampaigns.region(of: c.id) else { continue }
            counted.insert(r)
            let a = age(about: c.id, in: gs.shadow.intel, now: gs.turn) ?? Int.max
            worst[r] = min(worst[r] ?? Int.max, a)
        }
        return counted.sorted { $0.rawValue < $1.rawValue }.compactMap { r in
            guard let a = worst[r], a >= silenceTurns else { return nil }
            return a == Int.max
                ? "No reports from \(r.rawValue) at all."
                : "No reports from \(r.rawValue) in \(a) turns."
        }
    }
}

/// An order sent before the telegraph that has not been heard from.
struct PendingDispatch: Codable, Identifiable, Hashable {
    var id = UUID()
    /// What was ordered: "claim_land", "colony", "independence".
    var kind: String
    var land: String
    var troops: Double
    var sent: Date
    var due: Date
    var label: String
}

enum Dispatch {
    /// The telegraph reaches across oceans from 1866; wireless from 1901. Before that, orders went by ship.
    static let telegraph = 1866
    /// Degrees of separation past which an order is "distant".
    static let farDegrees = 45.0
    /// Under tests orders arrive at once unless a test asks otherwise.
    nonisolated(unsafe) static var enabled = !GameStoreService.isTestOrSmokeRun

    /// Chance an order to a distant place goes out with no word coming back (design choice, by era and distance).
    static func darkChance(year: Int, degrees: Double) -> Double {
        guard year < telegraph, degrees >= farDegrees else { return 0 }
        let far = min(1, (degrees - farDegrees) / 90)
        let era = year < 1800 ? 1.0 : (year < 1840 ? 0.8 : 0.5)
        return min(0.6, (0.2 + 0.4 * far) * era)
    }

    /// How long the answer takes: a month for every 20 degrees, at least two months.
    static func months(degrees: Double) -> Int { max(2, Int((degrees / 20).rounded())) }
}

extension GameEngine {
    // MARK: Collection

    /// Each turn: a sample of nations is reported on, by whatever sources the era and the President's services have.
    /// Reports are snapshots — they do not change when the world does.
    func collectIntelligence() {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return }
        let others = gs.liveCountries.filter { $0.id != me.id }
        guard !others.isEmpty else { return }
        let start = (gs.turn * Intelligence.sampleSize) % max(1, others.count)
        for k in 0..<min(Intelligence.sampleSize, others.count) {
            let c = others[(start + k) % others.count]
            let kit = Intelligence.sources(me, about: c, year: gs.currentYear,
                                           neighbours: Reach.landNeighbors(me.id, in: gs).contains(c.id))
            guard let source = kit.max(by: { $0.error > $1.error }) else { continue }
            for field in source.sees.sorted(by: { $0.rawValue < $1.rawValue }) {
                let roll = Double.random(in: 0..<1, using: &gs.rng)
                let r = IntelReport(subject: c.id, field: field,
                                    value: Intelligence.observe(field, of: c, by: source, roll: roll),
                                    asOfTurn: gs.turn, asOfDate: gs.currentDate, source: source)
                gs.shadow.intel.removeAll { $0.subject == c.id && $0.field == field }
                gs.shadow.intel.append(r)
            }
            // The figure in circulation: what every government's attachés are working from, however old it is.
            gs.shadow.worldIntel[c.id] = IntelReport(subject: c.id, field: .army, value: Intelligence.truth(.army, of: c),
                                                     asOfTurn: gs.turn, asOfDate: gs.currentDate, source: .militaryAttache)
            let mine = gs.shadow.intel.filter { $0.subject == c.id }
            if mine.count > Intelligence.keepPerSubject {
                let drop = Set(mine.sorted { $0.asOfTurn < $1.asOfTurn }.prefix(mine.count - Intelligence.keepPerSubject).map(\.id))
                gs.shadow.intel.removeAll { drop.contains($0.id) }
            }
        }
        self.gameState = gs
    }

    /// The figure the President's government is working from, with the report behind it (nil when nothing is known).
    func believedValue(_ field: IntelField, about subject: String) -> (value: Double, report: IntelReport?)? {
        guard let gs = gameState else { return nil }
        if subject == gs.playerCountryID, let c = gs.getCountry(id: subject) { return (Intelligence.truth(field, of: c), nil) }
        if let r = Intelligence.latest(field, about: subject, in: gs.shadow.intel) { return (r.value, r) }
        guard let c = gs.getCountry(id: subject) else { return nil }
        return (Intelligence.truth(field, of: c), nil)
    }

    /// What the dossier says about the age and reach of what we know.
    func intelLine(about subject: String) -> String? {
        guard let gs = gameState, subject != gs.playerCountryID,
              let r = Intelligence.latest(.army, about: subject, in: gs.shadow.intel),
              let name = gs.getCountry(id: subject)?.name else { return nil }
        return r.line(name: name, now: gs.turn)
    }

    // MARK: Dispatches that may not come back

    /// Whether an order to `land` goes out with no word coming back. True means the order was sent, the action was
    /// not spent, and the outcome arrives with the dispatch.
    func dispatchGoesDark(land: String, kind: String, troops: Double = 1, roll: Double? = nil) -> Bool {
        guard let gs = gameState, Dispatch.enabled || roll != nil, let me = gs.getPlayerCountry() else { return false }
        guard let t = WorldCountriesDatabase.template(id: land) ?? PreStateModel.template(land) else { return false }
        let there = t.toCountry().coordinates
        let degrees = hypot(me.coordinates.lat - there.lat, me.coordinates.lon - there.lon)
        let p = Dispatch.darkChance(year: gs.currentYear, degrees: degrees)
        guard p > 0, (roll ?? Double.random(in: 0..<1, using: &gs.rng)) < p else { return false }
        let months = Dispatch.months(degrees: degrees)
        let due = GameCalendar.calendar.date(byAdding: .month, value: months, to: gs.currentDate) ?? gs.currentDate
        let label = t.toCountry().name
        gs.shadow.dispatches.append(PendingDispatch(kind: kind, land: land, troops: troops, sent: gs.currentDate, due: due, label: label))
        gs.shadow.post("Orders have gone out for \(label). Nothing will come back for \(months) months; until then Washington will not know whether they were carried out.",
                       date: gs.currentDate, severity: 2)
        logPlayEvent("dispatch_sent", detail: ["land": land, "kind": kind, "months": months,
                                              "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return true
    }

    /// Each turn: dispatches whose answer has arrived are carried out and reported.
    func processDispatches() {
        guard let gs = gameState else { return }
        let due = gs.shadow.dispatches.filter { $0.due <= gs.currentDate }
        guard !due.isEmpty else { return }
        gs.shadow.dispatches.removeAll { $0.due <= gs.currentDate }
        self.gameState = gs
        for d in due {
            gs.shadow.post("Word has come back from \(d.label).", date: gs.currentDate, severity: 1)
            // ponytail: only expeditions travel by dispatch; a purchase or a backed revolt needs a negotiator on
            // the spot, and those verbs cost an action the President may no longer have when the answer arrives.
            if d.kind == "claim_land" { claimLand(d.land, troops: d.troops, spendAction: false) }
            logPlayEvent("dispatch_arrived", detail: ["land": d.land, "kind": d.kind, "game_date": PlayHistory.day(gs.currentDate)])
        }
    }
}
