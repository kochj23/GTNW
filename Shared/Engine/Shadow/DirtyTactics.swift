//
//  DirtyTactics.swift
//  Global Thermal Nuclear War
//
//  Dirty tactics (3.17.0). The President can fight dirty, and the game judges him for it — but only if he is caught.
//  Every tactic carries four things:
//    • a real era window: what existed when, with a research programme able to pull something earlier only where the
//      era's technology plausibly allowed it (crude war gas needs industrial chemistry, so no 1790s programme);
//    • a legal status by era that tightens with the real treaties (Paris Declaration 1856, Lieber Code 1863,
//      Hague 1899/1907, Geneva Protocol 1925, Geneva Conventions 1949, BWC 1975, CCW 1980, CWC 1997, Ottawa 1997,
//      Rome Statute 2002), reusing `LegalStatus` and the treaty costs of the weapons catalog (3.6.0);
//    • an open or covert choice. A covert use carries a discovery chance per use that rises with the scale ordered,
//      with the era (a mass press, aerial reconnaissance, satellites, modern intelligence) and with the number of
//      people in on it. Ruthlessness, a Hall of Infamy entry, Congress and impeachment pressure, world opinion and
//      war-crimes tribunal risk land mainly on discovery; a covert use always costs a little, because the people who
//      carried it out know;
//    • a real benefit, so the choice is tempting.
//  Discovery follows the pattern the secret chemical / biological restarts already use (`processWMDPrograms`).
//  Encyclopedia level only: names, dates, treaties, and effects on game stats.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// Which part of the catalog a tactic belongs to.
enum TacticGroup: String, Codable, CaseIterable, Identifiable {
    case chemical, incendiary, starvation, civilians, deception, sea
    var id: String { rawValue }

    var title: String {
        switch self {
        case .chemical: return "Chemical and biological"
        case .incendiary: return "Incendiary"
        case .starvation: return "Starvation and supply"
        case .civilians: return "Civilians and land"
        case .deception: return "Deception"
        case .sea: return "Sea and other"
        }
    }
}

/// What has to be picked before a tactic can be ordered.
enum TacticTarget: String, Codable {
    /// Nothing (a policy at home).
    case none
    /// An independent nation.
    case nation
    /// One of the player's own territories.
    case territory
    /// A resisting people's land on the map.
    case indigenous
}

/// One dirty tactic.
struct DirtyTactic: Identifiable, Hashable {
    /// Legal status over a period, with the treaty that set it.
    struct Period: Hashable {
        let from: Int
        let to: Int?
        let status: LegalStatus
        let note: String
    }

    let id: String
    let group: TacticGroup
    let name: String
    /// First year the tactic is physically possible, and the last (nil = still).
    let from: Int
    let to: Int?
    let periods: [Period]
    /// What it does in the game, and the historical precedent behind it.
    let blurb: String
    let target: TacticTarget
    /// Can it be hidden at all? Burning a city in front of the newspapers cannot be.
    let canBeCovert: Bool
    /// Roughly how many people have to be in on it (hundreds). Secrets keep badly as this grows.
    let people: Int
    /// A stance stays in force until it is lifted, instead of being ordered once.
    let isStance: Bool

    init(id: String, group: TacticGroup, name: String, from: Int, to: Int? = nil, periods: [Period], blurb: String,
         target: TacticTarget = .nation, canBeCovert: Bool = false, people: Int = 1, isStance: Bool = false) {
        self.id = id; self.group = group; self.name = name; self.from = from; self.to = to; self.periods = periods
        self.blurb = blurb; self.target = target; self.canBeCovert = canBeCovert; self.people = people; self.isStance = isStance
    }

    func exists(in year: Int) -> Bool { year >= from && year <= (to ?? Int.max) }
    /// Status in a year: the latest period that has begun (periods are chronological).
    func status(in year: Int) -> LegalStatus { periods.last { $0.from <= year }?.status ?? .legal }
    func note(in year: Int) -> String? { periods.last { $0.from <= year }?.note }
}

/// One use of a tactic, or a stance put in force.
struct TacticUse: Codable, Hashable, Identifiable {
    var id = UUID()
    var tactic: String
    var target: String?
    var date: Date
    var covert: Bool
    /// The Probe / Standard / Overwhelming multiplier: more gain, more chance of being found out.
    var scale: Double = 1
    var discovered = false
}

/// A research programme that delivers a tactic its era doesn't have off the shelf.
struct TacticProgram: Codable, Hashable {
    var tactic: String
    var started: Date
    var ready: Date
    /// Billions already paid in.
    var spent: Double = 0
    var discovered = false
}

/// A cost that lands later: defoliant illnesses, mines left in the ground, redress for internment, a procurement
/// scandal. Applied by `processDirtyTactics` on its date, and once a year until `until` when it lingers.
struct TacticAftermath: Codable, Hashable, Identifiable {
    var id = UUID()
    var tactic: String
    var due: Date
    var text: String
    var ruthlessness: Double = 0
    var popularity: Double = 0
    /// Relations with every other nation.
    var world: Int = 0
    /// Billions out of the President's funds.
    var cash: Double = 0
    var opensImpeachment = false
    /// A lingering cost repeats every year until this date; nil = once only.
    var until: Date?
}

enum DirtyTactics {

    // MARK: Catalog

    /// Every tactic in the game. Groups are added one release at a time (3.17.0 … 3.17.5).
    static let all: [DirtyTactic] = chemical + incendiary + starvation

    static func tactic(_ id: String) -> DirtyTactic? { all.first { $0.id == id } }

    /// The tactics an era has, newest first within a group.
    static func available(in year: Int, group: TacticGroup? = nil) -> [DirtyTactic] {
        all.filter { $0.exists(in: year) && (group == nil || $0.group == group) }
    }

    // MARK: Secrecy

    /// How badly a secret keeps, by era. DESIGN CHOICES, not published figures: a sleepy partisan press before the
    /// telegraph; a mass press and wire services from 1850; aerial reconnaissance and war correspondents from 1915;
    /// reconnaissance satellites from 1960 (Corona, Aug 1960); modern intelligence, leaks and the internet from 1990.
    static func eraExposure(year: Int) -> Double {
        switch year {
        case ..<1850: return 0.5
        case ..<1915: return 0.8
        case ..<1960: return 1.1
        case ..<1990: return 1.4
        default: return 1.8
        }
    }

    /// How badly a secret keeps as more people are in on it: the square root of the hundreds involved.
    static func crowdFactor(people: Int) -> Double { max(1, Double(max(1, people)).squareRoot()) }

    /// Chance one covert use is discovered. DESIGN CHOICE: a 6% base, times the era, the crowd and the scale ordered,
    /// capped at 90% — nothing is ever certainly safe and nothing is ever certainly caught.
    static let discoveryBase = 0.06

    static func discoveryChance(_ t: DirtyTactic, year: Int, scale: Double = 1) -> Double {
        min(0.9, discoveryBase * eraExposure(year: year) * crowdFactor(people: t.people) * max(0.5, scale) * exposureBonus(t, year: year))
    }


