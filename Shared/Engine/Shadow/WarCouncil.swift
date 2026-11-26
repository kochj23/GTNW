//
//  WarCouncil.swift
//  Global Thermal Nuclear War
//
//  3.32.0: nobody goes to war without saying why, what they expect, and when they would call it finished.
//  Three parts, all built from the same numbers the rules already use (force pools, home ground, relations, spy
//  networks, the historical base rates of Documentation/wars):
//    • A DELIBERATION every computer-run nation forms before it attacks: its estimate of its own capability, of the
//      target's will to fight, and of how good its own information is; a pre-mortem (what must be true, what would
//      break it, what off-ramp survives the first bad turn); and the same arithmetic applied to the cheaper
//      instruments that exist in this era — buying the land, a claim campaign, backing a colony's independence,
//      buying a colony, pressure short of war. Nations are often wrong, but wrong for reasons they state: stale
//      intelligence, mirror-imaging, domestic pressure, an ally's promise that was warmer in private than on paper.
//      The record is kept verbatim so the post-game column can quote it.
//    • A CASUS BELLI: an era-appropriate stated justification, checked against the facts. A thin or fabricated one
//      costs standing abroad and at home; a strong one buys allies.
//    • A DONE-TEST declared before the first move — territory held, a treaty signed, or a cost ceiling — checked
//      every turn. When it is met (or failed) the war goes to settlement instead of grinding on forever.
//  Game-balance weights here are design choices; the historical numbers come from HistoricalWars.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - Casus belli

/// A stated reason for war. Each belongs to the years in which a government could say it out loud and be heard.
enum CasusBelli: String, Codable, CaseIterable, Identifiable {
    case borderIncident, defenceOfAlly, treatyObligation, reclaimTerritory, protectNationals
    case dynasticClaim, civilisingMission, preemption, humanitarian, fabricated
    var id: String { rawValue }

    var title: String {
        switch self {
        case .borderIncident: return "A border incident"
        case .defenceOfAlly: return "The defence of an ally"
        case .treatyObligation: return "A treaty obligation"
        case .reclaimTerritory: return "A territorial claim"
        case .protectNationals: return "The protection of our nationals"
        case .dynasticClaim: return "A dynastic claim"
        case .civilisingMission: return "A civilising mission"
        case .preemption: return "Pre-emption of an imminent threat"
        case .humanitarian: return "A humanitarian intervention"
        case .fabricated: return "An incident of our own making"
        }
    }

    /// The years the reason belongs to (design choices, from how states have justified war).
    var from: Int {
        switch self {
        case .dynasticClaim: return 0
        case .civilisingMission: return 1830
        case .preemption: return 1914
        case .humanitarian: return 1991
        default: return 0
        }
    }

    var to: Int {
        switch self {
        case .dynasticClaim: return 1918
        case .civilisingMission: return 1945
        default: return 9999
        }
    }

    func available(year: Int) -> Bool { year >= from && year <= to }

    /// How much weight the world gives the reason when it is true, 0…1 (design choices).
    var weight: Double {
        switch self {
        case .defenceOfAlly, .treatyObligation: return 0.95
        case .humanitarian: return 0.8
        case .protectNationals: return 0.7
        case .borderIncident: return 0.6
        case .reclaimTerritory: return 0.5
        case .preemption: return 0.45
        case .dynasticClaim: return 0.4
        case .civilisingMission: return 0.35
        case .fabricated: return 0.1
        }
    }
}

/// A war's stated justification, whether the facts bear it out, and how the world took it.
struct CasusRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var actor: String
    var target: String
    var casus: CasusBelli
    var date: Date
    /// Whether the facts on the board support the reason.
    var supported: Bool
    /// 0…1: the weight the world gave it.
    var strength: Double
    var statement: String
}

// MARK: - Deliberation

/// What a government believed about a war before it started. Values are 0…1.
struct WarEstimate: Codable, Hashable {
    /// Our share of the balance of force, home ground included.
    var capability: Double
    /// Their will to fight.
    var resolve: Double
    /// How good our own information is.
    var confidence: Double
}

