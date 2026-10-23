//
//  Scenarios.swift
//  Global Thermal Nuclear War
//
//  Scenario definitions (start date, administration, pre-existing wars, relations, and a queue of dated scripted
//  events) plus save/load slots. Descriptions and event text are written for GTNW from the historical record.
//  The 1990 scenario can optionally refine leader personalities from the player's local Shadow Pack
//  (~/Library/Application Support/GTNW/ShadowPack/data/scenario_S0.json); nothing from that file is in this repo.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - Scripted events

enum ScriptedEventKind: String, Codable {
    case news            // headline only
    case condemn         // actor denounces target (relations fall, target political anxiety rises)
    case massTroops      // actor masses troops on target's border (military anxiety)
    case invade          // actor declares war on target
    case strike          // missile/air strike: target damaged, war if not already
    case assassination   // attempt on target's leader
    case unrest          // target's internal unrest rises
    case ceasefire       // actor and target stop fighting
}

struct ScheduledEvent: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var kind: ScriptedEventKind
    var actor: String?
    var target: String?
    var text: String
    var fired = false
}

// MARK: - Scenario definitions

struct ScenarioDefinition: Identifiable {
    let id: String
    let title: String
    let summary: String
    let startDate: Date
    /// Year used to pick the historical administration and era country data.
    let eraYear: Int
    let defcon: DefconLevel
    let wars: [(String, String)]
    let relations: [(String, String, Int)]
    let events: [ScheduledEvent]
    let suggestedTurnLength: TurnLength
    /// Build the board for this year rather than the administration's first year (3.12.0); nil = as before.
    var boardYear: Int? = nil
    var allowsEarlyWMD: Bool = false   // lift the WMD era-gate (the Civil War lets you wage bio/chem anachronistically)

    var administration: Administration? {
        let all = Advisor.allAdministrations()
        return all.first { $0.startYear <= eraYear && eraYear < $0.endYear } ?? all.last { $0.startYear <= eraYear }
    }

    static func d(_ y: Int, _ m: Int, _ day: Int) -> Date { GameCalendar.date(year: y, month: m, day: day) }

    static let all: [ScenarioDefinition] = [civilWar1861, pearlHarbor1941, berlin1948, korea1950, cuba1962, ableArcher1983, world1990, gulf1990, sept11_2001, modern2025]

    static func find(_ id: String) -> ScenarioDefinition? { all.first { $0.id == id } }

    /// Summer 1990: the Wall is down, the Gulf is about to ignite, the Soviet Union is wobbling.
    static let world1990 = ScenarioDefinition(
        id: "world1990",
        title: "The World in 1990",
        summary: "June 1, 1990. The Berlin Wall has fallen and the Cold War is ending — but not quietly. Ethiopia and "
            + "Somalia are still fighting, Baghdad is making threats toward Kuwait, and the Soviet republics are "
            + "restless. You have a little over two years until the next election.",
        startDate: d(1990, 6, 1), eraYear: 1990, defcon: .defcon4,
        wars: [("ETH", "SOM")],
        relations: [("IRQ", "KWT", -70), ("KWT", "IRQ", -60), ("IRQ", "ISR", -90), ("IRQ", "SAU", -40), ("USA", "IRQ", -30)],
        events: [
            ScheduledEvent(date: d(1990, 6, 20), kind: .condemn, actor: "IRQ", target: "KWT",
                           text: "Baghdad accuses Kuwait of stealing oil and flooding the market."),
            ScheduledEvent(date: d(1990, 7, 17), kind: .condemn, actor: "IRQ", target: "KWT",
                           text: "Iraq's president warns Gulf neighbours that 'cutting our necks' will not go unanswered."),
            ScheduledEvent(date: d(1990, 7, 24), kind: .massTroops, actor: "IRQ", target: "KWT",
                           text: "Satellite imagery shows Iraqi armoured divisions moving toward the Kuwaiti border."),
            ScheduledEvent(date: d(1990, 8, 2), kind: .invade, actor: "IRQ", target: "KWT",
                           text: "FLASH: Iraqi forces have crossed into Kuwait."),
            ScheduledEvent(date: d(1990, 8, 19), kind: .unrest, actor: nil, target: "RUS",
                           text: "Strikes and independence rallies spread across several Soviet republics."),
            ScheduledEvent(date: d(1990, 9, 15), kind: .massTroops, actor: "IRQ", target: "SAU",
                           text: "Iraqi units dig in along the Saudi border."),
            ScheduledEvent(date: d(1990, 11, 29), kind: .news, actor: nil, target: "IRQ",
                           text: "The UN Security Council sets a deadline for Iraq to leave Kuwait."),
            ScheduledEvent(date: d(1991, 1, 18), kind: .strike, actor: "IRQ", target: "ISR",
                           text: "Missiles fired from Iraq strike Israeli cities."),
            ScheduledEvent(date: d(1991, 8, 19), kind: .unrest, actor: nil, target: "RUS",
                           text: "Tanks in Moscow: hardliners attempt to seize power from the Soviet leadership."),
            ScheduledEvent(date: d(1991, 12, 8), kind: .news, actor: nil, target: "RUS",
                           text: "Leaders of three Soviet republics declare the Union finished."),
        ],
        suggestedTurnLength: .week)

