//
//  HomePlayCommands.swift
//  Global Thermal Nuclear War
//
//  The command box half of the power plays (3.36.0): the phrases the built-in reader knows ("fire the chief
//  statistician", "pressure the Fed to cut rates", "buy a stake in steel", "postpone the election", "build a missile
//  shield", "conduct an underground nuclear test", "send troops into Texas over the governor's objection"), the
//  confirmation card (what EXECUTE commits, and the cabinet's read-out with honest numbers), and the chief of staff's
//  lines. Nothing here changes the game; the order runs through `executeCommand` like every other.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum HomePlayCommands {

    /// Phrases matched at the start of an order (longest first), each with its play and mode.
    static let phrases: [(String, HomePlay, String)] = {
        let table: [(HomePlay, String, [String])] = [
            (.troopsHome, "deploy", ["federalize the national guard in", "federalize the guard in", "send federal troops into", "send federal troops to",
                                     "deploy federal troops to", "deploy federal troops in", "deploy federal troops into", "deploy the national guard to",
                                     "deploy the national guard in", "send the national guard into", "send the national guard to",
                                     "send troops into the state of", "deploy troops to the state of", "troops into the state of"]),
            (.troopsHome, "withdraw", ["withdraw federal troops from", "pull federal troops out of", "withdraw the national guard from",
                                       "send the national guard home from", "stand down the guard in"]),
            (.fixNumbers, "fire", ["fire the chief statistician", "fire the statistician", "fire the head of the bureau of labor statistics",
                                   "fire the labor statistics chief", "fire the bls chief", "fire the bls commissioner", "suppress the jobs report",
                                   "suppress the economic reports", "suppress the bad numbers", "bury the jobs report", "bury the bad numbers",
                                   "fix the numbers", "cook the books", "cook the numbers"]),
            (.fixNumbers, "restore", ["rehire an independent statistician", "rehire the statistician", "restore the statistics office",
                                      "restore independent statistics", "stop fixing the numbers"]),
            (.leanOnBank, "pressure", ["pressure the fed to cut rates", "pressure the federal reserve to cut rates", "pressure the central bank to cut rates",
                                       "pressure the fed", "pressure the federal reserve", "pressure the central bank", "lean on the fed",
                                       "lean on the central bank", "lean on the bank", "make the fed cut rates", "cut interest rates", "cut rates",
                                       "lower interest rates", "lower rates"]),
            (.leanOnBank, "overrule", ["overrule the fed", "overrule the federal reserve", "overrule the central bank", "fire the fed chair",
                                       "fire the chairman of the fed", "fire the central bank governor", "take control of the fed",
                                       "take control of the central bank", "order the fed to cut rates", "order the central bank to cut rates"]),
            (.leanOnBank, "release", ["restore the fed s independence", "restore fed independence", "restore central bank independence",
                                      "leave the fed alone", "leave the central bank alone"]),
            (.buyStake, "buy", ["buy a stake in", "take a stake in", "buy a government stake in", "take an equity stake in", "buy an equity stake in",
                                "buy shares in", "invest the sovereign wealth fund in", "nationalize part of", "buy into"]),
            (.buyStake, "sell", ["sell the stake in", "sell our stake in", "sell the government stake in", "sell the government s stake in",
                                 "divest from", "sell shares in"]),
            (.stayInPower, "defy", ["defy the 22nd amendment", "ignore the 22nd amendment", "ignore term limits", "defy term limits",
                                    "stay in power", "stay in office", "refuse to leave office", "seize a third term", "serve a third term"]),
            (.stayInPower, "postpone", ["postpone the election", "postpone the presidential election", "cancel the election", "delay the election",
                                        "suspend the election"]),
            (.stayInPower, "amendment", ["repeal the 22nd amendment", "repeal term limits", "propose an amendment to repeal term limits",
                                         "amend the constitution to allow a third term", "abolish term limits"]),
            (.stayInPower, "thirdTerm", ["run for a third term", "seek a third term", "run again for a third term"]),
            (.missileShield, "start", ["build a missile shield", "build a missile defense shield", "start a missile defense program",
                                       "build missile defense", "build a national missile defense", "fund a missile shield", "missile shield",
                                       "build a golden dome", "build an iron dome over", "build an iron dome"]),
            (.missileShield, "cancel", ["cancel the missile shield", "cancel missile defense", "stop the missile shield", "scrap the missile shield"]),
            (.nuclearTest, "underground", ["conduct an underground nuclear test", "underground nuclear test", "underground test",
                                           "conduct a nuclear test", "resume nuclear testing", "test a nuclear weapon", "test a nuke", "nuclear test",
                                           "test a bomb", "detonate a test device"]),
            (.nuclearTest, "atmospheric", ["conduct an atmospheric nuclear test", "atmospheric nuclear test", "atmospheric test",
                                           "test a nuke in the atmosphere", "above ground nuclear test"]),
        ]
        return table.flatMap { p, m, list in list.map { ($0, p, m) } }.sorted { $0.0.count > $1.0.count }
    }()

    /// A normalized order body (framing words already stripped) → a power play intent, or nil.
    static func parse(_ body: String) -> CommandIntent? {
        guard let (phrase, play, mode) = phrases.first(where: { body == $0.0 || body.hasPrefix($0.0 + " ") }) else { return nil }
        guard let verb = CommandVerb(rawValue: play.rawValue) else { return nil }
        var rest = String(body.dropFirst(phrase.count)).trimmingCharacters(in: .whitespaces)
        var resolvedMode = mode
        if play == .nuclearTest {
            if (" " + rest + " ").contains(" atmosphere ") || (" " + rest + " ").contains(" atmospheric ") { resolvedMode = "atmospheric" }
            rest = ""   // a test has no target
        }
        // "… over the governor's objection", "… to restore order": the state is what comes before.
        for cut in [" over ", " to restore", " against ", " despite ", " now", " immediately"] {
            if let r = (" " + rest).range(of: cut) { rest = String((" " + rest)[..<r.lowerBound]).trimmingCharacters(in: .whitespaces) }
        }
        while let f = rest.split(separator: " ").first, ["the", "a", "an", "of", "in", "into", "to"].contains(String(f)) {
            rest = String(rest.dropFirst(f.count)).trimmingCharacters(in: .whitespaces)
        }
        return CommandIntent(verb: verb, targets: [resolvedMode] + (rest.isEmpty ? [] : [rest]))
    }

    /// Words the chief of staff (or a player) may use for a mode.
    static let modeAliases: [String: String] = [
        "cut": "pressure", "pressure": "pressure", "lean": "pressure", "fire chair": "overrule", "control": "overrule",
        "independence": "release", "restore independence": "release", "rehire": "restore", "honest": "restore",
        "divest": "sell", "underground": "underground", "atmosphere": "atmospheric", "above ground": "atmospheric",
        "third term": "thirdterm", "repeal": "amendment", "postpone election": "postpone", "cancel election": "postpone",
        "delay": "postpone", "remain": "defy", "stay": "defy", "send": "deploy", "pull out": "withdraw", "stop": "cancel",
    ]

    /// The mode and argument in an intent's targets: [mode?, argument…].
    static func split(_ play: HomePlay, _ targets: [String]) -> (mode: String, arg: String) {
        let words = targets.map { CommandParser.normalize($0) }.filter { !$0.isEmpty }
        let modes = Dictionary(uniqueKeysWithValues: play.modes.map { ($0.lowercased(), $0) })
        if let first = words.first, let m = modes[first.replacingOccurrences(of: " ", with: "")] ?? modeAliases[first].flatMap({ modes[$0] }) {
            return (m, words.dropFirst().joined(separator: " "))
        }
        return (play.modes[0], words.joined(separator: " "))
    }

    /// "steel", "chips", "the oil industry" → an industry id.
    static func industryID(_ raw: String) -> String? {
        let n = " " + CommandParser.normalize(raw) + " "
        let table: [(String, [String])] = [
            ("semiconductors", ["semiconductor", "semiconductors", "chips", "chip", "chipmakers", "microchips"]),
            ("rareEarths", ["rare earth", "rare earths", "critical minerals", "minerals", "lithium", "mining"]),
            ("steel", ["steel", "steelmakers", "iron"]),
            ("oil", ["oil", "gas", "energy", "petroleum"]),
            ("shipbuilding", ["shipbuilding", "shipyards", "ships"]),
            ("railroads", ["railroads", "railroad", "railways", "railway", "rail"]),
            ("aerospace", ["aerospace", "aircraft", "aviation", "defense contractors", "defense industry"]),
            ("autos", ["automobiles", "autos", "cars", "automakers", "car"]),
            ("telecom", ["telegraph", "telephone", "telecom", "telecommunications"]),
        ]
        for (id, words) in table where words.contains(where: { n.contains(" \($0) ") }) { return id }
        return HomeFrontModel.industry(raw)?.id
    }
}