/// Why a government's estimate was wrong, in its own words.
enum WarBias: String, Codable, CaseIterable, Identifiable {
    case staleIntelligence, mirrorImaging, domesticPressure, softAllyPromise
    var id: String { rawValue }

    var note: String {
        switch self {
        case .staleIntelligence: return "our picture of their forces is months old"
        case .mirrorImaging: return "we are assuming they weigh this the way we do"
        case .domesticPressure: return "the ministry and the street want a war; caution reads as weakness"
        case .softAllyPromise: return "an ally's promise of support was warmer in private than it is on paper"
        }
    }
}

/// One instrument weighed against the others in the same numbers.
struct WarInstrument: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    /// Billions of dollars.
    var cost: Double
    /// 0…1 chance it works.
    var odds: Double
    /// What it would be worth, in billions.
    var prize: Double
    var note: String
    /// Expected value per billion spent.
    var score: Double { odds * prize / max(1, cost) }
}

/// The test a war declares before its first move.
struct WarDoneTest: Codable, Hashable {
    enum Kind: String, Codable { case territoryHeld, treatySigned, costCeiling }
    var kind: Kind
    /// Months after which a cost-ceiling war is abandoned (and a treaty war goes to the table).
    var months: Double
    /// Casualties (thousands) the attacker will spend before abandoning it.
    var casualties: Double
    var note: String
}

/// A government's pre-war record, kept verbatim.
struct WarDeliberation: Codable, Identifiable, Hashable {
    var id = UUID()
    var actor: String
    var target: String
    var date: Date
    var turn: Int
    /// What it believed.
    var estimate: WarEstimate
    /// What was true (never shown to the nation itself; the post-game debrief compares them).
    var truth: WarEstimate
    var mustBeTrue: String
    var wouldBreakIt: String
    var offRamp: String
    var biases: [WarBias]
    var casus: CasusBelli
    var instruments: [WarInstrument]
    var doneTest: WarDoneTest
    /// 3.32.2: what the record gives the side that starts a war like this (nil when the record is silent), and
    /// the nation's own record where it has one.
    var recordOdds: Double?
    var ownRecord: String?
    /// The instrument chosen ("war" or an instrument id).
    var chose: String
    /// The whole deliberation in the government's own words.
    var statement: String
}

enum WarCouncil {
    /// Deliberations and casus records kept on the game record.
    static let keep = 40

    // MARK: The numbers

    /// Their will to fight: stability and leadership hold it up, unrest eats it, allies stiffen it.
    static func resolve(_ d: Country) -> Double {
        let base = 0.3 + Double(max(0, min(100, d.stability))) / 250 + d.profile.leadership / 400
            + Double(min(4, d.alliances.count)) * 0.03 - d.profile.outcry / 400
        return min(1, max(0.05, base))
    }

    /// How good a nation's information about another is: its own spies, the era's eyes, its leadership.
    static func confidence(_ a: Country, about d: Country, year: Int) -> Double {
        let spies = Double(a.spyNetworks[d.id] ?? 0) / 200
        let era = year >= 1960 ? 0.25 : (year >= 1920 ? 0.12 : 0)   // reconnaissance aircraft, then satellites
        return min(0.98, max(0.1, 0.25 + spies + era + a.profile.leadership / 500))
    }

    /// Our share of the balance of force: the attacker's expeditionary pool against the defender's at home.
    /// 3.32.1: `believedArmy` is the figure the attacker is working from (Intelligence); without it, the truth.
    static func capability(_ a: Country, _ d: Country, believedArmy: Double? = nil) -> Double {
        var seen = d
        if let army = believedArmy { seen.militaryStrength = max(1, Int(army.rounded())) }
        let pa = CombatModel.forcePool(a) * 0.35
        let pd = CombatModel.forcePool(seen) * 0.55 * AttritionModel.homeGround(seen)
        return min(0.99, max(0.01, pa / max(0.001, pa + pd)))
    }

