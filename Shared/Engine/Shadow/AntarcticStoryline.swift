//
//  AntarcticStoryline.swift
//  Global Thermal Nuclear War
//
//  3.36.0: Antarctica as a storyline, not just a flag. On top of the 3.10.0 claim (Antarctica.swift):
//  - Research stations (an order, from 1904, the year the first permanent base opened): they cost money and upkeep,
//    pay science prestige at once and a little every year. Money comes only through land development (ReportBooks.swift):
//    while the President holds the ice, each station counts as one INVEST.
//  - The Antarctic Treaty (signed 1 Dec 1959, in force 23 Jun 1961) as diplomacy: withdraw (Article XII: it takes
//    effect two years after notice), rejoin, or renegotiate for a larger role. A withdrawn nation's claim no longer
//    breaks a treaty it is in; a successful renegotiation softens it too.
//  - Rival expeditions and counter-claims: the seven historical claims land as news, or as counter-claims when the
//    President already flies a flag there; every austral summer a rival lands a party on ground he claims.
//  - The ice: historical news (the Pole, the IGY, the treaty, the Madrid Protocol, the Larsen ice shelves), ice
//    shelves that wreck stations, and a stranded field party the cabinet must decide how to rescue.
//  - The penguins, who were not consulted about the new name.
//  - A name carried over: the last name the President gave Antarctica in any game (the Hall of Cartography) is
//    offered back at the start and goes up with the flag.
//  Everything is scheduled by the calendar, never drawn from the RNG, so a seed plays the same game.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// One research station.
struct AntarcticStation: Codable, Equatable, Hashable, Sendable {
    var site: String
    var built: Date
}

/// The President's Antarctic programme and treaty standing (on `ShadowState.antarctic`).
struct AntarcticProgram: Codable, Equatable, Sendable {
    var stations: [AntarcticStation] = []
    /// Withdrawal notice given on this date; it takes effect `Antarctica.withdrawalYears` later. nil = a party.
    var treatyNotice: Date?
    /// A renegotiation the parties accepted, and the last attempt (accepted or not).
    var renegotiated: Date?
    var lastRenegotiation: Date?
    /// A name from an earlier game: offered at the start (`offeredName`), applied when Antarctica is claimed (`restoredName`).
    var offeredName: String?
    var restoredName: String?
    /// The penguins' protests so far (picks the next line), the stranded parties rescued (or not).
    var penguinProtests = 0
    var rescues = 0
    var rescuePending = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case stations, treatyNotice, renegotiated, lastRenegotiation, offeredName, restoredName, penguinProtests, rescues, rescuePending
    }

    /// Tolerant: every field falls back to its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stations = (try? c.decodeIfPresent([AntarcticStation].self, forKey: .stations)) ?? []
        treatyNotice = try? c.decodeIfPresent(Date.self, forKey: .treatyNotice)
        renegotiated = try? c.decodeIfPresent(Date.self, forKey: .renegotiated)
        lastRenegotiation = try? c.decodeIfPresent(Date.self, forKey: .lastRenegotiation)
        offeredName = try? c.decodeIfPresent(String.self, forKey: .offeredName)
        restoredName = try? c.decodeIfPresent(String.self, forKey: .restoredName)
        penguinProtests = (try? c.decodeIfPresent(Int.self, forKey: .penguinProtests)) ?? 0
        rescues = (try? c.decodeIfPresent(Int.self, forKey: .rescues)) ?? 0
        rescuePending = (try? c.decodeIfPresent(Bool.self, forKey: .rescuePending)) ?? false
    }
}

/// Where the President's nation stands with the Antarctic Treaty.
enum AntarcticStanding: Equatable {
    /// Before 1 Dec 1959: there is no treaty.
    case noTreaty
    case party
    /// Notice given; still bound until the date.
    case withdrawing(until: Date)
    case withdrawn

    var label: String {
        switch self {
        case .noTreaty: return "No Antarctic Treaty yet: open exploration and rival claims"
        case .party: return "Party to the Antarctic Treaty"
        case .withdrawing(let d): return "Withdrawing from the Antarctic Treaty (effective \(GameCalendar.format(d)))"
        case .withdrawn: return "Outside the Antarctic Treaty"
        }
    }
}

/// The orders the Antarctic programme takes (the command box's `OrderKind.antarctic`, `GameOrder.mission`).
enum AntarcticOrder: String, CaseIterable, Sendable {
    case station, join, leave, renegotiate

    var verb: CommandVerb {
        switch self {
        case .station: return .researchStation
        case .join: return .joinAntarcticTreaty
        case .leave: return .leaveAntarcticTreaty
        case .renegotiate: return .renegotiateAntarcticTreaty
        }
    }

    var title: String {
        switch self {
        case .station: return "RESEARCH STATION"
        case .join: return "SIGN THE ANTARCTIC TREATY"
        case .leave: return "LEAVE THE ANTARCTIC TREATY"
        case .renegotiate: return "RENEGOTIATE THE ANTARCTIC TREATY"
        }
    }

