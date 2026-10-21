//
//  CombatModel.swift
//  Global Thermal Nuclear War
//
//  The War Room's model: each war is a front with troops on both sides, fighting resolved week by week (scaled to the
//  turn length), troop morale ("will to fight"), casualties and economic damage. A side that breaks surrenders and
//  the victor installs a new government; an attacker that breaks withdraws. The U.S. can commit troops to either side.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum FrontStatus: String, Codable {
    case fighting, attackerWon, defenderWon, ceasefire
}

struct WarFront: Codable, Identifiable, Hashable {
    var id = UUID()
    var attacker: String
    var defender: String
    var startDate: Date
    var lastBattle: Date
    /// Troops in theater, thousands.
    var attackerTroops: Double
    var defenderTroops: Double
    var attackerInitial: Double
    var defenderInitial: Double
    /// Will to fight, 0…1.
    var attackerWill: Double = 0.8
    var defenderWill: Double = 0.85
    /// Who is winning: -1 (defender) … +1 (attacker).
    var attackerMomentum: Double = 0
    /// Casualties, thousands.
    var attackerDead: Double = 0
    var defenderDead: Double = 0
    var civilianDead: Double = 0
    /// Economic damage to the defender, billions.
    var economicLoss: Double = 0
    /// U.S. troops committed, thousands, and on which side (nil = none).
    var usTroops: Double = 0
    var usSide: String?
    var status: FrontStatus = .fighting
    var battles: Int = 0

    var involvesUS: Bool { usSide != nil }
}

/// One week of fighting on a front: pure arithmetic over the inputs, randomness passed in.
struct BattleOutcome: Equatable {
    var attackerLosses: Double
    var defenderLosses: Double
    var civilianLosses: Double
    var momentumChange: Double
}

enum CombatModel {
    /// Troops a country can field, thousands.
    static func forcePool(_ c: Country) -> Double {
        max(5, Double(max(1, c.militaryStrength)) * sqrt(Double(max(1, c.population))) * 1.2)
    }

    static func makeFront(attacker: Country, defender: Country, date: Date) -> WarFront {
        let a = forcePool(attacker) * 0.35
        let d = forcePool(defender) * 0.55
        return WarFront(attacker: attacker.id, defender: defender.id, startDate: date, lastBattle: date,
                        attackerTroops: a, defenderTroops: d, attackerInitial: a, defenderInitial: d)
    }

    /// Combat power: troops × morale × quality (× defender's home-ground bonus).
    static func power(troops: Double, will: Double, strength: Int, defending: Bool) -> Double {
        troops * (0.4 + will) * (0.3 + Double(strength) / 100) * (defending ? 1.25 : 1.0)
    }

    /// Resolve one week. `rolls` are two numbers in 0..<1 (luck for each side).
    static func battle(_ f: WarFront, attackerStrength: Int, defenderStrength: Int, rolls: (Double, Double)) -> BattleOutcome {
        var aTroops = f.attackerTroops, dTroops = f.defenderTroops
        if f.usSide == f.attacker { aTroops += f.usTroops }
        if f.usSide == f.defender { dTroops += f.usTroops }
        let pa = power(troops: aTroops, will: f.attackerWill, strength: attackerStrength, defending: false)
        let pd = power(troops: dTroops, will: f.defenderWill, strength: defenderStrength, defending: true)
        let ratio = max(0.05, min(20, pa / max(0.001, pd)))
        let luckA = 0.7 + rolls.0 * 0.6, luckD = 0.7 + rolls.1 * 0.6
        let aLoss = aTroops * 0.012 * pow(1 / ratio, 0.5) * luckD
        let dLoss = dTroops * 0.012 * pow(ratio, 0.5) * luckA
        return BattleOutcome(attackerLosses: aLoss, defenderLosses: dLoss, civilianLosses: (aLoss + dLoss) * 0.3,
                             momentumChange: max(-0.25, min(0.25, (ratio - 1) * 0.08)))
    }