    // MARK: Stances

    /// A stance stays in force until it is lifted. Its key is the tactic, and the nation it is aimed at if any.
    static func stanceKey(_ id: String, target: String?) -> String {
        (target?.isEmpty == false) ? "\(id):\(target!)" : id
    }

    static func splitStance(_ key: String) -> (String, String?) {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        return (parts[0], parts.count > 1 ? parts[1] : nil)
    }

    /// The share of a stance's full price it pays every year it stays in force. DESIGN CHOICE.
    static let stanceYearlyShare = 0.35

    /// Extra exposure a particular tactic carries from a date. DESIGN CHOICE: federal food inspection after the
    /// Pure Food and Drug Act and the Meat Inspection Act (both 30 June 1906) makes a ration-contract scandal far
    /// likelier to come out.
    static func exposureBonus(_ t: DirtyTactic, year: Int) -> Double {
        t.id == "profiteer_contracts" && year >= 1906 ? 2.5 : 1
    }

    /// Chance a secret programme leaks in a year before it is ready, on the same terms as the 3.6.0 restarts.
    static func programLeakAnnual(_ t: DirtyTactic, year: Int) -> Double {
        min(0.6, 0.12 * eraExposure(year: year) * crowdFactor(people: t.people))
    }

    /// Chance a discovered, treaty-banned tactic brings the President before a war-crimes tribunal: nothing before
    /// Nuremberg and Tokyo (1945–48), more once the ad-hoc tribunals sit (Yugoslavia 1993, Rwanda 1994), more again
    /// under the Rome Statute (2002). A sitting President is not in the dock, but the hearings are ruinous.
    static func tribunalChance(year: Int, status: LegalStatus) -> Double {
        guard status == .treatyBanned else { return 0 }
        switch year {
        case ..<1945: return 0
        case ..<1993: return 0.10
        case ..<2002: return 0.20
        default: return 0.35
        }
    }

    // MARK: What it costs

    /// The full price of a tactic of this status, reusing the weapons catalog's treaty costs (3.6.0).
    static func cost(_ t: DirtyTactic, year: Int) -> ArsenalCatalog.Cost { ArsenalCatalog.cost(t.status(in: year)) }

    /// The share of the price a covert use pays even when nobody finds out, because the men who did it know:
    /// ruthlessness only, and only a fifth of it. DESIGN CHOICE.
    static let quietShare = 0.2

    /// A covert use that comes out costs more than doing it openly: the cover-up is its own scandal. DESIGN CHOICE.
    static let coverUpFactor = 1.25
}

// MARK: - The chemical and biological group (3.17.0)

extension DirtyTactics {
    /// Shorthand for a legal period.
    private static func p(_ from: Int, _ status: LegalStatus, _ note: String) -> DirtyTactic.Period {
        DirtyTactic.Period(from: from, to: nil, status: status, note: note)
    }

    /// Treaty notes used across the catalog.
    static let lieberNote = "Restricted: the Lieber Code (General Orders No. 100, 1863) binds U.S. forces."
    static let hague1899Note = "Restricted: Hague Declaration IV,2 (1899) and Hague IV Art. 23 (1907)."
    static let genevaProtocolSignedNote = "Restricted: the Geneva Protocol of 1925, which the United States signed but did not ratify until 1975."
    static let genevaProtocolNote = "Banned: the Geneva Protocol of 1925 (in force 1928)."
    static let geneva1949Note = "Banned: the Geneva Conventions of 1949."
    static let bwcNote = "Banned: the Biological Weapons Convention (in force 1975)."
    static let cwcNote = "Banned: the Chemical Weapons Convention (in force 1997)."
    static let romeNote = "A war crime under the Rome Statute (in force 2002)."

    /// Chemical and biological tactics below the weapons catalog's declared stockpiles.
    static let chemical: [DirtyTactic] = [
        DirtyTactic(
            id: "chem_program", group: .chemical, name: "Crude war-gas programme",
            from: 1880,
            periods: [p(1880, .legal, "No treaty yet covers gas as a weapon."),
                      p(1899, .restricted, hague1899Note),
                      p(1928, .treatyBanned, genevaProtocolNote),
                      p(1997, .treatyBanned, cwcNote)],
            blurb: "Four years and $12B of industrial chemistry to put chlorine and phosgene into shells before the "
                 + "Army has them. Germany's first chlorine attack was at Ypres on 22 April 1915; the chemistry and "
                 + "the plant behind it did not exist earlier.",
            target: .none, canBeCovert: true, people: 40),
        DirtyTactic(
            id: "contaminated_goods", group: .chemical, name: "Contaminated goods",
            from: 1789,
            periods: [p(1789, .legal, "No rule of war yet forbids it."),
                      p(1863, .restricted, "Restricted: the Lieber Code (1863) Art. 70 excludes poison in any manner."),
                      p(1899, .treatyBanned, hague1899Note),
                      p(1949, .treatyBanned, geneva1949Note)],
            blurb: "Blankets and stores from a smallpox ward, passed to a people you are fighting. At Fort Pitt in "
                 + "June 1763 British officers gave Delaware emissaries blankets from the fort's smallpox hospital. "
                 + "It works badly and at random, and the disease does not respect your own camps.",
            target: .indigenous, canBeCovert: true, people: 1),
        DirtyTactic(
            id: "gas_resistance", group: .chemical, name: "Gas against a resisting people",
            from: 1920,
            periods: [p(1920, .restricted, genevaProtocolSignedNote),
                      p(1928, .treatyBanned, genevaProtocolNote),
                      p(1997, .treatyBanned, cwcNote)],
            blurb: "Gas shells and bombs against people with no masks and nowhere to go. Spain used chemical bombs in "
                 + "the Rif between 1921 and 1927; Italy used mustard gas in Ethiopia in 1935–36 while a party to the "
                 + "1925 Protocol. Resistance collapses; the world notices sooner or later.",
            target: .indigenous, canBeCovert: true, people: 20),
        DirtyTactic(
            id: "human_subject_program", group: .chemical, name: "Human-subject biological programme",
            from: 1932,
            periods: [p(1932, .restricted, genevaProtocolSignedNote),
                      p(1949, .treatyBanned, geneva1949Note),
                      p(1975, .treatyBanned, bwcNote),
                      p(2002, .treatyBanned, romeNote)],
            blurb: "A weapons programme that tests on prisoners. Japan's Unit 731 ran at Pingfang from 1932 to 1945 "
                 + "under Ishii Shiro. It delivers a biological arsenal in three years instead of the usual wait, and "
                 + "if it is ever found out there is no political survival from it.",
            target: .none, canBeCovert: true, people: 30),
        DirtyTactic(
            id: "defoliants", group: .chemical, name: "Defoliants",
            from: 1961,
            periods: [p(1961, .legal, "No treaty covers herbicides as a weapon."),
                      p(1975, .restricted, "Restricted: Executive Order 11850 (1975) renounces first use of herbicides in war."),
                      p(1997, .treatyBanned, cwcNote)],
            blurb: "Spray the cover off the country. Operation Ranch Hand flew from January 1962 to January 1971 and "
                 + "put some 20 million gallons of herbicide, Agent Orange among them, over South Vietnam. The enemy "
                 + "loses his cover and his harvest; the dioxin bill arrives twenty years later.",
            target: .nation, canBeCovert: false, people: 10),
    ]
}

