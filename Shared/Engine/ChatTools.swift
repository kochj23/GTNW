//
//  ChatTools.swift
//  Global Thermal Nuclear War
//
//  3.35.0: the chief of staff's tools. The conversation (Shared/AI/ChatAgent.swift) may only learn about the world and
//  put orders in front of the President through this file. Every tool but one is read-only and answers only what the
//  President could see on screen: the top bar, dossiers (foreign forces as the intelligence estimate, never the true
//  figure), relations, fronts, reach, the budget and the polls, the cabinet's advice, the news wire, the actions on
//  offer with their cost and the odds the Situation Room shows. No tool reads the RNG, a hidden roll or an outcome
//  before it happens, and none writes game state (ChatTests checks a save is byte-identical after every tool).
//
//  `propose_orders` plans orders with the command box's `CommandPlanner` (the same whitelist, warnings and sizing)
//  and returns the cards; nothing runs until the President presses EXECUTE (twice for a nuclear order). Standing
//  orders ("if France mobilizes, move the fleet") are not offered: they would fire without the President's EXECUTE.
//
//  Pure Foundation, so the web core (GTNWCore) compiles it too.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// One tool the model may call: its name, what it is for, and its JSON-schema parameters.
struct ChatToolSpec: Equatable, Sendable {
    var name: String
    var description: String
    /// JSON Schema (object) as compact JSON text, so the spec stays `Sendable`.
    var parametersJSON: String

    var parameters: [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(parametersJSON.utf8))) as? [String: Any] ?? [:]
    }
}

/// One step of a proposed plan: what the model asked for and what the planner made of it.
struct ChatPlanStep: Equatable, Identifiable {
    var id: Int
    var intent: CommandIntent
    var outcome: CommandOutcome
    /// Set once the step has been carried out (or tried).
    var execution: GameEngine.CommandExecution?

    var plan: CommandPlan? { if case .plan(let p) = outcome { return p }; return nil }
    var isReady: Bool { plan != nil && execution == nil }
}

/// A numbered plan the President can execute all at once, step by step, or edit.
struct ChatPlan: Equatable, Identifiable {
    var id: Int
    var steps: [ChatPlanStep]
    var nuclear: Bool { steps.contains { $0.isReady && $0.plan?.nuclear == true } }
    var actionsNeeded: Int { steps.filter(\.isReady).compactMap(\.plan).reduce(0) { $0 + $1.actionsNeeded } }
}

/// What a tool call produced: the text the model reads, and a plan when `propose_orders` ran.
struct ChatToolOutput: Equatable {
    var text: String
    var plan: ChatPlan?
    var isError = false
}

enum ChatTools {
    static let maxSteps = 5
    static let maxOutput = 3_500
    static let maxArgString = 60

    // MARK: Specs