    static let cuba1962 = ScenarioDefinition(
        id: "cuba1962",
        title: "Thirteen Days, 1962",
        summary: "October 16, 1962. Reconnaissance photos show Soviet missile sites under construction in Cuba. "
            + "Get them out without starting the war everyone fears.",
        startDate: d(1962, 10, 16), eraYear: 1962, defcon: .defcon3,
        wars: [],
        relations: [("USA", "RUS", -80), ("USA", "CUB", -90), ("CUB", "USA", -90), ("RUS", "USA", -75)],
        events: [
            ScheduledEvent(date: d(1962, 10, 22), kind: .news, actor: nil, target: "CUB",
                           text: "The world waits as Soviet freighters steam toward Cuba."),
            ScheduledEvent(date: d(1962, 10, 24), kind: .massTroops, actor: "RUS", target: "USA",
                           text: "Soviet submarines are shadowing the quarantine line."),
            ScheduledEvent(date: d(1962, 10, 27), kind: .strike, actor: "CUB", target: "USA",
                           text: "A U.S. reconnaissance plane has been shot down over Cuba."),
        ],
        suggestedTurnLength: .day)

    static let ableArcher1983 = ScenarioDefinition(
        id: "ablearcher1983",
        title: "Able Archer, 1983",
        summary: "November 1983. A NATO command exercise looks, from Moscow, a lot like the real thing. "
            + "Soviet early-warning crews are jumpy. Keep the exercise an exercise.",
        startDate: d(1983, 11, 2), eraYear: 1983, defcon: .defcon3,
        wars: [("RUS", "AFG")],
        relations: [("USA", "RUS", -70), ("RUS", "USA", -80)],
        events: [
            ScheduledEvent(date: d(1983, 11, 7), kind: .massTroops, actor: "RUS", target: "DEU",
                           text: "Soviet air units in East Germany are placed on heightened alert."),
            ScheduledEvent(date: d(1983, 11, 9), kind: .news, actor: nil, target: "RUS",
                           text: "Moscow cables its stations: look for signs of a Western surprise attack."),
        ],
        suggestedTurnLength: .day)

    // MARK: Historical crises (3.12.0). Encyclopedia-level facts only; the scorecard compares the player with history.