    /// Apply a battle to a front (casualties split proportionally with committed U.S. troops).
    /// Returns U.S. troop losses (thousands).
    @discardableResult
    static func apply(_ o: BattleOutcome, to f: inout WarFront, date: Date) -> Double {
        var usLoss = 0.0
        func split(_ loss: Double, own: Double, side: String) -> Double {
            guard f.usSide == side, f.usTroops > 0 else { return loss }
            let share = f.usTroops / (own + f.usTroops)
            usLoss += loss * share
            return loss * (1 - share)
        }
        let aLoss = split(o.attackerLosses, own: f.attackerTroops, side: f.attacker)
        let dLoss = split(o.defenderLosses, own: f.defenderTroops, side: f.defender)
        f.usTroops = max(0, f.usTroops - usLoss)
        f.attackerTroops = max(0, f.attackerTroops - aLoss)
        f.defenderTroops = max(0, f.defenderTroops - dLoss)
        f.attackerDead += aLoss * 0.3
        f.defenderDead += dLoss * 0.3
        f.civilianDead += o.civilianLosses
        f.economicLoss += o.defenderLosses * 0.05
        f.attackerMomentum = max(-1, min(1, f.attackerMomentum + o.momentumChange))
        // Morale follows losses and momentum.
        let aFrac = o.attackerLosses / max(1, f.attackerInitial)
        let dFrac = o.defenderLosses / max(1, f.defenderInitial)
        f.attackerWill = max(0, min(1, f.attackerWill - aFrac * 2.5 + f.attackerMomentum * 0.01))
        f.defenderWill = max(0, min(1, f.defenderWill - dFrac * 2.5 - f.attackerMomentum * 0.01))
        f.lastBattle = date
        f.battles += 1
        return usLoss
    }

    /// Has one side broken?
    static func verdict(_ f: WarFront) -> FrontStatus {
        if f.defenderWill < 0.15 || f.defenderTroops < f.defenderInitial * 0.12 { return .attackerWon }
        if f.attackerWill < 0.15 || f.attackerTroops < f.attackerInitial * 0.12 { return .defenderWon }
        return .fighting
    }

    /// Probability a surrender demand is accepted right now.
    static func surrenderAcceptance(_ f: WarFront, demandedBy side: String) -> Double {
        let momentum = side == f.attacker ? f.attackerMomentum : -f.attackerMomentum
        let enemyWill = side == f.attacker ? f.defenderWill : f.attackerWill
        return min(0.95, max(0.02, 0.1 + momentum * 0.5 + (0.6 - enemyWill) * 0.8))
    }

    /// The conquered country gets a government shaped like the victor's.
    static func installGovernment(on loser: inout Country, by winner: Country) {
        loser.alignment = winner.alignment
        loser.government = winner.government == .monarchy ? .authoritarian : winner.government
        var p = loser.profile
        p.ideology = winner.profile.ideology
        p.ambition = 2
        p.ethic = max(2, winner.profile.ethic - 1)
        p.leadership = 30
        p.outcry = min(100, p.outcry + 30)
        loser.profile = p
        loser.stability = max(10, loser.stability - 30)
        loser.diplomaticRelations[winner.id] = 60
        loser.atWarWith.remove(winner.id)
    }
}

// MARK: - After a U.S. victory: annex, or choose the new government (3.2.0)

/// The governments the President can stand up in a vanquished country instead of annexing it.
enum PostWarGovernment: String, Codable, CaseIterable, Identifiable {
    case democraticRepublic, constitutionalMonarchy, militaryJunta, communistState, theocracy, provisional, clientState

    var id: String { rawValue }

    var title: String {
        switch self {
        case .democraticRepublic: return "Democratic Republic"
        case .constitutionalMonarchy: return "Constitutional Monarchy"
        case .militaryJunta: return "Military Junta"
        case .communistState: return "Communist One-Party State"
        case .theocracy: return "Theocracy"
        case .provisional: return "Provisional Government"
        case .clientState: return "Client State"
        }
    }

    /// What the choice does, in one line, for the choice sheet.
    var summary: String {
        switch self {
        case .democraticRepublic: return "Elections within two years. Western-leaning, middling stability, friendly to Washington."
        case .constitutionalMonarchy: return "Restore a crown under a constitution. The steadiest option; sides with the victor."
        case .militaryJunta: return "Generals keep order. Unstable, ambitious and independent; thin gratitude."
        case .communistState: return "A one-party state. Stable enough, but it turns toward the Eastern Bloc."
        case .theocracy: return "Clerics take power. Non-aligned, restless and cool toward the U.S."
        case .provisional: return "A caretaker council until elections. Fragile at first; leans no one's way yet."
        case .clientState: return "A strongman who owes you everything. Allied and loyal, resented at home."
        }
    }

