//
//  CountryProfile.swift
//  Global Thermal Nuclear War
//
//  Leader personality (ambition and ethic on a 1–6 scale, ideology), leadership effectiveness, quality of life,
//  foreign-aid need and the five threat anxieties (nuclear, military, political, economic, social) for every country.
//  Profiles are derived from GTNW's own country data; a scenario may override them (e.g. the 1990 scenario can read
//  values from the player's local Shadow Pack — never from this repository).
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - LeaderIdeology

enum LeaderIdeology: String, Codable, CaseIterable, Identifiable {
    case liberalDemocracy = "Liberal Democracy"
    case socialDemocracy = "Social Democracy"
    case developingDemocracy = "Developing Democracy"
    case constitutionalMonarchy = "Constitutional Monarchy"
    case absoluteMonarchy = "Absolute Monarchy"
    case communism = "Communism"
    case oneParty = "One-Party State"
    case nationalism = "Nationalism"
    case militaryJunta = "Military Junta"
    case theocracy = "Theocracy"
    case islamicRepublic = "Islamic Republic"
    case populism = "Populism"
    case expansionism = "Expansionism"

    var id: String { rawValue }

    /// Rough left/right & open/closed placement used for "same camp" checks.
    var isDemocratic: Bool {
        switch self {
        case .liberalDemocracy, .socialDemocracy, .developingDemocracy, .constitutionalMonarchy, .populism: return true
        default: return false
        }
    }
}

// MARK: - Threat anxieties

/// The five things a government can be afraid of. Each is 0 (calm) … 100 (panic).
struct ThreatAnxieties: Codable, Hashable {
    var nuclear: Double = 10
    var military: Double = 10
    var political: Double = 10
    var economic: Double = 10
    var social: Double = 10

    enum Kind: String, CaseIterable, Identifiable {
        case nuclear, military, political, economic, social
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    subscript(kind: Kind) -> Double {
        get {
            switch kind {
            case .nuclear: return nuclear
            case .military: return military
            case .political: return political
            case .economic: return economic
            case .social: return social
            }
        }
        set {
            let v = min(100, max(0, newValue))
            switch kind {
            case .nuclear: nuclear = v
            case .military: military = v
            case .political: political = v
            case .economic: economic = v
            case .social: social = v
            }
        }
    }

    var peak: (kind: Kind, value: Double) {
        Kind.allCases.map { ($0, self[$0]) }.max { $0.1 < $1.1 }!
    }

    var average: Double { (nuclear + military + political + economic + social) / 5 }
}

// MARK: - Foreign aid

enum AidCategory: String, Codable, CaseIterable, Identifiable {
    case humanitarian, economic, intelligence, military, nuclear
    var id: String { rawValue }
    var label: String {
        switch self {
        case .humanitarian: return "Humanitarian"
        case .economic: return "Economic"
        case .intelligence: return "Intelligence"
        case .military: return "Military"
        case .nuclear: return "Nuclear"
        }
    }
    var icon: String {
        switch self {
        case .humanitarian: return "cross.case.fill"
        case .economic: return "dollarsign.circle.fill"
        case .intelligence: return "eye.fill"
        case .military: return "shield.fill"
        case .nuclear: return "atom"
        }
    }
}

/// Five aid amounts in billions of dollars.
struct AidVector: Codable, Hashable {
    var humanitarian: Double = 0
    var economic: Double = 0
    var intelligence: Double = 0
    var military: Double = 0
    var nuclear: Double = 0

    subscript(c: AidCategory) -> Double {
        get {
            switch c {
            case .humanitarian: return humanitarian
            case .economic: return economic
            case .intelligence: return intelligence
            case .military: return military
            case .nuclear: return nuclear
            }
        }
        set {
            let v = max(0, newValue)
            switch c {
            case .humanitarian: humanitarian = v
            case .economic: economic = v
            case .intelligence: intelligence = v
            case .military: military = v
            case .nuclear: nuclear = v
            }
        }
    }

    var total: Double { humanitarian + economic + intelligence + military + nuclear }
}

// MARK: - Profile

struct CountryProfile: Codable, Hashable {
    /// 1 Restrained · 2 Engaged · 3 Assertive · 4 Forceful · 5 Aggressive · 6 Ruthless
    var ambition: Int
    /// 1 Treacherous · 2 Corrupt · 3 Guarded · 4 Cooperative · 5 Principled · 6 Selfless
    var ethic: Int
    var ideology: LeaderIdeology
    /// Leadership effectiveness 0–100: how likely this government is to make its actions stick.
    var leadership: Double
    /// Quality of life 0–100.
    var qualityOfLife: Double
    /// Social outcry 0–100: protest → riots → insurgency.
    var outcry: Double = 0
    var anxieties = ThreatAnxieties()
    /// Aid this country would like to receive per year, billions of dollars.
    var aidNeed = AidVector()
    /// Strategic value 0–100 (size, position, resources).
    var strategicValue: Double