// MARK: - Planning

extension GameEngine {

    /// The confirmation card for a power play (read-only).
    func planHomePlay(_ play: HomePlay, _ intent: CommandIntent, source: CommandSource) -> CommandOutcome {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return .rejected("Start a game first.") }
        let (mode, arg) = HomePlayCommands.split(play, intent.confirmedTargets ?? intent.targets)
        var target = me.id
        var label = "\(me.name), \(gs.currentYear)"
        switch play {
        case .buyStake:
            guard !arg.isEmpty else {
                let list = HomeFrontModel.industries.filter { $0.exists(in: gs.currentYear) }.map { $0.name.lowercased() }
                return .rejected("Name an industry: \(list.joined(separator: ", ")).")
            }
            guard let id = HomePlayCommands.industryID(arg), let ind = HomeFrontModel.industry(id) else {
                return .rejected("No industry called \"\(String(arg.prefix(30)))\". Try steel, oil, shipbuilding, aerospace or semiconductors.")
            }
            target = id
            label = "\(ind.name), \(gs.currentYear)"
        case .troopsHome:
            switch homeStateTarget(arg) {
            case .success(let s): target = s.id; label = s.label
            case .failure(let why): return .rejected(why.message)
            }
        default: break
        }
        let order = GameOrder(kind: .homePlay, target: target, action: play.rawValue, mission: mode)
        if let p = orderProblem(order) { return .rejected(p) }
        var plan = CommandPlan(title: play.title + (mode == play.modes[0] ? "" : ": \(mode.uppercased())"), target: label, orders: [order],
                               committed: [], heldBack: [], warnings: [], actionsNeeded: 1, actionsLeft: gs.actionsRemaining, source: source)
        let read = homePlayReadout(play, mode: mode, target: target)
        plan.committed = read.committed
        plan.warnings = read.warnings
        if plan.nuclear { plan.warnings.insert(CommandWarning(text: "NUCLEAR DETONATION. A second confirmation is required.", level: 2), at: 0) }
        return .plan(plan)
    }

    /// What an order commits and what the cabinet says about it, every number from the engine's own model.
    func homePlayReadout(_ play: HomePlay, mode: String, target: String) -> (committed: [String], warnings: [CommandWarning]) {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return ([], []) }
        let year = gs.currentYear
        let pp = gs.shadow.homeFront
        func who(_ role: String) -> String {
            let t = AdviceEngine.roleTitle(role)
            return AdviceEngine.advisor(for: role, in: gs.advisors).map { "\(t) \($0.name)" } ?? t
        }
        var c: [String] = []
        var w: [CommandWarning] = []
        switch play {
        case .troopsHome:
            let r = homeTroopsReadout(mode: mode, state: target)
            c = r.0; w = r.1
        case .fixNumbers:
            let office = HomeFrontModel.statsOffice(year: year)
            if mode == "restore" {
                c = ["Rehire an independent head of \(office); the official figures are honest again.", "Credit markets ease a little."]
            } else {
                let b = HomeFrontModel.officialBias(months: 0)
                let leak = Int((HomeFrontModel.leakAnnual(years: 0) * 100).rounded())
                c = ["Fire the head of \(office) and hold back the weak report.",
                     "Official growth reads about \(HomeFrontModel.signed(b.growth)) points better, and the error grows every month.",
                     "The true figures stay in the government's books; about \(leak)% chance they leak within a year, more after."]
                w.append(CommandWarning(text: "\(who("economic")): It changes what we say, not the economy. When the real numbers leak, markets punish us and approval falls about 6 points.", level: 2))
                w.append(CommandWarning(text: "\(who("press")): The story will be the firing, not the numbers.", level: 1))
            }
        case .leanOnBank:
            let bank = HomeFrontModel.centralBank(year: year, nation: me.id) ?? "the central bank"
            let base = pp.inflation ?? HomeFrontModel.baselineInflation(year: year)
            switch mode {
            case "release":
                c = ["Restore \(bank)'s independence: rates drift back to normal, inflation with them."]
            case "overrule":
                let p = min(HomeFrontModel.maxPressure, pp.bankPressure + HomeFrontModel.overruleStep)
                let t = HomeFrontModel.inflationTarget(baseline: HomeFrontModel.baselineInflation(year: year), pressure: p, overruled: true)
                c = ["Overrule \(bank) and order rates cut by \(Int(HomeFrontModel.overruleStep)) points; its chair will resign.",
                     "Growth about \(HomeFrontModel.signed(p * 0.5)) points for a year; approval up about 3."]
                w.append(CommandWarning(text: "\(who("economic")): Inflation heads toward \(HomeFrontModel.one(t))% (now \(HomeFrontModel.one(base))%) within a year or two, and borrowing costs jump the day we do it.", level: 2))
            default:
                let p = min(HomeFrontModel.maxPressure, pp.bankPressure + HomeFrontModel.pressureStep)
                let t = HomeFrontModel.inflationTarget(baseline: HomeFrontModel.baselineInflation(year: year), pressure: p, overruled: pp.bankOverruled)
                c = ["Press \(bank) in public until it cuts rates a point.",
                     "Growth about \(HomeFrontModel.signed(p * 0.5)) points for a year; approval up about 2."]
                w.append(CommandWarning(text: "\(who("economic")): Inflation follows in a year or two, heading toward \(HomeFrontModel.one(t))% (now \(HomeFrontModel.one(base))%). Above 4% it costs approval every month.", level: 1))
            }
        case .buyStake:
            let name = HomeFrontModel.industry(target)?.name.lowercased() ?? target
            if mode == "sell" {
                let v = pp.stakes.first { $0.industry == target }?.value ?? 0
                c = ["Sell the government's stake in \(name) for \(HomeFrontModel.billions(v))."]
            } else {
                let price = HomeFrontModel.stakePrice(gdpTrillions: me.gdp)
                let risk = Int((HomeFrontModel.scandalAnnual(stakes: pp.stakes.count + 1) * 100).rounded())
                c = ["Buy a \(HomeFrontModel.billions(price)) equity stake in \(name).",
                     "It pays about \(HomeFrontModel.billions(price * HomeFrontModel.stakeYield)) a year, and gives the government a say in the industry."]
                w.append(CommandWarning(text: "\(who("economic")): Every stake is a chance for insiders to trade ahead of us: about \(risk)% a year that a conflict-of-interest scandal breaks.", level: 1))
            }
        case .stayInPower:
            let r = stayInPowerReadout(route: mode)
            c = r.0
            for (role, text, level) in r.1 { w.append(CommandWarning(text: "\(who(role)): \(text)", level: level)) }
        case .missileShield:
            if mode == "cancel" {
                c = ["Cancel the missile-defense program; \(HomeFrontModel.billions(pp.shieldSpent)) already spent is lost."]
            } else {
                let years = HomeFrontModel.shieldBuildYears(year: year)
                let cost = HomeFrontModel.shieldAnnualCost(gdpTrillions: me.gdp)
                let pct = Int((HomeFrontModel.interceptRate(year: year) * 100).rounded())
                c = ["Build a national missile shield: \(years) years at about \(HomeFrontModel.billions(cost)) a year, a quarter of that to run.",
                     "Once ready it stops about \(pct)% of the warheads aimed at you. The rest get through."]
                w.append(CommandWarning(text: "\(who("defense")): It never stops most of a real attack; a big salvo still gets through.", level: 1))
                let banned = HomeFrontModel.shieldStatus(on: gs.currentDate) == .treatyBanned
                w.append(CommandWarning(text: "\(who("state")): Every nuclear rival will read it as preparing a first strike." + (banned ? " It breaks the ABM Treaty." : ""), level: banned ? 2 : 1))
            }
        case .nuclearTest:
            let atmo = mode == "atmospheric"
            let status = HomeFrontModel.testStatus(atmospheric: atmo, on: gs.currentDate)
            c = ["Detonate one warhead in \(atmo ? "an atmospheric" : "an underground") test (\(me.nuclearWarheads.formatted()) on hand).",
                 "Rivals grow more cautious; the world's opinion of you falls."]
            if atmo { c.append("Fallout drifts downwind of the test site.") }
            w.append(CommandWarning(text: "\(who("state")): \(HomeFrontModel.testNote(atmospheric: atmo, on: gs.currentDate)) Relations fall \(status == .treatyBanned ? 15 : status == .restricted ? 8 : 3) points with every nation.",
                                    level: status == .legal ? 1 : 2))
        }
        return (c, w)
    }

    /// The card's lines for staying in power, with the honest odds.
    func stayInPowerReadout(route: String) -> ([String], [(String, String, Int)]) {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return ([], []) }
        if route == "thirdTerm" {
            return (["Announce a run for a third term at the next election (legal before 1951)."],
                    [("whc", "Breaking Washington's two-term tradition will cost votes.", 1)])
        }
        let loyalty = HomeFrontModel.militaryLoyalty(popularity: gs.shadow.popularity, ruthlessness: gs.shadow.ruthlessness, defense: gs.shadow.budget.defense)
        let stages = HomeFrontModel.stages(route: route)
        let odds = stages.reduce(1.0) { acc, s in
            acc * HomeFrontModel.stageOdds(s, route: route, congress: Double(me.congressionalSupport), popularity: gs.shadow.popularity,
                                           outcry: me.profile.outcry, loyalty: loyalty, courtsWeakened: courtsWeakened())
        }
        let pct = odds < 0.01 ? "under 1%" : "about \(Int((odds * 100).rounded()))%"
        if route == "amendment" {
            return (["Ask Congress to repeal the 22nd Amendment: two-thirds of both houses, then three-quarters of the states.",
                     "Lawful. If it fails you pay in approval, not your office."],
                    [("whc", "Congress support \(me.congressionalSupport)/100, approval \(Int(gs.shadow.popularity.rounded()))%. Odds it passes: \(pct).", 1)])
        }
        let what = route == "postpone" ? "Postpone the next presidential election indefinitely." : "Remain in office past the end of your second term."
        return ([what, "Congress, the courts, the states and the military each get a say, one a turn.",
                 "Success: you stay, and the game ends with the republic. Failure: almost certainly removal."],
                [("whc", "Odds you are still in office at the end: \(pct). This ends your presidency one way or another.", 2),
                 ("defense", "The armed forces' loyalty to an order like this: \(Int(loyalty.rounded()))/100. They will not move against an election.", 2),
                 ("state", "Allies will treat us as a government that cancelled its own election.", 2)])
    }
}