    static let civilWar1861 = ScenarioDefinition(
        id: "civilwar1861",
        title: "A House Divided, 1861",
        summary: "April 12, 1861. Confederate guns open on Fort Sumter. Hold the Union together — or break it free. "
            + "Britain and France weigh recognition, and King Cotton is the Confederacy's gamble.",
        startDate: d(1861, 4, 12), eraYear: 1861, defcon: .defcon5,
        wars: [("USA", "CSA")],
        relations: [("GBR", "CSA", 10), ("FRA", "CSA", 10), ("USA", "CSA", -90), ("CSA", "USA", -90)],
        events: [
            ScheduledEvent(date: d(1861, 7, 21), kind: .strike, actor: "CSA", target: "USA",
                           text: "First Bull Run: the Confederates rout the Union army at Manassas."),
            ScheduledEvent(date: d(1863, 1, 1), kind: .news, actor: "USA", target: nil,
                           text: "The Emancipation Proclamation reframes the war — and warns Europe off recognition."),
        ],
        suggestedTurnLength: .month, allowsEarlyWMD: true)

    static let pearlHarbor1941 = ScenarioDefinition(
        id: "pearl1941",
        title: "Day of Infamy, 1941",
        summary: "December 7, 1941. Japanese carrier aircraft have struck the Pacific Fleet at Pearl Harbor. Europe has "
            + "been at war for two years and Germany is deep inside the Soviet Union. The nation waits for your answer.",
        startDate: d(1941, 12, 7), eraYear: 1941, defcon: .defcon2,
        wars: [("JPN", "USA"), ("DEU", "GBR"), ("DEU", "RUS"), ("ITA", "GBR"), ("JPN", "CHN")],
        relations: [("USA", "JPN", -95), ("JPN", "USA", -95), ("USA", "DEU", -60), ("USA", "GBR", 80)],
        events: [
            ScheduledEvent(date: d(1941, 12, 8), kind: .news, actor: nil, target: nil,
                           text: "Japanese forces strike the Philippines, Guam, Wake, Hong Kong and Malaya."),
            ScheduledEvent(date: d(1941, 12, 11), kind: .invade, actor: "DEU", target: "USA",
                           text: "Germany declares war on the United States."),
            ScheduledEvent(date: d(1941, 12, 11), kind: .invade, actor: "ITA", target: "USA",
                           text: "Italy declares war on the United States."),
        ],
        suggestedTurnLength: .week, boardYear: 1941)

    static let berlin1948 = ScenarioDefinition(
        id: "berlin1948",
        title: "The Berlin Blockade, 1948",
        summary: "June 24, 1948. Soviet forces have cut every road, rail and canal link to West Berlin. Two million "
            + "people have weeks of food. Supply the city, force the corridor, or let it go.",
        startDate: d(1948, 6, 24), eraYear: 1948, defcon: .defcon3,
        wars: [],
        relations: [("USA", "RUS", -60), ("RUS", "USA", -60), ("USA", "GBR", 85), ("USA", "FRA", 70)],
        events: [
            ScheduledEvent(date: d(1948, 6, 26), kind: .news, actor: nil, target: nil,
                           text: "The first transport aircraft land at Tempelhof with supplies for West Berlin."),
            ScheduledEvent(date: d(1949, 4, 4), kind: .news, actor: nil, target: nil,
                           text: "The North Atlantic Treaty is signed in Washington."),
        ],
        suggestedTurnLength: .week, boardYear: 1948)

    static let korea1950 = ScenarioDefinition(
        id: "korea1950",
        title: "Korea, 1950",
        summary: "June 25, 1950. North Korean armies have crossed the 38th parallel and are driving on Seoul. "
            + "The Security Council is meeting without the Soviet delegate.",
        startDate: d(1950, 6, 25), eraYear: 1950, defcon: .defcon3,
        wars: [("PRK", "KOR")],
        relations: [("USA", "PRK", -80), ("USA", "KOR", 60), ("USA", "CHN", -50)],
        events: [
            ScheduledEvent(date: d(1950, 6, 28), kind: .news, actor: nil, target: nil, text: "Seoul falls to North Korean forces."),
            ScheduledEvent(date: d(1950, 10, 25), kind: .invade, actor: "CHN", target: "KOR",
                           text: "Chinese 'volunteers' cross the Yalu River in force."),
        ],
        suggestedTurnLength: .week, boardYear: 1950)