    /// For the chief of staff's actions tool (bare verbs: its reply is capped, and the country tool explains them).
    static let hints = ["researchStation", "joinAntarcticTreaty", "leaveAntarcticTreaty", "renegotiateAntarcticTreaty (Antarctica)"]
}

extension CommandVerb {
    var antarcticOrder: AntarcticOrder? { AntarcticOrder.allCases.first { $0.verb == self } }
}

extension Antarctica {
    /// Orcadas (1904), the first permanent base on the ice or its islands.
    static let firstStationYear = 1904
    static let maxStations = 6
    /// Article XII(2)(b): a withdrawal takes effect two years after notice.
    static let withdrawalYears = 2
    static let renegotiationCooldownYears = 5
    /// The twelve original signatories (the Soviet Union is RUS on the board).
    static let signatories = ["ARG", "AUS", "BEL", "CHL", "FRA", "JPN", "NZL", "NOR", "ZAF", "RUS", "GBR", "USA"]
    /// The seven claims by nation id, with the name each gave its sector.
    static let claimSectors: [(id: String, nation: String, year: Int, sector: String)] = [
        ("GBR", "United Kingdom", 1908, "the Falkland Islands Dependencies"), ("NZL", "New Zealand", 1923, "the Ross Dependency"),
        ("FRA", "France", 1924, "Adélie Land"), ("AUS", "Australia", 1933, "the Australian Antarctic Territory"),
        ("NOR", "Norway", 1939, "Queen Maud Land"), ("CHL", "Chile", 1940, "the Chilean Antarctic Territory"),
        ("ARG", "Argentina", 1943, "Argentine Antarctica"),
    ]
    /// Where stations go, in order (the Pole only once aircraft can supply it, from 1956).
    static let sites = ["Ross Island", "the Bay of Whales", "the Antarctic Peninsula", "the South Pole", "Marie Byrd Land",
                        "Ellsworth Land", "Wilkes Land", "Queen Maud Land"]

    /// $B to build a station in a year; upkeep is a tenth of it a year.
    static func stationCost(year: Int) -> Double { year < 1946 ? 0.02 : (year < 1990 ? 0.15 : 0.4) }
    static let upkeepShare = 0.1

    /// Dated news (neutral history). Only the window a turn covers is posted, so a game started later never sees it.
    static let history: [(date: Date, text: String, severity: Int)] = [
        (GameCalendar.date(year: 1911, month: 12, day: 14), "Roald Amundsen's Norwegian party reaches the South Pole.", 2),
        (GameCalendar.date(year: 1912, month: 1, day: 17), "Robert Falcon Scott's British party reaches the South Pole, five weeks after Amundsen. None of the five survive the march back.", 2),
        (GameCalendar.date(year: 1929, month: 11, day: 29), "Richard E. Byrd's expedition makes the first flight over the South Pole.", 1),
        (GameCalendar.date(year: 1957, month: 7, day: 1), "The International Geophysical Year begins. Twelve nations run research stations in Antarctica.", 1),
        (GameCalendar.date(year: 1959, month: 12, day: 1), "Twelve nations sign the Antarctic Treaty in Washington: the continent is for peace and science, and every claim is frozen.", 2),
        (GameCalendar.date(year: 1961, month: 6, day: 23), "The Antarctic Treaty enters into force.", 1),
        (GameCalendar.date(year: 1991, month: 10, day: 4), "The Madrid Protocol is signed: Antarctica is a natural reserve, and mining is banned.", 1),
        (GameCalendar.date(year: 1998, month: 1, day: 14), "The Madrid Protocol enters into force.", 1),
        (GameCalendar.date(year: 1995, month: 1, day: 31), "The Larsen A ice shelf on the Antarctic Peninsula breaks apart.", 2),
        (GameCalendar.date(year: 2002, month: 3, day: 7), "The Larsen B ice shelf, about 3,250 square kilometers, collapses in weeks.", 2),
        (GameCalendar.date(year: 2017, month: 7, day: 12), "An iceberg about 5,800 square kilometers breaks away from the Larsen C ice shelf.", 2),
    ]
    /// The historical ice-shelf dates above (they hit stations); from 2030 another every seven years.
    static let iceShelfDates: Set<Date> = [GameCalendar.date(year: 1995, month: 1, day: 31), GameCalendar.date(year: 2002, month: 3, day: 7),
                                           GameCalendar.date(year: 2017, month: 7, day: 12)]

    /// The penguins were not consulted. One line a season while the continent carries another name.
    static let penguinLines = [
        "Emperor penguins at Cape Crozier were not consulted about the new name. They are standing very still about it.",
        "Adélie penguins at Cape Adare stage a sit-in over the renaming. Observers say it looks much like any other day.",
        "A colony of chinstrap penguins turns its back on the survey ship. Scientists note that this is also how they stand in the wind.",
        "Gentoo penguins on the Antarctic Peninsula decline to use the new name on any of their pebbles.",
        "The penguins have issued no statement. Their silence is being widely read as disapproval.",
        "A delegation of emperor penguins waddles up to the station door, waits, and leaves. Its message is under analysis.",
        "The penguin protest enters another season. Their demands remain unclear; their resolve does not.",
        "Adélie penguins march past the flagpole in single file. Officials insist it is the usual route to the sea.",
    ]
    static let penguinsPleased = "The penguins appear satisfied with the old name. Normal waddling resumes."
}