    /// The biases a government is carrying into this decision.
    static func biases(_ a: Country, _ d: Country, confidence: Double) -> [WarBias] {
        var out: [WarBias] = []
        if confidence < 0.55 { out.append(.staleIntelligence) }
        if abs(a.profile.ethic - d.profile.ethic) >= 2 || a.government != d.government { out.append(.mirrorImaging) }
        if a.profile.outcry >= 55 || a.profile.ambition >= 5 { out.append(.domesticPressure) }
        if a.alliances.contains(where: { (a.diplomaticRelations[$0] ?? 0) < 65 }) { out.append(.softAllyPromise) }
        return out
    }

    /// What the government believes, given what is true and what it is carrying. `roll` (0…1) sets which way stale
    /// information is wrong.
    static func believed(truth: WarEstimate, biases: [WarBias], roll: Double) -> WarEstimate {
        var e = truth
        let drift = (min(max(roll, 0), 1) - 0.5) * 2 * (1 - truth.confidence) * 0.25
        e.capability = min(0.99, max(0.01, truth.capability + (biases.contains(.staleIntelligence) ? drift : 0)
                                     + (biases.contains(.domesticPressure) ? 0.08 : 0)))
        e.resolve = min(1, max(0.02, truth.resolve * (biases.contains(.mirrorImaging) ? 0.6 : 1)
                               * (biases.contains(.softAllyPromise) ? 1 : 1) - (biases.contains(.domesticPressure) ? 0.05 : 0)))
        return e
    }

    /// The chance a war works, on the numbers the government believes.
    static func warOdds(_ e: WarEstimate) -> Double { min(0.97, max(0.03, e.capability - 0.35 * e.resolve + 0.2)) }

    /// The reason a government would state, strongest first, and whether the facts bear it out.
    static func casus(_ a: Country, _ d: Country, in gs: GameState) -> (CasusBelli, Bool) {
        let y = gs.currentYear
        let fb = WorldFactbookDatabase.records[d.id] != nil ? WorldFactbookDatabase.record(for: d.id) : nil
        let disputed = fb?.territorialDisputes.contains(a.id) ?? false
        let candidates: [(CasusBelli, Bool)] = [
            (.defenceOfAlly, a.alliances.contains { ally in d.atWarWith.contains(ally) }),
            (.treatyObligation, gs.treaties.contains { $0.signatories.contains(a.id) && d.atWarWith.contains(where: $0.signatories.contains) }),
            (.humanitarian, d.profile.outcry >= 70 || d.stability <= 20),
            (.protectNationals, d.stability <= 35),
            (.borderIncident, Reach.landNeighbors(a.id, in: gs).contains(d.id)),
            (.reclaimTerritory, disputed || gs.countries.contains { $0.territoryOf == d.id && ($0.diplomaticRelations[a.id] ?? 0) > 20 }),
            (.preemption, d.nuclearWarheads > 0 || d.militaryStrength >= a.militaryStrength),
            (.dynasticClaim, d.government == .monarchy && a.government == .monarchy),
            (.civilisingMission, d.profile.qualityOfLife < 35),
        ]
        for (c, ok) in candidates where c.available(year: y) && ok { return (c, true) }
        // Nothing on the board supports a reason: state one anyway, or invent the incident.
        if let thin = candidates.map(\.0).first(where: { $0.available(year: y) }) { return (thin, false) }
        return (.fabricated, false)
    }

    /// How much the world accepts a stated reason: its weight, cut to a third when the facts do not bear it out.
    static func strength(_ c: CasusBelli, supported: Bool) -> Double { supported ? c.weight : c.weight / 3 }

