//
//  HomeFrontEngine.swift
//  Global Thermal Nuclear War
//
//  The engine half of the power plays (3.36.0): what an order is allowed to do (`homePlayProblem`), what it does
//  (`executeHomePlay`, one action each, through the command box's `executeCommand`), and what comes due turn by turn
//  (`processHomeFront`). Every roll goes through the game's seeded RNG, and only once a power play is in play, so a
//  game that never uses them plays exactly as before. The missile shield joins strike resolution through
//  `missileShieldIntercepts`, a fixed share of the warheads with no dice.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - Two sets of books

extension GameState {
    /// The economy the engine plays on.
    var trueEconomy: EconomyFigures {
        let pp = shadow.homeFront
        let atWar = !(getPlayerCountry()?.atWarWith.isEmpty ?? true)
        let inflation = pp.inflation ?? HomeFrontModel.baselineInflation(year: currentYear)
        let borrowing = HomeFrontModel.borrowing(inflation: inflation, spread: pp.creditSpread, overruled: pp.bankOverruled)
        let growth = BudgetModel.project(shadow.budget, atWar: atWar).growth + homeFrontGrowth(borrowing: borrowing)
        return EconomyFigures(growth: growth, inflation: inflation, borrowing: borrowing)
    }

    /// Growth the central bank's cheap money adds (fading a year after the last push), less the drag of dear credit.
    func homeFrontGrowth(borrowing: Double) -> Double {
        let pp = shadow.homeFront
        guard pp.inflation != nil else { return 0 }
        let recent = pp.lastBankPressure.map { GameCalendar.days(from: $0, to: currentDate) < 365 } ?? false
        return pp.bankPressure * 0.5 * (recent ? 1 : 0.5) - max(0, borrowing - 5) * 0.3
    }

    /// The economy as the government reports it: the truth, unless the statistician was fired.
    var officialEconomy: EconomyFigures {
        var f = trueEconomy
        if let fired = shadow.homeFront.statisticianFired {
            let b = HomeFrontModel.officialBias(months: Double(GameCalendar.days(from: fired, to: currentDate)) / 30.44)
            f.growth += b.growth
            f.inflation = max(0, f.inflation + b.inflation)
        }
        return f
    }

    /// How far the official growth figure is above the truth (0 with an independent statistician).
    var officialGrowthBias: Double { numbersCooked ? officialEconomy.growth - trueEconomy.growth : 0 }

    /// True while the official figures are cooked.
    var numbersCooked: Bool { shadow.homeFront.statisticianFired != nil }

    /// The nation's next presidential election year (for the stay-in-power orders).
    var nextPresidentialYear: Int {
        var y = currentYear
        while y % 4 != 0 || ElectionRules(year: y).electionDay <= currentDate { y += 1 }
        return y
    }
}

// MARK: - Orders

extension GameEngine {

    /// The play, mode and argument an order carries.
    private func playParts(_ o: GameOrder) -> (HomePlay, String, String)? {
        guard let p = o.action.flatMap(HomePlay.init(rawValue:)) else { return nil }
        let mode = o.mission ?? p.modes[0]
        guard p.modes.contains(mode) else { return nil }
        return (p, mode, o.target)
    }