    static let specs: [ChatToolSpec] = [
        spec("game_status", "The President's top bar: nation, leader, date, actions left this turn, DEFCON or alert level, popularity, next election, free troops, wars and allies.", [:]),
        spec("country", "Dossier on one nation or land as the President sees it: government, leader, stability, approval, economy, military (foreign forces are intelligence estimates), warheads, relations with you, its wars and allies. Also colonies and unclaimed land.",
             ["name": str("Nation or land name, an era name, an ISO code, or 'me'")], required: ["name"]),
        spec("forces", "Military by type. Your own forces exactly (troops free, aircraft, navy, warheads, missiles, bombers, fleets); another nation's only as the intelligence estimate.",
             ["name": str("Nation name; omit for your own forces")]),
        spec("reach", "Who can hit whom: with 'target', whether you can reach that nation and how; without it, which nations can reach you (weapon: any, missiles, bombers or nuclear).",
             ["target": str("Nation you want to reach"), "weapon": ["type": "string", "enum": ReachWeapon.allCases.map(\.rawValue)]]),
        spec("diplomacy", "Relations, alliances and treaties. Without 'name': your best and worst relations, allies, wars, treaties and treaty offers. With 'name': that nation's relation to you, its allies, wars and treaties with you.",
             ["name": str("Nation name (optional)")]),
        spec("wars", "Every front you fight or back, and the biggest other wars: who is advancing, troops in theater, will to fight, and the recent war log.", [:]),
        spec("economy", "Your economy and budget: output, economic strength, the budget projection (revenue, spending, deficit, growth), the foreign-aid pool.", [:]),
        spec("politics", "Your popularity and the recent polls, the next election, impeachment, unrest, and the recent notable news that moved opinion.", [:]),
        spec("advisors", "The cabinet: each post, who holds it and their current advice. With action and target: that adviser's stance, reason and the odds the Situation Room shows for it, plus the cabinet's warnings.",
             ["action": str("An order verb from the actions tool (optional)"), "target": str("Nation name (with action)")]),
        spec("news", "The news wire, the latest game log lines, and the orders you carried out recently.",
             ["count": ["type": "integer", "minimum": 1, "maximum": 20]]),
        spec("actions", "Orders available this year with their verb, cost, risk and description; with a target, also the odds shown for each against it.",
             ["target": str("Nation name (optional)"), "category": ["type": "string", "enum": ["military", "diplomatic", "economic", "covert", "treaty", "all"]]]),
        spec("propose_orders", "Put orders in front of the President for confirmation. Nothing runs until the President presses EXECUTE. One step per order, in order, at most 5 steps. Use the verbs from the actions tool.",
             ["steps": ["type": "array", "maxItems": maxSteps, "items": [
                "type": "object",
                "properties": [
                    "verb": ["type": "string", "enum": CommandVerb.allCases.map(\.rawValue)],
                    "targets": ["type": "array", "items": ["type": "string", "maxLength": maxArgString], "maxItems": CommandParser.maxTargets],
                    "ground": ["type": "boolean"], "air": ["type": "boolean"], "naval": ["type": "boolean"],
                    "nuclear": ["type": "string", "enum": ["yes", "no", "unspecified"]],
                    "all": ["type": "boolean"], "light": ["type": "boolean"],
                    "troops": ["type": "number", "minimum": 0, "description": "in thousands: 50 means 50,000 troops"],
                    "aircraft": ["type": "integer", "minimum": 0], "warheads": ["type": "integer", "minimum": 0],
                    "fleet": ["type": "string", "maxLength": maxArgString],
                ] as [String: Any],
                "required": ["verb", "targets"],
             ] as [String: Any]] as [String: Any]], required: ["steps"]),
    ]

    static let names: Set<String> = Set(specs.map(\.name))

    private static func str(_ d: String) -> [String: Any] { ["type": "string", "maxLength": maxArgString, "description": d] }

    private static func spec(_ name: String, _ description: String, _ props: [String: Any], required: [String] = []) -> ChatToolSpec {
        var schema: [String: Any] = ["type": "object", "properties": props]
        if !required.isEmpty { schema["required"] = required }
        let data = (try? JSONSerialization.data(withJSONObject: schema, options: [.sortedKeys])) ?? Data("{}".utf8)
        return ChatToolSpec(name: name, description: description, parametersJSON: String(decoding: data, as: UTF8.self))
    }

    // MARK: Dispatch

    /// Run one tool. Unknown tools and bad arguments come back as an error the model can read and correct.
    static func run(_ name: String, arguments: [String: Any], engine: GameEngine, planID: Int = 0) -> ChatToolOutput {
        guard names.contains(name) else { return error("No tool named \(String(name.prefix(40))). Use only the listed tools.") }
        guard let gs = engine.gameState, let me = gs.getPlayerCountry() else { return error("No game in progress.") }
        let args = Args(arguments)
        switch name {
        case "game_status": return ok(status(engine, gs, me))
        case "country":
            guard let n = args.string("name") else { return error("country needs a name.") }
            return country(n, engine, gs, me)
        case "forces": return forces(args.string("name"), gs, me)
        case "reach":
            // A model asking "who can reach us" often names us as the target: that is the other question.
            if let t = args.string("target"), !Self.isMe(t, gs, me) {
                return ok(["answer": engine.answer(CommandQuestion(topic: .canReach, country: t), in: gs)])
            }
            let w = args.string("weapon").flatMap(ReachWeapon.init(rawValue:)) ?? .any
            return ok(["answer": engine.answer(CommandQuestion(topic: .reachMe, weapon: w), in: gs)])
        case "diplomacy": return diplomacy(args.string("name"), gs, me)
        case "wars": return ok(wars(gs, me))
        case "economy": return ok(economy(gs, me))
        case "politics": return ok(politics(gs, me))
        case "advisors": return advisors(args.string("action"), args.string("target"), engine, gs, me)
        case "news": return ok(news(min(20, max(1, args.int("count") ?? 10)), engine, gs))
        case "actions": return actions(args.string("target"), args.string("category"), gs, me)
        case "propose_orders": return propose(arguments, engine: engine, planID: planID)
        default: return error("No tool named \(name).")
        }
    }