    /// The table that drives everything else: government, ideology, camp, stability, relation with the victor,
    /// unrest added, ambition, ethic, and whether it joins the victor's alliance.
    fileprivate var traits: (gov: GovernmentType, ideology: LeaderIdeology, alignment: PoliticalAlignment?, stability: Int,
                             relation: Int, unrest: Double, ambition: Int, ethic: Int, allied: Bool) {
        switch self {   // alignment nil = take the victor's camp
        case .democraticRepublic: return (.republic, .liberalDemocracy, .western, 45, 55, 15, 2, 4, false)
        case .constitutionalMonarchy: return (.monarchy, .constitutionalMonarchy, nil, 55, 45, 10, 2, 4, false)
        case .militaryJunta: return (.military, .militaryJunta, .independent, 25, 20, 30, 4, 2, false)
        case .communistState: return (.communist, .communism, .eastern, 50, -20, 10, 3, 3, false)
        case .theocracy: return (.theocracy, .theocracy, .nonAligned, 40, -10, 20, 3, 3, false)
        case .provisional: return (.republic, .developingDemocracy, .nonAligned, 30, 35, 25, 1, 3, false)
        case .clientState: return (.authoritarian, .nationalism, nil, 35, 85, 30, 1, 2, true)
        }
    }
}

/// What the President decided for a vanquished country. `victorsModel` is the pre-3.2 behavior (a government shaped
/// like the victor's) and the default when no choice is made before the next turn.
enum SettlementChoice: Codable, Hashable {
    case annex
    case government(PostWarGovernment)
    case victorsModel
}

/// A surrender that is waiting for the President's decision.
struct PostWarSettlement: Codable, Identifiable, Hashable {
    var id = UUID()
    var loser: String
    var victor: String
    var date: Date
}

extension CombatModel {
    /// Map / dossier label for a territory: "U.S. TERRITORY" for the United States, else "<OWNER> TERRITORY".
    static func territoryTitle(ownerID: String, ownerName: String) -> String {
        ownerID == "USA" ? "U.S. TERRITORY" : "\(ownerName.uppercased()) TERRITORY"
    }

    /// Annex the loser as the owner's territory. Its arsenal is seized (the caller adds the returned warheads to the
    /// owner), it stops acting on its own, and occupation brings unrest and a hit to output while it is rebuilt.
    @discardableResult
    static func annex(_ loser: inout Country, to owner: Country) -> Int {
        let seized = loser.nuclearWarheads
        loser.territoryOf = owner.id
        loser.alignment = owner.alignment
        loser.government = owner.government
        loser.atWarWith = []
        loser.alliances = [owner.id]
        loser.diplomaticRelations[owner.id] = 100
        loser.nuclearWarheads = 0; loser.tacticalNukes = 0; loser.strategicNukes = 0
        loser.icbmCount = 0; loser.submarineLaunchedMissiles = 0; loser.bombers = 0
        loser.nuclearStatus = .none
        loser.aggressionLevel = 5
        loser.stability = max(5, loser.stability - 25)
        loser.economicStrength = max(1, loser.economicStrength * 7 / 10)
        loser.gdp *= 0.7
        var p = loser.profile
        p.ideology = owner.profile.ideology
        p.ambition = 1
        p.leadership = 25
        p.outcry = min(100, p.outcry + 40)   // occupation breeds insurgency
        loser.profile = p
        return seized
    }

    /// Stand up the government the President chose. The victor's own relation is set by the table; the caller
    /// handles alliances on the victor's side.
    static func installChosenGovernment(_ type: PostWarGovernment, on loser: inout Country, by victor: Country) {
        let t = type.traits
        loser.government = t.gov
        loser.alignment = t.alignment ?? victor.alignment
        loser.stability = t.stability
        loser.diplomaticRelations[victor.id] = t.relation
        loser.atWarWith.remove(victor.id)
        if t.allied { loser.alliances.insert(victor.id) }
        loser.electionCycle = (t.gov == .republic || t.gov == .democracy) ? (type == .provisional ? 2 : 8) : 0
        var p = loser.profile
        p.ideology = t.ideology
        p.ambition = t.ambition
        p.ethic = t.ethic
        p.leadership = 30
        p.outcry = min(100, p.outcry + t.unrest)
        loser.profile = p
    }