    static let gulf1990 = ScenarioDefinition(
        id: "gulf1990",
        title: "The Gulf War, 1990",
        summary: "August 2, 1990. Iraqi armoured divisions have overrun Kuwait in a matter of hours and stand on the "
            + "Saudi border. The oil of the Gulf, and the credibility of the post-Cold War order, are at stake.",
        startDate: d(1990, 8, 2), eraYear: 1990, defcon: .defcon4,
        wars: [("IRQ", "KWT")],
        relations: [("IRQ", "KWT", -95), ("KWT", "IRQ", -95), ("USA", "IRQ", -60), ("IRQ", "USA", -50), ("SAU", "IRQ", -60), ("USA", "SAU", 60)],
        events: [
            ScheduledEvent(date: d(1990, 8, 6), kind: .news, actor: nil, target: nil,
                           text: "The UN Security Council imposes sanctions on Iraq (Resolution 661)."),
            ScheduledEvent(date: d(1990, 8, 7), kind: .news, actor: nil, target: nil,
                           text: "Operation Desert Shield: the first U.S. forces deploy to Saudi Arabia."),
            ScheduledEvent(date: d(1990, 11, 29), kind: .news, actor: nil, target: nil,
                           text: "The Security Council authorizes 'all necessary means' if Iraq is not out of Kuwait by 15 January (Resolution 678)."),
        ],
        suggestedTurnLength: .week)

    static let sept11_2001 = ScenarioDefinition(
        id: "sept11_2001",
        title: "September 11, 2001",
        summary: "September 11, 2001. Hijacked airliners have struck the World Trade Center and the Pentagon. "
            + "The attack was planned from Afghanistan, where the Taliban shelter al-Qaeda.",
        startDate: d(2001, 9, 11), eraYear: 2001, defcon: .defcon3,
        wars: [],
        relations: [("USA", "AFG", -90), ("AFG", "USA", -70), ("USA", "PAK", 10), ("USA", "GBR", 90)],
        events: [
            ScheduledEvent(date: d(2001, 9, 12), kind: .news, actor: nil, target: nil,
                           text: "NATO invokes Article 5 for the first time: an attack on one is an attack on all."),
        ],
        suggestedTurnLength: .week, boardYear: 2001)

    static let modern2025 = ScenarioDefinition(
        id: "modern2025",
        title: "The World Today",
        summary: "January 20, 2025. Wars in Europe and the Middle East, a rising rival in the Pacific, and an "
            + "electorate that wants results.",
        startDate: d(2025, 1, 20), eraYear: 2025, defcon: .defcon4,
        wars: [("RUS", "UKR")],
        relations: [("USA", "RUS", -60), ("USA", "CHN", -30)],
        events: [],
        suggestedTurnLength: .month)
}

// MARK: - Scorecard (3.12.0)

/// One line of a scenario's scorecard: what happened in history against what happened in this game.
struct ScorecardLine: Hashable {
    let label: String
    let historical: String
    let player: String
    /// nil when there is nothing to compare yet.
    let matchesHistory: Bool?
}

enum Scorecard {
    /// Did a and b fight (a war either way, or U.S. troops on a front against the other)?
    static func fought(_ a: String, _ b: String, in gs: GameState) -> Bool {
        gs.activeWars.contains { ($0.aggressor == a && $0.defender == b) || ($0.aggressor == b && $0.defender == a) }
            || gs.shadow.fronts.contains { f in
                (f.attacker == a && f.defender == b) || (f.attacker == b && f.defender == a)
                    || (a == "USA" && f.usSide != nil && (f.attacker == b || f.defender == b) && f.usSide != b)
            }
    }