    /// The cheaper instruments that exist in this era, in the same numbers as the war.
    static func instruments(_ a: Country, _ d: Country, in gs: GameState, estimate e: WarEstimate) -> [WarInstrument] {
        let y = gs.currentYear
        let rel = d.diplomaticRelations[a.id] ?? 0
        let atWar = d.atWarWith.contains(a.id)
        /// What the target is worth, in billions: its output, weighted by how much the leader wants standing.
        let prize = max(1, d.gdp * 1000) * (1 + 0.3 * Double(max(0, a.profile.ambition - 3)))
        let months = HistoricalWars.interstate(year: y, strongerShare: max(e.capability, 1 - e.capability))?.q3_months ?? 18
        let burn = max(0.2, a.gdp * 1000 * 0.03)   // a month of war against a month of national output
        var out = [WarInstrument(id: "war", name: "War", cost: burn * months, odds: warOdds(e), prize: prize,
                                 note: String(format: "%.0f months of fighting at $%.0fB a month, on our own estimate.", months, burn))]
        let colonies = gs.countries.filter { $0.territoryOf == d.id }
        if d.isTerritory || !colonies.isEmpty || d.gdp * 1000 < max(50, a.gdp * 1000 * 0.1) {
            out.append(WarInstrument(id: "buy_land", name: "Buy the land on the open market",
                                     cost: max(1, d.gdp * 250), odds: PreStateModel.saleOdds(relation: rel, atWar: atWar, historical: false),
                                     prize: prize * 0.3, note: "A price, a signature, and no dead."))
        }
        if !colonies.isEmpty {
            let land = colonies[0]
            out.append(WarInstrument(id: "buy_colony", name: "Buy a colony from them",
                                     cost: PreStateModel.price(land.id, year: y, relation: rel),
                                     odds: PreStateModel.saleOdds(relation: rel, atWar: atWar, historical: false),
                                     prize: prize * 0.25, note: "Their holding, not their heartland."))
            out.append(WarInstrument(id: "independence", name: "Back a colony's independence", cost: 2,
                                     odds: PreStateModel.revoltOdds(year: y, independence: y, ownerAtWarWithPlayer: atWar, ownerStability: d.stability),
                                     prize: prize * 0.15, note: "Cheap, slow, and it makes a friend of what was theirs."))
        }
        if !gs.unclaimedLandIDs.isEmpty {
            out.append(WarInstrument(id: "claim_campaign", name: "A claim campaign on unclaimed land",
                                     cost: max(0.2, ClaimCampaigns.landingCost(year: y) * 10), odds: 0.85, prize: prize * 0.1,
                                     note: "A different prize: land nobody holds, not \(d.name)."))
        }
        out.append(WarInstrument(id: "pressure", name: "Pressure short of war", cost: 0.5,
                                 odds: min(0.6, 0.25 + Double(max(0, -rel)) / 300), prize: prize * 0.05,
                                 note: "Condemnation, money and agents. It does not take the ground."))
        return out
    }

    /// The test this war declares before its first move.
    static func doneTest(_ a: Country, _ d: Country, in gs: GameState, estimate e: WarEstimate) -> WarDoneTest {
        let months = HistoricalWars.interstate(year: gs.currentYear, strongerShare: max(e.capability, 1 - e.capability))?.q3_months ?? 18
        let ceiling = max(5, CombatModel.forcePool(a) * 0.02)
        if e.capability >= 0.7 {
            return WarDoneTest(kind: .territoryHeld, months: months * 1.5, casualties: ceiling * 2,
                               note: "Finished when their field army is broken and we hold \(d.capital).")
        }
        if gs.currentYear >= 1945 || !a.alliances.isEmpty {
            return WarDoneTest(kind: .treatySigned, months: months, casualties: ceiling * 1.5,
                               note: "Finished when they sign: terms at the table, not a march on \(d.capital).")
        }
        return WarDoneTest(kind: .costCeiling, months: months, casualties: ceiling,
                           note: String(format: "Finished — or abandoned — at %.0f months or %.0fK dead, whichever comes first.", months, ceiling))
    }

    // MARK: The record