    /// One line per option from the cabinet, shown on the choice sheet. Keyed by Situation Room role.
    static func advisorTake(on choice: SettlementChoice) -> (role: String, text: String) {
        switch choice {
        case .annex: return ("state", "Annexation will cost us at the UN and every capital that remembers being a colony.")
        case .victorsModel: return ("whc", "Let them copy our system and stand on their own feet.")
        case .government(let g):
            switch g {
            case .democraticRepublic: return ("state", "A democracy is the only settlement the world will call legitimate.")
            case .constitutionalMonarchy: return ("nsa", "A crown gives people something older than the war to rally around.")
            case .militaryJunta: return ("defense", "The generals can hold the country. Whether they stay ours is another matter.")
            case .communistState: return ("cia", "Installing a party state hands Moscow a client. I strongly advise against it.")
            case .theocracy: return ("cia", "The clerics have the street, but they will not take orders from Washington.")
            case .provisional: return ("economic", "A caretaker council keeps the aid flowing while the new constitution is written.")
            case .clientState: return ("defense", "A loyal strongman means basing rights and a friendly vote. The people will hate him.")
            }
        }
    }
}

// MARK: - Unclaimed lands and naming territories (3.3.0)

extension CombatModel {
    /// Longest name the President can give a territory.
    static let maxTerritoryNameLength = 40

    /// A territory name as the President typed it, trimmed; nil if empty, longer than 40 characters, or carrying
    /// newlines or other control characters. Anything else is kept verbatim (it is only ever shown as plain text).
    static func validTerritoryName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= maxTerritoryNameLength,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0) })
        else { return nil }
        return name
    }

    /// An unclaimed land taken by `owner`: a new country on the land's modern outline, annexed on the spot like a
    /// 3.2.0 territory. Nobody lived under a government there to resist, so it starts quieter than an occupation.
    /// `troops` (thousands, 3.4.0) sizes the expedition: the standard 5K gives the pre-3.4 garrison (strength 5,
    /// stability 50); a bigger one holds the land more firmly (strength = troops, stability +10 per doubling, 30…70).
    static func claim(_ land: CountryTemplate, for owner: Country, troops: Double = AttackSizing.expeditionStandard) -> Country {
        var c = land.toCountry()
        annex(&c, to: owner)
        let m = max(0.01, troops / AttackSizing.expeditionStandard)
        c.militaryStrength = max(1, min(100, Int((5 * m).rounded())))   // the garrison; there was no army to defeat
        c.stability = max(30, min(70, 50 + Int((10 * log2(m)).rounded())))
        var p = c.profile
        p.outcry = min(p.outcry, 20)
        c.profile = p
        return c
    }
}

// MARK: - Sizing an offensive (3.4.0)

/// What an offensive can be sized by. Each attack shows only the ones that fit it.
enum ForceKind: String, Codable, CaseIterable, Identifiable {
    case troops, aircraft, warheads
    var id: String { rawValue }
    var label: String {
        switch self {
        case .troops: return "Ground troops (thousands)"
        case .aircraft: return "Aircraft (sorties)"
        case .warheads: return "Nuclear warheads"
        }
    }
}

/// The size of an offensive the President orders. Only the fields for the attack's `ForceKind`s are used.
struct AttackSize: Codable, Hashable {
    var troops: Double = 0
    var aircraft: Int = 0
    var warheads: Int = 0

    func amount(_ k: ForceKind) -> Double {
        switch k {
        case .troops: return troops
        case .aircraft: return Double(aircraft)
        case .warheads: return Double(warheads)
        }
    }

    mutating func set(_ k: ForceKind, _ v: Double) {
        switch k {
        case .troops: troops = v.rounded()
        case .aircraft: aircraft = Int(v.rounded())
        case .warheads: warheads = Int(v.rounded())
        }
    }
}

/// Probe / Standard / Overwhelming. Standard is exactly what the game did before 3.4.0.
enum AttackPreset: String, CaseIterable, Identifiable {
    case probe, standard, overwhelming
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var multiplier: Double {
        switch self {
        case .probe: return 0.5
        case .standard: return 1
        case .overwhelming: return 2.5
        }
    }
}

/// The sizing rules. Every effect is a function of the scale m = chosen ÷ standard for the attack's main force
/// (warheads, else troops, else aircraft), so Standard (m = 1) reproduces the pre-3.4 numbers exactly:
///   success odds        min(1, √m)                    — only an undersized attack can fail
///   target's relations  legacy change × (0.75 + 0.25 m)
///   rest of the world   −round(4 × max(0, m − 1))     relations with the U.S.; ruthlessness +round(5 × max(0, m − 1))
///   escalation          m ≥ 2 raises DEFCON one more step
///   ground troops       the new front starts with the chosen troops (casualties then follow the War Room model)
///   air strikes         enemy troops −5% × max(0, m − 1) of their front; aircraft lost = round(sorties × 4% × enemy strength)
///   nuclear             the chosen warheads go to the existing strike (damage, radiation, casualties, retaliation)
/// Bounds: 1 … what the U.S. has free right now (`available`), and nothing in an era that doesn't have it.
enum AttackSizing {
    static let nuclearActions: Set<PresidentialAction> = [.launchNukes, .preemptive, .firstStrike, .strategicNuke, .tacticalNuke, .retaliate]