    // MARK: Tools

    private static func status(_ e: GameEngine, _ gs: GameState, _ me: Country) -> [String: Any] {
        var d: [String: Any] = [
            "nation": me.name, "leader": leaderName(gs, me), "date": gs.currentDateLabel, "year": gs.currentYear,
            "turn": "\(gs.turnLength.displayName) \(gs.turn + 1)",
            "actions_left": gs.actionsRemaining, "actions_per_turn": gs.actionsPerTurn,
            gs.defconName.lowercased(): gs.defconLabel, "popularity_percent": Int(gs.shadow.popularity.rounded()),
            "free_troops_thousands": Int(AttackSizing.freeTroops(gs)),
            "at_war_with": names(me.atWarWith, gs), "allies": names(me.alliances, gs),
        ]
        if gs.shadow.electionsEnabled, let next = ElectionCycle.next(after: gs.currentDate) {
            d["next_election_step"] = "\(next.stage.label(year: next.year)) in \(GameCalendar.days(from: gs.currentDate, to: next.date)) days"
        }
        if gs.gameOver { d["game_over"] = gs.gameOverReason }
        if e.isProcessingAITurn { d["note"] = "The world is moving; orders wait for your turn." }
        return d
    }

    static func isMe(_ name: String, _ gs: GameState, _ me: Country?) -> Bool {
        if case .one(.nation(let id), _) = CommandTargets.resolve(name, in: gs) { return id == me?.id }
        return false
    }

    static func leaderName(_ gs: GameState, _ me: Country) -> String {
        let president = Advisor.allAdministrations().last { $0.startYear <= gs.currentYear }?.president
        return gs.shadow.playerLeader ?? (gs.playerCountryID == "USA" ? president.map { "President \($0)" } : nil) ?? "the head of government of \(me.name)"
    }

    private static func country(_ raw: String, _ e: GameEngine, _ gs: GameState, _ me: Country) -> ChatToolOutput {
        let key = CommandParser.normalize(raw)
        let target: ResolvedTarget
        if ["me", "us", "my country", "my nation", "our country", "myself", "you"].contains(key) {
            target = .nation(me.id)
        } else {
            switch CommandTargets.resolve(raw, in: gs) {
            case .none: return error("No nation or land called \"\(String(raw.prefix(40)))\" in \(gs.currentYear).")
            case .many(let opts): return ok(["ambiguous": true, "candidates": opts.map { CommandTargets.label($0, in: gs) }])
            case .one(let t, let note):
                if let note { return withNote(dossier(t, e, gs, me), note) }
                target = t
            }
        }
        return ok(dossier(target, e, gs, me))
    }

    private static func withNote(_ d: [String: Any], _ note: String) -> ChatToolOutput {
        var d = d
        d["note"] = note
        return ok(d)
    }

    private static func dossier(_ t: ResolvedTarget, _ e: GameEngine, _ gs: GameState, _ me: Country) -> [String: Any] {
        guard case .nation(let id) = t, let c = gs.getCountry(id: id) else {
            var d: [String: Any] = ["name": CommandTargets.label(t, in: gs)]
            switch t {
            case .colony(let land):
                d["kind"] = "colony"
                if let col = e.colonyTarget(land) { d["owner"] = col.owner.name }
            case .indigenous: d["kind"] = "land held by its own people, not a state in the game"
            case .unclaimed: d["kind"] = "unclaimed land"
            case .nation: break
            }
            return d
        }
        let mine = c.id == me.id
        let leader = NationModel.leader(for: c, on: gs.currentDate)
        var d: [String: Any] = [
            "name": c.name, "capital": c.capital, "government": c.governmentLine,
            "stability": c.stability, "public_approval_percent": c.publicApproval,
            "economic_strength": c.economicStrength, "output_trillions": round2(c.gdp), "population_millions": c.population,
            "military_strength": estimate(c.militaryStrength, mine: mine, gs),
            "at_war_with": names(c.atWarWith, gs), "allies": names(c.alliances, gs),
            "landlocked": NavalModel.isLandlocked(c.id),
        ]
        if !leader.generic { d["leader"] = "\(leader.title) \(leader.name)" }
        if mine { d["is_you"] = true } else {
            let rel = me.diplomaticRelations[c.id] ?? 0
            d["relations_with_you"] = "\(rel) (\(A11y.relationWord(rel)))"
        }
        if gs.currentYear >= 1945, c.nuclearWarheads > 0 { d["nuclear_warheads"] = estimate(c.nuclearWarheads, mine: mine, gs) }
        if let bloc = MilitaryAllianceSystem.allianceName(year: gs.currentYear, forCountryID: c.id) { d["alliance_bloc"] = bloc }
        if let owner = c.territoryOf { d["territory_of"] = gs.getCountry(id: owner)?.name ?? owner }
        if !mine, let line = e.intelLine(about: c.id) { d["intelligence"] = line }
        return d
    }