    /// The whole deliberation, built from the numbers above. `roll` (0…1) sets which way thin information is wrong.
    /// 3.37.0: `seen` is the figure a model brain's council works from (its own fogged estimate, BrainBrief.swift);
    /// nil for the built-in AI, which reads the figure in general circulation.
    static func deliberate(_ a: Country, _ d: Country, in gs: GameState, roll: Double,
                           seen override: (value: Double, age: Int, source: IntelSource)? = nil) -> WarDeliberation {
        // 3.32.1: the figure the government is working from, and how old it is.
        let seen = override ?? Intelligence.believedArmy(of: d, for: a, in: gs)
        let aged = max(0, 1 - Double(seen.age) * 0.08)   // a figure loses a twelfth of its worth every turn
        let conf = confidence(a, about: d, year: gs.currentYear) * aged
        let truth = WarEstimate(capability: capability(a, d), resolve: resolve(d), confidence: conf)
        var bs = biases(a, d, confidence: conf)
        if seen.age >= Intelligence.staleTurns, !bs.contains(.staleIntelligence) { bs.insert(.staleIntelligence, at: 0) }
        var est = believed(truth: truth, biases: bs, roll: roll)
        est.capability = min(0.99, max(0.01, capability(a, d, believedArmy: seen.value)
                                       + (bs.contains(.domesticPressure) ? 0.08 : 0)))
        let kit = instruments(a, d, in: gs, estimate: est)
        let war = kit[0]
        let best = kit.dropFirst().max { $0.score < $1.score }
        let pushy = bs.contains(.domesticPressure) && a.profile.ambition >= 5
        let shortWar = war.odds >= 0.7 && est.resolve < 0.35
        // On the arithmetic alone a war almost never pays: the cheaper instruments cost a fraction as much for a
        // smaller prize, and making that comparison legible is what this record is for. Governments reach for war
        // anyway (a design choice, and the historical pattern), so only a cautious government with a workable
        // alternative in hand actually steps back — and the record says what it stepped back from either way.
        let cautious = a.profile.ambition <= 3 && a.profile.ethic >= 4 && !pushy && !shortWar
        let stepBack = cautious && roll < 0.5 && (best.map { $0.odds >= 0.5 && $0.score > war.score } ?? false)
        let chose = stepBack ? (best?.id ?? "war") : "war"
        let share = max(est.capability, 1 - est.capability)
        let record = HistoricalWars.initiatorOdds(year: gs.currentYear, strongerShare: share)
        let own = HistoricalWars.nationLine(a.id, year: gs.currentYear, name: a.name)
        let (cb, supported) = casus(a, d, in: gs)
        let test = doneTest(a, d, in: gs, estimate: est)
        let ally = a.alliances.sorted().first
        let mustBeTrue = "This works if their will to fight is near the \(pct(est.resolve)) we put it at"
            + (ally.map { ", and if \(gs.getCountry(id: $0)?.name ?? $0) stands by its promise" } ?? "") + "."
        let wouldBreakIt = bs.isEmpty
            ? "It breaks if they hold \(d.capital) through the first season."
            : "It breaks if we are wrong, and we may be: " + bs.map(\.note).joined(separator: "; ") + "."
        let offRamp = test.kind == .territoryHeld
            ? "If the first season goes badly we stop at the border and call what we hold a settlement."
            : "If the first season goes badly we take the terms on the table and call it a settlement."
        let alt = best.map { String(format: " %@ would cost $%.1fB against $%.0fB for the war (%@)", $0.name, $0.cost, war.cost, $0.note) } ?? ""
        let intel = seen.age == 0
            ? "Our figure for their army is this turn's, from \(seen.source.title)"
            : "Our figure for their army is \(seen.age) turn\(seen.age == 1 ? "" : "s") old, from \(seen.source.title) — \(seen.source.blindSpot)"
        let statement = """
        \(a.capital), \(GameCalendar.format(gs.currentDate)). \(a.name) weighs war on \(d.name). \(intel). \
        We put our share of the balance at \(pct(est.capability)) and their will to fight at \(pct(est.resolve)); \
        our information we rate \(pct(est.confidence)). Stated reason: \(cb.title.lowercased())\(supported ? "" : " — which the facts do not bear out"). \
        \(mustBeTrue) \(wouldBreakIt) \(offRamp)\(alt.isEmpty ? "" : alt + ".") \(test.note) \
        \(record.map { "The record gives the side that starts a war like this \(pct($0)); we think we are the exception." } ?? "")\
        \(own.map { " " + $0 } ?? "") \(chose == "war" ? "We go." : "We hold off and take the cheaper instrument.")
        """
        return WarDeliberation(actor: a.id, target: d.id, date: gs.currentDate, turn: gs.turn, estimate: est, truth: truth,
                               mustBeTrue: mustBeTrue, wouldBreakIt: wouldBreakIt, offRamp: offRamp, biases: bs, casus: cb,
                               instruments: kit, doneTest: test, recordOdds: record, ownRecord: own, chose: chose,
                               statement: statement)
    }

