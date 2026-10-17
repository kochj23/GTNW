//
//  AdviceEngine.swift
//  Global Thermal Nuclear War
//
//  Every proposed action gets a face: the cabinet post responsible for that rung of the escalation ladder recommends
//  APPROVE, CAUTION or OPPOSE with a reason built from the live situation (relationship, violence, odds, domestic
//  politics). Advisors who are overruled too often resign; others are fired, fall to scandal, or die in the line of
//  duty. All advice text is written fresh for GTNW.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum AdvisorStatus: String, Codable {
    case active, resigned, fired, killed, scandal

    var label: String {
        switch self {
        case .active: return "On duty"
        case .resigned: return "Resigned"
        case .fired: return "Dismissed"
        case .killed: return "Killed in the line of duty"
        case .scandal: return "Left in disgrace"
        }
    }
}

extension Advisor {
    var isActive: Bool { (status ?? .active) == .active }
    /// Which of the seven Situation Room posts this advisor fills, if any.
    var roleKey: String? { ShadowPack.advisorKey(forTitle: title) }
}

enum AdviceStance: String, Codable {
    case approve, caution, oppose

    var label: String {
        switch self {
        case .approve: return "APPROVE"
        case .caution: return "CAUTION"
        case .oppose: return "OPPOSE"
        }
    }
}

struct ActionAdvice: Equatable {
    var advisorID: String?
    var advisorName: String
    var advisorTitle: String
    var stance: AdviceStance
    var reason: String
    /// Estimated chance the action works, 0…1 (shown to the player).
    var successEstimate: Double
}

enum AdviceEngine {
    /// The seven Situation Room posts, in rail order.
    static let roleOrder = ["whc", "nsa", "state", "defense", "press", "cia", "economic"]

    static func roleTitle(_ key: String) -> String {
        switch key {
        case "whc": return "Chief of Staff"
        case "nsa": return "National Security Advisor"
        case "state": return "Secretary of State"
        case "defense": return "Secretary of Defense"
        case "press": return "Press Secretary"
        case "cia": return "Director of Central Intelligence"
        default: return "Economic Advisor"
        }
    }

    /// The active advisor filling a post, if any.
    static func advisor(for role: String, in advisors: [Advisor]) -> Advisor? {
        advisors.first { $0.isActive && $0.roleKey == role }
    }

    /// Odds the action succeeds, from its base odds and the two leaderships.
    static func successEstimate(action: PresidentialAction, player: Country, target: Country) -> Double {
        let base = action.successChance
        let edge = (player.profile.leadership - target.profile.leadership) / 400   // ±0.25 at the extremes
        return min(0.97, max(0.05, base + edge))
    }