    /// The player's own figures are exact; another nation's come as the President's intelligence estimate.
    private static func estimate(_ v: Int, mine: Bool, _ gs: GameState) -> String {
        if mine { return "\(v)" }
        let l = IntelligenceModel.label(trueValue: v, year: gs.currentYear, recon: (gs.shadow.satellites["recon"] ?? 0) > 0)
        return "\(l.text) (\(l.tag.lowercased()))"
    }

    private static func forces(_ name: String?, _ gs: GameState, _ me: Country) -> ChatToolOutput {
        var c = me
        if let name, !["me", "us", "my", "mine", "our", "my forces", "our forces"].contains(CommandParser.normalize(name)) {
            guard case .one(.nation(let id), _) = CommandTargets.resolve(name, in: gs), let other = gs.getCountry(id: id) else {
                return error("No nation called \"\(String(name.prefix(40)))\" in \(gs.currentYear).")
            }
            c = other
        }
        let mine = c.id == me.id
        let year = gs.currentYear
        var d: [String: Any] = [
            "nation": c.name,
            "military_strength": estimate(c.militaryStrength, mine: mine, gs),
            "army": estimate(min(100, c.groundForces), mine: mine, gs),
            "navy": estimate(min(100, c.navalForces), mine: mine, gs),
            "air_force": estimate(min(100, c.airForces), mine: mine, gs),
        ]
        if year >= 1945, c.nuclearWarheads > 0 || mine {
            d["nuclear_warheads"] = estimate(c.nuclearWarheads, mine: mine, gs)
            if mine {
                d["icbms"] = c.icbmCount; d["submarine_missiles"] = c.submarineLaunchedMissiles; d["bombers"] = c.bombers
            }
        }
        if mine {
            d["free_troops_thousands"] = Int(AttackSizing.freeTroops(gs))
            d["aircraft_available"] = Int(AttackSizing.available(.aircraft, in: gs))
            if c.id == "USA" {
                let deployed = Set(gs.shadow.fleetDeployments.map(\.fleetID))
                d["fleets_in_port"] = NavalModel.fleets(in: year).filter { !deployed.contains($0.id) }.map(\.name)
                d["fleets_at_sea"] = gs.shadow.fleetDeployments.map { f in
                    "\(NavalModel.fleet(id: f.fleetID)?.name ?? f.fleetID): \(f.mission.title.lowercased()), \(gs.getCountry(id: f.target)?.name ?? f.target)"
                }
            }
        } else {
            d["note"] = "Intelligence estimates, not confirmed figures."
        }
        return ok(d)
    }