    static func pct(_ v: Double) -> String { "\(Int((min(1, max(0, v)) * 100).rounded()))%" }

    /// A war a nation owes an ally: not deliberated (the promise was made before the numbers).
    static func obligated(_ a: Country, _ d: Country, in gs: GameState) -> Bool {
        a.alliances.contains { d.atWarWith.contains($0) }
            || gs.treaties.contains { $0.signatories.contains(a.id) && d.atWarWith.contains(where: $0.signatories.contains) }
    }

    /// Key for a war's done-test, one per attacker → defender pair.
    static func key(_ a: String, _ d: String) -> String { "\(a)>\(d)" }
}

// MARK: - Engine

extension GameEngine {
    /// A computer-run nation's decision to attack, recorded before the first move. Returns the deliberation, whose
    /// `chose` says whether it went ahead. Only the deliberation is kept; the caller carries out the choice.
    /// `committed`: the war has already been ordered (by the cabinet that just asked, by a treaty, by a revolt), so
    /// the paper records what was weighed and reads "war" — the comparison with the cheaper instruments stays on it.
    @discardableResult
    /// 3.37.0: `brain`: a model brain ordered the war; its council works from that nation's own estimates and the
    /// record says so (a stand-down names the move taken instead, `WarCouncil.brainAlternative`).
    func deliberateWar(actor: String, target: String, roll: Double? = nil, committed: Bool = false,
                       brain: Bool = false) -> WarDeliberation? {
        guard let gs = gameState, let a = gs.getCountry(id: actor), let d = gs.getCountry(id: target) else { return nil }
        // One sitting per pair per turn: the cabinet does not write the same paper twice on its way to the same war.
        if let last = gs.shadow.deliberations.last, last.actor == actor, last.target == target, last.turn == gs.turn {
            return last
        }
        let r = roll ?? Double.random(in: 0..<1, using: &gs.rng)
        var dl = WarCouncil.deliberate(a, d, in: gs, roll: r,
                                       seen: brain ? Intelligence.estimate(.army, of: d, for: a, in: gs).map { ($0.value, $0.age, $0.source) } : nil)
        if committed, dl.chose != "war" {
            dl.chose = "war"
            dl.statement = dl.statement.replacingOccurrences(
                of: "We hold off and take the cheaper instrument.",
                with: "The order had already gone out. We go, and the cheaper instrument stays on the paper.")
        }
        gs.shadow.deliberations.append(dl)
        if gs.shadow.deliberations.count > WarCouncil.keep { gs.shadow.deliberations.removeFirst() }
        if dl.chose == "war" {
            gs.shadow.doneTests[WarCouncil.key(actor, target)] = dl.doneTest
            // 3.32.1: a war opened on a figure that was months old, and wrong — counted, so the debrief can say so.
            if dl.biases.contains(.staleIntelligence), abs(dl.estimate.capability - dl.truth.capability) >= 0.1 {
                gs.shadow.worldStats["stale_wars", default: 0] += 1
            }
        } else {
            gs.shadow.post("\(a.name) steps back from war with \(d.name): \(dl.instruments.first { $0.id == dl.chose }?.name.lowercased() ?? "a cheaper instrument") costs less.",
                           date: gs.currentDate, severity: 1)
        }
        var detail: [String: Any] = ["actor": actor, "target": target, "chose": dl.chose,
                                     "capability": PlayHistory.num(dl.estimate.capability),
                                     "resolve": PlayHistory.num(dl.estimate.resolve),
                                     "confidence": PlayHistory.num(dl.estimate.confidence),
                                     "biases": dl.biases.map(\.rawValue).joined(separator: ","),
                                     "true_capability": PlayHistory.num(dl.truth.capability),
                                     "true_resolve": PlayHistory.num(dl.truth.resolve),
                                     "casus": dl.casus.rawValue, "done_test": dl.doneTest.kind.rawValue,
                                     "excerpt": PlayHistory.text(String(dl.statement.prefix(300))),
                                     "game_date": PlayHistory.day(gs.currentDate)]
        if brain {
            detail["source"] = "brain"
            if dl.chose != "war" { detail["instead"] = WarCouncil.brainAlternative(dl.chose, target: target).verb }
        }
        logPlayEvent("war_deliberation", detail: detail)
        self.gameState = gs
        return dl
    }