// MARK: - The chief of staff

extension HomePlayCommands {
    /// The power plays as the actions tool lists them.
    static func toolRows() -> [String] { HomePlay.allCases.map(\.toolLine) }

    /// The economy tool's figures, marked official or leaked.
    static func annotate(_ d: inout [String: Any], _ gs: GameState) {
        let official = gs.officialEconomy
        d["growth_percent_per_year"] = ChatTools.round1(official.growth)
        guard gs.shadow.homeFront.inflation != nil || gs.numbersCooked else { return }
        d["inflation_percent"] = ChatTools.round1(official.inflation)
        d["borrowing_cost_percent"] = ChatTools.round1(official.borrowing)
        if gs.numbersCooked {
            d["figures"] = "official (the statistician was fired; these may not be the true figures)"
            if let g = gs.shadow.homeFront.leakedGrowth, let i = gs.shadow.homeFront.leakedInflation {
                d["leaked_figures"] = "growth \(ChatTools.round1(g))%, inflation \(ChatTools.round1(i))% (leaked \(GameCalendar.format(gs.shadow.homeFront.numbersLeaked ?? gs.currentDate)))"
            }
        }
        if let bank = HomeFrontModel.centralBank(year: gs.currentYear, nation: gs.playerCountryID) {
            d["central_bank"] = gs.shadow.homeFront.bankOverruled ? "\(bank): overruled by the President" : "\(bank): independent"
        }
    }
}
