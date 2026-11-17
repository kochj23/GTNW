//
//  Outbreaks.swift
//  Global Thermal Nuclear War
//
//  Pandemics (3.31.0), real and engineered, on one spread model. A disease moves turn by turn along the ties
//  between nations (land borders from the map outlines, alliances, the CIA World Factbook's top trading partners)
//  and each country it reaches goes through a wave that costs lives, output, stability and military readiness.
//  • The real pandemics arrive on their dates as world emergencies: the cholera pandemics of 1829, 1846 and 1863,
//    the 1918 influenza, the 1957 and 1968 influenza pandemics, the 2009 H1N1 pandemic and COVID-19. A game that
//    starts mid-pandemic begins with it under way. The President's response (quarantine or lockdown, a travel ban,
//    a vaccine programme where the era has one, aid abroad, or nothing) trades approval and output against deaths.
//    Severities are rough historical orders of magnitude, not estimates: real pandemics killed millions.
//  • An engineered pathogen is the rung after the covert-agents programme (CovertAgents.swift), gated by the
//    biological-weapons rules (a stockpile, or a restarted programme that has delivered). Released against a
//    nation it does not respect borders, and the programme itself can fail containment at home. A countermeasure
//    programme limits the blowback. A treaty violation after the Biological Weapons Convention (1975).
//  Abstract by design: no organism, method or quantity appears anywhere.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// One outbreak and where it has reached.
struct Outbreak: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var origin: String
    var started: Date
    var engineered = false
    /// Who released an engineered pathogen (nil = nature or unknown).
    var by: String?
    /// Share of a country's population that dies over a full wave.
    var lethality: Double
    /// Share of output lost over a full wave.
    var economy: Double
    /// Weekly chance of crossing one tie between nations.
    var spread: Double
    var waveWeeks: Double
    /// Country → weeks into its wave.
    var waves: [String: Double] = [:]
    var over: Set<String> = []
    /// The President's response, and when a vaccine programme delivers.
    var response: String?
    var vaccineReady: Date?
    var attributed = false
}

/// A pandemic of the record.
struct HistoricalPandemic {
    let id: String, name: String, origin: String, year: Int, month: Int
    let lethality: Double, economy: Double, spread: Double, waveWeeks: Double
    /// Years it runs: a game starting inside this window begins with it under way.
    let years: Int
    let text: String
}

enum Outbreaks {
    /// Design choices: orders of magnitude only (deaths over a wave as a share of population, output lost).
    static let record: [HistoricalPandemic] = [
        HistoricalPandemic(id: "cholera_1829", name: "Cholera pandemic", origin: "IND", year: 1829, month: 6, lethality: 0.003, economy: 0.01, spread: 0.01, waveWeeks: 40, years: 4,
                           text: "Cholera spreads out of Bengal along the trade and pilgrim routes. It will reach Russia, Europe and North America."),
        HistoricalPandemic(id: "cholera_1846", name: "Cholera pandemic", origin: "IND", year: 1846, month: 6, lethality: 0.003, economy: 0.01, spread: 0.012, waveWeeks: 40, years: 4,
                           text: "Cholera moves west again from India. In London in 1854 John Snow will trace an outbreak to a single water pump."),
        HistoricalPandemic(id: "cholera_1863", name: "Cholera pandemic", origin: "IND", year: 1863, month: 6, lethality: 0.002, economy: 0.01, spread: 0.015, waveWeeks: 40, years: 4,
                           text: "A fifth decade of cholera: pilgrims and steamships carry it from the Ganges delta to Mecca, Europe and the Americas."),
        HistoricalPandemic(id: "influenza_1918", name: "1918 influenza pandemic", origin: "USA", year: 1918, month: 3, lethality: 0.02, economy: 0.04, spread: 0.05, waveWeeks: 30, years: 2,
                           text: "A new influenza is recorded at Camp Funston, Kansas; where it began is still debated. Troopships carry it to every front. It will kill tens of millions."),
        HistoricalPandemic(id: "influenza_1957", name: "1957 influenza pandemic", origin: "CHN", year: 1957, month: 2, lethality: 0.0004, economy: 0.01, spread: 0.04, waveWeeks: 20, years: 2,
                           text: "A new influenza spreads from southern China. A vaccine is rushed into production within months."),
        HistoricalPandemic(id: "influenza_1968", name: "1968 influenza pandemic", origin: "CHN", year: 1968, month: 7, lethality: 0.0003, economy: 0.005, spread: 0.04, waveWeeks: 20, years: 2,
                           text: "A new influenza strain is identified in Hong Kong and spreads around the world within a year."),
        HistoricalPandemic(id: "h1n1_2009", name: "2009 H1N1 pandemic", origin: "MEX", year: 2009, month: 4, lethality: 0.00005, economy: 0.005, spread: 0.06, waveWeeks: 20, years: 1,
                           text: "A new H1N1 influenza is identified in Mexico and the United States. The WHO declares a pandemic in June."),
        HistoricalPandemic(id: "covid_2020", name: "COVID-19 pandemic", origin: "CHN", year: 2020, month: 1, lethality: 0.001, economy: 0.05, spread: 0.06, waveWeeks: 104, years: 3,
                           text: "A novel coronavirus first identified in Wuhan spreads worldwide. Whether it began as a natural spillover from animals or in a laboratory accident remains unresolved."),
    ]