    /// The forces an action is sized by (empty = not an offensive the President sizes).
    static func kinds(for action: PresidentialAction) -> [ForceKind] {
        if nuclearActions.contains(action) { return [.warheads] }
        switch action {
        case .groundInvasion: return [.troops]
        case .airStrike, .bombardment: return [.aircraft]
        default: return []
        }
    }

    /// The kind whose scale drives the effects.
    static func primary(_ kinds: [ForceKind]) -> ForceKind? {
        kinds.contains(.warheads) ? .warheads : (kinds.contains(.troops) ? .troops : kinds.first)
    }

    /// Aircraft the U.S. can put up in a year: none before military aviation (1914), a small air arm to 1938,
    /// a WWII-sized one 1939–45, a smaller modern one after; scaled by military strength, less aircraft lost.
    static func aircraftPool(_ c: Country, year: Int, lost: Int = 0) -> Int {
        guard year >= 1914 else { return 0 }
        let perPoint = year < 1939 ? 2 : (year < 1946 ? 30 : 10)
        return max(0, max(1, c.militaryStrength) * perPoint - lost)
    }

    /// All the President's ground troops (thousands): the U.S. manpower of the era (3.9.0), or the force pool for
    /// other countries.
    static func troopPool(_ gs: GameState) -> Double {
        guard let p = gs.getPlayerCountry() else { return 0 }
        return p.id == "USA" ? ManpowerModel.total(on: gs.currentDate, called: gs.shadow.mobilizations) : CombatModel.forcePool(p)
    }

    /// Troops (thousands) not already in a fight or garrisoning a territory.
    static func freeTroops(_ gs: GameState) -> Double {
        guard let p = gs.getPlayerCountry() else { return 0 }
        let fighting = gs.shadow.fronts.filter { $0.status == .fighting }.reduce(0.0) { sum, f in
            sum + (f.usSide != nil ? f.usTroops : 0) + (f.attacker == p.id ? f.attackerTroops : 0)
        }
        // 3.7.0: territory rubber keeps a wartime army moving (1914–18, 1939–45).
        let rubber = ExpansionModel.strategic(gs).contains(.rubber) ? 1.1 : 1
        return max(0, troopPool(gs) * rubber - fighting - gs.shadow.garrisons.values.reduce(0, +))
    }

    /// What the U.S. can send of one kind right now.
    static func available(_ k: ForceKind, in gs: GameState) -> Double {
        guard let p = gs.getPlayerCountry() else { return 0 }
        switch k {
        case .troops: return freeTroops(gs)
        case .aircraft:   // 3.7.0: territory oil fuels a larger air arm
            let oil = ExpansionModel.strategic(gs).contains(.oil) ? 1.15 : 1
            return (Double(aircraftPool(p, year: gs.currentYear, lost: gs.shadow.aircraftLost)) * oil).rounded(.down)
        case .warheads: return gs.currentYear >= 1945 ? Double(p.nuclearWarheads) : 0
        }
    }

    /// The pre-3.4 size of each attack: 3 / 5 / 10 warheads by action, the War Room's opening force (35% of the
    /// force pool), and a fifth of the air arm.
    static func standard(_ action: PresidentialAction, in gs: GameState) -> AttackSize {
        guard let p = gs.getPlayerCountry() else { return AttackSize() }
        let warheads: Int
        switch action {
        case .tacticalNuke: warheads = 3
        case .strategicNuke, .firstStrike, .preemptive: warheads = 10
        default: warheads = 5
        }
        // Troops: the War Room's opening force, but never more than are free (3.9.0, you can't send what you don't have).
        return AttackSize(troops: min((CombatModel.forcePool(p) * 0.35).rounded(), freeTroops(gs).rounded()),
                          aircraft: max(1, aircraftPool(p, year: gs.currentYear) / 5),
                          warheads: min(warheads, p.nuclearWarheads))
    }