// MARK: - The incendiary group (3.17.1)

extension DirtyTactics {
    static let ccwNote = "Restricted: CCW Protocol III on incendiary weapons (in force 1983; the United States ratified it in 2009 with a reservation)."
    static let hague1907DestructionNote = "Restricted: Hague IV Art. 23(g) and Art. 25 (1907) — no destruction beyond the necessity of war, no attack on undefended towns."
    static let geneva1949DestructionNote = "Banned: Geneva Convention IV Art. 53 (1949) — wanton destruction of property."

    /// Fire as a weapon, era by era. Byzantine Greek fire — first used in the defence of Constantinople in 672 and
    /// credited to Kallinikos of Heliopolis — is older than this game and its recipe was lost; the nineteenth-century
    /// "Greek fire" shells below only borrowed the name.
    static let incendiary: [DirtyTactic] = [
        DirtyTactic(
            id: "hot_shot", group: .incendiary, name: "Heated shot",
            from: 1789, to: 1865,
            periods: [p(1789, .legal, "No rule of war covers it; it is ordinary gunnery.")],
            blurb: "Round shot heated in a furnace until it glows, fired into wooden hulls and waterfronts. It broke "
                 + "the floating batteries at Gibraltar in 1782 and stayed in coastal forts until iron hulls and "
                 + "explosive shell made it pointless.",
            target: .nation, canBeCovert: false, people: 1),
        DirtyTactic(
            id: "congreve_rockets", group: .incendiary, name: "Congreve rockets",
            from: 1805, to: 1870,
            periods: [p(1805, .legal, "No rule of war covers it."),
                      p(1863, .restricted, lieberNote)],
            blurb: "William Congreve's rockets, in service from 1805: Boulogne 1806, Copenhagen 1807, Fort McHenry "
                 + "in September 1814 — the rockets' red glare — and a U.S. rocket battery at Veracruz in 1847. They "
                 + "cannot be aimed, which is rather the point: they set fire to whatever is behind the enemy.",
            target: .nation, canBeCovert: false, people: 2),
        DirtyTactic(
            id: "incendiary_shells", group: .incendiary, name: "Incendiary shells and arson",
            from: 1861, to: 1945,
            periods: [p(1861, .legal, "No rule of war covers it yet."),
                      p(1863, .restricted, lieberNote),
                      p(1899, .restricted, hague1907DestructionNote),
                      p(1949, .treatyBanned, geneva1949DestructionNote)],
            blurb: "Shells of burning compound fired into a city, or agents with the same stuff in carpet bags. The "
                 + "Union fired \"Greek fire\" shells into Charleston from the Marsh Battery in August 1863; "
                 + "Confederate agents tried to burn the New York hotels on 25 November 1864 and were hanged for it. "
                 + "Byzantine Greek fire, first used in 672, was something else entirely, and its recipe was lost.",
            target: .nation, canBeCovert: true, people: 1),
        DirtyTactic(
            id: "burn_towns", group: .incendiary, name: "Burn the towns",
            from: 1789,
            periods: [p(1789, .legal, "No rule of war covers it."),
                      p(1863, .restricted, lieberNote),
                      p(1907, .restricted, hague1907DestructionNote),
                      p(1949, .treatyBanned, geneva1949DestructionNote),
                      p(2002, .treatyBanned, romeNote)],
            blurb: "Put the countryside and its towns to the torch so the enemy cannot live in them. The British "
                 + "burned Washington on 24 August 1814; Sherman burned Atlanta in November 1864 and Columbia in "
                 + "February 1865; Sheridan burned the Shenandoah Valley through September and October 1864. An army "
                 + "cannot do this quietly.",
            target: .nation, canBeCovert: false, people: 40),
        DirtyTactic(
            id: "flamethrowers", group: .incendiary, name: "Flamethrowers",
            from: 1915,
            periods: [p(1915, .legal, "No treaty covers it; the law of war applies as usual."),
                      p(1983, .restricted, ccwNote)],
            blurb: "Burn the defenders out of what they are holding. German Flammenwerfer troops were first used at "
                 + "Hooge on 30 July 1915; U.S. M1A1 and M2 flamethrowers cleared caves and bunkers across the "
                 + "Pacific from 1943. It takes positions that artillery cannot.",
            target: .nation, canBeCovert: false, people: 5),
        DirtyTactic(
            id: "napalm_wp", group: .incendiary, name: "Napalm and white phosphorus",
            from: 1942,
            periods: [p(1942, .legal, "No treaty covers incendiaries."),
                      p(1983, .restricted, ccwNote),
                      p(2002, .treatyBanned, romeNote)],
            blurb: "Thickened petrol that sticks and burns, and phosphorus that cannot be put out. Napalm came out "
                 + "of Louis Fieser's work at Harvard in 1942–43 and went into combat in 1944; white phosphorus had "
                 + "been in service since the First World War. Against a city it is the most destructive thing short "
                 + "of a warhead.",
            target: .nation, canBeCovert: false, people: 10),
    ]
}

// MARK: - The starvation and supply group (3.17.2)

extension DirtyTactics {
    static let apiStarvationNote = "Restricted: Additional Protocol I Art. 54 (1977) forbids starvation of civilians as a method of warfare."
    static let geneva1949OccupierNote = "Banned: Geneva Convention IV Art. 55 (1949) — an occupier must ensure the food supply of the population."
    static let parisNote = "Blockades must be effective and declared (Declaration of Paris, 1856)."