    static let ambitionNames = ["Restrained", "Engaged", "Assertive", "Forceful", "Aggressive", "Ruthless"]
    static let ethicNames = ["Treacherous", "Corrupt", "Guarded", "Cooperative", "Principled", "Selfless"]

    var ambitionName: String { Self.ambitionNames[max(1, min(6, ambition)) - 1] }
    var ethicName: String { Self.ethicNames[max(1, min(6, ethic)) - 1] }

    /// Stable 0..<1 value from a string (Swift's hashValue is randomized per launch, so roll our own FNV-1a).
    static func stableUnit(_ s: String, salt: UInt64 = 0) -> Double {
        var h: UInt64 = 0xcbf29ce484222325 ^ salt
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return Double(h % 10_000) / 10_000
    }

    /// Derive a plausible profile from GTNW's own country data.
    static func derived(from c: Country) -> CountryProfile {
        let jitter = stableUnit(c.id)
        let jitter2 = stableUnit(c.id, salt: 77)

        // Ambition: aggression 1–100 → 1–6, nudged by regime type.
        var ambition = 1 + Int((Double(min(100, max(1, c.aggressionLevel))) / 100.0) * 5.0 + jitter * 0.8)
        switch c.government {
        case .authoritarian, .military: ambition += 1
        case .monarchy: ambition -= 1
        default: break
        }
        ambition = min(6, max(1, ambition))

        // Ethic: open governments start cooperative; closed ones guarded or worse; aggression erodes it.
        var ethic: Int
        switch c.government {
        case .democracy, .republic: ethic = 4 + (jitter2 > 0.6 ? 1 : 0)
        case .monarchy: ethic = 4
        case .communist, .theocracy: ethic = 3
        case .authoritarian: ethic = 2 + (jitter2 > 0.5 ? 1 : 0)
        case .military: ethic = 2
        }
        if c.aggressionLevel > 75 { ethic -= 1 }
        ethic = min(6, max(1, ethic))

        let ideology = ideologyFor(c, jitter: jitter)
        let perCapita = c.population > 0 ? (c.gdp * 1000) / Double(c.population) : 0       // $ thousands per person
        let wealth = min(100, max(0, log10(max(perCapita, 0.3)) * 35 + 20))                   // ~0.3k→2, 60k→82
        let qol = min(100, max(3, wealth * 0.6 + Double(c.stability) * 0.25 + Double(c.economicStrength) * 0.15))
        let leadership = min(100, max(5, Double(c.stability) * 0.6 + Double(c.publicApproval) * 0.25 + jitter * 15))
        let strategic = min(100, max(2, Double(c.militaryStrength) * 0.4 + Double(c.economicStrength) * 0.35
                                     + min(25, Double(c.population) / 40) + (c.nuclearWarheads > 0 ? 10 : 0)))

        var need = AidVector()
        let poverty = max(0, 70 - qol) / 70                       // 0 for rich countries, ~1 for the poorest
        let pop = Double(max(1, c.population))
        need.humanitarian = (poverty * poverty * min(pop, 300) / 10).rounded(toPlaces: 1)
        need.economic = (poverty * min(pop, 300) / 25).rounded(toPlaces: 1)
        need.intelligence = (Double(max(0, 60 - c.stability)) / 60 * 1.5).rounded(toPlaces: 1)
        need.military = ((c.atWarWith.isEmpty ? 0.3 : 3.0) * (c.militaryStrength < 50 ? 1.5 : 0.6)).rounded(toPlaces: 1)
        need.nuclear = (c.nuclearStatus == .developing ? 2.0 : 0).rounded(toPlaces: 1)

        return CountryProfile(ambition: ambition, ethic: ethic, ideology: ideology, leadership: leadership,
                              qualityOfLife: qol, outcry: max(0, 40 - Double(c.stability)) / 2,
                              anxieties: ThreatAnxieties(), aidNeed: need, strategicValue: strategic)
    }