    static func defeated(_ id: String, in gs: GameState) -> Bool {
        gs.shadow.fronts.contains { $0.defender == id && $0.status == .attackerWon } || (gs.getCountry(id: id)?.isTerritory ?? false)
            || (gs.getCountry(id: id)?.isDestroyed ?? false)
    }

    private static func yes(_ b: Bool) -> String { b ? "Yes" : "No" }

    /// A yes/no line: history's answer and date, and the game's.
    private static func line(_ label: String, history: Bool, when: String, game: Bool) -> ScorecardLine {
        ScorecardLine(label: label, historical: yes(history) + (when.isEmpty ? "" : " (\(when))"), player: yes(game), matchesHistory: history == game)
    }

    static func lines(for id: String, in gs: GameState) -> [ScorecardLine] {
        let nukes = !gs.nuclearStrikes.isEmpty
        var out: [ScorecardLine] = []
        switch id {
        case "civilwar1861":
            out = [line("Union and Confederacy at war", history: true, when: "from Fort Sumter, 12 Apr 1861", game: fought("USA", "CSA", in: gs)),
                   line("The Confederacy is defeated", history: true, when: "Appomattox, 9 Apr 1865", game: defeated("CSA", in: gs)),
                   line("Nuclear weapons used", history: false, when: "", game: nukes)]
        case "pearl1941":
            out = [line("The U.S. fights Japan", history: true, when: "declared 8 Dec 1941", game: fought("USA", "JPN", in: gs)),
                   line("The U.S. fights Germany", history: true, when: "11 Dec 1941", game: fought("USA", "DEU", in: gs)),
                   line("Japan defeated", history: true, when: "surrender 2 Sep 1945", game: defeated("JPN", in: gs)),
                   line("Nuclear weapons used", history: true, when: "Hiroshima and Nagasaki, Aug 1945", game: nukes)]
        case "berlin1948":
            out = [line("War with the Soviet Union", history: false, when: "", game: fought("USA", "RUS", in: gs)),
                   line("Nuclear weapons used", history: false, when: "", game: nukes),
                   line("NATO founded", history: true, when: "4 Apr 1949", game: gs.currentDate >= ScenarioDefinition.d(1949, 4, 4))]
        case "korea1950":
            out = [line("The U.S. fights North Korea", history: true, when: "from Jun 1950, under the UN flag", game: fought("USA", "PRK", in: gs)),
                   line("China enters the war", history: true, when: "Oct 1950", game: fought("CHN", "KOR", in: gs) || fought("USA", "CHN", in: gs)),
                   line("Nuclear weapons used", history: false, when: "", game: nukes),
                   line("North Korea defeated", history: false, when: "armistice 27 Jul 1953", game: defeated("PRK", in: gs))]
        case "cuba1962":
            out = [line("Naval quarantine of Cuba", history: true, when: "from 24 Oct 1962",
                        game: gs.shadow.fleetDeployments.contains { $0.target == "CUB" && $0.mission == .blockade }),
                   line("DEFCON 2 reached", history: true, when: "Strategic Air Command, 24 Oct 1962", game: gs.defconLevel.rawValue <= 2 || gs.reachedDEFCON1),
                   line("War with the Soviet Union", history: false, when: "", game: fought("USA", "RUS", in: gs)),
                   line("Invasion of Cuba", history: false, when: "", game: fought("USA", "CUB", in: gs)),
                   line("Nuclear weapons used", history: false, when: "missiles withdrawn, Oct–Nov 1962", game: nukes)]
        case "gulf1990":
            let liberated = defeated("IRQ", in: gs) || gs.shadow.fronts.contains { $0.attacker == "IRQ" && $0.defender == "KWT" && $0.status == .defenderWon }
            out = [line("Congress authorizes force", history: true, when: "12 Jan 1991", game: gs.shadow.authorizations.contains { $0.target == "IRQ" && $0.passed }),
                   line("A coalition joins the U.S.", history: true, when: "35 nations", game: !(gs.shadow.coalitions["IRQ"]?.members.isEmpty ?? true)),
                   line("The U.S. fights Iraq", history: true, when: "Desert Storm, from 17 Jan 1991", game: fought("USA", "IRQ", in: gs)),
                   line("Kuwait liberated", history: true, when: "28 Feb 1991", game: liberated),
                   line("Nuclear weapons used", history: false, when: "", game: nukes)]
        case "ablearcher1983":
            out = [line("War with the Soviet Union", history: false, when: "", game: fought("USA", "RUS", in: gs)),
                   line("Nuclear weapons used", history: false, when: "", game: nukes)]
        case "world1990":
            out = [line("Iraq invades Kuwait", history: true, when: "2 Aug 1990", game: fought("IRQ", "KWT", in: gs)),
                   line("The U.S. fights Iraq", history: true, when: "Desert Storm, from 17 Jan 1991", game: fought("USA", "IRQ", in: gs)),
                   line("A coalition joins the U.S.", history: true, when: "35 nations", game: !(gs.shadow.coalitions["IRQ"]?.members.isEmpty ?? true)),
                   line("Nuclear weapons used", history: false, when: "", game: nukes)]
        case "sept11_2001":
            out = [line("Congress authorizes force", history: true, when: "AUMF, 18 Sep 2001", game: gs.shadow.authorizations.contains { $0.target == "AFG" && $0.passed }),
                   line("The U.S. fights Afghanistan", history: true, when: "from 7 Oct 2001", game: fought("USA", "AFG", in: gs)),
                   line("A coalition joins the U.S.", history: true, when: "NATO Article 5, 12 Sep 2001", game: !(gs.shadow.coalitions["AFG"]?.members.isEmpty ?? true)),
                   line("Nuclear weapons used", history: false, when: "", game: nukes)]
        case "modern2025":
            out = [line("Nuclear weapons used", history: false, when: "to date", game: nukes)]
        default:
            break
        }
        return out
    }

