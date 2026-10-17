//
//  ShadowSimulation.swift
//  Global Thermal Nuclear War
//
//  Wires the Shadow systems into GameEngine: new-game setup, the per-turn world step (scripted events, anxieties,
//  personality-driven AI, War Room combat, budget and aid cycles, popularity, polls, elections, impeachment,
//  assassination, advisor fates) and the player-facing verbs (advised actions, aid, budget, troops, saves).
//  Every rate is expressed per game year and scaled to the turn length through `TurnScale`.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum ShadowSettings {
    static let electionsKey = "GTNW.electionsEnabled"
    static func electionsEnabled(_ d: UserDefaults = .standard) -> Bool { d.object(forKey: electionsKey) as? Bool ?? true }
}

extension GameEngine {

    // MARK: - Setup

    /// Seed profiles, budget, aid pool and the opening snapshot for a fresh game.
    func setupShadowSystems(electionsEnabled: Bool = ShadowSettings.electionsEnabled()) {
        guard let gs = gameState else { return }
        for i in gs.countries.indices where gs.countries[i].leaderProfile == nil {
            gs.countries[i].leaderProfile = CountryProfile.derived(from: gs.countries[i])
        }
        for i in gs.countries.indices {
            gs.countries[i].profile.anxieties = AnxietyModel.targets(for: gs.countries[i], in: gs)
        }
        gs.shadow.electionsEnabled = electionsEnabled
        // Every Situation Room post gets someone, even in eras whose cabinet data lacks it.
        for role in AdviceEngine.roleOrder where !gs.advisors.contains(where: { $0.roleKey == role }) {
            gs.advisors.append(AdviceEngine.staffer(for: role, year: gs.currentYear))
        }
        gs.shadow.budget = FederalBudget.forYear(gs.currentYear)
        gs.shadow.aidRemaining = gs.shadow.budget.aidPool(gdpTrillions: gs.getPlayerCountry()?.gdp ?? 1)
        gs.shadow.lastBudgetYear = gs.currentYear
        gs.shadow.popularity = Double(gs.getPlayerCountry()?.publicApproval ?? 50)
        gs.shadow.polls = [PollRecord(date: gs.currentDate, popularity: gs.shadow.popularity)]
        gs.shadow.startSnapshot = WorldEvaluation.evaluate(gs).snapshot(date: gs.currentDate, popularity: gs.shadow.popularity)
        gs.shadow.post("\(gs.currentDateLabel): You take the oath of office. The Situation Room is yours.", date: gs.currentDate, severity: 1)
        if gs.shadow.electionsEnabled {
            let e = GameCalendar.nextElection(after: gs.currentDate)
            gs.shadow.post("Next presidential election: \(GameCalendar.format(e)).", date: gs.currentDate)
        }
        for i in gs.advisors.indices { AdviceEngine.refreshRecommendation(advisorIndex: i, in: gs) }
        self.gameState = gs
    }

    /// Start a scenario from the scenario list.
    func startScenario(_ s: ScenarioDefinition, difficulty: DifficultyLevel = .normal, turnLength: TurnLength? = nil) {
        gameState = ScenarioLoader.makeGameState(s, difficulty: difficulty, turnLength: turnLength)
        logMessages = []
        showingGameOver = false
        crisisManager.activeCrisis = nil
        setupShadowSystems()
        gameState?.shadow.post(s.summary, date: gameState?.currentDate ?? s.startDate, severity: 1)
        addLog("SCENARIO: \(s.title.uppercased())", type: .system)
        addLog(s.summary, type: .info)
    }

    // MARK: - Turn step

    /// Run one turn of the Shadow world. Called from `endTurn()` after the turn counter advances.
    func processShadowTurn() {
        guard let gs = gameState, !gs.gameOver else { return }
        let from = gs.previousTurnDate, to = gs.currentDate
        let scale = gs.scale

        processScriptedEvents(from: from, to: to)
        updateAnxietiesAndSociety(scale: scale)
        syncFronts()
        processCombat(from: from, to: to)
        processEconomy(from: from, to: to, scale: scale)
        processDomesticPolitics(from: from, to: to, scale: scale)
        processAdvisorFates(scale: scale)

        // Peace streak (years of peace = peaceTurns × turn length).
        if let p = gs.getPlayerCountry(), p.atWarWith.isEmpty { gs.peaceTurns += 1 } else { gs.peaceTurns = 0 }
        gs.actionsUsedThisTurn = 0
        self.gameState = gs
    }