    static func ideologyFor(_ c: Country, jitter: Double) -> LeaderIdeology {
        switch c.government {
        case .communist: return .communism
        case .theocracy: return c.region == .middleEast ? .islamicRepublic : .theocracy
        case .military: return .militaryJunta
        case .monarchy:
            return c.region == .middleEast ? .absoluteMonarchy : .constitutionalMonarchy
        case .authoritarian:
            if c.aggressionLevel > 70 { return .expansionism }
            return jitter > 0.5 ? .nationalism : .oneParty
        case .democracy, .republic:
            if c.economicStrength < 45 { return .developingDemocracy }
            if c.region == .europe && jitter > 0.45 { return .socialDemocracy }
            if c.stability < 45 { return .populism }
            return .liberalDemocracy
        }
    }
}

extension Double {
    func rounded(toPlaces p: Int) -> Double {
        let m = pow(10.0, Double(p))
        return (self * m).rounded() / m
    }
}

// MARK: - Country accessor

extension Country {
    /// The leader profile, derived on first use for countries (or saves) that don't carry one yet.
    var profile: CountryProfile {
        get { leaderProfile ?? CountryProfile.derived(from: self) }
        set { leaderProfile = newValue }
    }
}

// MARK: - Anxiety model

enum AnxietyModel {
    /// The level each anxiety is drifting toward, from the current world.
    static func targets(for c: Country, in gs: GameState) -> ThreatAnxieties {
        var t = ThreatAnxieties()
        let hostile = gs.countries.filter { !$0.isDestroyed && $0.id != c.id && (c.diplomaticRelations[$0.id] ?? 0) < -30 }

        // Nuclear: hostile nuclear arsenals, alert level, strikes anywhere.
        let hostileNukes = hostile.reduce(0) { $0 + $1.nuclearWarheads }
        let defconFear = Double(5 - gs.defconLevel.rawValue) * 12
        let strikeFear = gs.nuclearStrikes.contains { $0.target == c.id } ? 60 : Double(min(gs.nuclearStrikes.count, 5)) * 6
        t.nuclear = min(100, log10(Double(hostileNukes) + 1) * 14 + defconFear + strikeFear)

        // Military: open wars, hostile neighbours' strength versus our own, war room fronts.
        let warFear = Double(c.atWarWith.count) * 25
        let hostileStrength = hostile.map { Double($0.militaryStrength) }.max() ?? 0
        let imbalance = max(0, hostileStrength - Double(c.militaryStrength)) * 0.6
        let fronts = gs.shadow.fronts.filter { $0.defender == c.id || $0.attacker == c.id }
        let losing = fronts.contains { $0.defender == c.id && $0.attackerMomentum > 0.3 } ? 20.0 : 0
        t.military = min(100, warFear + imbalance + losing + Double(hostile.count) * 1.5)

        // Political: shaky government, unrest, foreign meddling (spy networks aimed at us), sanctions.
        let meddling = gs.countries.reduce(0) { $0 + ($1.spyNetworks[c.id] ?? 0) } / 10
        t.political = min(100, Double(100 - c.stability) * 0.7 + c.profile.outcry * 0.3 + Double(meddling))

        // Economic: weak economy, sanctions, debt.
        t.economic = min(100, Double(100 - c.economicStrength) * 0.55 + Double(c.economicSanctions.count) * 8
                         + Double(max(0, c.debtLevel - 60)) * 0.3)

        // Social: quality of life, refugees, radiation, outcry.
        t.social = min(100, (100 - c.profile.qualityOfLife) * 0.55 + c.profile.outcry * 0.35
                       + Double(c.radiationLevel) * 0.5 + (c.refugeeCount > 0 ? 10 : 0))
        return t
    }

    /// Move anxieties toward their targets. Half of the gap closes every ~3 game months, regardless of turn length.
    static func step(_ current: ThreatAnxieties, toward target: ThreatAnxieties, scale: TurnScale) -> ThreatAnxieties {
        let keep = pow(0.5, scale.yearFraction / 0.25)
        var out = current
        for k in ThreatAnxieties.Kind.allCases {
            out[k] = current[k] * keep + target[k] * (1 - keep)
        }
        return out
    }

    /// A spike is a big jump within one turn, or crossing into panic.
    static func spike(from old: ThreatAnxieties, to new: ThreatAnxieties) -> ThreatAnxieties.Kind? {
        for k in ThreatAnxieties.Kind.allCases {
            if new[k] - old[k] >= 20 || (old[k] < 85 && new[k] >= 85) { return k }
        }
        return nil
    }
}

// MARK: - Nation characters (3.27.0)

/// A nation's character as data: multipliers on the built-in AI's choices plus the temperament a model brain is told.
/// After Quake 3's bot characters (chars.h, BotLoadCachedCharacter): one bundled table, a default block, overrides
/// and per-skill blocks, read by both the built-in AI and the LLM prompt. GTNW's own data and code.
struct NationCharacter: Codable, Equatable, Sendable {
    /// Weight on hostile moves (attack, threaten, covert action, rebels, condemn).
    var aggression = 1.0
    /// Weight on nuclear moves (build-up, threats, launching in a war).
    var risk = 1.0
    /// How strongly anxieties drive the choice.
    var reaction = 1.0
    /// Multiplier on diplomatic chatter (see `SafeDiplomacyService.chatGate`).
    var chatRate = 1.0
    /// Turns a nation stays quiet after it has spoken.
    var chatCooldownTurns = 3
    /// A model brain thinks every N turns (staggered by nation); the built-in AI plays the turns between.
    var thinkEveryTurns = 1
    var temperament = "pragmatic"