// MARK: - The name carried over

/// The last name the President gave Antarctica in any game (the Hall of Cartography), if it is worth offering back.
enum AntarcticaNames {
    /// Off in the headless engine (the golden games and the soak stay identical) and under XCTest unless a test turns
    /// it on (one test's rename must not put a card in the next test's game).
    #if GTNW_CORE
    nonisolated(unsafe) static var offers = false
    #else
    nonisolated(unsafe) static var offers = !AudioGate.underXCTest
    #endif

    /// Valid, not the plain name, inside the content rules.
    static func last() -> String? {
        guard offers, let raw = CartographyHall.lastName(forLand: Antarctica.id), let n = CombatModel.validTerritoryName(raw),
              n != Antarctica.template.name, !ChatSafety.violates(n) else { return nil }
        return n
    }
}

// MARK: - Standing

extension GameState {
    var antarcticStanding: AntarcticStanding {
        if currentDate < Antarctica.treatySigned { return .noTreaty }
        guard let notice = shadow.antarctic.treatyNotice else { return .party }
        let until = GameCalendar.calendar.date(byAdding: .year, value: Antarctica.withdrawalYears, to: notice) ?? notice
        return currentDate < until ? .withdrawing(until: until) : .withdrawn
    }

    /// What claiming Antarctica means today for this President: the treaty's dates, softened once he is out of the
    /// treaty or has renegotiated a larger role (bad faith, not a breach).
    var antarcticClaimStatus: LegalStatus {
        let base = Antarctica.legalStatus(on: currentDate)
        guard base == .treatyBanned else { return base }
        if antarcticStanding == .withdrawn || shadow.antarctic.renegotiated != nil { return .restricted }
        return base
    }

    /// The flag over Antarctica: nil while nobody holds it.
    var antarcticaOwner: String? { getCountry(id: Antarctica.id).flatMap { $0.isDestroyed ? nil : $0.territoryOf } }
}

// MARK: - Orders

extension GameEngine {
    private func ownWord(_ gs: GameState) -> String {
        gs.playerCountryID == "USA" ? "U.S." : (gs.getPlayerCountry()?.name ?? "U.S.")
    }

    private func signatoryIDs(_ gs: GameState) -> [String] {
        Antarctica.signatories.filter { id in id != gs.playerCountryID && gs.getCountry(id: id).map { !$0.isDestroyed && !$0.isTerritory } == true }
    }

    /// The next station's site, or nil when the ice is full.
    func nextAntarcticSite(_ gs: GameState) -> String? {
        let used = Set(gs.shadow.antarctic.stations.map(\.site))
        return Antarctica.sites.first { !used.contains($0) && ($0 != "the South Pole" || gs.currentYear >= 1956) }
    }

    /// Will the parties agree to renegotiate? Deterministic: two stations and the original signatories' goodwill.
    func renegotiationOutlook(_ gs: GameState) -> (agrees: Bool, why: String) {
        let ids = signatoryIDs(gs)
        let avg = ids.isEmpty ? 0 : ids.map { gs.getCountry(id: $0)?.diplomaticRelations[gs.playerCountryID] ?? 0 }.reduce(0, +) / ids.count
        let stations = gs.shadow.antarctic.stations.count
        if stations < 2 { return (false, "The parties listen to those who do the science: \(stations) station\(stations == 1 ? "" : "s"), and they want at least 2.") }
        if avg < 10 { return (false, "The original signatories' goodwill averages \(avg); they want at least 10.") }
        return (true, "With \(stations) stations and goodwill averaging \(avg), the parties are ready to agree.")
    }

    /// Why an Antarctic order can't be given now, or nil.
    func antarcticProblem(_ op: AntarcticOrder) -> String? {
        guard let gs = gameState else { return "No game in progress." }
        let year = gs.currentYear
        let program = gs.shadow.antarctic
        switch op {
        case .station:
            if year < Antarctica.firstStationYear { return "No nation keeps a permanent base on the ice in \(year). An expedition can claim the land instead." }
            if let owner = gs.antarcticaOwner, owner != gs.playerCountryID { return "\(gs.getCountry(id: owner)?.name ?? owner) holds Antarctica in \(year)." }
            if program.stations.count >= Antarctica.maxStations || nextAntarcticSite(gs) == nil {
                return "\(program.stations.count) stations already: the ice can't supply more."
            }
            return nil
        case .join, .leave, .renegotiate:
            let standing = gs.antarcticStanding
            if standing == .noTreaty { return "There is no Antarctic Treaty in \(year)." }
            switch (op, standing) {
            case (.join, .party): return "You are already a party to the Antarctic Treaty."
            case (.leave, .withdrawing(let d)): return "Notice is already given; the withdrawal takes effect on \(GameCalendar.format(d))."
            case (.leave, .withdrawn): return "You have already left the Antarctic Treaty."
            case (.renegotiate, .party):
                if gs.currentDate < Antarctica.treatyInForce { return "The Antarctic Treaty is not yet in force." }
                if let d = program.renegotiated { return "The parties renegotiated with you on \(GameCalendar.format(d)); they won't reopen it." }
                if let last = program.lastRenegotiation,
                   let next = GameCalendar.calendar.date(byAdding: .year, value: Antarctica.renegotiationCooldownYears, to: last), gs.currentDate < next {
                    return "The parties turned you down on \(GameCalendar.format(last)); they won't meet again before \(GameCalendar.format(next))."
                }
                return nil
            case (.renegotiate, _): return "Only a party can renegotiate the treaty: rejoin it first."
            default: return nil
            }
        }
    }