    /// Recommend for or against an action. Deterministic for a given game state.
    static func advise(action: PresidentialAction, player: Country, target: Country, gameState gs: GameState) -> ActionAdvice {
        let rung = action.rung
        let role = rung.leadAdvisorKey
        let adv = advisor(for: role, in: gs.advisors) ?? gs.advisors.first { $0.isActive && !$0.title.contains("President") }
        let hawk = Double(adv?.hawkishness ?? 50)
        let relation = player.diplomaticRelations[target.id] ?? 0
        let tp = target.profile
        let odds = successEstimate(action: action, player: player, target: target)
        let popularity = gs.shadow.popularity
        let atWar = player.atWarWith.contains(target.id)
        let name = target.name

        var score = 0.0          // > 1 approve, < -1 oppose, otherwise caution
        var reasons: [String] = []

        if action.isHostile {
            if relation > 30 {
                score -= 2
                reasons.append("\(name) is a friend (relations \(relation)). Turning on them now contradicts everything our policy has built.")
            } else if relation < -40 {
                score += 1
                reasons.append("\(name) has earned this: relations are at \(relation) and their leadership is \(tp.ambitionName.lowercased()).")
            } else {
                reasons.append("Relations with \(name) are lukewarm (\(relation)); this will push them toward our rivals.")
            }
            if tp.ambition >= 5 { score += 0.7; reasons.append("A \(tp.ambitionName.lowercased()) regime only respects strength.") }
            if tp.ambition <= 2 { score -= 0.6; reasons.append("Their government is \(tp.ambitionName.lowercased()); pressure may be overkill.") }

            switch rung {
            case .covert:
                if odds < 0.5 { score -= 1; reasons.append(String(format: "Our people put the odds at %.0f%%. If it's traced back to us, it's a scandal.", odds * 100)) }
                else { score += 0.3; reasons.append(String(format: "The Agency rates this at %.0f%% — workable.", odds * 100)) }
            case .military:
                score += (hawk - 50) / 30
                if !atWar && target.militaryStrength > player.militaryStrength - 10 {
                    score -= 1; reasons.append("Their forces are nearly a match for ours. This would not be a short campaign.")
                }
                if gs.defconLevel.rawValue <= 2 { score -= 0.5; reasons.append("At DEFCON \(gs.defconLevel.rawValue), any shot could start something much bigger.") }
            case .nuclear:
                score -= 3
                if atWar && hawk > 85 && target.nuclearWarheads == 0 {
                    score += 1.5
                    reasons.append("They cannot answer in kind. It would end the war — and our standing in the world.")
                } else {
                    reasons.append("Once the first warhead flies, nobody controls what comes next. I cannot support this.")
                }
            default:
                break
            }
            if popularity < 35 && rung.rawValue >= EscalationRung.military.rawValue {
                score -= 0.7; reasons.append(String(format: "With approval at %.0f%%, the country has no appetite for this.", popularity))
            }
        } else {
            score += 1
            if relation < -60 {
                score -= 1.5
                reasons.append("\(name) will pocket the gesture and give nothing back. Their leaders are \(tp.ethicName.lowercased()).")
            } else if relation > 50 {
                reasons.append("A sensible investment in a reliable partner.")
            } else {
                score += 0.3
                reasons.append("This could move \(name) our way — they are watching who shows up.")
            }
            if tp.ethic <= 2 { score -= 0.5; reasons.append("Expect some of it to disappear into the wrong pockets.") }
            if action.cost > 5_000_000_000 && gs.shadow.budget.deficit > 5 {
                score -= 0.6; reasons.append("We are already running a deficit; Treasury will object to the price.")
            }
            if tp.anxieties.peak.value > 60 {
                reasons.append("They are badly worried about \(tp.anxieties.peak.kind.label.lowercased()) threats — reassurance lands well right now.")
                score += 0.4
            }
        }

        let stance: AdviceStance = score >= 1 ? .approve : (score <= -1 ? .oppose : .caution)
        let opener: String
        switch stance {
        case .approve: opener = "I recommend we go ahead."
        case .caution: opener = "I can live with this, but go in with your eyes open."
        case .oppose: opener = "Mr. President, I advise against it."
        }
        let reason = ([opener] + reasons.prefix(3)).joined(separator: " ")
        return ActionAdvice(advisorID: adv?.id, advisorName: adv?.name ?? roleTitle(role),
                            advisorTitle: adv?.title ?? roleTitle(role), stance: stance, reason: reason,
                            successEstimate: odds)
    }

    // MARK: Situation briefing (advisor rail)

    /// A short briefing from a post about the selected country (or the world when nil).
    static func briefing(role: String, country: Country?, gameState gs: GameState) -> String {
        guard let c = country, let player = gs.getPlayerCountry() else {
            let wars = gs.activeWars.count
            switch role {
            case "whc": return "\(gs.currentDateLabel). \(wars == 0 ? "No shooting wars anywhere — enjoy it." : "\(wars) wars are burning around the world.")"
            case "press": return String(format: "Approval stands at %.0f%%.", gs.shadow.popularity)
            case "economic": return String(format: "The budget runs a %@ of %.1f%% of GDP.", gs.shadow.budget.deficit >= 0 ? "deficit" : "surplus", abs(gs.shadow.budget.deficit))
            default: return "Select a country on the map for a briefing."
            }
        }
        let p = c.profile
        let rel = player.diplomaticRelations[c.id] ?? 0
        switch role {
        case "nsa":
            return "\(c.name): relations \(rel), alignment \(c.alignment.rawValue). Nuclear worry \(Int(p.anxieties.nuclear)), military worry \(Int(p.anxieties.military))."
        case "state":
            let need = p.aidNeed.total
            return String(format: "%@ is %@ and %@. They would welcome about $%.1fB in aid this year.", c.name, p.ambitionName.lowercased(), p.ethicName.lowercased(), need)
        case "defense":
            return "\(c.name) fields strength \(c.militaryStrength) vs our \(player.militaryStrength). \(c.atWarWith.isEmpty ? "Not at war." : "At war with \(c.atWarWith.count) nation(s).")"
        case "press":
            return String(format: "Americans view %@ %@. Your approval: %.0f%%.", c.name, rel > 30 ? "favorably" : (rel < -30 ? "with suspicion" : "with indifference"), gs.shadow.popularity)
        case "cia":
            return "Leadership effectiveness \(Int(p.leadership)). Ideology: \(p.ideology.rawValue). Unrest \(Int(p.outcry))."
        case "economic":
            return String(format: "GDP $%.2fT, quality of life %.0f/100. Economic worry %.0f.", c.gdp, p.qualityOfLife, p.anxieties.economic)
        default:
            return "\(c.name) is most worried about \(p.anxieties.peak.kind.label.lowercased()) threats right now."
        }
    }