    private static func diplomacy(_ name: String?, _ gs: GameState, _ me: Country) -> ChatToolOutput {
        if let name, !name.isEmpty {
            guard case .one(.nation(let id), _) = CommandTargets.resolve(name, in: gs), let c = gs.getCountry(id: id) else {
                return error("No nation called \"\(String(name.prefix(40)))\" in \(gs.currentYear).")
            }
            let rel = me.diplomaticRelations[c.id] ?? 0
            var d: [String: Any] = [
                "nation": c.name, "relations_with_you": "\(rel) (\(A11y.relationWord(rel)))",
                "its_allies": names(c.alliances, gs), "its_wars": names(c.atWarWith, gs),
                "treaties_with_you": gs.treaties.filter { Set($0.signatories).isSuperset(of: [me.id, c.id]) }.map(\.type.rawValue),
            ]
            if let bloc = MilitaryAllianceSystem.allianceName(year: gs.currentYear, forCountryID: c.id) { d["alliance_bloc"] = bloc }
            d["allied_with_you"] = me.alliances.contains(c.id) || MilitaryAllianceSystem.areAllied(country1: me.id, country2: c.id, year: gs.currentYear)
            return ok(d)
        }
        let rels = gs.countries.filter { !$0.isDestroyed && $0.id != me.id && $0.territoryOf == nil }
            .map { ($0.name, me.diplomaticRelations[$0.id] ?? 0) }
        let best = rels.sorted { ($0.1, $1.0) > ($1.1, $0.0) }.prefix(6).map { "\($0.0) \($0.1)" }
        let worst = rels.sorted { ($0.1, $0.0) < ($1.1, $1.0) }.prefix(6).map { "\($0.0) \($0.1)" }
        var d: [String: Any] = [
            "best_relations": Array(best), "worst_relations": Array(worst),
            "allies": names(me.alliances, gs), "at_war_with": names(me.atWarWith, gs),
            "treaties": gs.treaties.filter { $0.signatories.contains(me.id) }.suffix(12).map { t in
                "\(t.type.rawValue): " + t.signatories.filter { $0 != me.id }.map { gs.getCountry(id: $0)?.name ?? $0 }.joined(separator: ", ")
            },
            "treaty_offers": gs.shadow.treatyOffers.map { "\($0.type.rawValue) from \(gs.getCountry(id: $0.from)?.name ?? $0.from)" },
        ]
        if let bloc = MilitaryAllianceSystem.allianceName(year: gs.currentYear, forCountryID: me.id) { d["your_alliance_bloc"] = bloc }
        return ok(d)
    }

    private static func wars(_ gs: GameState, _ me: Country) -> [String: Any] {
        func n(_ id: String) -> String { gs.getCountry(id: id)?.name ?? id }
        let fighting = gs.shadow.fronts.filter { $0.status == .fighting }
        let ours = fighting.filter { $0.attacker == me.id || $0.defender == me.id || $0.usSide != nil }
        let others = fighting.filter { f in !ours.contains { $0.id == f.id } }
            .sorted { ($0.attackerTroops + $0.defenderTroops) > ($1.attackerTroops + $1.defenderTroops) }.prefix(5)
        func line(_ f: WarFront) -> String {
            let momentum = f.attackerMomentum > 0.05 ? "\(n(f.attacker)) advancing"
                : (f.attackerMomentum < -0.05 ? "\(n(f.defender)) pushing back" : "front static")
            return "\(n(f.attacker)) vs \(n(f.defender)) since \(GameCalendar.format(f.startDate)): \(momentum); troops \(Int(f.attackerTroops))K vs \(Int(f.defenderTroops))K; will to fight \(Int(f.attackerWill * 100))% vs \(Int(f.defenderWill * 100))%"
        }
        return [
            "your_wars": names(me.atWarWith, gs),
            "your_fronts": ours.map(line),
            "other_wars": others.map(line),
            "war_log": Array(gs.shadow.warLog.suffix(8)),
        ]
    }

    private static func economy(_ gs: GameState, _ me: Country) -> [String: Any] {
        let p = BudgetModel.project(gs.shadow.budget, atWar: !me.atWarWith.isEmpty)
        return [
            "nation": me.name, "output_trillions": round2(me.gdp), "economic_strength": me.economicStrength,
            "budget_year": gs.currentYear,
            "revenue_percent_gdp": round1(p.revenue), "spending_percent_gdp": round1(p.spending),
            (p.deficit >= 0 ? "deficit_percent_gdp" : "surplus_percent_gdp"): round1(abs(p.deficit)),
            "growth_percent_per_year": round1(p.growth),
            "defense_percent_gdp": round1(gs.shadow.budget.defense),
            "foreign_aid_pool_billions": round1(gs.shadow.budget.aidPool(gdpTrillions: me.gdp)),
            "budget_review_pending": gs.shadow.budgetReviewPending,
        ]
    }

    private static func politics(_ gs: GameState, _ me: Country) -> [String: Any] {
        let polls = gs.shadow.polls.suffix(6).map { "\(GameCalendar.format($0.date)): \(Int($0.popularity.rounded()))%" }
        var d: [String: Any] = [
            "popularity_percent": Int(gs.shadow.popularity.rounded()),
            "recent_polls": Array(polls),
            "public_approval_percent": me.publicApproval, "stability": me.stability,
            "impeachment": ["none", "Congress investigating", "articles of impeachment", "trial in the Senate"][max(0, min(3, gs.shadow.impeachmentStage))],
            "public_outrage": gs.shadow.ruthlessness > 30 ? "high" : (gs.shadow.ruthlessness > 10 ? "rising" : "low"),
            "notable_news": gs.shadow.ticker.filter { $0.severity >= 1 }.suffix(8).map { "\(GameCalendar.format($0.date)): \($0.text)" },
        ]
        if !gs.shadow.electionsEnabled { d["elections"] = "off" }
        else if let next = ElectionCycle.next(after: gs.currentDate) {
            d["next_election_step"] = "\(next.stage.label(year: next.year)) in \(GameCalendar.days(from: gs.currentDate, to: next.date)) days"
        }
        return d
    }