    static func start(_ p: HistoricalPandemic) -> Date { GameCalendar.date(year: p.year, month: p.month, day: 1) }

    /// Engineered pathogen: design choices for a severe wave.
    static let engineeredLethality = 0.01
    static let engineeredEconomy = 0.04
    static let engineeredSpread = 0.04
    static let engineeredWeeks = 26.0
    /// $B and years for the home countermeasure programme.
    static let countermeasureCost = 3.0
    /// Chance a year the pathogen programme fails containment at home (halved with a countermeasure ready).
    static let containmentAnnual = 0.04
    /// Under tests rivals don't release pathogens unless a test asks.
    nonisolated(unsafe) static var aiEnabled = !GameStoreService.isTestOrSmokeRun

    /// The President's responses, by era.
    static func responses(year: Int) -> [String] {
        ["quarantine", "travel_ban"] + (year >= 1945 ? ["vaccine"] : []) + ["aid", "ignore"]
    }

    static func responseTitle(_ r: String, year: Int) -> String {
        switch r {
        case "quarantine": return year >= 1950 ? "Lockdown and closures" : "Quarantine the ports and cities"
        case "travel_ban": return "Close the borders to travel"
        case "vaccine": return "A crash vaccine programme"
        case "aid": return "Send doctors and supplies abroad"
        default: return "Carry on as normal"
        }
    }

    /// Ties a disease can cross from a country.
    static func ties(_ id: String, in gs: GameState) -> Set<String> {
        var out = Reach.landNeighbors(id, in: gs).union(gs.getCountry(id: id)?.alliances ?? [])
        if WorldFactbookDatabase.records[id] != nil { out.formUnion(WorldFactbookDatabase.record(for: id).topTradingPartners) }
        out.remove(id)
        return out
    }

    /// How hard the President's response holds a disease off at home: spread into the country, and deaths.
    static func homeFactors(_ o: Outbreak, in gs: GameState) -> (spread: Double, deaths: Double, economy: Double) {
        var s = 1.0, d = 1.0, e = 1.0
        switch o.response {
        case "quarantine": s = 0.5; d = 0.5; e = 1.6
        case "travel_ban": s = 0.4
        case "vaccine": if let v = o.vaccineReady, v <= gs.currentDate { d = 0.4 }
        case "ignore": d = 1.3; e = 0.8
        default: break
        }
        if o.engineered, let c = gs.shadow.countermeasureReady, c <= gs.currentDate { s *= 0.4; d *= 0.5 }
        return (s, d, e)
    }
}

extension GameEngine {
    // MARK: Turn processing