    func antarcticProblem(_ o: GameOrder) -> String? {
        guard o.target == Antarctica.id, let op = o.mission.flatMap(AntarcticOrder.init(rawValue:)) else { return "Not an Antarctic order." }
        if gameState?.gameOver == true { return "The game is over." }
        return antarcticProblem(op)
    }

    /// The command box's card for an Antarctic order. Any target named must be Antarctica (under any name).
    func planAntarctic(_ op: AntarcticOrder, intent: CommandIntent, source: CommandSource) -> CommandOutcome {
        guard let gs = gameState else { return .rejected("Start a game first.") }
        for name in (intent.confirmedTargets ?? intent.targets).prefix(CommandParser.maxTargets) {
            guard case .one(let t, _) = CommandTargets.resolve(name, in: gs), t.id == Antarctica.id else {
                return .rejected("That order is for Antarctica, not \(String(CommandParser.sanitize(name).prefix(40))).")
            }
        }
        if let p = antarcticProblem(op) { return .rejected(p) }
        let shown = gs.getCountry(id: Antarctica.id)?.name ?? "Antarctica"
        var plan = CommandPlan(title: op.title, target: (shown == "Antarctica" ? shown : "\(shown) (Antarctica)") + ", \(gs.currentYear)",
                               orders: [GameOrder(kind: .antarctic, target: Antarctica.id, mission: op.rawValue)], committed: [], heldBack: [],
                               warnings: [], actionsNeeded: 1, actionsLeft: gs.actionsRemaining, source: source)
        let cost = Antarctica.stationCost(year: gs.currentYear)
        switch op {
        case .station:
            plan.committed.append(String(format: "Build a %@ at %@: $%.2fB now, $%.3fB a year to run.", gs.currentYear < 1946 ? "base" : "research station",
                                         nextAntarcticSite(gs) ?? "", cost, cost * Antarctica.upkeepShare))
            plan.warnings.append(CommandWarning(text: "Science prestige at home at once and every year. On ice you hold, it counts as development (one INVEST).", level: 0))
        case .join:
            plan.committed.append("Sign the Antarctic Treaty: Antarctica for peace and science, claims frozen.")
            plan.warnings.append(CommandWarning(text: "The original signatories welcome it (relations +5). A claim breaks the treaty again.", level: 0))
        case .leave:
            plan.committed.append("Give notice of withdrawal from the Antarctic Treaty. It takes effect in \(Antarctica.withdrawalYears) years (Article XII).")
            plan.warnings.append(CommandWarning(text: "The original signatories −8, everyone else −2, approval −2. Once out, a claim is bad faith rather than a breach.", level: 2))
        case .renegotiate:
            let o = renegotiationOutlook(gs)
            plan.committed.append("Ask the consultative parties for a larger role on the ice.")
            plan.warnings.append(CommandWarning(text: o.why + (o.agrees ? " A claim is no longer a breach."
                                                                          : " A refusal costs goodwill (−2) and they won't meet again for \(Antarctica.renegotiationCooldownYears) years."),
                                                level: o.agrees ? 0 : 1))
        }
        if plan.actionsLeft < 1 { plan.warnings.append(CommandWarning(text: "No actions left this turn.", level: 2)) }
        return .plan(plan)
    }