    // MARK: Standing recommendations (Advisor detail ACCEPT / REJECT / ALTERNATIVE)

    /// What the world looks like to the cabinet right now, in the terms Advisor.generateAdvice understands.
    static func situation(in gs: GameState) -> GameSituation {
        let player = gs.getPlayerCountry()
        if gs.defconLevel.rawValue <= 2, let rival = player.flatMap({ p in gs.countries.filter { $0.nuclearWarheads > 0 && $0.id != p.id }.min { (p.diplomaticRelations[$0.id] ?? 0) < (p.diplomaticRelations[$1.id] ?? 0) } }) {
            return .nuclearThreat(country: rival.id)
        }
        if gs.shadow.popularity < 35 || (player?.profile.outcry ?? 0) > 50 { return .domesticCrisis }
        if let war = gs.activeWars.first { return .diplomaticCrisis(country: war.defender) }
        if (player?.profile.anxieties.economic ?? 0) > 50 { return .economicSanctions }
        return .covertOperation
    }

    /// The action a post would urge right now, skipping `excluding` (for REQUEST ALTERNATIVE).
    static func recommendation(role: String, in gs: GameState, excluding: Set<String> = []) -> (PresidentialAction, String)? {
        guard let player = gs.getPlayerCountry() else { return nil }
        let others = gs.countries.filter { !$0.isDestroyed && !$0.isPlayerControlled }
        func rel(_ c: Country) -> Int { player.diplomaticRelations[c.id] ?? 0 }
        let rival = others.min { rel($0) < rel($1) }
        let worriedFriend = others.filter { rel($0) > 20 }.max { $0.profile.anxieties.average < $1.profile.anxieties.average }
        let needy = others.filter { rel($0) > -20 }.max { $0.profile.aidNeed.total < $1.profile.aidNeed.total }
        let warVictim = gs.activeWars.compactMap { gs.getCountry(id: $0.defender) }.first { rel($0) > 0 && !$0.isPlayerControlled }
        let swing = others.filter { abs(rel($0)) < 30 }.max { $0.profile.strategicValue < $1.profile.strategicValue }
        var options: [(PresidentialAction, Country?)] = []
        switch role {
        case "state": options = [(.stateVisit, worriedFriend), (.mediateConflict, warVictim), (.sendAmbassador, swing), (.summit, rival)]
        case "defense": options = [(.militaryAid, warVictim), (.jointExercise, worriedFriend), (.deployTroops, rival), (.defensivePact, swing)]
        case "cia": options = [(.infiltrate, rival), (.stealSecrets, rival), (.fundOpposition, rival), (.deploySpies, swing)]
        case "economic": options = [(.tradeDeal, swing), (.economicAid, needy), (.sanctions, rival), (.investment, worriedFriend)]
        case "nsa": options = [(.armsControl, rival), (.summit, rival), (.nonAggression, swing), (.militaryAid, warVictim)]
        case "press": options = [(.jointStatement, worriedFriend), (.cultural, swing), (.unCondemn, rival), (.foodAid, needy)]
        default: options = [(.summit, rival), (.foodAid, needy), (.stateVisit, worriedFriend), (.tradeDeal, swing)]
        }
        for (a, c) in options {
            guard let c, a.eraAvailableYear <= gs.currentYear, !excluding.contains(a.rawValue + c.id) else { continue }
            return (a, c.id)
        }
        return nil
    }

    /// Refresh one advisor's spoken advice: the situation read (Advisor.generateAdvice) plus a concrete proposal.
    static func refreshRecommendation(advisorIndex i: Int, in gs: GameState, excluding: Set<String> = []) {
        guard gs.advisors.indices.contains(i), gs.advisors[i].isActive else { return }
        var adv = gs.advisors[i]
        adv.generateAdvice(for: situation(in: gs))
        let role = adv.roleKey ?? "whc"
        if let (action, target) = recommendation(role: role, in: gs, excluding: excluding) {
            adv.recommendedAction = action.rawValue
            adv.recommendedTarget = target
            let name = gs.getCountry(id: target)?.name ?? target
            adv.currentAdvice = (adv.currentAdvice ?? "") + " My recommendation: \(action.rawValue) — \(name)."
        } else {
            adv.recommendedAction = nil
            adv.recommendedTarget = nil
        }
        adv.lastAdviceGiven = gs.currentDateLabel
        gs.advisors[i] = adv
    }