    /// Each turn: the record's pandemics begin on their dates; every outbreak spreads and runs its waves.
    func processOutbreaks() {
        guard let gs = gameState else { return }
        for p in Outbreaks.record where !gs.shadow.firedRivalries.contains("pandemic-\(p.id)") {
            let start = Outbreaks.start(p)
            let end = GameCalendar.calendar.date(byAdding: .year, value: p.years, to: start) ?? start
            guard start <= gs.currentDate else { continue }
            gs.shadow.firedRivalries.insert("pandemic-\(p.id)")
            guard gs.currentDate < end, gs.getCountry(id: p.origin) != nil else { continue }
            beginPandemic(p)
        }
        let turnWeeks = gs.turnLength.yearFraction * 52
        for k in gs.shadow.outbreaks.indices.reversed() {
            var o = gs.shadow.outbreaks[k]
            // Spread first, from every country in a wave.
            for (c, _) in o.waves.sorted(by: { $0.key < $1.key }) {
                for t in Outbreaks.ties(c, in: gs).sorted() where o.waves[t] == nil && !o.over.contains(t) {
                    guard let tc = gs.getCountry(id: t), !tc.isDestroyed else { continue }
                    let home = t == gs.playerCountryID ? Outbreaks.homeFactors(o, in: gs).spread : 1
                    let era = gs.currentYear < 1900 ? 0.5 : 1
                    let p = 1 - pow(1 - min(0.9, o.spread * home * era), turnWeeks)
                    if Double.random(in: 0..<1, using: &gs.rng) < p {
                        o.waves[t] = 0
                        if t == gs.playerCountryID {
                            gs.shadow.post("\(o.name) reaches \(tc.name).", date: gs.currentDate, severity: 3)
                        }
                    }
                }
            }
            // Then the waves.
            for (c, done) in o.waves.sorted(by: { $0.key < $1.key }) {
                let w = min(turnWeeks, max(0, o.waveWeeks - done))
                applyWave(o, country: c, weeks: w)
                if done + turnWeeks >= o.waveWeeks {
                    o.waves.removeValue(forKey: c)
                    o.over.insert(c)
                } else {
                    o.waves[c] = done + turnWeeks
                }
            }
            if o.waves.isEmpty {
                gs.shadow.outbreaks.remove(at: k)
                gs.shadow.post("The \(o.name.lowercased()) has run its course.", date: gs.currentDate, severity: 1)
                logPlayEvent("outbreak_over", detail: ["id": o.id, "countries": o.over.count, "game_date": PlayHistory.day(gs.currentDate)])
            } else {
                gs.shadow.outbreaks[k] = o
            }
        }
        self.gameState = gs
        processPathogenProgram()
    }