    private func processScriptedEvents(from: Date, to: Date) {
        guard let gs = gameState else { return }
        for i in gs.shadow.eventQueue.indices where !gs.shadow.eventQueue[i].fired && gs.shadow.eventQueue[i].date <= to {
            gs.shadow.eventQueue[i].fired = true
            let e = gs.shadow.eventQueue[i]
            let actor = e.actor.flatMap { gs.getCountry(id: $0) }
            let target = e.target.flatMap { gs.getCountry(id: $0) }
            if (e.actor != nil && (actor == nil || actor!.isDestroyed)) || (e.target != nil && target == nil) { continue }
            gs.shadow.post(e.text, date: e.date, severity: e.kind == .invade || e.kind == .strike ? 3 : 1)
            addLog("📅 \(GameCalendar.format(e.date)): \(e.text)", type: e.kind == .news ? .info : .warning)
            guard let t = e.target else { continue }
            switch e.kind {
            case .news: break
            case .condemn:
                if let a = e.actor { modifyDiplomaticRelation(from: a, to: t, by: -10); bumpAnxiety(t, .political, 10) }
            case .massTroops:
                bumpAnxiety(t, .military, 25)
            case .invade:
                if let a = e.actor, !(actor?.atWarWith.contains(t) ?? true) { declareWar(aggressor: a, defender: t) }
            case .strike:
                if let a = e.actor {
                    if let ti = gs.countries.firstIndex(where: { $0.id == t }) {
                        gs.countries[ti].damageLevel = min(100, gs.countries[ti].damageLevel + 5)
                    }
                    bumpAnxiety(t, .military, 30)
                    modifyDiplomaticRelation(from: t, to: a, by: -30)
                }
            case .assassination:
                if let ti = gs.countries.firstIndex(where: { $0.id == t }) {
                    gs.countries[ti].profile.leadership = max(5, gs.countries[ti].profile.leadership - 20)
                    gs.countries[ti].stability = max(0, gs.countries[ti].stability - 15)
                }
            case .unrest:
                if let ti = gs.countries.firstIndex(where: { $0.id == t }) {
                    gs.countries[ti].profile.outcry = min(100, gs.countries[ti].profile.outcry + 20)
                    gs.countries[ti].stability = max(0, gs.countries[ti].stability - 10)
                }
            case .ceasefire:
                if let a = e.actor { _ = sueForPeace(from: a, to: t) }
            }
        }
    }

    func bumpAnxiety(_ id: String, _ kind: ThreatAnxieties.Kind, _ amount: Double) {
        guard let gs = gameState, let i = gs.countries.firstIndex(where: { $0.id == id }) else { return }
        gs.countries[i].profile.anxieties[kind] += amount
    }

    private func updateAnxietiesAndSociety(scale: TurnScale) {
        guard let gs = gameState else { return }
        var spikes: [(String, ThreatAnxieties.Kind)] = []
        let targets = gs.countries.map { $0.isDestroyed ? ThreatAnxieties() : AnxietyModel.targets(for: $0, in: gs) }
        for i in gs.countries.indices where !gs.countries[i].isDestroyed {
            var p = gs.countries[i].profile
            let old = p.anxieties
            p.anxieties = AnxietyModel.step(old, toward: targets[i], scale: scale)
            if let k = AnxietyModel.spike(from: old, to: p.anxieties) { spikes.append((gs.countries[i].id, k)) }

            // Social outcry drifts toward a level set by stability, quality of life and (for the U.S.) popularity.
            let c = gs.countries[i]
            var outcryTarget = Double(max(0, 50 - c.stability)) * 0.8 + (100 - p.qualityOfLife) * 0.2
            if c.isPlayerControlled { outcryTarget += max(0, 40 - gs.shadow.popularity) * 1.5 }
            let keep = pow(0.5, scale.yearFraction / 0.5)
            p.outcry = min(100, max(0, p.outcry * keep + outcryTarget * (1 - keep)))
            // Leadership tracks stability.
            p.leadership = min(100, max(5, p.leadership * keep + (Double(c.stability) * 0.7 + 15) * (1 - keep)))
            gs.countries[i].profile = p

            // Governments under enough pressure fall.
            if !c.isPlayerControlled && p.outcry > 85 && c.stability < 20
                && Double.random(in: 0..<1) < scale.probability(annual: 0.5) {
                let new = LeaderIdeology.allCases.randomElement() ?? .nationalism
                gs.countries[i].profile.ideology = new
                gs.countries[i].profile.outcry = 30
                gs.countries[i].stability = 45
                gs.countries[i].government = new.isDemocratic ? .republic : .military
                gs.shadow.post("Government falls in \(c.name); the new regime proclaims \(new.rawValue).", date: gs.currentDate, severity: 2)
            }
        }
        for (id, kind) in spikes.prefix(4) {
            guard let c = gs.getCountry(id: id) else { continue }
            let text = "\(c.name) is alarmed: \(kind.label.lowercased()) anxiety is spiking (\(Int(c.profile.anxieties[kind])))."
            gs.shadow.post(text, date: gs.currentDate, severity: c.isPlayerControlled ? 2 : 1)
            // A spike at home, or in a major power, can become a crisis on the President's desk.
            let major = c.isPlayerControlled || c.profile.strategicValue > 70
            if major && crisisManager.activeCrisis == nil && Double.random(in: 0..<1) < 0.5 {
                let type: CrisisEventType
                switch kind {
                case .nuclear: type = .falseAlarm
                case .military: type = .rogueCommander
                case .political: type = .militaryCoup
                case .economic: type = .economicCollapse
                case .social: type = .civilUnrest
                }
                let crisis = crisisManager.createCrisis(type: type, gameState: gs)
                crisisManager.presentCrisis(crisis)
                addLog("🚨 ANXIETY SPIKE → CRISIS: \(crisis.title)", type: .critical)
            }
        }
    }