    /// Record the stated reason for a war and let the world react to it: a strong reason costs the actor little and
    /// warms its allies; a thin or invented one costs standing everywhere.
    @discardableResult
    func stateCasus(actor: String, target: String, casus: CasusBelli? = nil, applyReaction: Bool = true) -> CasusRecord? {
        guard let gs = gameState, let a = gs.getCountry(id: actor), let d = gs.getCountry(id: target) else { return nil }
        let found = WarCouncil.casus(a, d, in: gs)
        let c = casus ?? found.0
        let supported = casus == nil ? found.1 : (c == found.0 ? found.1 : false)
        let s = WarCouncil.strength(c, supported: supported)
        let statement = "\(a.name) declares war on \(d.name), citing \(c.title.lowercased())."
            + (supported ? "" : " No one outside \(a.capital) can find the incident.")
        let rec = CasusRecord(actor: actor, target: target, casus: c, date: gs.currentDate, supported: supported, strength: s, statement: statement)
        gs.shadow.casusLog.append(rec)
        if gs.shadow.casusLog.count > WarCouncil.keep { gs.shadow.casusLog.removeFirst() }
        // The world's reaction to the reason, on top of the war's own cost in relations: a strong reason warms the
        // actor's allies, a thin or invented one costs it standing everywhere.
        if applyReaction {
            let hit = Int((-12 * (1 - s)).rounded())
            for o in gs.countries where o.id != actor && o.id != target && !o.isDestroyed && !o.isTerritory {
                modifyDiplomaticRelation(from: o.id, to: actor, by: a.alliances.contains(o.id) ? Int(Double(hit) * 0.4) + (s >= 0.7 ? 5 : 0) : hit)
            }
            if actor == gs.playerCountryID {
                gs.shadow.ruthlessness += 12 * (1 - s)
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + (s >= 0.7 ? 2 : -6 * (1 - s)))
            }
        }
        gs.shadow.post(statement, date: gs.currentDate, severity: s < 0.4 ? 3 : 2)
        logPlayEvent("casus_belli", detail: ["actor": actor, "target": target, "casus": c.rawValue, "supported": supported,
                                            "strength": PlayHistory.num(s), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return rec
    }

    /// The President states the reason the United States will give for a war on `target`, before he orders it.
    /// Only reasons the era would recognise are accepted.
    @discardableResult
    func statePlayerCasus(target: String, casus: CasusBelli) -> Bool {
        guard let gs = gameState, gs.getCountry(id: target) != nil, casus.available(year: gs.currentYear) else { return false }
        gs.shadow.statedCasus[target] = casus.rawValue
        gs.shadow.post("The White House prepares its case against \(gs.getCountry(id: target)?.name ?? target): \(casus.title.lowercased()).",
                       date: gs.currentDate, severity: 1)
        self.gameState = gs
        return true
    }

    /// Every war gets a done-test before its first move, even one nobody deliberated (the player's, or a scripted
    /// one): the same arithmetic, from the attacker's own point of view.
    func ensureDoneTest(actor: String, target: String) {
        guard let gs = gameState, gs.shadow.doneTests[WarCouncil.key(actor, target)] == nil,
              let a = gs.getCountry(id: actor), let d = gs.getCountry(id: target) else { return }
        let e = WarEstimate(capability: WarCouncil.capability(a, d), resolve: WarCouncil.resolve(d),
                            confidence: WarCouncil.confidence(a, about: d, year: gs.currentYear))
        gs.shadow.doneTests[WarCouncil.key(actor, target)] = WarCouncil.doneTest(a, d, in: gs, estimate: e)
        self.gameState = gs
    }

    /// Each turn: has any war met the test it declared? Met or failed, it goes to settlement rather than grinding on.
    /// 3.32.0: this closes the hole the attrition model opened — an optimizer can no longer feed a war forever.
    func checkWarDoneTests() {
        guard let gs = gameState else { return }
        for i in gs.shadow.fronts.indices where gs.shadow.fronts[i].status == .fighting {
            let f = gs.shadow.fronts[i]
            guard let test = gs.shadow.doneTests[WarCouncil.key(f.attacker, f.defender)] else { continue }
            let months = Double(GameCalendar.days(from: f.startDate, to: gs.currentDate)) / 30.44
            let aName = gs.getCountry(id: f.attacker)?.name ?? f.attacker
            let dName = gs.getCountry(id: f.defender)?.name ?? f.defender
            var met: Bool? = nil   // true: the attacker's test is met; false: it has failed
            switch test.kind {
            case .territoryHeld:
                if f.defenderTroops <= f.defenderInitial * 0.25 || f.attackerMomentum >= 0.6 { met = true }
                else if months >= test.months || f.attackerDead >= test.casualties { met = false }
            case .treatySigned:
                if months >= test.months * 0.5 && abs(f.attackerMomentum) < 0.35 { met = true }
                else if months >= test.months || f.attackerDead >= test.casualties { met = false }
            case .costCeiling:
                if f.defenderTroops <= f.defenderInitial * 0.3 { met = true }
                else if months >= test.months || f.attackerDead >= test.casualties { met = false }
            }
            guard let done = met else { continue }
            gs.shadow.doneTests.removeValue(forKey: WarCouncil.key(f.attacker, f.defender))
            let line: String
            if done && test.kind == .treatySigned {
                line = "\(aName) and \(dName) go to the table: the war has met the test \(aName) set for it."
                gs.shadow.post(line, date: gs.currentDate, severity: 2)
                self.gameState = gs
                settleWar(front: i, negotiated: true)
            } else if done {
                line = "\(aName) has what it went to war for in \(dName)."
                gs.shadow.post(line, date: gs.currentDate, severity: 2)
                self.gameState = gs
                resolveFront(index: i, verdict: .attackerWon)
            } else {
                line = "\(aName) abandons the war on \(dName): \(test.note.lowercased())"
                gs.shadow.post(line, date: gs.currentDate, severity: 2)
                self.gameState = gs
                settleWar(front: i, negotiated: true)
            }
            gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(line)")
            logPlayEvent("war_done_test", detail: ["attacker": f.attacker, "defender": f.defender, "kind": test.kind.rawValue,
                                                  "met": done, "months": PlayHistory.num(months),
                                                  "game_date": PlayHistory.day(gs.currentDate)])
            guard let g = gameState else { return }
            self.gameState = g
        }
    }

    /// A war that ends at the table rather than in a capital: the fighting stops, the front closes, and the terms
    /// go on paper (3.32.2). The side with the momentum writes them.
    func settleWar(front i: Int, negotiated: Bool) {
        guard let gs = gameState, gs.shadow.fronts.indices.contains(i) else { return }
        let f = gs.shadow.fronts[i]
        gs.shadow.fronts[i].status = .ceasefire
        self.gameState = gs
        makePeace(f.attacker, f.defender)
        let victor = f.attackerMomentum >= 0 ? f.attacker : f.defender
        let loser = victor == f.attacker ? f.defender : f.attacker
        writePeaceTerms(victor: victor, loser: loser, negotiated: negotiated)
    }
}