    /// Carry out an Antarctic order (one action). False when it can't be given now.
    @discardableResult
    func runAntarcticOrder(_ op: AntarcticOrder) -> Bool {
        guard antarcticProblem(op) == nil, let gs = gameState, gs.actionsRemaining > 0, !gs.gameOver else { return false }
        let own = ownWord(gs)
        let year = gs.currentYear
        switch op {
        case .station:
            guard let site = nextAntarcticSite(gs) else { return false }
            let cost = Antarctica.stationCost(year: year)
            spendFunds(cost)
            gs.shadow.antarctic.stations.append(AntarcticStation(site: site, built: gs.currentDate))
            creditStationsToDevelopment(gs)
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + (year >= 1957 ? 1 : 0.5))
            if gs.antarcticStanding == .party { for id in signatoryIDs(gs) { modifyDiplomaticRelation(from: id, to: gs.playerCountryID, by: 1) } }
            gs.shadow.post(year < 1946 ? "A \(own) expedition base is built at \(site), Antarctica." : "A \(own) research station opens at \(site), Antarctica.",
                           date: gs.currentDate, severity: 1)
            addLog(String(format: "🧊 Antarctic station at %@ ($%.2fB).", site, cost), type: .info)
            logPlayEvent("antarctic_station", detail: ["site": PlayHistory.text(site), "stations": gs.shadow.antarctic.stations.count,
                                                       "cost_b": PlayHistory.num(cost), "game_date": PlayHistory.day(gs.currentDate)])
        case .join:
            gs.shadow.antarctic.treatyNotice = nil
            for id in signatoryIDs(gs) { modifyDiplomaticRelation(from: id, to: gs.playerCountryID, by: 5) }
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 1)
            let frozen = gs.antarcticaOwner == gs.playerCountryID ? " The \(own) claim is frozen, not renounced." : ""
            gs.shadow.post("The \(own) government signs the Antarctic Treaty again.\(frozen)", date: gs.currentDate, severity: 1)
            addLog("🧊 Antarctic Treaty signed.", type: .info)
            logPlayEvent("antarctic_treaty", detail: ["step": "join", "game_date": PlayHistory.day(gs.currentDate)])
        case .leave:
            gs.shadow.antarctic.treatyNotice = gs.currentDate
            let signers = Set(signatoryIDs(gs))
            for c in gs.countries where c.id != gs.playerCountryID && !c.isDestroyed && !c.isTerritory {
                modifyDiplomaticRelation(from: c.id, to: gs.playerCountryID, by: signers.contains(c.id) ? -8 : -2)
            }
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 2)
            gs.shadow.ruthlessness += 5
            gs.shadow.post("The \(own) government gives notice of withdrawal from the Antarctic Treaty. It takes effect in \(Antarctica.withdrawalYears) years.",
                           date: gs.currentDate, severity: 2)
            addLog("🧊 Notice of withdrawal from the Antarctic Treaty.", type: .warning)
            logPlayEvent("antarctic_treaty", detail: ["step": "leave", "game_date": PlayHistory.day(gs.currentDate)])
        case .renegotiate:
            let o = renegotiationOutlook(gs)
            gs.shadow.antarctic.lastRenegotiation = gs.currentDate
            if o.agrees {
                gs.shadow.antarctic.renegotiated = gs.currentDate
                for id in signatoryIDs(gs) { modifyDiplomaticRelation(from: id, to: gs.playerCountryID, by: 3) }
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 2)
                gs.shadow.post("The Antarctic Treaty's consultative parties agree to a larger \(own) role on the ice.", date: gs.currentDate, severity: 2)
            } else {
                for id in signatoryIDs(gs) { modifyDiplomaticRelation(from: id, to: gs.playerCountryID, by: -2) }
                gs.shadow.post("The Antarctic Treaty's consultative parties decline to reopen the treaty for the \(own) government.", date: gs.currentDate, severity: 1)
            }
            addLog(o.agrees ? "🧊 The Antarctic Treaty is renegotiated." : "🧊 The parties refuse to renegotiate.", type: o.agrees ? .info : .warning)
            logPlayEvent("antarctic_treaty", detail: ["step": "renegotiate", "agreed": o.agrees, "game_date": PlayHistory.day(gs.currentDate)])
        }
        self.gameState = gs
        completePlayerAction()
        return true
    }

    // MARK: Hooks

    /// After Antarctica is claimed (`claimLand`): the claimants of the day restate their own claims, and a name
    /// carried over from an earlier game is put on the map.
    func antarcticaClaimed() {
        guard let gs = gameState, gs.antarcticaOwner == gs.playerCountryID else { return }
        creditStationsToDevelopment(gs)   // stations built before the flag are its development
        let rivals = Antarctica.claimSectors.filter { $0.year <= gs.currentYear && $0.id != gs.playerCountryID && gs.getCountry(id: $0.id).map { !$0.isDestroyed } == true }
        if !rivals.isEmpty {
            for r in rivals { modifyDiplomaticRelation(from: r.id, to: gs.playerCountryID, by: -3) }
            gs.shadow.post("\(rivals.map { gs.getCountry(id: $0.id)?.name ?? $0.nation }.joined(separator: ", ")) reject the \(ownWord(gs)) claim and restate their own.",
                           date: gs.currentDate, severity: 1)
        }
        self.gameState = gs
        if let name = gs.shadow.antarctic.restoredName { renameTerritory(Antarctica.id, to: name) }
    }

    /// After Antarctica is renamed (`renameTerritory`): the penguins react. (The Hall of Cartography keeps the name.)
    func antarcticaRenamed(to name: String) {
        guard let gs = gameState else { return }
        if name == Antarctica.template.name {
            gs.shadow.post(Antarctica.penguinsPleased, date: gs.currentDate, severity: 0)
        } else {
            postPenguinProtest(gs)
        }
        self.gameState = gs
    }

    private func postPenguinProtest(_ gs: GameState) {
        let lines = Antarctica.penguinLines
        gs.shadow.post(lines[gs.shadow.antarctic.penguinProtests % lines.count], date: gs.currentDate, severity: 0)
        gs.shadow.antarctic.penguinProtests += 1
    }

    /// At the start of a new game: offer back the name the President gave Antarctica last time.
    func offerAntarcticName() {
        guard let gs = gameState, !spectating, !gs.isMultiplayer, let name = AntarcticaNames.last() else { return }
        gs.shadow.antarctic.offeredName = name
        self.gameState = gs
        var restore = CrisisConsequences(message: "When the flag goes up over Antarctica, it will be called \(name) again.")
        restore.shadowChoice = "antarctic|restore"
        var keep = CrisisConsequences(message: "Antarctica keeps its name.")
        keep.shadowChoice = "antarctic|keep"
        var card = CrisisEvent(type: .diplomaticIncident, severity: .minor, title: "A NAME FROM ANOTHER PRESIDENCY",
                               description: "Restore your name for Antarctica: \(name)?\n\nIn an earlier game you renamed the continent. "
                                + "Restored, the name goes up with the flag the day Antarctica is claimed.",
                               affectedCountries: [], turn: gs.turn,
                               options: [CrisisOption(title: "Restore \(name)", description: "Applied when Antarctica is claimed.", advisorRecommendation: "Chief of Staff", consequences: restore),
                                         CrisisOption(title: "Keep Antarctica", description: "Start fresh.", consequences: keep)])
        card.quoteTags = [.power, .leadership]
        crisisManager.presentCrisis(card)
    }

    /// A card's answer ("antarctic|restore", "antarctic|keep", "antarctic|rescue|fly", "antarctic|rescue|ask|GBR",
    /// "antarctic|rescue|wait"), from `ShadowChoice`.
    func resolveAntarcticChoice(_ f: [String]) {
        guard let gs = gameState, f.count >= 2 else { return }
        let own = ownWord(gs)
        switch f[1] {
        case "restore":
            guard let name = gs.shadow.antarctic.offeredName else { return }
            gs.shadow.antarctic.restoredName = name
            self.gameState = gs
            if gs.antarcticaOwner == gs.playerCountryID { renameTerritory(Antarctica.id, to: name) }
        case "keep":
            gs.shadow.antarctic.offeredName = nil
        case "rescue" where f.count >= 3 && gs.shadow.antarctic.rescuePending:
            gs.shadow.antarctic.rescuePending = false
            switch f[2] {
            case "fly":
                spendFunds(Antarctica.stationCost(year: gs.currentYear) * 0.5)
                gs.shadow.antarctic.rescues += 1
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 2)
                gs.shadow.post("The stranded \(own) field party is brought home. All eight are safe.", date: gs.currentDate, severity: 1)
            case "ask" where f.count >= 4:
                let id = f[3]
                gs.shadow.antarctic.rescues += 1
                modifyDiplomaticRelation(from: id, to: gs.playerCountryID, by: 6)
                modifyDiplomaticRelation(from: gs.playerCountryID, to: id, by: 6)
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 1)
                gs.shadow.post("A team from \(gs.getCountry(id: id)?.name ?? id)'s nearest station reaches the stranded \(own) party. All eight are safe.",
                               date: gs.currentDate, severity: 1)
            default:
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 3)
                gs.shadow.post("The storms pass and the stranded \(own) party is reached. Two of the eight did not survive the wait.", date: gs.currentDate, severity: 2)
            }
            logPlayEvent("antarctic_rescue", detail: ["choice": f[2], "game_date": PlayHistory.day(gs.currentDate)])
        default:
            return
        }
        self.gameState = gs
    }

    // MARK: Each turn

    /// On ice the President holds, each station counts as one INVEST (B's land development): Antarctica pays only
    /// once developed, and the stations are that development. Never lowers what INVEST orders bought.
    func creditStationsToDevelopment(_ gs: GameState) {
        guard gs.antarcticaOwner == gs.playerCountryID else { return }
        let n = Double(gs.shadow.antarctic.stations.count) * LandDevelopment.investYears
        if n > LandDevelopment.bought(Antarctica.id, in: gs) { gs.shadow.books.developed[Antarctica.id] = n }
    }

    /// Each turn: stations' upkeep and prestige (and development on held ice); the dated history; and once a season (1 Dec, the austral
    /// summer) a rival expedition, a stranded party, or the penguins. Calendar-driven, no RNG.
    func processAntarcticStoryline() {
        guard let gs = gameState, !gs.gameOver else { return }
        let from = gs.previousTurnDate, to = gs.currentDate
        guard to > from else { return }
        let own = ownWord(gs)
        let years = gs.turnLength.yearFraction
        let year = gs.currentYear

        // Stations: upkeep and prestige.
        let stations = gs.shadow.antarctic.stations
        if !stations.isEmpty {
            let cost = Antarctica.stationCost(year: year)
            spendFunds(Double(stations.count) * cost * Antarctica.upkeepShare * years)
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 0.15 * Double(min(stations.count, 4)) * years)
        }
        creditStationsToDevelopment(gs)

        // The dated history, and the claims of the day (counter-claims when the President already holds the ice).
        for h in Antarctica.history where GameCalendar.window(from: from, to: to, contains: h.date) {
            gs.shadow.post(h.text, date: to, severity: h.severity)
            if Antarctica.iceShelfDates.contains(h.date) { iceShelfDamage(gs) }
        }
        let held = gs.antarcticaOwner == gs.playerCountryID
        for c in Antarctica.claimSectors where c.id != gs.playerCountryID
            && GameCalendar.window(from: from, to: to, contains: GameCalendar.date(year: c.year, month: 1, day: 1)) {
            let rival = gs.getCountry(id: c.id).flatMap { $0.isDestroyed ? nil : $0 }
            let name = rival?.name ?? c.nation
            if held {
                if rival != nil { modifyDiplomaticRelation(from: c.id, to: gs.playerCountryID, by: -5) }
                gs.shadow.post("\(name) claims \(c.sector), rejecting the \(own) claim to Antarctica.", date: to, severity: 2)
            } else {
                gs.shadow.post("\(name) claims a sector of Antarctica as \(c.sector).", date: to, severity: 1)
            }
        }
        // From 2030, another ice shelf breaks up every seven years (1 Feb).
        for y in max(2030, GameCalendar.year(of: from))...max(2030, year) where y % 7 == 0
            && GameCalendar.window(from: from, to: to, contains: GameCalendar.date(year: y, month: 2, day: 1)) {
            gs.shadow.post("Another ice shelf on the Antarctic Peninsula breaks up as the ocean warms.", date: to, severity: 2)
            iceShelfDamage(gs)
        }

        // The austral summer (1 Dec): rivals, rescues, penguins.
        for y in GameCalendar.year(of: from)...year where GameCalendar.window(from: from, to: to, contains: GameCalendar.date(year: y, month: 12, day: 1)) {
            season(y, gs)
        }
        self.gameState = gs
    }

    private func iceShelfDamage(_ gs: GameState) {
        let n = gs.shadow.antarctic.stations.count
        guard n > 0 else { return }
        let repair = Antarctica.stationCost(year: gs.currentYear) * 0.25 * Double(min(n, 2))
        spendFunds(repair)
        gs.shadow.post(String(format: "Collapsing ice damages %@ stations on the Peninsula: $%.2fB to repair. The scientists' measurements make headlines.",
                              ownWord(gs), repair), date: gs.currentDate, severity: 1)
    }

    /// The year (presence) began: the claim or the first station.
    private func presenceSince(_ gs: GameState) -> Date? {
        var dates = gs.shadow.antarctic.stations.map(\.built)
        if gs.antarcticaOwner == gs.playerCountryID, let d = gs.shadow.claimDates[Antarctica.id] { dates.append(d) }
        return dates.min()
    }

    private func season(_ y: Int, _ gs: GameState) {
        let own = ownWord(gs)
        let held = gs.antarcticaOwner == gs.playerCountryID
        // A rival lands a party on ground the President claims.
        if held {
            var rivals = Antarctica.claimSectors.filter { $0.year <= y }.map(\.id)
            if y >= 1956 { rivals.append("RUS") }
            if y >= 1985 { rivals.append("CHN") }
            let present = rivals.filter { $0 != gs.playerCountryID && gs.getCountry(id: $0).map { !$0.isDestroyed && !$0.isTerritory } == true }
            if !present.isEmpty {
                let id = present[y % present.count]
                let name = gs.getCountry(id: id)?.name ?? id
                let site = Antarctica.sites[y % Antarctica.sites.count]
                modifyDiplomaticRelation(from: id, to: gs.playerCountryID, by: -2)
                gs.shadow.post(y < 1959 ? "Rival expedition: \(name) lands a party near \(site) and calls the \(own) claim void."
                               : "Rival expedition: \(name) opens a summer camp near \(site) and protests the \(own) claim under the Antarctic Treaty.",
                               date: gs.currentDate, severity: 1)
            }
            if gs.getCountry(id: Antarctica.id)?.name != Antarctica.template.name { postPenguinProtest(gs) }
        } else if !gs.shadow.antarctic.stations.isEmpty, gs.antarcticStanding == .party, y >= 1961, y % 4 == 0 {
            gs.shadow.post("Treaty inspectors visit the \(own) station at \(gs.shadow.antarctic.stations[0].site) and find it in order.", date: gs.currentDate, severity: 0)
        }
        // A stranded field party: the first summer after arriving, then every fifth.
        if let since = presenceSince(gs), !gs.shadow.antarctic.rescuePending {
            let n = y - GameCalendar.year(of: since)
            if n >= 1, n % 5 == 1 { presentRescue(gs) }
        }
    }

    private func presentRescue(_ gs: GameState) {
        let year = gs.currentYear
        let own = ownWord(gs)
        let site = gs.shadow.antarctic.stations.last?.site ?? "the coast"
        gs.shadow.antarctic.rescuePending = true
        let fly = year < 1928 ? "Send a relief ship" : (year < 1956 ? "Send a relief ship and aircraft" : "Fly a rescue mission")
        let military = year < 1947 ? "Secretary of the Navy" : "Secretary of Defense"
        func option(_ title: String, _ what: String, _ who: String?, _ choice: String, _ msg: String) -> CrisisOption {
            var k = CrisisConsequences(message: msg)
            k.shadowChoice = "antarctic|rescue|" + choice
            return CrisisOption(title: title, description: what, advisorRecommendation: who, consequences: k)
        }
        var options = [option(fly, String(format: "About $%.2fB. Risky flying, but they come home.", Antarctica.stationCost(year: year) * 0.5),
                              military, "fly", "\(fly).")]
        // The nearest friendly station: the claimant or Antarctic power that likes us best.
        var helpers = Antarctica.claimSectors.filter { $0.year <= year }.map(\.id)
        if year >= 1956 { helpers.append("RUS") }
        func rel(_ id: String) -> Int { gs.getCountry(id: id)?.diplomaticRelations[gs.playerCountryID] ?? 0 }
        let friend = helpers.filter { $0 != gs.playerCountryID && gs.getCountry(id: $0).map { !$0.isDestroyed && !$0.isTerritory } == true }
            .sorted { (-rel($0), $0) < (-rel($1), $1) }.first
        if let friend, let c = gs.getCountry(id: friend) {
            options.append(option("Ask \(c.name) for help", "Their station is closer. No cost; it owes them a favor, and both sides remember it.",
                                  "Secretary of State", "ask|\(friend)", "The President asks \(c.name) for help."))
        }
        options.append(option("Wait for the weather", "No cost now. Storms on the ice can last weeks.", "Chief of Staff", "wait", "The rescue waits for the weather."))
        var card = CrisisEvent(type: .naturalDisaster, severity: .serious, title: "STRANDED ON THE ICE",
                               description: "A \(own) field party of eight is cut off by storms near \(site), Antarctica. Their supplies last three weeks. How do we bring them home?",
                               affectedCountries: [], turn: gs.turn, options: options)
        card.quoteTags = [.disaster, .mercy]
        gs.shadow.post("A \(own) field party is stranded by storms in Antarctica.", date: gs.currentDate, severity: 2)
        crisisManager.presentCrisis(card)
    }

    // MARK: The chief of staff

    /// What the chief of staff's `country` tool says about Antarctica: who holds it, the claims, the stations, the
    /// treaty standing, and the orders on offer.
    func antarcticReport() -> [String: Any] {
        guard let gs = gameState else { return [:] }
        let p = gs.shadow.antarctic
        let year = gs.currentYear
        var d: [String: Any] = ["treaty_standing": gs.antarcticStanding.label]
        if let owner = gs.antarcticaOwner {
            d["held_by"] = owner == gs.playerCountryID ? "you" : (gs.getCountry(id: owner)?.name ?? owner)
            if owner == gs.playerCountryID, let n = gs.getCountry(id: Antarctica.id)?.name, n != Antarctica.template.name { d["your_name_for_it"] = n }
        } else {
            d["held_by"] = "nobody"
            d["claiming_it_would_be"] = gs.antarcticClaimStatus.label.lowercased()
        }
        let claims = Antarctica.claims(by: year)
        d["other_claims"] = claims.isEmpty ? "none yet" : claims.joined(separator: ", ")
        d["your_stations"] = p.stations.map { "\($0.site) (\(GameCalendar.year(of: $0.built)))" }
        if year >= Antarctica.firstStationYear {
            d["station_cost_billions"] = ChatTools.round2(Antarctica.stationCost(year: year))
        }
        if let r = p.renegotiated { d["renegotiated"] = GameCalendar.format(r) }
        if let n = p.restoredName { d["name_to_restore_on_claim"] = n }
        d["orders"] = AntarcticOrder.allCases.map { op -> String in
            "\(op.verb.rawValue): " + (antarcticProblem(op) ?? "available")
        }
        return d
    }
}

// MARK: - What the dossier shows

extension Antarctica {
    /// The legal line under the claims, or nil when a claim is simply legal.
    static func statusLine(_ gs: GameState) -> String? {
        switch gs.antarcticClaimStatus {
        case .treatyBanned, .destroyed: return "TREATY-BANNED — Antarctic Treaty (in force 23 Jun 1961)"
        case .restricted:
            return gs.currentDate < treatyInForce ? "RESTRICTED — Antarctic Treaty signed 1 Dec 1959"
                : "RESTRICTED — no breach for you now, but the signatories call a claim bad faith"
        case .legal: return nil
        }
    }

    /// The programme in one or two lines: treaty standing, stations.
    static func programLines(_ gs: GameState) -> [String] {
        var out: [String] = []
        if gs.antarcticStanding != .noTreaty { out.append(gs.antarcticStanding.label + (gs.shadow.antarctic.renegotiated != nil ? ", with a larger role agreed." : ".")) }
        let s = gs.shadow.antarctic.stations
        if !s.isEmpty { out.append("Your stations: " + s.map { "\($0.site) (\(GameCalendar.year(of: $0.built)))" }.joined(separator: ", ") + ".") }
        return out
    }
}