    // MARK: Personality-driven AI

    /// Chance a computer-run country acts this turn: about four moves a game year, at most one per turn.
    func aiActionProbability(_ gs: GameState) -> Double { min(1, 4 * gs.turnLength.yearFraction) }

    func executeWorldMove(_ move: WorldMove, for country: Country) {
        guard let gs = gameState, let i = gs.countries.firstIndex(where: { $0.id == country.id }) else { return }
        let flag = country.flag, name = country.name
        func tname(_ id: String) -> String { gs.getCountry(id: id)?.name ?? id }
        func againstUS(_ id: String) -> Bool { id == gs.playerCountryID }
        switch move {
        case .wait:
            break
        case .improveRelations(let t):
            modifyDiplomaticRelation(from: country.id, to: t, by: 8)
            modifyDiplomaticRelation(from: t, to: country.id, by: 5)
            gs.aiActionSummary.append("\(flag) \(name) 🤝 courts \(tname(t))")
        case .tradeTies(let t):
            modifyDiplomaticRelation(from: country.id, to: t, by: 5)
            gs.countries[i].economicStrength = min(100, gs.countries[i].economicStrength + 1)
            if let j = gs.countries.firstIndex(where: { $0.id == t }) { gs.countries[j].economicStrength = min(100, gs.countries[j].economicStrength + 1) }
            gs.aiActionSummary.append("\(flag) \(name) 💱 signs a trade deal with \(tname(t))")
        case .condemn(let t):
            modifyDiplomaticRelation(from: t, to: country.id, by: -8)
            bumpAnxiety(t, .political, 6)
            gs.aiActionSummary.append("\(flag) \(name) 📢 condemns \(tname(t))")
            if againstUS(t) { gs.shadow.post("\(name) publicly condemns the United States.", date: gs.currentDate, severity: 1) }
        case .armsBuildup:
            gs.countries[i].militaryStrength = min(100, gs.countries[i].militaryStrength + 2)
            gs.countries[i].gdp = max(0.001, gs.countries[i].gdp * 0.995)
            gs.aiActionSummary.append("\(flag) \(name) 🪖 expands its armed forces")
        case .nuclearBuildup:
            guard gs.currentYear >= 1945 else { break }
            gs.countries[i].nuclearWarheads += max(1, gs.countries[i].nuclearWarheads / 50)
            if gs.countries[i].nuclearStatus == .none { gs.countries[i].nuclearStatus = .developing }
            gs.aiActionSummary.append("\(flag) \(name) ☢️ expands its nuclear program")
        case .seekAlliance(let t):
            if !country.alliances.contains(t) { formAlliance(country1: country.id, country2: t) }
        case .covertAction(let t):
            if let j = gs.countries.firstIndex(where: { $0.id == t }) {
                gs.countries[j].stability = max(0, gs.countries[j].stability - 3)
                gs.countries[i].spyNetworks[t] = min(100, (gs.countries[i].spyNetworks[t] ?? 0) + 10)
            }
            if Double.random(in: 0..<1) < 0.35 {
                modifyDiplomaticRelation(from: t, to: country.id, by: -20)
                gs.aiActionSummary.append("\(flag) \(name) 🕵️ caught running agents in \(tname(t))")
                if againstUS(t) { gs.shadow.post("FBI arrests agents working for \(name).", date: gs.currentDate, severity: 2) }
            }
        case .supportRebels(let t):
            if let j = gs.countries.firstIndex(where: { $0.id == t }) {
                gs.countries[j].profile.outcry = min(100, gs.countries[j].profile.outcry + 8)
                gs.countries[j].stability = max(0, gs.countries[j].stability - 4)
            }
            gs.aiActionSummary.append("\(flag) \(name) 🔫 arms rebels in \(tname(t))")
        case .threaten(let t):
            executeAIAction(.threatenNuclearStrike(target: t), for: country)
            if againstUS(t) { gs.shadow.post("\(name) threatens the United States with nuclear retaliation.", date: gs.currentDate, severity: 3) }
        case .attack(let t):
            executeAIAction(.declareWar(target: t), for: country)
            gs.shadow.post("\(name) attacks \(tname(t)).", date: gs.currentDate, severity: 3)
        case .internalReform:
            gs.countries[i].profile.qualityOfLife = min(100, gs.countries[i].profile.qualityOfLife + 1)
            gs.countries[i].profile.outcry = max(0, gs.countries[i].profile.outcry - 3)
        }
        self.gameState = gs
    }

    // MARK: War Room