    /// One line for a model brain's brief.
    func brief(_ p: CountryProfile) -> String {
        "Character: \(p.ambitionName), \(p.ethicName), \(p.ideology.rawValue); temperament \(temperament)"
            + String(format: "; aggression x%.2f, nuclear risk x%.2f, reaction x%.2f.", aggression, risk, reaction)
    }
}

/// The bundled `nation_characters.json`. Every field of every block is optional; values are clamped, so a bad file
/// can't make a nation absurd, and a missing or unreadable file means every nation plays the default.
struct NationCharacterTable: Codable, Sendable {
    struct Block: Codable, Sendable {
        var aggression, risk, reaction, chatRate: Double?
        var chatCooldownTurns, thinkEveryTurns: Int?
        var temperament: String?
    }
    var version = 1
    var `default` = Block()
    var ideology: [String: Block] = [:]
    var countries: [String: Block] = [:]
    var difficulty: [String: Block] = [:]

    init() {}

    /// Every top-level section is optional too.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.default = try c.decodeIfPresent(Block.self, forKey: .default) ?? Block()
        ideology = try c.decodeIfPresent([String: Block].self, forKey: .ideology) ?? [:]
        countries = try c.decodeIfPresent([String: Block].self, forKey: .countries) ?? [:]
        difficulty = try c.decodeIfPresent([String: Block].self, forKey: .difficulty) ?? [:]
    }

    static let shared = load()

    static func load(_ data: Data? = Bundle.main.url(forResource: "nation_characters", withExtension: "json")
                        .flatMap { try? Data(contentsOf: $0) }) -> NationCharacterTable {
        data.flatMap { try? JSONDecoder().decode(NationCharacterTable.self, from: $0) } ?? NationCharacterTable()
    }

    /// default, then the ideology's block, then the country's; the difficulty block multiplies the weights.
    func character(for c: Country, difficulty: DifficultyLevel? = nil) -> NationCharacter {
        var ch = NationCharacter()
        for b in [self.default, ideology[c.profile.ideology.rawValue], countries[c.id]].compactMap({ $0 }) {
            ch.aggression = b.aggression ?? ch.aggression
            ch.risk = b.risk ?? ch.risk
            ch.reaction = b.reaction ?? ch.reaction
            ch.chatRate = b.chatRate ?? ch.chatRate
            ch.chatCooldownTurns = b.chatCooldownTurns ?? ch.chatCooldownTurns
            ch.thinkEveryTurns = b.thinkEveryTurns ?? ch.thinkEveryTurns
            ch.temperament = b.temperament ?? ch.temperament
        }
        if let d = difficulty.flatMap({ self.difficulty[$0.rawValue] }) {
            ch.aggression *= d.aggression ?? 1
            ch.risk *= d.risk ?? 1
            ch.reaction *= d.reaction ?? 1
            ch.chatRate *= d.chatRate ?? 1
            ch.chatCooldownTurns = d.chatCooldownTurns ?? ch.chatCooldownTurns
            ch.thinkEveryTurns = d.thinkEveryTurns ?? ch.thinkEveryTurns
        }
        func clamp(_ v: Double) -> Double { v.isFinite ? min(3, max(0.25, v)) : 1 }
        ch.aggression = clamp(ch.aggression); ch.risk = clamp(ch.risk); ch.reaction = clamp(ch.reaction)
        ch.chatRate = ch.chatRate.isFinite ? min(3, max(0, ch.chatRate)) : 1
        ch.chatCooldownTurns = min(50, max(0, ch.chatCooldownTurns))
        ch.thinkEveryTurns = min(52, max(1, ch.thinkEveryTurns))
        ch.temperament = String(ch.temperament.filter { $0.isLetter || $0.isNumber || " ,.-'".contains($0) }.prefix(80))
        return ch
    }
}

// MARK: - Personality-driven AI