    /// A wave's toll for `weeks` in one country. Game stats only.
    func applyWave(_ o: Outbreak, country id: String, weeks w: Double) {
        guard w > 0, let gs = gameState, let i = gs.countries.firstIndex(where: { $0.id == id }) else { return }
        let f = w / o.waveWeeks
        let home = id == gs.playerCountryID ? Outbreaks.homeFactors(o, in: gs) : (spread: 1, deaths: 1, economy: 1)
        var c = gs.countries[i]
        gs.totalCasualties += Int(Double(max(1, c.population)) * 1_000_000 * o.lethality * f * home.deaths)
        c.gdp *= 1 - o.economy * f * home.economy
        c.stability = max(0, c.stability - Int(((5 + 300 * o.economy) * f).rounded()))
        c.militaryStrength = max(1, c.militaryStrength - Int((200 * o.lethality * f).rounded()))
        gs.countries[i] = c
        if id == gs.playerCountryID {
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 100 * o.lethality * f * home.deaths)
        }
        self.gameState = gs
    }

    /// A pandemic of the record begins; a game that starts inside its window finds it already under way.
    func beginPandemic(_ p: HistoricalPandemic) {
        guard let gs = gameState else { return }
        var o = Outbreak(id: p.id, name: p.name, origin: p.origin, started: Outbreaks.start(p), lethality: p.lethality, economy: p.economy,
                         spread: p.spread, waveWeeks: p.waveWeeks)
        let elapsed = Double(GameCalendar.days(from: Outbreaks.start(p), to: gs.currentDate)) / 7
        o.waves[p.origin] = min(p.waveWeeks - 1, max(0, elapsed))
        if elapsed > 8 {   // mid-pandemic start: it has already crossed its ties, the President's country among them
            for t in Outbreaks.ties(p.origin, in: gs).union([gs.playerCountryID]) where gs.getCountry(id: t) != nil {
                o.waves[t] = min(p.waveWeeks - 1, elapsed / 2)
            }
        }
        gs.shadow.outbreaks.append(o)
        let item = TickerItem(date: gs.currentDate, text: p.text, severity: 3)
        gs.shadow.ticker.append(item)
        gs.shadow.worldAtrocities.append(TickerItem(date: gs.currentDate, text: "\(p.name): \(p.text)", severity: 1))
        logPlayEvent("pandemic_begins", detail: ["id": p.id, "origin": p.origin, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        crisisManager.presentCrisis(Outbreaks.responseCard(o, text: p.text, in: gs))
    }

    /// The President answers an outbreak (from its card). Costs and approval land now; the factors work every turn.
    func respondToOutbreak(_ id: String, response: String) {
        guard let gs = gameState, let k = gs.shadow.outbreaks.firstIndex(where: { $0.id == id }),
              Outbreaks.responses(year: gs.currentYear).contains(response) else { return }
        gs.shadow.outbreaks[k].response = response
        switch response {
        case "quarantine": gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 4)
        case "travel_ban":
            modifyDiplomaticRelation(from: gs.shadow.outbreaks[k].origin, to: gs.playerCountryID, by: -5)
        case "vaccine":
            spendFunds(3)
            gs.shadow.outbreaks[k].vaccineReady = GameCalendar.calendar.date(byAdding: .month, value: gs.currentYear >= 2000 ? 10 : 6, to: gs.currentDate)
        case "aid":
            spendFunds(2)
            for c in gs.shadow.outbreaks[k].waves.keys where c != gs.playerCountryID { modifyDiplomaticRelation(from: c, to: gs.playerCountryID, by: 10) }
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 1)
        default:
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 2)
        }
        logPlayEvent("outbreak_response", detail: ["id": id, "response": response, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
    }

    // MARK: Engineered pathogens

    /// Biological capability: a stockpile, or a restarted programme that has delivered.
    func hasBiologicalCapability() -> Bool {
        guard let gs = gameState else { return false }
        return ArsenalCatalog.stockpileExists(.biological, on: gs.currentDate)
            || gs.shadow.wmdPrograms[WMDKind.biological.rawValue].map { $0.ready <= gs.currentDate } == true
    }

    /// Why a pathogen can't be released against `target`, or nil.
    func pathogenProblem(target: String) -> String? {
        guard let gs = gameState else { return "No game." }
        guard gs.shadow.pathogenReadySince != nil else { return "The pathogen programme must deliver first (TACTICS → Chemical and biological)." }
        guard let c = gs.getCountry(id: target), c.id != gs.playerCountryID, !c.isDestroyed, !c.isTerritory else { return "Pick a nation." }
        guard gs.actionsRemaining > 0 else { return "No actions left this turn." }
        return nil
    }

    /// Release an engineered pathogen (one action). It spreads like any disease: to allies, and home.
    @discardableResult
    func releasePathogen(target: String, discoveryRoll: Double = Double.random(in: 0..<1)) -> Outbreak? {
        guard pathogenProblem(target: target) == nil, let gs = gameState, let t = DirtyTactics.tactic("engineered_pathogen") else { return nil }
        let o = startEngineeredOutbreak(origin: target, by: gs.playerCountryID)
        var use = TacticUse(tactic: t.id, target: target, date: gs.currentDate, covert: true, scale: 2)
        use.discovered = discoveryRoll < DirtyTactics.discoveryChance(t, year: gs.currentYear, scale: 1.5)
        gs.shadow.tacticUses.append(use)
        gs.shadow.ruthlessness += DirtyTactics.cost(t, year: gs.currentYear).ruthlessness * DirtyTactics.quietShare
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): an engineered pathogen is released in \(gs.getCountry(id: target)?.name ?? target).")
        logPlayEvent("pathogen_released", detail: ["target": target, "discovered": use.discovered, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        if use.discovered { exposePathogen(use.id) }
        completePlayerAction()
        return o
    }

    @discardableResult
    func startEngineeredOutbreak(origin: String, by: String?) -> Outbreak {
        let gs = gameState
        var o = Outbreak(id: "engineered-\(UUID().uuidString.prefix(8))", name: "Outbreak of unknown origin", origin: origin,
                         started: gs?.currentDate ?? Date(), engineered: true, by: by, lethality: Outbreaks.engineeredLethality,
                         economy: Outbreaks.engineeredEconomy, spread: Outbreaks.engineeredSpread, waveWeeks: Outbreaks.engineeredWeeks)
        o.waves[origin] = 0
        guard let gs else { return o }
        gs.shadow.outbreaks.append(o)
        gs.shadow.post("An outbreak of an unknown disease is reported in \(gs.getCountry(id: origin)?.name ?? origin).", date: gs.currentDate, severity: 3)
        self.gameState = gs
        return o
    }

    /// The release is traced to the United States: the dirty-tactics price (a tribunal after 1975) and outrage.
    func exposePathogen(_ useID: UUID) {
        exposeTactic(useID)
        guard let gs = gameState else { return }
        for o in gs.countries where o.id != gs.playerCountryID && !o.isDestroyed && !o.isTerritory {
            modifyDiplomaticRelation(from: o.id, to: gs.playerCountryID, by: -30)
        }
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 20)
        gs.shadow.impeachmentStage = max(gs.shadow.impeachmentStage, 2)
        for k in gs.shadow.outbreaks.indices where gs.shadow.outbreaks[k].by == gs.playerCountryID { gs.shadow.outbreaks[k].attributed = true }
        self.gameState = gs
    }

    /// Order the home countermeasure programme (one action, $3B, a year).
    @discardableResult
    func startCountermeasure() -> Bool {
        guard let gs = gameState, gs.actionsRemaining > 0, gs.shadow.countermeasureReady == nil,
              gs.shadow.pathogenReadySince != nil || gs.shadow.tacticPrograms["engineered_pathogen"] != nil else { return false }
        spendFunds(Outbreaks.countermeasureCost)
        gs.shadow.countermeasureReady = GameCalendar.calendar.date(byAdding: .year, value: 1, to: gs.currentDate)
        gs.shadow.post("A countermeasure and vaccine programme begins at home.", date: gs.currentDate, severity: 1)
        self.gameState = gs
        completePlayerAction()
        return true
    }

    /// Each turn: the programme can fail containment at home; an engineered outbreak can be traced; rivals may release.
    func processPathogenProgram(leakRoll: Double? = nil, traceRoll: Double? = nil, rivalRoll: Double? = nil) {
        guard let gs = gameState else { return }
        let running = gs.shadow.pathogenReadySince != nil || gs.shadow.tacticPrograms["engineered_pathogen"] != nil
        if running {
            spendFunds(1.0 * gs.turnLength.yearFraction)
            let guarded = gs.shadow.countermeasureReady.map { $0 <= gs.currentDate } == true
            let r = leakRoll ?? Double.random(in: 0..<1, using: &gs.rng)
            if r < gs.scale.probability(annual: Outbreaks.containmentAnnual * (guarded ? 0.5 : 1)) {
                startEngineeredOutbreak(origin: gs.playerCountryID, by: gs.playerCountryID)
                gs.shadow.post("Containment failure at a government laboratory. Staff are sick before anyone outside knows why.",
                               date: gs.currentDate, severity: 3)
                let line = TickerItem(date: gs.currentDate, text: "Nova: Somebody left a door open. Stephen King wrote this one in 1978, and nobody listened then either.", severity: 1)
                gs.shadow.novaLines.append(line)
                gs.shadow.ticker.append(line)
                logPlayEvent("pathogen_containment_failure", detail: ["game_date": PlayHistory.day(gs.currentDate)])
            }
        }
        // Forensics: an untraced American release can be attributed over time.
        if let use = gs.shadow.tacticUses.last(where: { $0.tactic == "engineered_pathogen" && !$0.discovered }),
           gs.shadow.outbreaks.contains(where: { $0.by == gs.playerCountryID && !$0.attributed }) {
            let r = traceRoll ?? Double.random(in: 0..<1, using: &gs.rng)
            if r < gs.scale.probability(annual: 0.15 * DirtyTactics.eraExposure(year: gs.currentYear)) {
                if let i = gs.shadow.tacticUses.firstIndex(where: { $0.id == use.id }) { gs.shadow.tacticUses[i].discovered = true }
                self.gameState = gs
                exposePathogen(use.id)
            }
        }
        if let g = gameState, Outbreaks.aiEnabled || rivalRoll != nil {
            let r = rivalRoll ?? Double.random(in: 0..<1, using: &g.rng)
            if r < g.scale.probability(annual: 0.02), let rival = agentRival(g, from: 1953) {
                let o = startEngineeredOutbreak(origin: g.playerCountryID, by: rival.id)
                logPlayEvent("pathogen_suspected", detail: ["suspect": rival.id, "game_date": PlayHistory.day(g.currentDate)])
                crisisManager.presentCrisis(Outbreaks.suspectedCard(o, suspect: rival, in: g))
            }
        }
        self.gameState = gameState
    }
}