    /// Keep one front per active war.
    func syncFronts() {
        guard let gs = gameState else { return }
        for w in gs.activeWars where !gs.shadow.fronts.contains(where: { $0.status == .fighting && $0.attacker == w.aggressor && $0.defender == w.defender }) {
            guard let a = gs.getCountry(id: w.aggressor), let d = gs.getCountry(id: w.defender) else { continue }
            gs.shadow.fronts.append(CombatModel.makeFront(attacker: a, defender: d, date: gs.currentDate))
        }
        for i in gs.shadow.fronts.indices where gs.shadow.fronts[i].status == .fighting {
            let f = gs.shadow.fronts[i]
            let stillAtWar = gs.activeWars.contains { $0.aggressor == f.attacker && $0.defender == f.defender }
            if !stillAtWar { gs.shadow.fronts[i].status = .ceasefire }
        }
        // Keep the list readable.
        if gs.shadow.fronts.count > 60 {
            gs.shadow.fronts.removeAll { $0.status != .fighting && $0.lastBattle < gs.date(atTurn: max(0, gs.turn - gs.scale.turns(forYears: 2))) }
        }
    }

    private func processCombat(from: Date, to: Date) {
        guard let gs = gameState else { return }
        let days = Double(max(1, GameCalendar.days(from: from, to: to)))
        var weeks = Int(days / 7)
        if Double.random(in: 0..<1) < (days / 7 - Double(weeks)) { weeks += 1 }
        guard weeks > 0 else { return }
        for i in gs.shadow.fronts.indices where gs.shadow.fronts[i].status == .fighting {
            for _ in 0..<weeks {
                var f = gs.shadow.fronts[i]
                guard let a = gs.getCountry(id: f.attacker), let d = gs.getCountry(id: f.defender) else { break }
                let o = CombatModel.battle(f, attackerStrength: a.militaryStrength, defenderStrength: d.militaryStrength,
                                           rolls: (Double.random(in: 0..<1), Double.random(in: 0..<1)))
                let usLoss = CombatModel.apply(o, to: &f, date: to)
                gs.totalCasualties += Int((o.attackerLosses + o.defenderLosses) * 300 + o.civilianLosses * 1000)
                if usLoss > 0.5 { gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - usLoss * 0.05) }
                let verdict = CombatModel.verdict(f)
                gs.shadow.fronts[i] = f
                if verdict != .fighting {
                    resolveFront(index: i, verdict: verdict)
                    break
                }
            }
        }
    }

    /// End a front: surrender and a new government, or a withdrawal.
    func resolveFront(index i: Int, verdict: FrontStatus) {
        guard let gs = gameState, gs.shadow.fronts.indices.contains(i) else { return }
        var f = gs.shadow.fronts[i]
        f.status = verdict
        gs.shadow.fronts[i] = f
        guard let ai = gs.countries.firstIndex(where: { $0.id == f.attacker }),
              let di = gs.countries.firstIndex(where: { $0.id == f.defender }) else { return }
        let aName = gs.countries[ai].name, dName = gs.countries[di].name
        // End the war record without the peace-treaty relationship bonus.
        gs.countries[ai].atWarWith.remove(f.defender)
        gs.countries[di].atWarWith.remove(f.attacker)
        gs.activeWars.removeAll { $0.aggressor == f.attacker && $0.defender == f.defender }
        let player = gs.playerCountryID
        if verdict == .attackerWon {
            if gs.countries[di].isPlayerControlled {
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 25)
                gs.shadow.post("The United States accepts humiliating terms from \(aName).", date: gs.currentDate, severity: 3)
            } else {
                var loser = gs.countries[di]
                CombatModel.installGovernment(on: &loser, by: gs.countries[ai])
                gs.countries[di] = loser
                gs.shadow.post("\(dName) surrenders to \(aName). A new government is installed in \(gs.countries[di].capital).", date: gs.currentDate, severity: 3)
            }
            if f.attacker == player || f.usSide == f.attacker { gs.warsWon += 1; gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 6) }
        } else {
            gs.countries[ai].stability = max(0, gs.countries[ai].stability - 15)
            gs.countries[ai].profile.outcry = min(100, gs.countries[ai].profile.outcry + 15)
            gs.shadow.post("\(aName)'s offensive collapses; its forces withdraw from \(dName).", date: gs.currentDate, severity: 2)
            if f.defender == player || f.usSide == f.defender { gs.warsWon += 1; gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 4) }
            if f.attacker == player { gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 15) }
        }
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(verdict == .attackerWon ? "\(dName) surrendered to \(aName)" : "\(aName) withdrew from \(dName)").")
        ShadowPack.shared.play(verdict == .attackerWon ? "sfx.war6" : "sfx.negotiation")
        self.gameState = gs
    }

    /// Commit (or recall, with a negative amount) U.S. troops to a front, on one side.
    @discardableResult
    func commitTroops(frontID: UUID, side: String, thousands: Double) -> Bool {
        guard let gs = gameState, let i = gs.shadow.fronts.firstIndex(where: { $0.id == frontID }),
              gs.shadow.fronts[i].status == .fighting else { return false }
        var f = gs.shadow.fronts[i]
        if f.usSide != nil && f.usSide != side { return false }
        f.usSide = side
        f.usTroops = max(0, f.usTroops + thousands)
        if f.usTroops == 0 { f.usSide = nil }
        gs.shadow.fronts[i] = f
        let other = side == f.attacker ? f.defender : f.attacker
        if thousands > 0 {
            modifyDiplomaticRelation(from: other, to: gs.playerCountryID, by: -15)
            modifyDiplomaticRelation(from: side, to: gs.playerCountryID, by: 10)
            gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): U.S. commits \(Int(thousands))K troops to support \(gs.getCountry(id: side)?.name ?? side).")
            ShadowPack.shared.play("sfx.warroom_enter")
        }
        self.gameState = gs
        return true
    }

    /// Demand the enemy's surrender on a front where the U.S. is fighting. Returns true when they give up.
    func demandSurrender(frontID: UUID) -> Bool {
        guard let gs = gameState, let i = gs.shadow.fronts.firstIndex(where: { $0.id == frontID }) else { return false }
        let f = gs.shadow.fronts[i]
        let usSide = f.usSide ?? (f.attacker == gs.playerCountryID ? f.attacker : (f.defender == gs.playerCountryID ? f.defender : nil))
        guard let side = usSide else { return false }
        let p = CombatModel.surrenderAcceptance(f, demandedBy: side)
        if Double.random(in: 0..<1) < p {
            resolveFront(index: i, verdict: side == f.attacker ? .attackerWon : .defenderWon)
            return true
        }
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): Surrender demand rejected.")
        if side == f.attacker { gs.shadow.fronts[i].defenderWill = min(1, f.defenderWill + 0.05) }
        else { gs.shadow.fronts[i].attackerWill = min(1, f.attackerWill + 0.05) }
        self.gameState = gs
        return false
    }

    // MARK: Economy (budget, growth, aid cycle)

    private func processEconomy(from: Date, to: Date, scale: TurnScale) {
        guard let gs = gameState, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
        let atWar = !gs.countries[pi].atWarWith.isEmpty
        let proj = BudgetModel.project(gs.shadow.budget, atWar: atWar)
        gs.countries[pi].gdp *= scale.growthFactor(annual: proj.growth / 100)
        gs.countries[pi].profile.qualityOfLife = min(100, max(0, gs.countries[pi].profile.qualityOfLife + scale.amount(annual: proj.qualityOfLifeChange)))
        gs.countries[pi].militaryStrength = min(100, max(1, gs.countries[pi].militaryStrength + scale.integer(annual: proj.militaryChange)))

        // Other economies grow a little every turn; war, unrest and radiation drag them down.
        for i in gs.countries.indices where i != pi && !gs.countries[i].isDestroyed {
            let c = gs.countries[i]
            var g = 0.025 + Double(c.profile.ethic - 3) * 0.003 - c.profile.outcry / 2000 - Double(c.radiationLevel) / 1000
            if !c.atWarWith.isEmpty { g -= 0.03 }
            gs.countries[i].gdp = max(0.0001, c.gdp * scale.growthFactor(annual: g))
        }

        // Fiscal year turnover on January 1.
        if GameCalendar.window(from: from, to: to, containsMonth: 1, day: 1) {
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + proj.popularityChange)
            gs.shadow.aidRemaining = gs.shadow.budget.aidPool(gdpTrillions: gs.countries[pi].gdp)
            gs.shadow.aidSent = [:]
            for i in gs.countries.indices where !gs.countries[i].isDestroyed {
                gs.countries[i].profile.aidNeed = CountryProfile.derived(from: gs.countries[i]).aidNeed
            }
            gs.shadow.lastBudgetYear = gs.currentYear
            gs.shadow.budgetReviewPending = true
            let summary = String(format: "New fiscal year: GDP growth %.1f%%, deficit %.1f%% of GDP. The budget for %d is ready for your review.",
                                 proj.growth, proj.deficit, gs.currentYear)
            gs.shadow.post(summary, date: to, severity: 1)
            addLog("💵 \(summary)", type: .info)
        }
    }

    /// Replace the budget (from the Budget view). Applies immediately; popularity reacts at year end.
    func applyBudget(_ b: FederalBudget) {
        guard let gs = gameState else { return }
        let oldPool = gs.shadow.budget.aidPool(gdpTrillions: gs.getPlayerCountry()?.gdp ?? 1)
        gs.shadow.budget = b
        let newPool = b.aidPool(gdpTrillions: gs.getPlayerCountry()?.gdp ?? 1)
        gs.shadow.aidRemaining = max(0, gs.shadow.aidRemaining + (newPool - oldPool))
        gs.shadow.budgetReviewPending = false
        self.gameState = gs
    }

    /// Send a five-category aid package. Unused money comes back to the pool.
    @discardableResult
    func sendAid(_ package: AidVector, to countryID: String) -> AidOutcome? {
        guard let gs = gameState, let ti = gs.countries.firstIndex(where: { $0.id == countryID }),
              let player = gs.getPlayerCountry() else { return nil }
        guard package.total <= gs.shadow.aidRemaining + 0.0001 else {
            return AidOutcome(reaction: .reject, accepted: AidVector(), returned: package.total, relationChange: 0,
                              message: String(format: "Not enough aid money left this year ($%.1fB).", gs.shadow.aidRemaining))
        }
        let target = gs.countries[ti]
        let outcome = AidModel.evaluate(package: package, need: target.profile.aidNeed,
                                        relation: target.diplomaticRelations[player.id] ?? 0, recipient: target,
                                        donorName: player.name)
        gs.shadow.aidRemaining = max(0, gs.shadow.aidRemaining - outcome.accepted.total)
        var c = gs.countries[ti]
        AidModel.apply(outcome.accepted, to: &c)
        gs.countries[ti] = c
        var sent = gs.shadow.aidSent[countryID] ?? AidVector()
        for k in AidCategory.allCases { sent[k] += outcome.accepted[k] }
        gs.shadow.aidSent[countryID] = sent
        if outcome.relationChange != 0 {
            modifyDiplomaticRelation(from: countryID, to: player.id, by: outcome.relationChange)
            modifyDiplomaticRelation(from: player.id, to: countryID, by: max(0, outcome.relationChange / 2))
        }
        if outcome.accepted.humanitarian > 0 { gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 0.3) }
        if outcome.accepted.nuclear > 0 { gs.shadow.ruthlessness += 3 }
        gs.shadow.post(outcome.message, date: gs.currentDate, severity: outcome.reaction == .publicRejection ? 2 : 0)
        addLog("💰 AID: \(outcome.message)", type: outcome.reaction == .publicRejection ? .warning : .info)
        ShadowPack.shared.play(outcome.reaction == .thanks || outcome.reaction == .partial ? "sfx.social_reform" : "sfx.condemnation")
        self.gameState = gs
        return outcome
    }

    // MARK: Domestic politics

    private func processDomesticPolitics(from: Date, to: Date, scale: TurnScale) {
        guard let gs = gameState, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
        let player = gs.countries[pi]
        let proj = BudgetModel.project(gs.shadow.budget, atWar: !player.atWarWith.isEmpty)
        gs.shadow.ruthlessness *= pow(0.7, scale.yearFraction)
        let hits = gs.nuclearStrikes.filter { $0.target == player.id }.count
        let target = PopularityModel.equilibrium(usQoL: player.profile.qualityOfLife, growth: proj.growth,
                                                 warsInvolvingPlayer: player.atWarWith.count,
                                                 ruthlessness: gs.shadow.ruthlessness, nuclearHitsOnPlayer: hits)
        gs.shadow.popularity = PopularityModel.drift(gs.shadow.popularity, toward: target, scale: scale)

        // Polls on the first of each month.
        let cal = GameCalendar.calendar
        let newMonth = cal.component(.month, from: from) != cal.component(.month, from: to) || GameCalendar.year(of: from) != GameCalendar.year(of: to)
        if newMonth {
            let last = gs.shadow.polls.last?.popularity ?? gs.shadow.popularity
            gs.shadow.polls.append(PollRecord(date: to, popularity: gs.shadow.popularity))
            if gs.shadow.polls.count > 240 { gs.shadow.polls.removeFirst() }
            let phrase = PopularityModel.pollPhrase(from: last, to: gs.shadow.popularity)
            gs.shadow.post("Press Secretary: \(phrase)", date: to)
            if gs.shadow.popularity < last - 5 { ShadowPack.shared.play("sfx.popularity_hit") }

            // Congress watches the polls.
            let stage = PopularityModel.nextImpeachmentStage(current: gs.shadow.impeachmentStage, popularity: gs.shadow.popularity,
                                                             ruthlessness: gs.shadow.ruthlessness, congress: player.congressionalSupport)
            if stage != gs.shadow.impeachmentStage {
                if stage > 0 { gs.shadow.post(PopularityModel.impeachmentText(stage: stage), date: to, severity: stage >= 3 ? 3 : 2) }
                else { gs.shadow.post("Congress drops its investigation of the White House.", date: to, severity: 1) }
                gs.shadow.impeachmentStage = stage
                if stage >= 4 { endPresidency(.impeached) }
            }
        }

        // State of the Union in early February.
        if GameCalendar.window(from: from, to: to, containsMonth: 2, day: 1) {
            let bump = player.profile.qualityOfLife > 55 ? 2.0 : 0.5
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + bump)
            gs.shadow.post("State of the Union: the President addresses a joint session of Congress.", date: to, severity: 1)
        }

        // Election day.
        if gs.shadow.electionsEnabled && gs.shadow.domesticEnding == nil {
            for y in GameCalendar.year(of: from)...GameCalendar.year(of: to) where y % 4 == 0 {
                let day = GameCalendar.electionDay(year: y)
                if GameCalendar.window(from: from, to: to, contains: day) { holdElection(on: day) }
            }
        }

        // Assassination.
        let pAssassin = scale.probability(annual: PopularityModel.assassinationAnnualProbability(popularity: gs.shadow.popularity, ruthlessness: gs.shadow.ruthlessness))
        if gs.shadow.domesticEnding == nil && Double.random(in: 0..<1) < pAssassin { endPresidency(.assassinated) }

        // Civil war.
        if gs.shadow.domesticEnding == nil && player.profile.outcry > 90 && player.stability < 15 { endPresidency(.civilWar) }

        // Mirror into the legacy approval numbers that other systems read.
        gs.countries[pi].publicApproval = Int(gs.shadow.popularity.rounded())
        let congressTarget = Int((gs.shadow.popularity * 0.7 + 15).rounded())
        gs.countries[pi].congressionalSupport += (congressTarget - gs.countries[pi].congressionalSupport) / 4
    }

    func holdElection(on day: Date) {
        guard let gs = gameState else { return }
        let share = PopularityModel.voteShare(popularity: gs.shadow.popularity, termsWon: gs.shadow.termsWon, noise: Double.random(in: -1...1))
        let won = share > 50
        let result = ElectionResult(date: day, playerShare: share, opponentShare: 100 - share, won: won,
                                    opponentName: PopularityModel.challenger(for: GameCalendar.year(of: day)))
        gs.shadow.lastElection = result
        ShadowPack.shared.play("sfx.election_speech\(Int.random(in: 1...3))")
        if won {
            gs.shadow.termsWon += 1
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 5)
            gs.shadow.post(String(format: "ELECTION NIGHT: You win %.1f%% to %.1f%%. Four more years.", share, 100 - share), date: day, severity: 3)
            addLog(String(format: "🗳️ RE-ELECTED with %.1f%% of the vote.", share), type: .critical)
        } else {
            gs.shadow.post(String(format: "ELECTION NIGHT: %@ wins %.1f%% to %.1f%%.", result.opponentName, 100 - share, share), date: day, severity: 3)
            endPresidency(.lostElection)
        }
        self.gameState = gs
    }

    /// End the game for a domestic reason. The normal game-over flow (VictoryChecker.checkDefeat) picks this up.
    func endPresidency(_ ending: DomesticEnding) {
        guard let gs = gameState, gs.shadow.domesticEnding == nil else { return }
        gs.shadow.domesticEnding = ending
        gs.shadow.post(ending.headline, date: gs.currentDate, severity: 3)
        addLog("🏛️ \(ending.headline)", type: .critical)
        switch ending {
        case .impeached: ShadowPack.shared.play("sfx.lockdown")
        case .assassinated: ShadowPack.shared.play("sfx.gunshot")
        default: break
        }
        self.gameState = gs
    }

    // MARK: Advisors

    private func processAdvisorFates(scale: TurnScale) {
        guard let gs = gameState else { return }
        let pScandal = scale.probability(annual: 0.03)
        for i in gs.advisors.indices where gs.advisors[i].isActive && !gs.advisors[i].title.contains("President") {
            if Double.random(in: 0..<1) < pScandal {
                let what = AdviceEngine.scandals.randomElement() ?? "was caught in an embarrassing scandal"
                departAdvisor(index: i, status: .scandal, reason: "\(gs.advisors[i].name) \(what) and has resigned.")
            }
        }
        // Keep each advisor's standing advice fresh (situation read + a concrete proposal).
        for i in gs.advisors.indices where gs.advisors[i].isActive {
            AdviceEngine.refreshRecommendation(advisorIndex: i, in: gs)
        }
        self.gameState = gs
    }

    /// Remove an advisor from duty with a fate, and appoint an acting replacement.
    func departAdvisor(index i: Int, status: AdvisorStatus, reason: String) {
        guard let gs = gameState, gs.advisors.indices.contains(i), gs.advisors[i].isActive else { return }
        gs.advisors[i].status = status
        let acting = AdviceEngine.appointActing(replacing: gs.advisors[i], sequence: gs.advisors.count)
        gs.advisors.append(acting)
        gs.shadow.post(reason, date: gs.currentDate, severity: 2)
        addLog("👔 \(reason)", type: .warning)
        if status == .scandal { gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 3) }
        self.gameState = gs
    }

    /// Advisors near the impact die when the homeland is struck.
    func homelandStruck() {
        guard let gs = gameState else { return }
        for i in gs.advisors.indices where gs.advisors[i].isActive && !gs.advisors[i].title.contains("President") {
            if Double.random(in: 0..<1) < 0.3 {
                departAdvisor(index: i, status: .killed, reason: "\(gs.advisors[i].name), \(gs.advisors[i].title), was killed in the attack.")
            }
        }
    }

    // MARK: - Player verbs

    /// The advice the responsible cabinet post gives on an action.
    func advice(for action: PresidentialAction, targetID: String) -> ActionAdvice? {
        guard let gs = gameState, let player = gs.getPlayerCountry(), let target = gs.getCountry(id: targetID) else { return nil }
        return AdviceEngine.advise(action: action, player: player, target: target, gameState: gs)
    }

    /// Carry out an action the player confirmed, after hearing the advice. Handles popularity, ruthlessness,
    /// the advisor's reaction to being followed or overruled, and the per-turn action allowance.
    func performAdvisedAction(_ action: PresidentialAction, targetID: String, advice: ActionAdvice?) {
        guard let gs = gameState else { return }
        executeShadowPresidentAction(action, from: gs.playerCountryID, to: targetID)
        // Nuclear launches record their own fallout in launchNuclearStrike.
        if action.rung != .nuclear { recordPlayerAction(rung: action.rung, hostile: action.isHostile, detected: false) }
        if let a = advice, let id = a.advisorID, let i = gs.advisors.firstIndex(where: { $0.id == id }) {
            if a.stance == .oppose {
                if let msg = AdviceEngine.registerOverrule(advisorIndex: i, in: gs) {
                    gs.advisors.append(AdviceEngine.appointActing(replacing: gs.advisors[i], sequence: gs.advisors.count))
                    gs.shadow.post(msg, date: gs.currentDate, severity: 2)
                    addLog("👔 \(msg)", type: .warning)
                }
            } else {
                AdviceEngine.registerFollowed(advisorIndex: i, in: gs)
            }
        }
        self.gameState = gs
        completePlayerAction()
    }

    /// ACCEPT on an advisor's standing recommendation: carry it out with that advisor's blessing.
    @discardableResult
    func acceptRecommendation(advisorID: String) -> Bool {
        guard let gs = gameState, let i = gs.advisors.firstIndex(where: { $0.id == advisorID }),
              let raw = gs.advisors[i].recommendedAction, let action = PresidentialAction(rawValue: raw),
              let target = gs.advisors[i].recommendedTarget, gs.actionsRemaining > 0 else { return false }
        let adv = gs.advisors[i]
        let advice = ActionAdvice(advisorID: adv.id, advisorName: adv.name, advisorTitle: adv.title, stance: .approve,
                                  reason: adv.currentAdvice ?? "", successEstimate: action.successChance)
        performAdvisedAction(action, targetID: target, advice: advice)
        AdviceEngine.refreshRecommendation(advisorIndex: i, in: gs)
        return true
    }

    /// REJECT: the advisor notes it; repeated rejections wear down loyalty (and can end in resignation).
    func rejectRecommendation(advisorID: String) {
        guard let gs = gameState, let i = gs.advisors.firstIndex(where: { $0.id == advisorID }) else { return }
        if let msg = AdviceEngine.registerOverrule(advisorIndex: i, in: gs) {
            gs.advisors.append(AdviceEngine.appointActing(replacing: gs.advisors[i], sequence: gs.advisors.count))
            gs.shadow.post(msg, date: gs.currentDate, severity: 2)
            addLog("👔 \(msg)", type: .warning)
        }
        self.gameState = gs
    }

    /// REQUEST ALTERNATIVE: the advisor proposes something different.
    func alternativeRecommendation(advisorID: String) {
        guard let gs = gameState, let i = gs.advisors.firstIndex(where: { $0.id == advisorID }) else { return }
        var skip: Set<String> = []
        if let a = gs.advisors[i].recommendedAction, let t = gs.advisors[i].recommendedTarget { skip.insert(a + t) }
        AdviceEngine.refreshRecommendation(advisorIndex: i, in: gs, excluding: skip)
        self.gameState = gs
    }

    /// The player listened and backed off.
    func declineAdvisedAction(advice: ActionAdvice?) {
        guard let gs = gameState, let a = advice, a.stance == .oppose, let id = a.advisorID,
              let i = gs.advisors.firstIndex(where: { $0.id == id }) else { return }
        AdviceEngine.registerFollowed(advisorIndex: i, in: gs)
        self.gameState = gs
    }

    /// Domestic fallout of an action.
    func recordPlayerAction(rung: EscalationRung, hostile: Bool, detected: Bool) {
        guard let gs = gameState else { return }
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + PopularityModel.actionEffect(rung: rung, hostile: hostile, detected: detected))
        gs.shadow.ruthlessness += PopularityModel.ruthlessnessEffect(rung: rung, hostile: hostile)
        self.gameState = gs
    }

    /// Use up one of this turn's actions; when none are left the turn ends (after a short beat for the UI).
    func completePlayerAction(endTurnDelay: Double = 0.5) {
        guard let gs = gameState else { return }
        gs.actionsUsedThisTurn += 1
        self.gameState = gs
        if gs.actionsUsedThisTurn >= gs.actionsPerTurn {
            DispatchQueue.main.asyncAfter(deadline: .now() + endTurnDelay) { [weak self] in self?.endTurn() }
        } else {
            addLog("▶ \(gs.actionsRemaining) action(s) left this \(gs.turnLength.displayName.lowercased()).", type: .info)
        }
    }

    // MARK: - Saves

    func saveGame(slot: Int, manager: SaveManager = SaveManager()) throws {
        guard let gs = gameState else { return }
        try manager.save(gs, slot: slot)
        addLog("💾 Game saved to \(slot == 0 ? "autosave" : "slot \(slot)").", type: .info)
    }

    func loadGame(slot: Int, manager: SaveManager = SaveManager()) throws {
        let gs = try manager.load(slot: slot)
        crisisManager.activeCrisis = nil
        showingGameOver = false
        gameState = gs
        if gs.shadow.startSnapshot == nil { setupShadowSystems(electionsEnabled: gs.shadow.electionsEnabled) }
        addLog("📂 Loaded \(slot == 0 ? "autosave" : "slot \(slot)") — \(gs.currentDateLabel).", type: .info)
    }
}