/// What a computer-run government decides to do with its turn.
enum WorldMove: Equatable {
    case wait
    case improveRelations(String)
    case condemn(String)
    case tradeTies(String)
    case armsBuildup
    case nuclearBuildup
    case seekAlliance(String)
    case covertAction(String)
    case supportRebels(String)
    case threaten(String)
    case attack(String)
    case internalReform
}

enum PersonalityAI {
    /// Weighted choice of a move. `roll` in 0..<1 makes it deterministic for tests.
    static func choose(for c: Country, in gs: GameState, roll: Double = Double.random(in: 0..<1)) -> WorldMove {
        let p = c.profile
        // 3.27.0: the nation's character (data) scales hostility, nuclear risk and how hard anxieties bite.
        let ch = NationCharacterTable.shared.character(for: c, difficulty: gs.difficultyLevel)
        var a = p.anxieties
        for k in ThreatAnxieties.Kind.allCases { a[k] = a[k] * ch.reaction }
        let ambition = Double(p.ambition)          // 1…6
        let ethic = Double(p.ethic)                // 1…6
        let difficulty = gs.difficultyLevel.aiAggressionMultiplier

        let others = gs.countries.filter { !$0.isDestroyed && $0.id != c.id }
        let rival = others.min { (c.diplomaticRelations[$0.id] ?? 0) < (c.diplomaticRelations[$1.id] ?? 0) }
        let friend = others.filter { !c.alliances.contains($0.id) }
            .max { (c.diplomaticRelations[$0.id] ?? 0) < (c.diplomaticRelations[$1.id] ?? 0) }
        let neutral = others.filter { abs(c.diplomaticRelations[$0.id] ?? 0) < 40 }
            .min { CountryProfile.stableUnit($0.id + c.id) < CountryProfile.stableUnit($1.id + c.id) }
        // 3.14.0: harder AIs pick fights sooner and against closer matches (Nightmare: relations < −20, up to 1.2×).
        let hostile = -40 + (difficulty - 1) * 20
        let weakEnemy = others.filter { Double(c.diplomaticRelations[$0.id] ?? 0) < hostile && !c.alliances.contains($0.id) && !$0.isTerritory
                                         && Double($0.militaryStrength) < Double(c.militaryStrength) * (0.8 + 0.2 * difficulty) }
            .min { $0.militaryStrength < $1.militaryStrength }

        var options: [(WorldMove, Double)] = [(.wait, 6 / max(0.5, difficulty))]
        if let n = neutral { options.append((.improveRelations(n.id), 2 + ethic * 0.8)) }
        if let n = neutral { options.append((.tradeTies(n.id), 1 + a.economic / 20 + ethic * 0.3)) }
        options.append((.internalReform, a.social / 18 + (ethic >= 4 ? 1 : 0)))
        options.append((.armsBuildup, 0.5 + a.military / 15 + ambition * 0.4))
        if c.nuclearWarheads > 0 || c.nuclearStatus == .developing, gs.currentYear >= 1945 {
            options.append((.nuclearBuildup, (a.nuclear / 25 + max(0, ambition - 3) * 0.5) * ch.risk))
        }
        if let f = friend, (c.diplomaticRelations[f.id] ?? 0) > 50 {
            options.append((.seekAlliance(f.id), 0.5 + a.military / 25 + a.nuclear / 30))
        }
        if let r = rival, (c.diplomaticRelations[r.id] ?? 0) < -20 {
            options.append((.condemn(r.id), (1 + ambition * 0.4) * ch.aggression))
            options.append((.covertAction(r.id), (max(0, 7 - ethic) * 0.35 * difficulty + a.political / 40) * ch.aggression))
            options.append((.supportRebels(r.id), max(0, 6 - ethic) * 0.25 * difficulty * ch.aggression))
            if c.nuclearWarheads > 0 {
                options.append((.threaten(r.id), (max(0, ambition - 3) * 0.4 * difficulty + a.nuclear / 50) * ch.aggression * ch.risk))
            }
        }
        if let w = weakEnemy, c.atWarWith.isEmpty {
            // War is the rare, ambition-driven option: ~0 for restrained leaders, real for ruthless ones.
            // 3.14.0: a floor of 0.4 so cautious monarchies still go to war sometimes.
            options.append((.attack(w.id), (pow(max(0, ambition - 2), 1.6) * 0.35 + 0.4) * difficulty * ch.aggression))
        }

        let total = options.reduce(0) { $0 + max(0, $1.1) }
        guard total > 0 else { return .wait }
        var r = min(max(roll, 0), 0.999_999) * total
        for (move, w) in options {
            r -= max(0, w)
            if r < 0 { return move }
        }
        return .wait
    }
}