    static let starvation: [DirtyTactic] = [
        DirtyTactic(
            id: "scorched_earth", group: .starvation, name: "Scorched earth",
            from: 1789,
            periods: [p(1789, .legal, "No rule of war covers it."),
                      p(1863, .restricted, lieberNote),
                      p(1907, .restricted, hague1907DestructionNote),
                      p(1949, .treatyBanned, geneva1949DestructionNote),
                      p(1977, .treatyBanned, apiStarvationNote),
                      p(2002, .treatyBanned, romeNote)],
            blurb: "Take or destroy the mills, barns, stock and standing crops so the enemy army cannot feed itself "
                 + "off the land. Russia did it ahead of Napoleon in 1812; Sheridan did it in the Shenandoah in "
                 + "1864; the British burned Boer farms from 1900. The enemy's supply and will go first; his "
                 + "civilians go with them.",
            target: .nation, canBeCovert: false, people: 30),
        DirtyTactic(
            id: "starve_blockade", group: .starvation, name: "Starvation blockade",
            from: 1789,
            periods: [p(1789, .legal, parisNote),
                      p(1856, .legal, parisNote),
                      p(1949, .restricted, "Restricted: Geneva Convention IV (1949) requires free passage of food and medicine for civilians."),
                      p(1977, .treatyBanned, apiStarvationNote),
                      p(2002, .treatyBanned, romeNote)],
            blurb: "A stance on a blockade already in place: stop food and fertiliser too, not only war material. "
                 + "The Union's Anaconda plan squeezed the Confederacy from 1861; the British blockade of Germany "
                 + "ran from 1914 until the Versailles signature in June 1919, and the German Board of Public Health "
                 + "put the deaths from it at 763,000.",
            target: .nation, canBeCovert: false, people: 20, isStance: true),
        DirtyTactic(
            id: "buffalo_slaughter", group: .starvation, name: "Destroy the herds",
            from: 1868, to: 1884,
            periods: [p(1868, .legal, "No law of the United States or of war covers it; a Texas bill to stop it was vetoed in 1875.")],
            blurb: "Pay and protect the hide hunters until the herds a people lives on are gone. The southern bison "
                 + "herd was destroyed between 1872 and 1874 and the northern herd by 1883. Resistance on the plains "
                 + "ends not in battle but in hunger.",
            target: .indigenous, canBeCovert: false, people: 5),
        DirtyTactic(
            id: "requisition_harvest", group: .starvation, name: "Requisition the harvest",
            from: 1789,
            periods: [p(1789, .legal, "No rule of war covers it."),
                      p(1863, .restricted, lieberNote),
                      p(1907, .restricted, "Restricted: Hague IV Art. 52 (1907) — requisitions in proportion to the resources of the country."),
                      p(1949, .treatyBanned, geneva1949OccupierNote),
                      p(2002, .treatyBanned, romeNote)],
            blurb: "Take the grain out of an occupied territory and ship it home. It pays at once and it goes on "
                 + "paying while anyone is left to farm. The hunger it makes is not an accident of the policy; it is "
                 + "the policy.",
            target: .territory, canBeCovert: false, people: 10),
        DirtyTactic(
            id: "profiteer_contracts", group: .starvation, name: "War-profiteering contracts",
            from: 1861,
            periods: [p(1861, .legal, "Fraud on the government is a crime; the contracts themselves are not."),
                      p(1906, .restricted, "Restricted: the Pure Food and Drug Act and the Meat Inspection Act (both 30 June 1906) make it far likelier to come out."),
                      p(1949, .restricted, "Restricted: the Geneva Conventions (1949) oblige a state to feed and care for its own prisoners and wounded.")],
            blurb: "Award the ration contracts to friends on terms that pay you back. The Army's canned and "
                 + "chemically treated beef in 1898 sickened its own men; Nelson A. Miles called it embalmed beef "
                 + "and the Dodge Commission sat on it through the winter of 1898–99. Cash and kickbacks now; sick "
                 + "soldiers soon; a scandal after that.",
            target: .none, canBeCovert: true, people: 2),
    ]
}

// MARK: - Engine

extension GameEngine {
    /// Tactics the President can choose from now (era window only; `tacticProblem` says whether one can be ordered).
    func availableTactics(group: TacticGroup? = nil) -> [DirtyTactic] {
        guard let gs = gameState else { return [] }
        return DirtyTactics.available(in: gs.currentYear, group: group)
    }

    /// Why a tactic can't be ordered now, or nil. The era-window message explains itself, so the President learns
    /// why a 1790s gas programme is impossible rather than finding the button missing.
    func tacticProblem(_ id: String, target: String? = nil) -> String? {
        guard let gs = gameState, let t = DirtyTactics.tactic(id) else { return "Unknown order." }
        guard gs.playerCountryID == "USA" || t.target != .none else { return "Only the United States has this option." }
        if !t.exists(in: gs.currentYear) {
            if gs.currentYear < t.from { return "\(t.name) is not possible in \(gs.currentYear). \(DirtyTactics.eraReason(t, year: gs.currentYear))" }
            return "\(t.name) belongs to an age that has passed."
        }
        if gs.shadow.tacticPrograms[id] != nil { return "\(t.name) is already under way." }
        switch t.target {
        case .none:
            break
        case .nation:
            guard let target, let c = gs.getCountry(id: target), c.id != gs.playerCountryID, !c.isDestroyed, !c.isTerritory else {
                return "Pick a nation."
            }
        case .territory:
            guard let target, gs.getCountry(id: target)?.territoryOf == gs.playerCountryID else { return "Pick one of your territories." }
        case .indigenous:
            guard let target, gs.indigenousLandIDs.contains(target) || gs.getCountry(id: target)?.territoryOf == gs.playerCountryID else {
                return "Pick a resisting people's land, or a territory still fighting you."
            }
        }
        // What a particular tactic needs on top of a target.
        switch id {
        case "starve_blockade":
            guard let target, gs.shadow.fleetDeployments.contains(where: { $0.target == target && $0.mission == .blockade }) else {
                return "Blockade the country first: this is a stance on a blockade, not a blockade of its own."
            }
        default:
            break
        }
        return nil
    }