    /// Lines that match history, out of those that can be compared.
    static func score(_ lines: [ScorecardLine]) -> (matched: Int, total: Int) {
        let c = lines.compactMap(\.matchesHistory)
        return (c.filter { $0 }.count, c.count)
    }
}

// MARK: - Applying a scenario

enum ScenarioLoader {
    /// Build a fresh GameState for a scenario.
    static func makeGameState(_ s: ScenarioDefinition, difficulty: DifficultyLevel = .normal,
                              turnLength: TurnLength? = nil, player: String = "USA", packFolder: URL? = ShadowPack.shared.isInstalled ? ShadowPack.shared.folder : nil) -> GameState {
        let gs = GameState(playerCountryID: player, difficultyLevel: difficulty, administration: s.administration,
                           turnLength: turnLength ?? s.suggestedTurnLength, startDate: s.startDate, boardYear: s.boardYear)
        apply(s, to: gs, packFolder: packFolder)
        return gs
    }

    static func apply(_ s: ScenarioDefinition, to gs: GameState, packFolder: URL?) {
        gs.eraStartYear = s.eraYear
        gs.defconLevel = s.defcon
        gs.shadow.scenarioID = s.id
        for (a, b) in s.wars where gs.getCountry(id: a) != nil && gs.getCountry(id: b) != nil {
            gs.activeWars.append(War(aggressor: a, defender: b, startTurn: 0))
            if let i = gs.countries.firstIndex(where: { $0.id == a }) { gs.countries[i].atWarWith.insert(b) }
            if let i = gs.countries.firstIndex(where: { $0.id == b }) { gs.countries[i].atWarWith.insert(a) }
            gs.setRelation(from: a, to: b, value: -90)
            gs.setRelation(from: b, to: a, value: -90)
        }
        for (a, b, v) in s.relations { gs.setRelation(from: a, to: b, value: v) }
        gs.shadow.eventQueue = s.events.filter { e in
            [e.actor, e.target].compactMap { $0 }.allSatisfy { gs.getCountry(id: $0) != nil }
        }
        if s.id == "world1990", let folder = packFolder {
            applyPackPersonalities(from: folder.appendingPathComponent("data/scenario_S0.json"), to: gs)
        }
    }