    /// Why a power play can't be ordered now, or nil.
    func homePlayProblem(_ o: GameOrder) -> String? {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return "No game in progress." }
        guard o.target.count <= 24, o.target.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "-" }),
              let (play, mode, arg) = playParts(o) else { return "Not an order the command box can give." }
        let pp = gs.shadow.homeFront
        let year = gs.currentYear
        switch play {
        case .troopsHome:
            return homeTroopsProblem(mode: mode, state: arg)
        case .fixNumbers:
            if mode == "fire" { return pp.statisticianFired == nil ? nil : "The statistician is already gone; the numbers are already yours." }
            return pp.statisticianFired == nil ? "The statistics office is already independent." : nil
        case .leanOnBank:
            guard let bank = HomeFrontModel.centralBank(year: year, nation: me.id) else { return HomeFrontModel.noBankReason(year: year, nation: me.id) }
            switch mode {
            case "release": return pp.bankOverruled || pp.bankPressure > 0.05 ? nil : "\(bank.prefix(1).uppercased() + bank.dropFirst()) already sets rates on its own."
            case "overrule": return pp.bankOverruled ? "You already set the rates; \(bank) answers to you." : nil
            default: return pp.bankPressure >= HomeFrontModel.maxPressure - 0.01 ? "Rates are as low as \(bank) can push them." : nil
            }
        case .buyStake:
            guard let ind = HomeFrontModel.industry(arg) else { return "Name an industry: \(HomeFrontModel.industries.filter { $0.exists(in: year) }.map(\.name).joined(separator: ", "))." }
            if mode == "sell" { return pp.stakes.contains { $0.industry == ind.id } ? nil : "The government holds no stake in \(ind.name.lowercased())." }
            guard ind.exists(in: year) else { return "No \(ind.name.lowercased()) industry to buy into in \(year)." }
            if pp.stakes.contains(where: { $0.industry == ind.id }) { return "The government already holds a stake in \(ind.name.lowercased())." }
            let price = HomeFrontModel.stakePrice(gdpTrillions: me.gdp)
            return Double(me.treasury) / 1e9 >= price ? nil : "The Treasury can't cover the \(HomeFrontModel.billions(price)) stake."
        case .stayInPower:
            return stayInPowerProblem(route: mode)
        case .missileShield:
            if mode == "cancel" { return pp.shieldStarted == nil ? "There is no missile-defense program to cancel." : nil }
            if year < HomeFrontModel.shieldFrom { return "No ballistic missiles to stop until 1957; a shield has nothing to aim at in \(year)." }
            return pp.shieldStarted == nil ? nil : "The missile-defense program is already under way."
        case .nuclearTest:
            if year < 1945 || !PresidentialAction.launchNukes.isAvailable(on: gs.currentDate, in: gs) { return "No nuclear weapons exist in \(year)." }
            if me.nuclearWarheads < 1 { return "You have no warhead to test." }
            if mode == "underground", gs.currentDate < HomeFrontModel.undergroundFrom { return "No underground test is possible before September 1957; test in the atmosphere." }
            return nil
        }
    }

    /// Carry out a power play. One action; refused orders cost nothing.
    @discardableResult
    func executeHomePlay(_ o: GameOrder) -> Bool {
        guard homePlayProblem(o) == nil, let (play, mode, arg) = playParts(o), gameState != nil else { return false }
        let ok: Bool
        switch play {
        case .troopsHome: ok = runHomeTroops(mode: mode, state: arg)
        case .fixNumbers: ok = runFixNumbers(mode: mode)
        case .leanOnBank: ok = runLeanOnBank(mode: mode)
        case .buyStake: ok = runStake(mode: mode, industry: arg)
        case .stayInPower: ok = runStayInPower(route: mode)
        case .missileShield: ok = runMissileShield(mode: mode)
        case .nuclearTest: ok = runNuclearTest(atmospheric: mode == "atmospheric")
        }
        guard ok else { return false }
        overruleCabinet(play, mode: mode)
        logPlayEvent("home_play", detail: ["play": play.rawValue, "mode": mode, "target": arg,
                                            "game_date": PlayHistory.day(gameState?.currentDate ?? Date())])
        completePlayerAction()
        return true
    }

    /// The posts that argued against it take it personally (repeated defiance ends in resignation).
    private func overruleCabinet(_ play: HomePlay, mode: String) {
        guard let gs = gameState else { return }
        let opposed = (mode == "restore" || mode == "release" || mode == "sell" || mode == "cancel" || mode == "withdraw") ? [] : play.opposedBy
        for role in opposed {
            guard let i = gs.advisors.firstIndex(where: { $0.isActive && $0.roleKey == role }) else { continue }
            if let msg = AdviceEngine.registerOverrule(advisorIndex: i, in: gs) {
                gs.shadow.post(msg, date: gs.currentDate, severity: 2)
                addLog("🚪 \(msg)", type: .warning)
            }
        }
        self.gameState = gs
    }

    private func news(_ text: String, severity: Int = 1, icon: String = "🏛️") {
        guard let gs = gameState else { return }
        gs.shadow.post(text, date: gs.currentDate, severity: severity)
        addLog("\(icon) \(text)", type: severity >= 2 ? .warning : .info)
    }

    private func bump(popularity dp: Double = 0, ruthlessness dr: Double = 0, congress dc: Int = 0) {
        guard let gs = gameState else { return }
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + dp)
        gs.shadow.ruthlessness = max(0, gs.shadow.ruthlessness + dr)
        if dc != 0, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) {
            gs.countries[pi].congressionalSupport = min(100, max(0, gs.countries[pi].congressionalSupport + dc))
        }
        self.gameState = gs
    }

    private func spend(billions: Double) {
        guard let gs = gameState, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
        gs.countries[pi].treasury -= Int64((billions * 1e9).rounded())
        self.gameState = gs
    }

    // MARK: Fixing the numbers

    private func runFixNumbers(mode: String) -> Bool {
        guard let gs = gameState else { return false }
        let office = HomeFrontModel.statsOffice(year: gs.currentYear)
        if mode == "restore" {
            gs.shadow.homeFront.statisticianFired = nil
            gs.shadow.homeFront.numbersLeaked = nil
            gs.shadow.homeFront.leakedGrowth = nil
            gs.shadow.homeFront.leakedInflation = nil
            gs.shadow.homeFront.creditSpread = max(0, gs.shadow.homeFront.creditSpread - 0.25)
            self.gameState = gs
            bump(popularity: 1)
            news("An independent statistician takes over \(office). The official figures are honest again.")
            return true
        }
        gs.shadow.homeFront.statisticianFired = gs.currentDate
        gs.shadow.homeFront.numbersLeaked = nil
        gs.shadow.homeFront.firings += 1
        self.gameState = gs
        bump(popularity: 2, ruthlessness: 5)
        news("The President fires the head of \(office) the day before a weak report. The next figures come out better.", severity: 2)
        return true
    }

    // MARK: Central bank

    private func runLeanOnBank(mode: String) -> Bool {
        guard let gs = gameState, let me = gs.getPlayerCountry(),
              let bank = HomeFrontModel.centralBank(year: gs.currentYear, nation: me.id) else { return false }
        var pp = gs.shadow.homeFront
        if pp.inflation == nil { pp.inflation = HomeFrontModel.baselineInflation(year: gs.currentYear) }
        switch mode {
        case "release":
            pp.bankOverruled = false
            pp.creditSpread = max(0, pp.creditSpread - 0.3)
            gs.shadow.homeFront = pp
            self.gameState = gs
            bump(popularity: -1)
            news("The President restores \(bank)'s independence. Markets steady; cheap money ends.")
        case "overrule":
            pp.bankPressure = min(HomeFrontModel.maxPressure, pp.bankPressure + HomeFrontModel.overruleStep)
            pp.bankOverruled = true
            pp.lastBankPressure = gs.currentDate
            pp.creditSpread += 0.5
            gs.shadow.homeFront = pp
            self.gameState = gs
            bump(popularity: 3, ruthlessness: 8)
            news("The President overrules \(bank) and orders rates cut. Its chair resigns; bond markets take note.", severity: 2)
        default:
            pp.bankPressure = min(HomeFrontModel.maxPressure, pp.bankPressure + HomeFrontModel.pressureStep)
            pp.lastBankPressure = gs.currentDate
            gs.shadow.homeFront = pp
            self.gameState = gs
            bump(popularity: 2.5, ruthlessness: 2)
            news("After weeks of public pressure from the President, \(bank) cuts rates. Borrowers cheer; economists worry.")
        }
        return true
    }

    // MARK: Equity stakes

    private func runStake(mode: String, industry id: String) -> Bool {
        guard let gs = gameState, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }),
              let ind = HomeFrontModel.industry(id) else { return false }
        if mode == "sell" {
            guard let i = gs.shadow.homeFront.stakes.firstIndex(where: { $0.industry == id }) else { return false }
            let s = gs.shadow.homeFront.stakes.remove(at: i)
            self.gameState = gs
            spend(billions: -s.value)
            news("The government sells its stake in \(ind.name.lowercased()) for \(HomeFrontModel.billions(s.value)).")
            return true
        }
        let price = HomeFrontModel.stakePrice(gdpTrillions: gs.countries[pi].gdp)
        gs.shadow.homeFront.stakes.append(EquityStake(industry: id, bought: gs.currentDate, value: price))
        gs.countries[pi].economicStrength = min(100, gs.countries[pi].economicStrength + 1)
        if ind.strategic { gs.countries[pi].militaryStrength = min(100, gs.countries[pi].militaryStrength + 1) }
        self.gameState = gs
        spend(billions: price)
        bump(popularity: 1)
        news("The government takes a \(HomeFrontModel.billions(price)) equity stake in \(ind.name.lowercased()). Critics ask who knew first.")
        return true
    }

    // MARK: Missile shield

    private func runMissileShield(mode: String) -> Bool {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return false }
        if mode == "cancel" {
            let wasReady = gs.shadow.homeFront.shieldReady.map { gs.currentDate >= $0 } ?? false
            gs.shadow.homeFront.shieldStarted = nil
            gs.shadow.homeFront.shieldReady = nil
            self.gameState = gs
            news(wasReady ? "The President stands down the missile shield." : "The President cancels the missile-defense program; \(HomeFrontModel.billions(gs.shadow.homeFront.shieldSpent)) already spent.")
            return true
        }
        let years = HomeFrontModel.shieldBuildYears(year: gs.currentYear)
        gs.shadow.homeFront.shieldStarted = gs.currentDate
        gs.shadow.homeFront.shieldReady = GameCalendar.calendar.date(byAdding: .year, value: years, to: gs.currentDate)
        self.gameState = gs
        let banned = HomeFrontModel.shieldStatus(on: gs.currentDate) == .treatyBanned
        // Every nuclear rival reads a shield as a bid for a first strike.
        for c in gs.countries.sorted(by: { $0.id < $1.id }) where c.id != me.id && !c.isDestroyed && c.nuclearWarheads > 0 && c.territoryOf == nil {
            modifyDiplomaticRelation(from: c.id, to: me.id, by: banned ? -25 : -10)
            if let i = gameState?.countries.firstIndex(where: { $0.id == c.id }) {
                gameState?.countries[i].aggressionLevel = min(100, c.aggressionLevel + 3)
            }
        }
        if banned, let pi = gameState?.countries.firstIndex(where: { $0.id == me.id }) {
            gameState?.countries[pi].treatyViolations += 1
            bump(popularity: -2, ruthlessness: 10)
        } else {
            bump(popularity: 1)
        }
        news("The President orders a national missile shield: \(years) years and about \(HomeFrontModel.billions(HomeFrontModel.shieldAnnualCost(gdpTrillions: me.gdp))) a year."
             + (banned ? " It breaks the ABM Treaty." : " Rivals call it destabilizing."), severity: banned ? 2 : 1, icon: "🛡️")
        return true
    }

    /// Warheads the shield stops in a strike on the President's nation: a fixed share of those still coming.
    func missileShieldIntercepts(target: String, incoming: Int) -> Int {
        guard let gs = gameState, target == gs.playerCountryID, incoming > 0,
              gs.shadow.homeFront.shieldStarted != nil, let ready = gs.shadow.homeFront.shieldReady, gs.currentDate >= ready else { return 0 }
        let n = HomeFrontModel.intercepted(incoming, rate: HomeFrontModel.interceptRate(year: gs.currentYear))
        gs.shadow.homeFront.shieldIntercepted += n
        self.gameState = gs
        addLog("🛡️ MISSILE SHIELD: \(n) of \(incoming) incoming warheads intercepted. \(incoming - n) get through.", type: .warning)
        return n
    }

    // MARK: Nuclear tests

    private func runNuclearTest(atmospheric: Bool) -> Bool {
        guard let gs = gameState, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return false }
        let me = gs.countries[pi]
        let status = HomeFrontModel.testStatus(atmospheric: atmospheric, on: gs.currentDate)
        gs.countries[pi].nuclearWarheads -= 1
        gs.shadow.homeFront.tests.append(NuclearTestRecord(date: gs.currentDate, atmospheric: atmospheric, status: status))
        if gs.shadow.homeFront.tests.count > 100 { gs.shadow.homeFront.tests.removeFirst() }
        if status == .treatyBanned { gs.countries[pi].treatyViolations += 1 }
        if atmospheric {
            gs.globalRadiation += 1
            gs.countries[pi].profile.qualityOfLife = max(0, gs.countries[pi].profile.qualityOfLife - 0.5)
        }
        self.gameState = gs
        let world = status == .treatyBanned ? -15 : status == .restricted ? -8 : -3
        for c in gs.countries.sorted(by: { $0.id < $1.id }) where c.id != me.id && !c.isDestroyed && c.territoryOf == nil {
            let rival = (c.diplomaticRelations[me.id] ?? 0) < 0 && !me.alliances.contains(c.id)
            modifyDiplomaticRelation(from: c.id, to: me.id, by: rival ? world - 3 : world)
            // Deterrence: rivals think twice.
            if rival, let i = gameState?.countries.firstIndex(where: { $0.id == c.id }) {
                gameState?.countries[i].aggressionLevel = max(1, c.aggressionLevel - 4)
            }
        }
        switch status {
        case .treatyBanned: bump(popularity: -6, ruthlessness: 15)
        case .restricted: bump(popularity: -3, ruthlessness: 6)
        default: bump(popularity: gs.currentDate < HomeFrontModel.limitedTestBan ? 1 : 0, ruthlessness: 2)
        }
        let kind = atmospheric ? "an atmospheric" : "an underground"
        news("\(me.name) conducts \(kind) nuclear test. \(HomeFrontModel.testNote(atmospheric: atmospheric, on: gs.currentDate))"
             + (atmospheric ? " Fallout is detected downwind." : ""), severity: status == .legal ? 1 : 2, icon: "☢️")
        return true
    }

    // MARK: Staying in power

    /// Why an attempt to stay in power can't be made now, or nil.
    func stayInPowerProblem(route: String) -> String? {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return "No game in progress." }
        guard me.id == "USA" else { return "Only the U.S. presidency's term and election rules are modeled; your government falls its own way." }
        guard gs.shadow.electionsEnabled else { return "Elections are off in this game; there is no term to extend." }
        if gs.shadow.homeFront.bid != nil { return "An attempt to stay in power is already under way." }
        let y = gs.nextPresidentialYear
        let limited = ElectionCycle.termLimited(gs.shadow.campaign, termsWon: gs.shadow.termsWon, year: y)
            || gs.shadow.campaign.leaveReason == .termLimited
        switch route {
        case "amendment":
            guard ElectionRules(year: y).termLimited else { return "No amendment limits a President's terms before 1951: there is nothing to repeal." }
            return gs.shadow.homeFront.termLimitRepealed ? "The 22nd Amendment is already repealed." : nil
        case "thirdTerm":
            if ElectionRules(year: y).termLimited { return "The 22nd Amendment bars a third term. Defy it, postpone the election, or seek its repeal." }
            return gs.shadow.campaign.leaveReason == .retired ? nil
                : "No law bars a third term before 1951: run again at the next election. Breaking Washington's two-term tradition will cost votes."
        case "defy":
            guard ElectionRules(year: y).termLimited else { return "No amendment limits your terms in \(gs.currentYear): to stay, win the next election (or postpone it)." }
            return limited ? nil : "You can still run for another term lawfully: win the election."
        default:   // postpone
            return nil
        }
    }

    private func runStayInPower(route: String) -> Bool {
        guard let gs = gameState, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return false }
        if route == "thirdTerm" {
            // Before 1951: legal, but the tradition costs votes.
            gs.shadow.campaign.running = true
            gs.shadow.campaign.leaveOfficeOn = nil
            gs.shadow.campaign.leaveReason = nil
            self.gameState = gs
            bump(popularity: -3)
            news("The President will seek a third term, breaking the two-term tradition Washington set.", severity: 2)
            return true
        }
        gs.shadow.homeFront.bid = TenureBid(route: route, started: gs.currentDate)
        if route == "amendment" {
            self.gameState = gs
            bump(popularity: -4, ruthlessness: 5, congress: -3)
            news("The President asks Congress to repeal the 22nd Amendment. It needs two-thirds of both houses and three-quarters of the states.", severity: 2)
            return true
        }
        gs.countries[pi].profile.outcry = min(100, gs.countries[pi].profile.outcry + 20)
        gs.shadow.impeachmentStage = max(gs.shadow.impeachmentStage, 1)
        self.gameState = gs
        bump(popularity: -10, ruthlessness: 35, congress: -10)
        news(route == "postpone"
             ? "The President announces the next presidential election will be postponed. No federal election has ever been postponed, not even in 1864."
             : "The President declares he will remain in office past the end of his second term, defying the 22nd Amendment.",
             severity: 3)
        return true
    }

    /// One stage a turn: Congress, the courts, the states, the military. Pass them all and the President stays.
    private func advanceTenureBid() {
        guard let gs = gameState, let bid = gs.shadow.homeFront.bid, let me = gs.getPlayerCountry() else { return }
        let stages = HomeFrontModel.stages(route: bid.route)
        guard bid.stage < stages.count else { return }
        let stage = stages[bid.stage]
        let loyalty = HomeFrontModel.militaryLoyalty(popularity: gs.shadow.popularity, ruthlessness: gs.shadow.ruthlessness,
                                                     defense: gs.shadow.budget.defense)
        let odds = HomeFrontModel.stageOdds(stage, route: bid.route, congress: Double(me.congressionalSupport),
                                            popularity: gs.shadow.popularity, outcry: me.profile.outcry, loyalty: loyalty,
                                            courtsWeakened: courtsWeakened())
        let roll = Double.random(in: 0..<1, using: &gs.rng)
        self.gameState = gs
        guard roll < odds else { return failTenureBid(bid, at: stage) }
        gs.shadow.homeFront.bid?.stage += 1
        self.gameState = gs
        let lines: [String: String] = [
            "congress": bid.route == "amendment" ? "Two-thirds of Congress vote to send the repeal to the states." : "Congress does not stop him: the leadership blocks every resolution of disapproval.",
            "courts": "The Supreme Court declines to rule, calling it a political question.",
            "states": bid.route == "amendment" ? "The thirty-eighth state ratifies." : "Governors grumble, but the states fall into line.",
            "military": "The Joint Chiefs say the armed forces will follow lawful orders, and take no side.",
        ]
        news(lines[stage] ?? "", severity: 2)
        if bid.stage + 1 >= stages.count { succeedTenureBid(bid) }
    }

    /// The hook for emergency powers and court challenges: courts are weaker while emergency powers are in force.
    func courtsWeakened() -> Bool { homeFrontEmergencyInForce() }

    func failTenureBid(_ bid: TenureBid, at stage: String) {
        guard let gs = gameState else { return }
        gs.shadow.homeFront.bid = nil
        gs.shadow.homeFront.bidsFailed += 1
        self.gameState = gs
        if bid.route == "amendment" {
            bump(popularity: -5)
            news(stage == "congress" ? "The repeal of the 22nd Amendment fails in Congress." : "The repeal of the 22nd Amendment dies in the state legislatures.", severity: 2)
            return
        }
        let why: [String: String] = [
            "congress": "Congress votes to stop the President.",
            "courts": "The Supreme Court rules unanimously against the President.",
            "states": "Governors and state legislatures refuse to go along; the states will hold the election.",
            "military": "The Joint Chiefs refuse to support an unconstitutional order.",
        ]
        news(why[stage] ?? "The attempt fails.", severity: 3)
        let roll = Double.random(in: 0..<1, using: &gs.rng)
        self.gameState = gs
        if roll < HomeFrontModel.removalShare {
            news("Within days the House impeaches and the Senate convicts. You are removed from office.", severity: 3)
            endPresidency(.impeached)
        } else {
            gs.shadow.impeachmentStage = max(gs.shadow.impeachmentStage, 2)
            self.gameState = gs
            bump(popularity: -15, ruthlessness: 40)
            news("The President backs down. Articles of impeachment are drafted anyway.", severity: 3)
        }
    }

    func succeedTenureBid(_ bid: TenureBid) {
        guard let gs = gameState else { return }
        gs.shadow.homeFront.bid = nil
        if bid.route == "amendment" {
            gs.shadow.homeFront.termLimitRepealed = true
            gs.shadow.campaign.exemptFromTermLimit = true
            if gs.shadow.campaign.leaveReason == .termLimited {
                gs.shadow.campaign.leaveReason = nil
                gs.shadow.campaign.leaveOfficeOn = nil
                gs.shadow.campaign.running = true
            }
            self.gameState = gs
            news("The 22nd Amendment is repealed. The President may run again, and again.", severity: 3)
            return
        }
        self.gameState = gs
        endPresidency(.ruleExtended)
    }

    // MARK: Each turn

    /// What the power plays bring each turn: cooked numbers leaking, cheap money turning into inflation, stakes paying
    /// (and scandals), the shield's bills, a power bid's next stage, troops in the states. Nothing until one is used.
    func processHomeFront() {
        guard let gs = gameState, !gs.gameOver, gs.shadow.homeFront.isActive,
              let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
        let scale = gs.scale
        let yf = scale.yearFraction
        let now = gs.currentDate

        // Fixing the numbers: the good-looking figures help a little, until the truth leaks.
        if let fired = gs.shadow.homeFront.statisticianFired {
            if gs.shadow.homeFront.numbersLeaked == nil {
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + scale.amount(annual: 2))
                let years = Double(GameCalendar.days(from: fired, to: now)) / 365.25
                if Double.random(in: 0..<1, using: &gs.rng) < scale.probability(annual: HomeFrontModel.leakAnnual(years: years)) {
                    let truth = gs.trueEconomy
                    gs.shadow.homeFront.numbersLeaked = now
                    gs.shadow.homeFront.leakedGrowth = truth.growth
                    gs.shadow.homeFront.leakedInflation = truth.inflation
                    gs.shadow.homeFront.creditSpread += 0.75
                    gs.countries[pi].gdp *= 0.997
                    gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 6)
                    gs.shadow.ruthlessness += 6
                    gs.shadow.post("LEAKED: the government's own data show growth of \(HomeFrontModel.one(truth.growth))% and inflation of \(HomeFrontModel.one(truth.inflation))%, not the official figures. Bond markets sell off.", date: now, severity: 3)
                    addLog("📉 The true economic figures leak. Markets and the polls react.", type: .warning)
                }
            }
        }

        // The central bank: cheap money now, inflation and dear credit later.
        if var inflation = gs.shadow.homeFront.inflation {
            var pp = gs.shadow.homeFront
            let baseline = HomeFrontModel.baselineInflation(year: gs.currentYear)
            let target = HomeFrontModel.inflationTarget(baseline: baseline, pressure: pp.bankPressure, overruled: pp.bankOverruled)
            inflation += (target - inflation) * (1 - GameMath.pow(0.55, yf))
            pp.inflation = inflation
            if !pp.bankOverruled { pp.bankPressure *= GameMath.pow(0.7, yf) }
            pp.creditSpread *= GameMath.pow(0.6, yf)
            gs.shadow.homeFront = pp
            let borrowing = HomeFrontModel.borrowing(inflation: inflation, spread: pp.creditSpread, overruled: pp.bankOverruled)
            let extra = gs.homeFrontGrowth(borrowing: borrowing)
            gs.countries[pi].gdp = max(0.0001, gs.countries[pi].gdp * scale.growthFactor(annual: extra / 100))
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - scale.amount(annual: max(0, inflation - 4) * 1.5))
            if borrowing > 5 {
                let interest = gs.countries[pi].gdp * 1000 * (borrowing - 5) / 100 * 0.3 * yf
                gs.countries[pi].treasury -= Int64((interest * 1e9).rounded())
            }
        }

        // Equity stakes: dividends, and the insiders who traded first.
        if !gs.shadow.homeFront.stakes.isEmpty {
            let income = gs.shadow.homeFront.stakes.reduce(0) { $0 + $1.value } * HomeFrontModel.stakeYield * yf
            gs.shadow.homeFront.stakeIncome += income
            gs.countries[pi].treasury += Int64((income * 1e9).rounded())
            if Double.random(in: 0..<1, using: &gs.rng) < scale.probability(annual: HomeFrontModel.scandalAnnual(stakes: gs.shadow.homeFront.stakes.count)) {
                let stakes = gs.shadow.homeFront.stakes
                let s = stakes[Int.random(in: 0..<stakes.count, using: &gs.rng)]
                let name = HomeFrontModel.industry(s.industry)?.name.lowercased() ?? s.industry
                gs.shadow.homeFront.scandals += 1
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 4)
                gs.shadow.ruthlessness += 6
                gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport - 4)
                gs.shadow.post("Conflict-of-interest scandal: people close to the White House traded \(name) shares ahead of the government's stake. Congress opens hearings.", date: now, severity: 2)
                addLog("💼 Conflict-of-interest scandal over the \(name) stake.", type: .warning)
            }
        }

        // Missile shield: the bills, and the day it goes live.
        if gs.shadow.homeFront.shieldStarted != nil, let ready = gs.shadow.homeFront.shieldReady {
            let live = now >= ready
            let cost = HomeFrontModel.shieldAnnualCost(gdpTrillions: gs.countries[pi].gdp) * (live ? 0.25 : 1) * yf
            gs.shadow.homeFront.shieldSpent += cost
            gs.countries[pi].treasury -= Int64((cost * 1e9).rounded())
            if live, gs.previousTurnDate < ready {
                let pct = Int((HomeFrontModel.interceptRate(year: gs.currentYear) * 100).rounded())
                gs.shadow.post("The missile shield is operational. Planners expect it to stop about \(pct)% of incoming warheads.", date: now, severity: 2)
                addLog("🛡️ Missile shield operational (about \(pct)% of incoming warheads).", type: .info)
            }
        }
        self.gameState = gs

        processHomeDeployments()
        if gameState?.shadow.homeFront.bid != nil, gameState?.shadow.domesticEnding == nil { advanceTenureBid() }
    }
}