    private static func advisors(_ action: String?, _ target: String?, _ e: GameEngine, _ gs: GameState, _ me: Country) -> ChatToolOutput {
        if let action {
            guard let a = actionFor(action), OrderWhitelist.allows(a) else {
                return error("\(String(action.prefix(40))) is not an order the chief of staff can put forward. Use a verb from the actions tool.")
            }
            guard let target, case .one(.nation(let id), _) = CommandTargets.resolve(target, in: gs), let t = gs.getCountry(id: id) else {
                return error("advisors needs a target nation with an action.")
            }
            let adv = AdviceEngine.advise(action: a, player: me, target: t, gameState: gs)
            let size = AttackSizing.kinds(for: a).isEmpty ? nil : AttackSizing.standard(a, in: gs)
            let warnings = MajorAction.isMajor(a) ? e.advisorWarnings(for: .attack(a, target: t.id, size: size)).filter { $0.level > 0 } : []
            return ok([
                "order": a.rawValue, "target": t.name,
                "adviser": "\(adv.advisorTitle) \(adv.advisorName)", "stance": adv.stance.rawValue, "reason": adv.reason,
                "odds_percent_shown": Int((adv.successEstimate * 100).rounded()),
                "cabinet_warnings": warnings.map { "\($0.who): \($0.text)" },
            ])
        }
        let posts = AdviceEngine.roleOrder.compactMap { role -> String? in
            guard let a = AdviceEngine.advisor(for: role, in: gs.advisors) else { return nil }
            var s = "\(AdviceEngine.roleTitle(role)): \(a.name)"
            if let adv = a.currentAdvice, !adv.isEmpty { s += " says: \(String(adv.prefix(220)))" }
            if let act = a.recommendedAction, let t = a.recommendedTarget { s += " (recommends \(act) on \(gs.getCountry(id: t)?.name ?? t))" }
            return s
        }
        return ok(["cabinet": posts])
    }

    private static func news(_ count: Int, _ e: GameEngine, _ gs: GameState) -> [String: Any] {
        [
            "news_wire": gs.shadow.ticker.suffix(count).map { "\(GameCalendar.format($0.date)): \($0.text)" },
            "game_log": e.logMessages.suffix(count).map(\.message).filter { !$0.isEmpty },
            "your_recent_orders": gs.shadow.commandLog.suffix(5).map { r in
                "\(GameCalendar.format(r.date)): " + r.orders.map { $0.summary(names: gs) }.joined(separator: "; ")
            },
        ]
    }

    private static func actions(_ target: String?, _ category: String?, _ gs: GameState, _ me: Country) -> ChatToolOutput {
        var t: Country?
        if let target, !target.isEmpty {
            guard case .one(.nation(let id), _) = CommandTargets.resolve(target, in: gs), let c = gs.getCountry(id: id) else {
                return error("No nation called \"\(String(target.prefix(40)))\" in \(gs.currentYear).")
            }
            t = c
        }
        let groups: [String: Set<PresidentialAction>] = [
            "military": OrderWhitelist.military.union(OrderWhitelist.nuclear), "diplomatic": OrderWhitelist.diplomatic,
            "economic": OrderWhitelist.economic, "covert": OrderWhitelist.covert, "treaty": OrderWhitelist.treaties,
        ]
        let pool = category.flatMap { groups[$0] } ?? OrderWhitelist.actions
        var rows: [String] = []
        for (verb, a) in verbActions where pool.contains(a) && a.isAvailable(on: gs.currentDate, in: gs) {
            var row = "\(verb.rawValue): \(a.rawValue), $\(money(a.cost)), risk \(a.riskLevel.rawValue.lowercased())"
            if let t { row += ", odds shown \(Int((AdviceEngine.successEstimate(action: a, player: me, target: t) * 100).rounded()))%" }
            rows.append(row + ". " + String(a.description.prefix(90)))
        }
        var d: [String: Any] = ["actions_left": gs.actionsRemaining, "orders": rows]
        if category == nil || category == "military" || category == "all" {
            d["also"] = ["attack (any mix of ground, air and naval; set all for everything)", "declareWar", "navalStrike", "showOfForce",
                         "claim (unclaimed land)", "buy (a colony)", "liberate (back a colony's independence)"]
        }
        d["not_available_here"] = "Chemical and biological weapons, assassination, terror support and drug operations stay on the escalation ladder."
        if let t { d["target"] = t.name }
        return ok(d)
    }