    /// Old-name → ISO3 aliases for the pack's 1990 country names.
    static let aliases: [String: String] = [
        "ussr": "RUS", "soviet union": "RUS", "united states": "USA", "usa": "USA", "united kingdom": "GBR", "uk": "GBR",
        "west germany": "DEU", "germany, west": "DEU", "north korea": "PRK", "korea, north": "PRK", "south korea": "KOR",
        "korea, south": "KOR", "china": "CHN", "iran": "IRN", "iraq": "IRQ", "kuwait": "KWT", "israel": "ISR",
        "saudi arabia": "SAU", "ethiopia": "ETH", "somalia": "SOM", "japan": "JPN", "france": "FRA", "india": "IND",
        "pakistan": "PAK", "cuba": "CUB", "egypt": "EGY", "syria": "SYR", "libya": "LBY", "jordan": "JOR",
    ]

    /// Map a generic ideology label onto GTNW's ideology list.
    static func ideologyFromLabel(_ label: String) -> LeaderIdeology? {
        let l = label.lowercased()
        if l.contains("commun") { return .communism }
        if l.contains("fundamental") { return .theocracy }
        if l.contains("islam") { return .islamicRepublic }
        if l.contains("imperial") { return .expansionism }
        if l.contains("fascis") || l.contains("national") { return .nationalism }
        if l.contains("central") { return .oneParty }
        if l.contains("socialis") { return l.contains("democ") ? .socialDemocracy : .oneParty }
        if l.contains("developing") { return .developingDemocracy }
        if l.contains("capital") || l.contains("democ") { return .liberalDemocracy }
        if l.contains("monarch") { return .absoluteMonarchy }
        return nil
    }

    /// Refine ambition/ethic/anxieties from the local pack's 1990 data, when the player has built the pack.
    @discardableResult
    static func applyPackPersonalities(from url: URL, to gs: GameState) -> Int {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["countries"] as? [[String: Any]] else { return 0 }
        var applied = 0
        for row in rows {
            guard let name = (row["name"] as? String)?.lowercased() else { continue }
            let id = aliases[name] ?? gs.countries.first { $0.name.lowercased() == name }?.id
            guard let cid = id, let i = gs.countries.firstIndex(where: { $0.id == cid }) else { continue }
            var p = gs.countries[i].profile
            if let a = row["Ambition"] as? Double { p.ambition = min(6, max(1, Int(a.rounded()))) }
            if let e = row["Ethic"] as? Double { p.ethic = min(6, max(1, Int(e.rounded()))) }
            let keys: [(String, ThreatAnxieties.Kind)] = [("NTA_nuclear_threat_anxiety", .nuclear), ("MTA_military_threat_anxiety", .military),
                                                          ("PTA_political_threat_anxiety", .political), ("ETA_economic_threat_anxiety", .economic),
                                                          ("STA_social_threat_anxiety", .social)]
            for (k, kind) in keys { if let v = row[k] as? Double { p.anxieties[kind] = v } }
            if let ideology = (row["Ideology"] as? String).flatMap(ideologyFromLabel) { p.ideology = ideology }
            gs.countries[i].profile = p
            applied += 1
        }
        return applied
    }
}

// MARK: - Save slots

struct SaveSlotInfo: Identifiable, Equatable {
    let slot: Int
    let label: String
    let modified: Date
    var id: Int { slot }
}

/// JSON save slots under Application Support/GTNW/Saves. Slot 0 is the autosave.
/// This folder is the on-device cache of the slots; `GameStoreService` syncs it with the Games DB
/// (see `Shared/Storage/`). Every load is size-capped and validated by `SaveCodec`.
struct SaveManager {
    let folder: URL
    static let slotCount = 5