    // MARK: Advisor fates

    static let scandals = [
        "was photographed accepting a vintage sports car from a defense contractor",
        "billed the taxpayers for a private bowling alley in the Pentagon basement",
        "left a briefcase of classified maps on a commuter train",
        "used an Air Force jet to fly a prize-winning poodle to a dog show",
        "was caught moonlighting as a talk-radio host under a fake name",
        "expensed thirty thousand dollars of novelty paperweights",
        "ghost-wrote a spy thriller that reads suspiciously like last month's briefings",
        "hired three cousins as 'strategic consultants'",
    ]

    /// After the player overrules an advisor: loyalty drops and repeated defiance ends in resignation.
    static func registerOverrule(advisorIndex i: Int, in gs: GameState) -> String? {
        guard gs.advisors.indices.contains(i), gs.advisors[i].isActive else { return nil }
        let id = gs.advisors[i].id
        gs.advisors[i].loyalty = max(0, gs.advisors[i].loyalty - 8)
        let grievances = (gs.shadow.advisorGrievances[id] ?? 0) + 1
        gs.shadow.advisorGrievances[id] = grievances
        if grievances >= 3 && gs.advisors[i].loyalty < 70 {
            gs.advisors[i].status = .resigned
            return "\(gs.advisors[i].name) has resigned as \(gs.advisors[i].title), citing \"fundamental disagreements over policy.\""
        }
        return nil
    }

    /// Following advice rebuilds trust.
    static func registerFollowed(advisorIndex i: Int, in gs: GameState) {
        guard gs.advisors.indices.contains(i) else { return }
        gs.advisors[i].loyalty = min(100, gs.advisors[i].loyalty + 3)
        gs.shadow.advisorGrievances[gs.advisors[i].id] = max(0, (gs.shadow.advisorGrievances[gs.advisors[i].id] ?? 0) - 1)
    }

    /// A career staffer for a post the era's cabinet data doesn't cover (fictional names).
    static func staffer(for role: String, year: Int) -> Advisor {
        let names = ["whc": "Margaret Holloway", "nsa": "Gen. Walter Pryce", "state": "Edmund Ashby",
                     "defense": "Adm. Lucas Brandt", "press": "Nora Delaney", "cia": "Victor Krane", "economic": "Dr. Helen Ruiz"]
        let title: String
        switch role {
        case "whc": title = "White House Chief of Staff"
        case "press": title = "Press Secretary"
        case "economic": title = "Chairman, Council of Economic Advisers"
        case "cia": title = year < 1947 ? "Director of National Intelligence (OSS)" : "Director of Central Intelligence"
        default: title = roleTitle(role)
        }
        let hawk = ["defense": 70, "nsa": 60, "cia": 55, "state": 35, "press": 40, "whc": 45, "economic": 40][role] ?? 50
        return Advisor(id: "staff-\(role)", name: names[role] ?? "Staff", title: title, department: "Executive Office",
                       bio: "Career professional serving the administration.", expertise: 65, loyalty: 75, influence: 50,
                       publicSupport: 50, hawkishness: hawk, interventionism: 50, fiscalConservatism: 50,
                       adviceAreas: [.diplomacy], portraitColor: "#4A6FA5")
    }

    /// Appoint an acting replacement for a departed advisor so the post is not left empty.
    static func appointActing(replacing old: Advisor, sequence: Int) -> Advisor {
        let surnames = ["Brennan", "Okonkwo", "Haldane", "Vasquez", "Kowalski", "Lindgren", "Abernathy", "Tanaka"]
        let surname = surnames[(sequence + old.id.count) % surnames.count]
        return Advisor(id: "\(old.id)-acting-\(sequence)", name: "Acting: \(surname)", title: old.title,
                       department: old.department, bio: "Career deputy elevated after \(old.name) left the post.",
                       expertise: max(35, old.expertise - 20), loyalty: 70, influence: 40, publicSupport: 45,
                       hawkishness: old.hawkishness, interventionism: old.interventionism,
                       fiscalConservatism: old.fiscalConservatism, adviceAreas: old.adviceAreas,
                       portraitColor: old.portraitColor)
    }
}