    /// The verbs `propose_orders` takes, each with the Situation Room action it runs (force verbs by their main arm).
    static let verbActions: [(CommandVerb, PresidentialAction)] = {
        var out: [(CommandVerb, PresidentialAction)] = [(.invade, .groundInvasion), (.airStrike, .airStrike), (.blockade, .navalBlockade),
                                                         (.landing, .amphAssault), (.nuke, .launchNukes)]
        for v in CommandVerb.allCases { if let a = v.simpleAction { out.append((v, a)) } }
        return out
    }()

    /// An action named by its verb ("sanction"), its Situation Room name ("Sanctions") or its raw value.
    static func actionFor(_ s: String) -> PresidentialAction? {
        let k = s.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
        if let v = CommandVerb.allCases.first(where: { $0.rawValue.lowercased() == k }), let a = verbActions.first(where: { $0.0 == v })?.1 { return a }
        return PresidentialAction.allCases.first { $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "") == k }
    }

    // MARK: propose_orders

    static func propose(_ arguments: [String: Any], engine: GameEngine, planID: Int) -> ChatToolOutput {
        guard let raw = arguments["steps"] as? [Any], !raw.isEmpty else {
            return error("propose_orders needs steps: [{verb, targets, ...}].")
        }
        guard raw.count <= maxSteps else { return error("At most \(maxSteps) steps in one plan.") }
        var steps: [ChatPlanStep] = []
        var lines: [[String: Any]] = []
        for (i, item) in raw.enumerated() {
            guard let obj = item as? [String: Any] else { return error("Step \(i + 1) is not an object.") }
            let intent: CommandIntent
            do { intent = try stepIntent(obj) } catch let e as ChatToolError { return Self.error("Step \(i + 1): \(e.message)") } catch { return Self.error("Step \(i + 1) is malformed.") }
            let outcome = engine.planCommand(intent, source: .chat)
            steps.append(ChatPlanStep(id: i + 1, intent: intent, outcome: outcome))
            lines.append(describe(outcome, step: i + 1))
        }
        let plan = ChatPlan(id: planID, steps: steps)
        var d: [String: Any] = [
            "steps": lines, "actions_left": engine.gameState?.actionsRemaining ?? 0,
            "status": "Shown to the President as a card. NOTHING HAS BEEN EXECUTED. Only the President's EXECUTE carries it out.",
        ]
        if plan.nuclear { d["nuclear"] = "Nuclear release needs a second confirmation from the President." }
        return ChatToolOutput(text: encode(d), plan: plan)
    }

    struct ChatToolError: Error { let message: String }

    /// A step object → the command box's intent. Every field is checked against its closed list.
    static func stepIntent(_ o: [String: Any]) throws -> CommandIntent {
        // Models also write the order as "action", or by the Situation Room name the actions tool lists.
        guard let vs = (o["verb"] ?? o["action"]) as? String else { throw ChatToolError(message: "verb is missing (use the verb the actions tool lists, e.g. \"sanction\").") }
        let key = vs.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
        guard let verb = CommandVerb.allCases.first(where: { $0.rawValue.lowercased() == key })
                ?? actionFor(vs).flatMap({ a in verbActions.first(where: { $0.1 == a })?.0 }) else {
            throw ChatToolError(message: "\(String(vs.prefix(30))) is not an order on the list. Use a verb from the actions tool.")
        }
        var targets: [String] = []
        if let t = o["targets"] as? [Any] { targets = t.compactMap { $0 as? String } }
        else if let t = o["targets"] as? String { targets = [t] }
        else if let t = o["target"] as? String { targets = [t] }
        targets = targets.prefix(CommandParser.maxTargets).map { String(CommandParser.sanitize($0).prefix(maxArgString)) }.filter { !$0.isEmpty }
        guard !targets.isEmpty else { throw ChatToolError(message: "name at least one target nation or land.") }
        var f = ForceRequest()
        func flag(_ k: String) -> Bool? { (o[k] as? Bool) ?? (o[k] as? String).map { $0.lowercased() == "true" } }
        func number(_ k: String) throws -> Double? {
            guard let v = (o[k] as? Double) ?? (o[k] as? Int).map(Double.init) ?? (o[k] as? String).flatMap(Double.init) else { return nil }
            guard v.isFinite, v >= 0, v <= 10_000_000 else { throw ChatToolError(message: "\(k) is out of range.") }
            return v > 0 ? v : nil
        }
        f.ground = flag("ground") == true ? true : nil
        f.air = flag("air") == true ? true : nil
        f.naval = flag("naval") == true ? true : nil
        f.all = flag("all") == true
        f.light = flag("light") == true
        switch (o["nuclear"] as? String)?.lowercased() {
        case "yes", "true": f.nuclear = true
        case "no", "false": f.nuclear = false
        default: if let b = o["nuclear"] as? Bool { f.nuclear = b }
        }
        if verb == .nuke, f.nuclear == nil { f.nuclear = true }
        // Models often send a head count ("50000") for a field in thousands; no army fields ten million troops.
        f.troops = try number("troops").map { $0 >= 10_000 ? $0 / 1000 : $0 }
        f.aircraft = try number("aircraft").map { Int($0) }
        f.warheads = try number("warheads").map { Int($0) }
        if let fl = o["fleet"] as? String { f.fleet = String(CommandParser.sanitize(fl).prefix(maxArgString)) }
        return CommandIntent(verb: verb, targets: targets, forces: f)
    }

    static func describe(_ outcome: CommandOutcome, step: Int) -> [String: Any] {
        switch outcome {
        case .plan(let p):
            return ["step": step, "status": "ready for the President", "order": p.title, "target": p.target,
                    "committed": p.committed, "held_back": p.heldBack, "warnings": p.warnings.map(\.text), "actions_needed": p.actionsNeeded]
        case .clarify(let c):
            return ["step": step, "status": "needs the President's choice", "question": c.question, "choices": c.options.map(\.label)]
        case .answer(let l):
            return ["step": step, "status": "answer", "lines": l]
        case .rejected(let why):
            return ["step": step, "status": "refused by the game", "reason": why]
        }
    }

    // MARK: Helpers

    struct Args {
        let raw: [String: Any]
        init(_ raw: [String: Any]) { self.raw = raw }
        func string(_ k: String) -> String? {
            guard let s = raw[k] as? String else { return nil }
            let c = String(CommandParser.sanitize(s).prefix(maxArgString))
            return c.isEmpty || c.lowercased() == "none" || c.lowercased() == "null" ? nil : c
        }
        func int(_ k: String) -> Int? {
            if let n = raw[k] as? Int { return max(-1_000_000, min(1_000_000, n)) }
            if let n = raw[k] as? Double, n.isFinite { return Int(max(-1_000_000, min(1_000_000, n))) }
            return (raw[k] as? String).flatMap { Int($0) }
        }
    }

    static func names<S: Sequence>(_ ids: S, _ gs: GameState) -> [String] where S.Element == String {
        ids.compactMap { gs.getCountry(id: $0) }.filter { !$0.isDestroyed }.map(\.name).sorted()
    }

    static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
    static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    static func money(_ v: Int64) -> String {
        let d = Double(v)
        if d >= 1e12 { return String(format: "%.1fT", d / 1e12) }
        if d >= 1e9 { return String(format: "%.1fB", d / 1e9) }
        if d >= 1e6 { return String(format: "%.0fM", d / 1e6) }
        return "\(v)"
    }

    static func ok(_ d: [String: Any]) -> ChatToolOutput { ChatToolOutput(text: encode(d)) }
    static func error(_ s: String) -> ChatToolOutput { ChatToolOutput(text: encode(["error": s]), isError: true) }

    /// Compact JSON, keys sorted, capped.
    static func encode(_ d: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(d),
              let data = try? JSONSerialization.data(withJSONObject: d, options: [.sortedKeys]) else { return "{}" }
        let s = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\\/", with: "/")
        return s.count > maxOutput ? String(s.prefix(maxOutput)) + "…" : s
    }
}

extension GameOrder {
    /// The summary with nation names instead of ids.
    func summary(names gs: GameState) -> String {
        var s = summary
        if let c = gs.getCountry(id: target) { s = s.replacingOccurrences(of: "→ \(target)", with: "→ \(c.name)") }
        return s
    }
}