    /// A preset, bounded by what is available (and at least 1 of anything available).
    static func preset(_ preset: AttackPreset, for action: PresidentialAction, in gs: GameState) -> AttackSize {
        let std = standard(action, in: gs)
        if preset == .standard { return std }
        var s = std
        for k in kinds(for: action) {
            let cap = available(k, in: gs)
            s.set(k, min(cap, max(cap > 0 ? 1 : 0, std.amount(k) * preset.multiplier)))
        }
        return s
    }

    /// Clamp a requested size to 1 … available for each kind the action uses.
    static func clamp(_ size: AttackSize, for action: PresidentialAction, in gs: GameState) -> AttackSize {
        var s = size
        for k in kinds(for: action) {
            let v = size.amount(k)
            s.set(k, max(min(1, available(k, in: gs)), min(available(k, in: gs), v.isFinite ? v : 0)))
        }
        return s
    }

    /// m = chosen ÷ standard for the main force (1 when nothing is sized).
    static func scale(_ size: AttackSize, for action: PresidentialAction, in gs: GameState) -> Double {
        guard let k = primary(kinds(for: action)) else { return 1 }
        let std = standard(action, in: gs).amount(k)
        guard std > 0 else { return 1 }
        return max(0, size.amount(k) / std)
    }

    static func successOdds(scale m: Double) -> Double { min(1, m.squareRoot()) }
    static func relationFactor(scale m: Double) -> Double { 0.75 + 0.25 * m }
    static func worldHit(scale m: Double) -> Int { Int((4 * max(0, m - 1)).rounded()) }
    static func ruthlessness(scale m: Double) -> Int { Int((5 * max(0, m - 1)).rounded()) }
    static func escalates(scale m: Double) -> Bool { m >= 2 }
    static func aircraftLost(sorties: Int, against target: Country) -> Int {
        Int((Double(sorties) * 0.04 * Double(max(1, target.militaryStrength)) / 100).rounded())
    }
    static func airBlow(scale m: Double) -> Double { 0.05 * max(0, m - 1) }

    /// The opening odds of a ground offensive with `troops` (thousands): the War Room's first-week power ratio r,
    /// as r² ÷ (1 + r²). Shown on the sizing panel; the war itself is still fought week by week.
    static func invasionOdds(troops: Double, attacker: Country, defender: Country) -> Double {
        let pa = CombatModel.power(troops: troops, will: 0.8, strength: attacker.militaryStrength, defending: false)
        let pd = CombatModel.power(troops: CombatModel.forcePool(defender) * 0.55, will: 0.85, strength: defender.militaryStrength, defending: true)
        let r = pa / max(0.001, pd)
        return r * r / (1 + r * r)
    }

    /// "12 warheads", "40K troops, 200 aircraft": for the log, the ticker and play history.
    /// How a computer-run country sizes its own attack (3.9.0): aggressive ones (70+) go in overwhelming, cautious ones
    /// (under 30) probe, the rest standard; one step smaller when already three times the target's strength.
    static func aiPreset(attacker a: Country, defender d: Country) -> AttackPreset {
        var p: AttackPreset = a.aggressionLevel >= 70 ? .overwhelming : (a.aggressionLevel < 30 ? .probe : .standard)
        if CombatModel.forcePool(a) > 3 * CombatModel.forcePool(d) {
            p = p == .overwhelming ? .standard : .probe
        }
        return p
    }

    /// A computer's sized troop commitment (thousands) and warhead salvo, capped by what it has.
    static func aiTroops(attacker a: Country, defender d: Country) -> Double {
        min(CombatModel.forcePool(a) * 0.9, CombatModel.forcePool(a) * 0.35 * aiPreset(attacker: a, defender: d).multiplier)
    }
    static func aiWarheads(_ base: Int, attacker a: Country, defender d: Country) -> Int {
        max(1, min(a.nuclearWarheads, Int((Double(base) * aiPreset(attacker: a, defender: d).multiplier).rounded())))
    }

    /// An expedition to unclaimed land (3.3.0) needs troops only; 5K is the standard (pre-3.4) garrison.
    static let expeditionStandard: Double = 5

    static func describe(_ size: AttackSize, kinds: [ForceKind]) -> String {
        kinds.map { k -> String in
            switch k {
            case .troops: return "\(Int(size.troops))K troops"
            case .aircraft: return "\(size.aircraft) aircraft"
            case .warheads: return "\(size.warheads) warhead\(size.warheads == 1 ? "" : "s")"
            }
        }.joined(separator: ", ")
    }
}