    static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GTNW/Saves", isDirectory: true)
    }

    init(folder: URL = SaveManager.defaultFolder) { self.folder = folder }

    func url(slot: Int) -> URL { folder.appendingPathComponent(slot == 0 ? "autosave.json" : "slot\(slot).json") }

    func save(_ gs: GameState, slot: Int) throws {
        try write(SaveCodec.encode(gs), slot: slot, modified: nil)
    }

    /// Write raw (already validated) payload bytes, optionally stamping the modification date (used when pulling from the DB).
    func write(_ data: Data, slot: Int, modified: Date?) throws {
        guard StoreValidation.slotRange.contains(slot) else { throw GameStoreError.invalid("slot \(slot) out of range") }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: url(slot: slot), options: .atomic)
        if let modified { try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url(slot: slot).path) }
    }

    /// Raw bytes of a slot, refusing anything over the payload cap before reading it.
    func data(slot: Int) throws -> Data {
        let u = url(slot: slot)
        let size = (try FileManager.default.attributesOfItem(atPath: u.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size <= StoreValidation.maxPayloadBytes else { throw GameStoreError.invalid("save file is \(size) bytes") }
        return try Data(contentsOf: u)
    }

    func modified(slot: Int) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url(slot: slot).path))?[.modificationDate] as? Date
    }

    func load(slot: Int) throws -> GameState {
        try Self.decode(data(slot: slot))
    }

    /// Validated decode (size cap, JSON, sanity checks). Use this for anything read from disk or the network.
    static func decode(_ data: Data) throws -> GameState { try SaveCodec.decode(data) }

    /// Decode a save, accepting both ISO-8601 dates (current) and the default numeric encoding. No validation.
    static func decodeUnchecked(_ data: Data) throws -> GameState {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let gs = try? dec.decode(GameState.self, from: data) { return gs }
        return try JSONDecoder().decode(GameState.self, from: data)
    }

    func list() -> [SaveSlotInfo] {
        (0...Self.slotCount).compactMap { slot in
            guard let mod = modified(slot: slot) else { return nil }
            var label = slot == 0 ? "Autosave" : "Slot \(slot)"
            if let gs = try? load(slot: slot) {
                label += " — \(gs.currentDateLabel), turn \(gs.turn)"
            }
            return SaveSlotInfo(slot: slot, label: label, modified: mod)
        }
    }

    func delete(slot: Int) { try? FileManager.default.removeItem(at: url(slot: slot)) }
}

// MARK: - Civil War: foreign recognition (3.18.x)

/// Whether Britain and France recognize (and back) a side in the 1861 Civil War. A great power leans toward whichever
/// side has courted it more (relations), under European cotton pressure that builds the longer the war drags (the
/// Confederacy's "King Cotton" gamble), tilted by who is winning on the battlefield. Recognition brings arms, credit,
/// and ships to the recognized side — the decisive foreign help the President pleads for.
enum CivilWarRecognition {
    enum Side: String { case union = "USA", confederacy = "CSA" }

    /// Lean toward a side. Positive = toward the Confederacy, negative = toward the Union. `relToUnion`/`relToCSA`
    /// are each side's relations *to the power* — what the player raises by courting it with diplomacy and aid.
    static func lean(relToUnion: Int, relToCSA: Int, monthsIn: Int, unionStability: Int, csaStability: Int) -> Double {
        let diplomacy = Double(relToCSA - relToUnion) * 0.4
        let cotton = Double(max(0, monthsIn)) * 0.3                  // pressure builds over time
        let momentum = Double(csaStability - unionStability) * 0.3   // a faltering Union invites recognition
        return diplomacy + cotton + momentum
    }

    /// A power recognizes a side once its lean passes ±`threshold`.
    static func recognizedSide(lean: Double, threshold: Double = 35) -> Side? {
        lean >= threshold ? .confederacy : (lean <= -threshold ? .union : nil)
    }
}