    /// Order a tactic (one action). `roll` and `discoveryRoll` are injected by tests.
    @discardableResult
    func useTactic(_ id: String, target: String? = nil, covert: Bool = false, preset: AttackPreset = .standard,
                   discoveryRoll: Double = Double.random(in: 0..<1)) -> TacticUse? {
        guard let gs = gameState, gs.actionsRemaining > 0, tacticProblem(id, target: target) == nil,
              let t = DirtyTactics.tactic(id) else { return nil }
        let hidden = covert && t.canBeCovert
        // A research programme starts instead of landing at once.
        if let years = DirtyTactics.programYears(t) {
            let ready = GameCalendar.calendar.date(byAdding: .year, value: years, to: gs.currentDate) ?? gs.currentDate
            gs.shadow.tacticPrograms[id] = TacticProgram(tactic: id, started: gs.currentDate, ready: ready)
            spendFunds(DirtyTactics.programCost(t))
            gs.shadow.post("A \(t.name.lowercased()) is authorised in secret. Expected \(GameCalendar.format(ready)).",
                           date: gs.currentDate, severity: 2)
            logPlayEvent("tactic_program_started", detail: ["tactic": id, "ready": PlayHistory.day(ready),
                                                            "cost_b": PlayHistory.num(DirtyTactics.programCost(t)),
                                                            "game_date": PlayHistory.day(gs.currentDate)])
            self.gameState = gs
            completePlayerAction()
            return TacticUse(tactic: id, target: target, date: gs.currentDate, covert: true, scale: 1)
        }
        var use = TacticUse(tactic: id, target: target, date: gs.currentDate, covert: hidden, scale: preset.multiplier)
        applyTacticBenefit(t, use: use)
        if hidden {
            applyQuietCost(t)
            use.discovered = discoveryRoll < DirtyTactics.discoveryChance(t, year: gs.currentYear, scale: use.scale)
        } else {
            gs.shadow.post(DirtyTactics.headline(t, target: gs.getCountry(id: target ?? "")?.name ?? PreStateModel.landName(target, in: gs)),
                           date: gs.currentDate, severity: 3)
        }
        gs.shadow.tacticUses.append(use)
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(t.name) (\(hidden ? "covert" : "open"), \(t.status(in: gs.currentYear).label.lowercased())).")
        logPlayEvent("tactic_used", detail: ["tactic": id, "target": target ?? "", "covert": hidden,
                                             "scale": PlayHistory.num(use.scale), "legal_status": t.status(in: gs.currentYear).rawValue,
                                             "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        if !hidden { applyTacticCost(t, target: target, coverUp: false) }
        if use.discovered { exposeTactic(use.id) }
        completePlayerAction()
        return use
    }

    /// The small price a covert use pays whatever happens: the men who carried it out know what they did.
    private func applyQuietCost(_ t: DirtyTactic) {
        guard let gs = gameState else { return }
        gs.shadow.ruthlessness += DirtyTactics.cost(t, year: gs.currentYear).ruthlessness * DirtyTactics.quietShare
        self.gameState = gs
    }

    /// The full price: relations, ruthlessness, approval, sanctions and impeachment hearings (the 3.6.0 treaty cost),
    /// plus a war-crimes tribunal in the eras that have one.
    func applyTacticCost(_ t: DirtyTactic, target: String?, coverUp: Bool, tribunalRoll: Double = Double.random(in: 0..<1)) {
        guard let gs = gameState else { return }
        let status = t.status(in: gs.currentYear)
        applyTreatyCost(status, target: target)
        if coverUp, let g = gameState {
            let extra = ArsenalCatalog.cost(status).ruthlessness * (DirtyTactics.coverUpFactor - 1)
            g.shadow.ruthlessness += extra
            g.shadow.popularity = PopularityModel.clamp(g.shadow.popularity - ArsenalCatalog.cost(status).popularity * (DirtyTactics.coverUpFactor - 1))
            self.gameState = g
        }
        guard tribunalRoll < DirtyTactics.tribunalChance(year: gs.currentYear, status: status), let g = gameState else { return }
        g.shadow.ruthlessness += 20
        g.shadow.popularity = PopularityModel.clamp(g.shadow.popularity - 10)
        g.shadow.impeachmentStage = max(g.shadow.impeachmentStage, 2)
        g.shadow.post("An international tribunal opens an inquiry into American conduct. Congress drafts articles of impeachment.",
                      date: g.currentDate, severity: 3)
        logPlayEvent("tactic_tribunal", detail: ["tactic": t.id, "game_date": PlayHistory.day(g.currentDate)])
        self.gameState = g
    }

    /// A covert use comes out: the full price, the cover-up on top, and a line nobody forgets.
    func exposeTactic(_ useID: UUID) {
        guard let gs = gameState, let i = gs.shadow.tacticUses.firstIndex(where: { $0.id == useID }),
              let t = DirtyTactics.tactic(gs.shadow.tacticUses[i].tactic) else { return }
        gs.shadow.tacticUses[i].discovered = true
        let target = gs.shadow.tacticUses[i].target
        gs.shadow.post(DirtyTactics.exposureHeadline(t, target: gs.getCountry(id: target ?? "")?.name ?? PreStateModel.landName(target, in: gs)),
                       date: gs.currentDate, severity: 3)
        logPlayEvent("tactic_exposed", detail: ["tactic": t.id, "target": target ?? "", "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        applyTacticCost(t, target: target, coverUp: true)
    }


    /// Put a stance in force, or lift it. Setting one costs an action; lifting one is free.
    @discardableResult
    func setStance(_ id: String, target: String? = nil, on: Bool) -> Bool {
        guard let gs = gameState, let t = DirtyTactics.tactic(id), t.isStance else { return false }
        let key = DirtyTactics.stanceKey(id, target: target)
        if !on {
            guard gs.shadow.tacticStances.remove(key) != nil else { return false }
            gs.shadow.post("The United States lifts its \(t.name.lowercased()).", date: gs.currentDate, severity: 1)
            logPlayEvent("tactic_stance", detail: ["tactic": id, "target": target ?? "", "on": false,
                                                   "game_date": PlayHistory.day(gs.currentDate)])
            self.gameState = gs
            return true
        }
        guard gs.actionsRemaining > 0, tacticProblem(id, target: target) == nil, !gs.shadow.tacticStances.contains(key) else { return false }
        gs.shadow.tacticStances.insert(key)
        gs.shadow.post(DirtyTactics.headline(t, target: gs.getCountry(id: target ?? "")?.name), date: gs.currentDate, severity: 3)
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(t.name) in force (\(t.status(in: gs.currentYear).label.lowercased())).")
        logPlayEvent("tactic_stance", detail: ["tactic": id, "target": target ?? "", "on": true,
                                               "legal_status": t.status(in: gs.currentYear).rawValue,
                                               "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        applyTacticCost(t, target: target, coverUp: false)
        completePlayerAction()
        return true
    }

    /// Each turn: a stance in force does its work, and goes on costing while it lasts. A stance whose conditions
    /// have gone (the blockade lifted, the war over) lapses by itself.
    func processTacticStances() {
        guard let gs = gameState else { return }
        for key in gs.shadow.tacticStances.sorted() {
            let (id, target) = DirtyTactics.splitStance(key)
            guard let t = DirtyTactics.tactic(id) else { gs.shadow.tacticStances.remove(key); continue }
            if let problem = stanceLapsed(t, target: target) {
                gs.shadow.tacticStances.remove(key)
                gs.shadow.post("The \(t.name.lowercased()) ends: \(problem)", date: gs.currentDate, severity: 1)
                continue
            }
            applyStanceTick(t, target: target)
            // A standing policy is nobody's secret: a share of its price every year it runs.
            let c = DirtyTactics.cost(t, year: gs.currentYear)
            gs.shadow.ruthlessness += c.ruthlessness * DirtyTactics.stanceYearlyShare * gs.turnLength.yearFraction
            let hit = gs.scale.integer(annual: Double(c.world) * DirtyTactics.stanceYearlyShare)
            if hit > 0 {
                for o in gs.countries where o.id != gs.playerCountryID && !o.isTerritory && !o.isDestroyed {
                    modifyDiplomaticRelation(from: o.id, to: gs.playerCountryID, by: -hit)
                }
            }
        }
        self.gameState = gs
    }

    /// Why a stance can no longer stand, or nil.
    private func stanceLapsed(_ t: DirtyTactic, target: String?) -> String? {
        guard let gs = gameState else { return "the game is over" }
        guard let target, let c = gs.getCountry(id: target), !c.isDestroyed else { return nil }
        switch t.id {
        case "starve_blockade":
            let blockading = gs.shadow.fleetDeployments.contains { $0.target == target && $0.mission == .blockade }
            return blockading ? nil : "the blockade of \(c.name) has been lifted"
        default:
            return c.atWarWith.contains(gs.playerCountryID) ? nil : "the war with \(c.name) is over"
        }
    }


    /// What a stance does to the world each turn it stays in force. Game stats only, scaled to the turn length.
    private func applyStanceTick(_ t: DirtyTactic, target: String?) {
        guard let gs = gameState else { return }
        let yf = gs.turnLength.yearFraction
        switch t.id {
        case "starve_blockade":
            // The 1914-19 blockade worked slowly and did not stop at the docks.
            guard let target, let i = gs.countries.firstIndex(where: { $0.id == target }) else { return }
            gs.countries[i].gdp *= 1 - 0.10 * yf
            gs.countries[i].stability = max(0, gs.countries[i].stability - Int((14 * yf).rounded()))
            gs.countries[i].profile.anxieties.social += 20 * yf
            gs.totalCasualties += Int(Double(max(1, gs.countries[i].population)) * 1500 * yf)
            frontBlow(target, will: 0.18 * yf, troops: 0.05 * yf)
        default:
            break
        }
        self.gameState = gs
    }

    /// Each turn: secret programmes come in or leak, and costs that were always coming land.
    func processDirtyTactics() {
        guard let gs = gameState else { return }
        for (id, p) in gs.shadow.tacticPrograms {
            guard let t = DirtyTactics.tactic(id) else { continue }
            if p.ready <= gs.currentDate {
                gs.shadow.tacticPrograms.removeValue(forKey: id)
                finishTacticProgram(t, program: p)
                continue
            }
            guard !p.discovered,
                  Double.random(in: 0..<1) < gs.scale.probability(annual: DirtyTactics.programLeakAnnual(t, year: gs.currentYear)) else { continue }
            gs.shadow.tacticPrograms[id]?.discovered = true
            gs.shadow.post("A leak exposes a secret American \(t.name.lowercased()).", date: gs.currentDate, severity: 3)
            logPlayEvent("tactic_program_discovered", detail: ["tactic": id, "game_date": PlayHistory.day(gs.currentDate)])
            self.gameState = gs
            applyTacticCost(t, target: nil, coverUp: true)
        }
        processTacticStances()
        processTacticAftermath()
    }

    /// A programme delivers. Chemistry hands the Army a stockpile the weapons catalog then prices as usual (3.6.0);
    /// a human-subject programme hands it a biological one.
    private func finishTacticProgram(_ t: DirtyTactic, program p: TacticProgram) {
        guard let gs = gameState else { return }
        switch t.id {
        case "chem_program":
            gs.shadow.wmdPrograms[WMDKind.chemical.rawValue] = WMDProgram(kind: .chemical, started: p.started, ready: gs.currentDate,
                                                                          discovered: p.discovered)
            gs.shadow.post("The war-gas programme delivers: shells filled with chlorine and phosgene are in store.",
                           date: gs.currentDate, severity: 2)
        case "human_subject_program":
            gs.shadow.wmdPrograms[WMDKind.biological.rawValue] = WMDProgram(kind: .biological, started: p.started, ready: gs.currentDate,
                                                                            discovered: p.discovered)
            gs.shadow.post("The biological programme reports success. Its records are sealed.", date: gs.currentDate, severity: 2)
        default:
            break
        }
        logPlayEvent("tactic_program_ready", detail: ["tactic": t.id, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
    }

    /// Costs that come due: dioxin claims, mines in the ground, redress, a procurement scandal.
    func processTacticAftermath() {
        guard let gs = gameState else { return }
        for a in gs.shadow.aftermath where a.due <= gs.currentDate {
            gs.shadow.ruthlessness += a.ruthlessness
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - a.popularity)
            if a.world > 0 {
                for o in gs.countries where o.id != gs.playerCountryID && !o.isDestroyed && !o.isTerritory {
                    modifyDiplomaticRelation(from: o.id, to: gs.playerCountryID, by: -a.world)
                }
            }
            if a.cash > 0 { spendFunds(a.cash) }
            if a.opensImpeachment, let g = gameState, g.shadow.impeachmentStage == 0 {
                g.shadow.impeachmentStage = 1
                g.shadow.post(PopularityModel.impeachmentText(stage: 1), date: g.currentDate, severity: 2)
                self.gameState = g
            }
            guard let g = gameState else { return }
            g.shadow.post(a.text, date: g.currentDate, severity: 2)
            logPlayEvent("tactic_aftermath", detail: ["tactic": a.tactic, "text": PlayHistory.text(a.text),
                                                      "cash_b": PlayHistory.num(a.cash), "game_date": PlayHistory.day(g.currentDate)])
            // A lingering cost comes back every year until its window closes.
            if let i = g.shadow.aftermath.firstIndex(where: { $0.id == a.id }) {
                if let until = a.until, until > g.currentDate {
                    g.shadow.aftermath[i].due = GameCalendar.calendar.date(byAdding: .year, value: 1, to: g.currentDate) ?? until
                } else {
                    g.shadow.aftermath.remove(at: i)
                }
            }
            self.gameState = g
        }
    }

    /// Queue a cost for later.
    func scheduleAftermath(_ a: TacticAftermath) {
        guard let gs = gameState else { return }
        gs.shadow.aftermath.append(a)
        self.gameState = gs
    }
}

// MARK: - Era reasons, headlines and programmes

extension DirtyTactics {
    /// Why an era cannot do this yet, in the game's own words. Encyclopedia level.
    static func eraReason(_ t: DirtyTactic, year: Int) -> String {
        switch t.id {
        case "chem_program":
            return "War gas needs industrial chemistry: chlorine and phosgene by the ton, pressure cylinders to hold "
                 + "them and shells to carry them. None of that exists before the 1880s — the first electrolytic "
                 + "chlorine plants date from the 1890s, and the first gas attack from 1915. No amount of money moves it."
        case "gas_resistance":
            return "There is no gas to use: the United States had no chemical stockpile before 1917."
        case "human_subject_program":
            return "Bacteriology is not far enough along: Koch's postulates date from 1884, and no state ran a "
                 + "weapons programme on them before the 1930s."
        case "defoliants":
            return "Synthetic herbicides come out of wartime research: 2,4-D was published in 1944 and the spray "
                 + "aircraft that carry them later still."
        case "congreve_rockets":
            return "William Congreve's rockets did not enter service until 1805."
        case "incendiary_shells":
            return "Rifled guns and incendiary compounds able to carry fire into a city are a product of the 1860s. "
                 + "Byzantine Greek fire, first used in the defence of Constantinople in 672, is older than this "
                 + "game and its recipe was lost."
        case "flamethrowers":
            return "The first portable flamethrowers were used in 1915; nothing before that could project burning "
                 + "fuel far enough to matter."
        case "napalm_wp":
            return "Napalm came out of Louis Fieser's Harvard laboratory in 1942 and went into combat in 1944."
        case "buffalo_slaughter":
            return "The commercial hide trade that destroyed the herds ran from about 1868; before that there was "
                 + "no market, and after 1884 there were no herds."
        case "profiteer_contracts":
            return "Contracts on this scale need a war department buying for a mass army, which the United States "
                 + "first had in 1861."
        default:
            return "The technology and the organisation for it do not exist yet."
        }
    }

    /// Programmes: how long they take, and what they cost. DESIGN CHOICES.
    static func programYears(_ t: DirtyTactic) -> Int? {
        switch t.id {
        case "chem_program": return 4
        case "human_subject_program": return 3
        default: return nil
        }
    }

    static func programCost(_ t: DirtyTactic) -> Double {
        switch t.id {
        case "chem_program": return 12
        case "human_subject_program": return 8
        default: return 0
        }
    }

    /// The line the ticker carries when a tactic is used openly.
    static func headline(_ t: DirtyTactic, target: String?) -> String {
        let at = target.map { " in \($0)" } ?? ""
        switch t.id {
        case "contaminated_goods": return "The United States admits distributing infected stores\(at)."
        case "gas_resistance": return "American aircraft drop gas on resisting villages\(at)."
        case "defoliants": return "American aircraft begin spraying defoliant over\(at.isEmpty ? " the war zone" : at)."
        case "hot_shot": return "American batteries fire heated shot into\(at.isEmpty ? " the harbour" : at)."
        case "congreve_rockets": return "Rocket batteries set\(at.isEmpty ? " the town" : at) alight."
        case "incendiary_shells": return "Incendiary shells fall on\(at.isEmpty ? " the city" : at); whole blocks burn."
        case "burn_towns": return "American troops burn the towns and farms of\(at.isEmpty ? " the valley" : at)."
        case "flamethrowers": return "American flamethrower teams burn out the defences of\(at.isEmpty ? " the position" : at)."
        case "napalm_wp": return "American aircraft put napalm and phosphorus over\(at.isEmpty ? " the city" : at)."
        case "scorched_earth": return "American columns strip and burn the country ahead of them\(at)."
        case "starve_blockade": return "The United States closes\(at.isEmpty ? " the enemy's" : at + "'s") ports to food and fertiliser as well as to war material."
        case "buffalo_slaughter": return "The Army protects the hide hunters\(at). The herds are going."
        case "requisition_harvest": return "The harvest of\(at.isEmpty ? " the territory" : at) is requisitioned for the United States."
        case "profiteer_contracts": return "The Army's ration contracts go to friends of the administration."
        default: return "The United States orders \(t.name.lowercased())\(at)."
        }
    }

    /// The line when a covert use comes out.
    static func exposureHeadline(_ t: DirtyTactic, target: String?) -> String {
        let at = target.map { " in \($0)" } ?? ""
        switch t.id {
        case "contaminated_goods": return "A quartermaster's letters surface: the United States handed out infected stores\(at)."
        case "gas_resistance": return "Photographs of gassed villages\(at) reach the newspapers."
        case "human_subject_program": return "A defector's testimony exposes an American programme that experimented on prisoners."
        case "incendiary_shells": return "An agent is taken with a carpet bag of incendiary compound\(at); the papers have the rest."
        case "profiteer_contracts": return "The ration contracts are published in full. So are the names on the cheques."
        default: return "The press exposes an American \(t.name.lowercased())\(at)."
        }
    }
}

// MARK: - Benefits

extension GameEngine {
    /// What a tactic buys. Game stats only, scaled by the preset the President chose.
    func applyTacticBenefit(_ t: DirtyTactic, use: TacticUse) {
        guard let gs = gameState else { return }
        let m = use.scale
        switch t.id {
        case "contaminated_goods":
            // Low, random effectiveness, and blowback into your own camps and cities (the 1763 blankets are not
            // known to have started the epidemic that was already running).
            let bite = Double.random(in: 0...1)
            if let target = use.target, let i = gs.countries.firstIndex(where: { $0.id == target }) {
                gs.countries[i].stability = max(0, gs.countries[i].stability - Int(12 * bite * m))
                gs.countries[i].profile.anxieties.social += 20 * bite
            } else if let target = use.target {
                resistanceHit(target, by: 10 * bite * m)
            }
            if Double.random(in: 0..<1) < 0.35, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) {
                gs.countries[pi].stability = max(0, gs.countries[pi].stability - Int(4 * m))
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 2)
                gs.shadow.post("The sickness crosses into American camps and towns.", date: gs.currentDate, severity: 2)
            }
        case "gas_resistance":
            if let target = use.target { resistanceHit(target, by: 35 * m) }
            if let target = use.target, let i = gs.countries.firstIndex(where: { $0.id == target }) {
                gs.countries[i].profile.outcry = max(0, gs.countries[i].profile.outcry - 30 * m)
                gs.countries[i].stability = min(100, gs.countries[i].stability + Int(10 * m))
            }
        case "defoliants":
            // Cover and harvest gone: the enemy's front weakens and his economy with it. The bill comes later.
            if let target = use.target, let i = gs.countries.firstIndex(where: { $0.id == target }) {
                gs.countries[i].gdp *= 1 - 0.04 * m
                gs.countries[i].stability = max(0, gs.countries[i].stability - Int(8 * m))
            }
            if let target = use.target, let fi = gs.shadow.fronts.firstIndex(where: { $0.status == .fighting && ($0.defender == target || $0.attacker == target) }) {
                let defending = gs.shadow.fronts[fi].defender == target
                if defending {
                    gs.shadow.fronts[fi].defenderWill = max(0, gs.shadow.fronts[fi].defenderWill - 0.12 * m)
                    gs.shadow.fronts[fi].defenderTroops *= 1 - 0.06 * m
                } else {
                    gs.shadow.fronts[fi].attackerWill = max(0, gs.shadow.fronts[fi].attackerWill - 0.12 * m)
                    gs.shadow.fronts[fi].attackerTroops *= 1 - 0.06 * m
                }
            }
            // Dioxin: veterans' illnesses and claims, twenty years on (the Agent Orange class settlement of 1984 was
            // $180M; the Agent Orange Act followed in 1991).
            scheduleAftermath(TacticAftermath(tactic: t.id,
                                              due: GameCalendar.calendar.date(byAdding: .year, value: 20, to: gs.currentDate) ?? gs.currentDate,
                                              text: "Veterans of the spraying campaign win their claim. The settlement and the headlines both cost.",
                                              ruthlessness: 8, popularity: 6, world: 2, cash: 4 * m))
        // --- 3.17.1: fire ---
        case "hot_shot":
            // Wooden hulls and waterfront stores: the enemy's navy and his trade.
            if let target = use.target, let i = gs.countries.firstIndex(where: { $0.id == target }) {
                gs.countries[i].militaryStrength = max(1, gs.countries[i].militaryStrength - Int(2 * m))
                gs.countries[i].gdp *= 1 - 0.01 * m
            }
            frontBlow(use.target, will: 0.03 * m, troops: 0.02 * m)
        case "congreve_rockets":
            if let target = use.target { burnTarget(target, gdp: 0.015 * m, stability: 6 * m, dead: 60 * m) }
            frontBlow(use.target, will: 0.06 * m, troops: 0.01 * m)
        case "incendiary_shells":
            if let target = use.target { burnTarget(target, gdp: 0.025 * m, stability: 10 * m, dead: 200 * m) }
            frontBlow(use.target, will: 0.05 * m, troops: 0)
        case "burn_towns":
            if let target = use.target { burnTarget(target, gdp: 0.06 * m, stability: 18 * m, dead: 600 * m) }
            frontBlow(use.target, will: 0.18 * m, troops: 0.03 * m)
        case "flamethrowers":
            // Takes positions artillery cannot: it helps the side the U.S. is fighting on.
            if let target = use.target, let fi = gs.shadow.fronts.firstIndex(where: { $0.status == .fighting && ($0.defender == target || $0.attacker == target) }) {
                let weAttack = gs.shadow.fronts[fi].defender == target
                gs.shadow.fronts[fi].attackerMomentum = min(1, gs.shadow.fronts[fi].attackerMomentum + (weAttack ? 0.15 : -0.15) * m)
            }
            frontBlow(use.target, will: 0.08 * m, troops: 0.04 * m)
        case "napalm_wp":
            if let target = use.target { burnTarget(target, gdp: 0.05 * m, stability: 15 * m, dead: 900 * m) }
            frontBlow(use.target, will: 0.15 * m, troops: 0.05 * m)
        // --- 3.17.2: hunger ---
        case "scorched_earth":
            if let target = use.target { burnTarget(target, gdp: 0.05 * m, stability: 12 * m, dead: 300 * m) }
            frontBlow(use.target, will: 0.12 * m, troops: 0.08 * m)
        case "buffalo_slaughter":
            // The herds a people lives on: the resistance goes with them, and it does not come back.
            if let target = use.target { resistanceHit(target, by: 45 * m) }
        case "requisition_harvest":
            // Cash now out of an occupied territory, hunger and hatred after.
            if let target = use.target, let i = gs.countries.firstIndex(where: { $0.id == target }) {
                let take = ExpansionModel.levyAmount(gs.countries[i], in: gs) * 1.5 * m
                gs.shadow.aidRemaining += take
                gs.shadow.resourceEarnings += take
                gs.countries[i].stability = max(0, gs.countries[i].stability - Int(25 * m))
                gs.countries[i].profile.outcry = min(100, gs.countries[i].profile.outcry + 30 * m)
                gs.shadow.post(String(format: "The harvest of %@ is requisitioned: $%.1fB.", gs.countries[i].name, take),
                               date: gs.currentDate, severity: 2)
                scheduleAftermath(TacticAftermath(tactic: t.id,
                                                  due: GameCalendar.calendar.date(byAdding: .year, value: 1, to: gs.currentDate) ?? gs.currentDate,
                                                  text: "Famine in \(gs.countries[i].name). The relief appeals name the United States.",
                                                  ruthlessness: 10 * m, popularity: 4 * m, world: 3))
            }
        case "profiteer_contracts":
            // Cash and kickbacks now; your own soldiers sick; a scandal after that.
            let take = 3.0 * m
            gs.shadow.aidRemaining += take
            gs.shadow.resourceEarnings += take
            let me = gs.playerCountryID
            for i in gs.shadow.fronts.indices where gs.shadow.fronts[i].status == .fighting {
                let f = gs.shadow.fronts[i]
                // The front the United States is on, as attacker, as defender, or as somebody's ally.
                guard f.attacker == me || f.defender == me || f.usSide != nil else { continue }
                let ours = f.attacker == me || f.usSide == f.attacker
                if ours {
                    gs.shadow.fronts[i].attackerWill = max(0, gs.shadow.fronts[i].attackerWill - 0.08 * m)
                    gs.shadow.fronts[i].attackerTroops *= 1 - 0.03 * m
                } else {
                    gs.shadow.fronts[i].defenderWill = max(0, gs.shadow.fronts[i].defenderWill - 0.08 * m)
                    gs.shadow.fronts[i].defenderTroops *= 1 - 0.03 * m
                }
            }
            gs.shadow.post("The Army's new ration contracts are signed. The men are already complaining about the beef.",
                           date: gs.currentDate, severity: 1)
            scheduleAftermath(TacticAftermath(tactic: t.id,
                                              due: GameCalendar.calendar.date(byAdding: .month, value: 18, to: gs.currentDate) ?? gs.currentDate,
                                              text: "A commission of inquiry opens into the ration contracts. The newspapers have a name for the beef.",
                                              ruthlessness: 6 * m, popularity: 8 * m, world: 0, cash: 0, opensImpeachment: true))
        default:
            break
        }
        self.gameState = gs
    }

    /// Break a resisting people's will on a land that is not a country in the game (3.13.0 pre-state land), or the
    /// insurgency in a territory.
    func resistanceHit(_ land: String, by amount: Double) {
        guard let gs = gameState else { return }
        if let i = gs.countries.firstIndex(where: { $0.id == land }) {
            gs.countries[i].profile.outcry = max(0, gs.countries[i].profile.outcry - amount)
            gs.countries[i].stability = min(100, gs.countries[i].stability + Int(amount / 3))
        } else {
            // Land not yet taken: the resistance it will put up is softened.
            gs.shadow.resistanceBroken[land] = (gs.shadow.resistanceBroken[land] ?? 0) + amount
        }
        self.gameState = gs
    }

    /// Fire on a country: its output, its nerve and its dead. Game stats only.
    func burnTarget(_ target: String, gdp: Double, stability: Double, dead: Double) {
        guard let gs = gameState, let i = gs.countries.firstIndex(where: { $0.id == target }) else { return }
        gs.countries[i].gdp *= 1 - gdp
        gs.countries[i].stability = max(0, gs.countries[i].stability - Int(stability))
        gs.countries[i].profile.anxieties.military += stability
        gs.totalCasualties += Int(Double(max(1, gs.countries[i].population)) * dead)
        self.gameState = gs
    }

    /// A blow to whichever front the target is fighting on: its will and its troops in theatre.
    func frontBlow(_ target: String?, will: Double, troops: Double) {
        guard let gs = gameState, let target,
              let fi = gs.shadow.fronts.firstIndex(where: { $0.status == .fighting && ($0.defender == target || $0.attacker == target) }) else { return }
        if gs.shadow.fronts[fi].defender == target {
            gs.shadow.fronts[fi].defenderWill = max(0, gs.shadow.fronts[fi].defenderWill - will)
            gs.shadow.fronts[fi].defenderTroops *= 1 - troops
        } else {
            gs.shadow.fronts[fi].attackerWill = max(0, gs.shadow.fronts[fi].attackerWill - will)
            gs.shadow.fronts[fi].attackerTroops *= 1 - troops
        }
        self.gameState = gs
    }
}

extension PreStateModel {
    /// A pre-state land's era name, for ticker lines ("the Rif", "Apacheria").
    static func landName(_ id: String?, in gs: GameState) -> String? {
        guard let id else { return nil }
        return gs.preState(id)?.era.name ?? WorldCountriesDatabase.template(id: id)?.name
    }
}