// MARK: - Cards

extension Outbreaks {
    static func responseCard(_ o: Outbreak, text: String, in gs: GameState) -> CrisisEvent {
        let y = gs.currentYear
        let options = responses(year: y).map { r -> CrisisOption in
            var k = CrisisConsequences(message: responseTitle(r, year: y) + ".")
            k.shadowChoice = "outbreak|\(o.id)|\(r)"
            let what: String
            switch r {
            case "quarantine": what = "Fewer cases and deaths at home; output and approval suffer while it lasts."
            case "travel_ban": what = "Slows its arrival. The origin country resents it."
            case "vaccine": what = "$3B. Deaths fall once the vaccine arrives, months from now."
            case "aid": what = "$2B. Friends abroad remember it."
            default: what = "No disruption now. More deaths when it comes."
            }
            return CrisisOption(title: responseTitle(r, year: y), description: what, consequences: k)
        }
        return CrisisEvent(type: .naturalDisaster, severity: .critical, title: o.name.uppercased(),
                           description: text + "\n\nHow does the government respond?", affectedCountries: [o.origin], turn: gs.turn, options: options)
    }

    static func suspectedCard(_ o: Outbreak, suspect: Country, in gs: GameState) -> CrisisEvent {
        CrisisEvent(
            type: .espionageDiscovered, severity: .critical, title: "OUTBREAK OF SUSPECTED DELIBERATE ORIGIN",
            description: """
            An unfamiliar disease is spreading at home. Its pattern troubles the epidemiologists, and intelligence \
            reports point toward a programme in \(suspect.name). Nothing is proven.
            """,
            affectedCountries: [suspect.id], turn: gs.turn,
            options: [
                CrisisOption(title: "Investigate", description: "Samples, forensics and patience before any accusation.",
                             consequences: CrisisConsequences(approvalChange: 1, message: "An investigation into the outbreak's origin begins.",
                                                              mutualRelations: [suspect.id: -10])),
                CrisisOption(title: "Retaliate", description: "Strike back at \(suspect.name) before the evidence is in.",
                             consequences: CrisisConsequences(approvalChange: 2, message: "The United States retaliates against \(suspect.name).",
                                                              mutualRelations: [suspect.id: -50], countryStability: [suspect.id: -8])),
                CrisisOption(title: "Accuse at the United Nations", description: "Make the case in public and seek inspections.",
                             consequences: CrisisConsequences(approvalChange: 3, message: "The President accuses \(suspect.name) before the Security Council.",
                                                              mutualRelations: [suspect.id: -30]))
            ])
    }
}

/// 3.31.0: decisions a crisis card hands back to the simulation ("outbreak|id|response", "posture|n", "ruthless|n",
/// "funds|n"; several joined by ";"). Unknown keys are ignored.
enum ShadowChoice {
    static func apply(_ s: String, engine: GameEngine?, to gs: GameState) {
        for part in s.split(separator: ";") {
            let f = part.split(separator: "|").map(String.init)
            switch f.first {
            case "outbreak" where f.count == 3: engine?.respondToOutbreak(f[1], response: f[2])
            case "posture" where f.count == 2: gs.shadow.intelPosture = min(3, max(0, gs.shadow.intelPosture + (Double(f[1]) ?? 0)))
            case "ruthless" where f.count == 2: gs.shadow.ruthlessness += Double(f[1]) ?? 0
            case "funds" where f.count == 2: gs.shadow.aidRemaining = max(0, gs.shadow.aidRemaining - max(0, Double(f[1]) ?? 0))
            default: break
            }
        }
    }
}
