//
//  PowerPlayPlanner.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the command box's and the chief of staff's power plays. Reads the phrasings ("offer to buy Greenland",
//  "tariff the objectors over Greenland", "threaten Denmark", "take the framework deal on Greenland", "declare a
//  national emergency over trade", "emergency tariffs on Canada under section 232", "reissue the tariffs on Canada
//  under national security", "capture the leader of X", "precision strike on X", "strike X's nuclear facilities",
//  "strike boats off X") into a `CommandIntent`, and plans it into the same confirmation card every other order gets:
//  the target by its name in the game's year, what will happen with the odds the Situation Room shows, and the
//  cabinet's warnings (legality first). Read-only; EXECUTE runs the `GameOrder`s through `executePowerPlay`.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

extension CommandVerb {
    /// The power-play verbs.
    var isPowerPlay: Bool {
        [.acquire, .pressure, .posture, .frameworkDeal, .escalateCampaign, .emergency, .endEmergency, .emergencyTariffs, .reissue,
         .captureLeader, .limitedStrike, .renamePlace].contains(self)
    }

    /// The step of an acquisition campaign a verb takes.
    var campaignStep: CampaignStep? {
        switch self {
        case .acquire: return .offer
        case .pressure: return .pressure
        case .posture: return .posture
        case .frameworkDeal: return .deal
        case .escalateCampaign: return .escalate
        default: return nil
        }
    }

    /// The card's heading for a power play.
    var powerPlayTitle: String? {
        switch self {
        case .acquire: return "ACQUISITION: OFFER TO BUY"
        case .pressure: return "ACQUISITION: TARIFFS ON OBJECTORS"
        case .posture: return "ACQUISITION: MILITARY POSTURING"
        case .frameworkDeal: return "ACQUISITION: FRAMEWORK DEAL"
        case .escalateCampaign: return "ACQUISITION: ESCALATE"
        case .emergency: return "DECLARE A NATIONAL EMERGENCY"
        case .endEmergency: return "END THE NATIONAL EMERGENCY"
        case .emergencyTariffs: return "EMERGENCY TARIFFS"
        case .reissue: return "REISSUE UNDER NEW AUTHORITY"
        case .captureLeader: return "LEADER CAPTURE RAID"
        case .limitedStrike: return "LIMITED STRIKE"
        case .renamePlace: return "RENAME"
        default: return nil
        }
    }
}

// MARK: - Reading

enum PowerPlayParser {

    /// Phrases (normalized), longest first. The rest of the text is the target, then an optional "under <authority>".
    static let phrases: [(String, CommandVerb)] = {
        let table: [CommandVerb: [String]] = [
            .acquire: ["offer to buy", "make an offer for", "make an offer to buy", "start a campaign to acquire", "campaign to acquire",
                       "launch a campaign to acquire", "acquire", "try to buy", "pressure campaign for", "start a pressure campaign for"],
            .pressure: ["turn up the pressure on", "increase the pressure on", "pressure", "tariff the objectors over", "tariff the objectors to",
                        "tariffs on the objectors over", "tariffs on the objectors to", "punish the objectors over", "tariff the objectors"],
            .posture: ["threaten", "threaten force against", "threaten force over", "military posturing against", "military posturing over",
                       "posture against", "posture over", "rattle the saber at", "rattle sabers at", "saber rattle at"],
            .frameworkDeal: ["take the framework deal on", "take a framework deal on", "framework deal on", "framework deal with",
                             "framework deal over", "take the deal on", "back down on", "back down over", "settle for a framework on"],
            .escalateCampaign: ["escalate over", "escalate the campaign for", "escalate the campaign over", "take it by force", "escalate on"],
            .emergency: ["declare a national emergency", "declare national emergency", "declare a state of emergency",
                         "declare an emergency", "national emergency", "state of emergency"],
            .endEmergency: ["end the national emergency", "end the emergency", "lift the national emergency", "lift the emergency",
                            "terminate the national emergency", "terminate the emergency", "end national emergency"],
            .emergencyTariffs: ["impose emergency tariffs on", "emergency tariffs on", "emergency tariffs against", "emergency tariff on"],
            .reissue: ["reissue the tariffs on", "reissue tariffs on", "reissue the order on", "reissue", "re issue the tariffs on", "re issue"],
            .captureLeader: ["capture the leader of", "capture the head of government of", "capture the president of", "seize the leader of",
                             "seize the head of government of", "raid to capture the leader of", "snatch the leader of", "capture the ruler of",
                             "capture", "seize the leader", "leader capture raid on", "leader capture raid against", "capture raid on"],
            .limitedStrike: ["precision strike on", "precision strike against", "precision strikes on", "limited strike on", "limited strike against",
                             "limited strikes on", "surgical strike on", "surgical strike against", "pinpoint strike on", "facility strike on",
                             "strike the nuclear facilities of", "strike nuclear facilities in", "strike the nuclear sites of",
                             "bomb the nuclear facilities of", "strike boats off", "strike the boats of", "strike boats from", "boat strike on",
                             "boat strikes on", "strike vessels off", "strike vessels from", "sink boats from", "sink the boats of"],
        ]
        return table.flatMap { verb, list in list.map { ($0, verb) } }.sorted { $0.0.count > $1.0.count }
    }()

    /// Words that end the names, and words that are never part of them for these verbs.
    static let noise: Set<String> = ["the", "of", "on", "in", "off", "from", "against", "over", "to", "with", "for", "their", "its",
                                     "leader", "leaders", "head", "government", "president", "ruler", "nuclear", "facility", "facilities",
                                     "site", "sites", "program", "programme", "plant", "plants", "reactor", "reactors", "enrichment",
                                     "boats", "boat", "vessels", "ships", "now", "please", "immediately", "a", "an"]

    /// The intent for a power play, or nil when the text is not one.
    static func parse(_ text: String) -> CommandIntent? {
        var body = " " + text + " "
        var stripped = true
        while stripped {
            stripped = false
            for p in CommandParser.prefixes where body.hasPrefix(" " + p + " ") {
                body = String(body.dropFirst(p.count + 1))
                stripped = true
            }
        }
        body = body.trimmingCharacters(in: .whitespaces)
        let padded = " " + body + " "
        func has(_ w: String) -> Bool { padded.contains(" \(w) ") }
        var verb: CommandVerb?
        var rest = ""
        if let (phrase, v) = phrases.first(where: { body == $0.0 || body.hasPrefix($0.0 + " ") }) {
            verb = v
            rest = String(body.dropFirst(phrase.count))
            // "capture" alone is only a raid when it names a leader ("capture Venezuela's leader").
            if phrase == "capture" && !(has("leader") || has("president") || has("ruler") || has("head")) { return nil }
            // "pressure" with "to sell" or a campaign word stays pressure; "threaten" stays posture.
        } else if ["strike", "bomb", "hit", "air strike", "airstrike", "destroy", "sink"].contains(where: { body.hasPrefix($0 + " ") }),
                  ((has("nuclear") && ["facility", "facilities", "site", "sites", "program", "programme", "plant", "plants", "reactor", "reactors", "enrichment"].contains(where: has))
                   || has("boats") || has("boat") || has("vessels")) {
            verb = .limitedStrike
            rest = String(body.drop(while: { $0 != " " }))
        } else if (body.hasPrefix("tariffs on ") || body.hasPrefix("impose tariffs on ") || body.hasPrefix("put tariffs on ")), has("under") {
            verb = .emergencyTariffs
            rest = String(body.drop(while: { $0 != " " }))
        }
        guard let verb else { return nil }
        var detail: String?
        var names = " " + rest + " "
        if let r = names.range(of: " under ") {
            detail = basis(in: String(names[r.upperBound...]))?.rawValue
            names = String(names[..<r.lowerBound])
        }
        switch verb {
        case .emergency:
            if has("end") || has("lift") { return CommandIntent(verb: .endEmergency) }
            return CommandIntent(verb: .emergency, detail: reason(in: padded).rawValue)
        case .endEmergency:
            return CommandIntent(verb: .endEmergency)
        case .limitedStrike:
            detail = strikeKind(in: padded).rawValue
        case .reissue:
            if detail == nil, let r = padded.range(of: " as ") { detail = basis(in: String(padded[r.upperBound...]))?.rawValue }
        default:
            break
        }
        if verb == .pressure, let r = names.range(of: " to sell") { names = String(names[..<r.lowerBound]) }
        let kept = names.split(separator: " ").map(String.init).filter { !noise.contains($0) && !$0.hasPrefix("emergenc") && $0 != "tariffs" }
        let target = kept.joined(separator: " ")
        return CommandIntent(verb: verb, targets: target.isEmpty ? [] : [target], detail: detail)
    }

    /// "rename <a sea, mountain or department> to <new name>", read from the raw text so the new name keeps its
    /// capitals. Only a name in MapFeatures.swift is taken here (a territory's rename stays in its own sheet).
    static func parseRename(_ raw: String) -> CommandIntent? {
        let s = CommandParser.sanitize(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.lowercased().hasPrefix("rename "), let r = s.range(of: " to ", options: [.caseInsensitive, .backwards]) else { return nil }
        let old = String(s[s.index(s.startIndex, offsetBy: 7)..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        let new = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
        var n = CommandParser.normalize(old)
        if n.hasPrefix("the ") { n = String(n.dropFirst(4)) }
        func norm(_ x: String) -> String { let t = CommandParser.normalize(x); return t.hasPrefix("the ") ? String(t.dropFirst(4)) : t }
        let known = MapFeatures.all.contains { $0.names.contains { norm($0.name) == n } }
            || (Departments.american + Departments.ministries).contains { norm($0.name) == n } || n == "pentagon"
            || n.hasSuffix(" department") || n.hasSuffix(" ministry")
        guard known, !new.isEmpty else { return nil }
        return CommandIntent(verb: .renamePlace, targets: [old], detail: new)
    }

    /// The reason a national emergency is declared over.
    static func reason(in t: String) -> EmergencyReason {
        func has(_ w: String) -> Bool { t.contains(" \(w)") }
        if has("trade") || has("tariff") || has("imbalance") || has("deficit") || has("dumping") { return .trade }
        if has("border") || has("immigration") || has("migra") || has("smuggl") || has("cartel") || has("drug") { return .border }
        if has("riot") || has("unrest") || has("crime") || has("protest") || has("disorder") || has("public order") { return .publicOrder }
        if has("energy") || has("oil") || has("fuel") || has("power grid") || has("electric") { return .energy }
        return .security
    }

    /// The legal authority a phrase names.
    static func basis(in s: String) -> LegalBasis? {
        let t = " " + CommandParser.normalize(s) + " "
        func has(_ w: String) -> Bool { t.contains(" \(w) ") || t.contains(" \(w)") }
        if has("232") || has("national security") { return .nationalSecurity232 }
        if has("301") || has("unfair") { return .unfairTrade301 }
        if has("122") || has("balance of payments") { return .balanceOfPayments122 }
        if has("338") || has("tariff act") { return .tariffAct338 }
        if has("trading with the enemy") || has("twea") { return .tradingWithEnemy }
        if has("ieepa") || has("emergency economic") || has("emergency powers") || has("economic powers") { return .emergencyEconomic }
        if has("article ii") || has("article 2") || has("inherent") || has("executive power") { return .article2 }
        if has("insurrection") { return .insurrectionAct }
        if has("decree") { return .emergencyDecree }
        if has("trade law") || has("trade laws") { return .tradeLaw }
        return nil
    }

    static func strikeKind(in t: String) -> StrikeKind {
        func has(_ w: String) -> Bool { t.contains(" \(w)") }
        if has("nuclear") { return .nuclearFacility }
        if has("boat") || has("vessel") || has("ships") { return .boats }
        if has("facilit") || has("base") || has("factory") || has("depot") || has("plant") { return .facility }
        return .precision
    }
}

// MARK: - Planning

extension GameEngine {

    /// Plan a power play, or nil when the verb isn't one (the ordinary planner carries on). `.buy` aimed at a whole
    /// nation or a land drawn under one becomes an offer that starts an acquisition campaign.
    func planPowerPlay(_ intent: CommandIntent, verb: CommandVerb, source: CommandSource) -> CommandOutcome? {
        guard let gs = gameState else { return nil }
        if verb == .buy {
            guard let raw = intent.targets.first ?? intent.confirmedTargets?.first, let id = acquisitionID(raw, in: gs),
                  let t = acquisitionTarget(id), t.kind != .colony else { return nil }
            var i = intent
            i.verb = .acquire
            i.targets = []
            i.confirmedTargets = [id]
            return planPowerPlay(i, verb: .acquire, source: source)
        }
        guard verb.isPowerPlay else { return nil }
        if verb == .renamePlace { return planRenamePlace(intent, source: source) }
        if gs.actionsRemaining == 0 {
            return .rejected("No actions left this \(gs.turnLength.displayName.lowercased()). End the turn first.")
        }
        var plan = CommandPlan(title: verb.powerPlayTitle ?? verb.title, target: "", orders: [], committed: [], heldBack: [], warnings: [],
                               actionsNeeded: 1, actionsLeft: gs.actionsRemaining, source: source)
        func warn(_ ws: [AdvisorWarning]) {
            for w in ws where !w.text.isEmpty { plan.warnings.append(CommandWarning(text: "\(w.who): \(w.text)", level: w.level)) }
        }
        func finish(_ o: GameOrder, target: String) -> CommandOutcome {
            if let p = powerPlayProblem(o) { return .rejected(p) }
            plan.orders = [o]
            plan.target = target + ", \(gs.currentYear)"
            plan.warnings = plan.warnings.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
            return .plan(plan)
        }

        // No target: the emergency itself.
        if verb == .emergency || verb == .endEmergency {
            if verb == .endEmergency {
                guard let e = gs.shadow.powerPlays.emergency else { return .rejected("No national emergency is in force.") }
                plan.actionsNeeded = 0
                let lapse = gs.shadow.powerPlays.orders.filter { $0.status.isLive && $0.status != .upheld && $0.basis.needsEmergency }
                plan.committed = ["End the national emergency over \(e.reason.title) (no action)."]
                if !lapse.isEmpty { plan.warnings.append(CommandWarning(text: "These orders lapse with it: \(PowerPlay.list(lapse.map(\.subject))).", level: 1)) }
                return finish(GameOrder(kind: .emergency, target: "HOME", mission: EmergencyStep.end.rawValue), target: gs.getPlayerCountry()?.name ?? "Home")
            }
            let reason = intent.detail.flatMap(EmergencyReason.init(rawValue:)) ?? .security
            plan.committed = ["Declare a national emergency over \(reason.title)."]
            let unlocked = LegalBasis.allCases.filter { $0.needsEmergency && $0.american == (gs.playerCountryID == "USA") && gs.currentYear >= $0.since }
            if !unlocked.isEmpty { plan.committed.append("Unlocks: \(unlocked.map(\.title).joined(separator: ", ")).") }
            plan.warnings.append(CommandWarning(text: "\(PowerPlay.counsel): every order under it will be challenged in court; the emergency itself only helps an order whose authority needs it.", level: 0))
            if gs.playerCountryID == "USA" && gs.currentYear >= EmergencyPowers.nationalEmergenciesAct {
                plan.warnings.append(CommandWarning(text: "Vice President: Congress can end it by joint resolution if it turns against you.", level: 0))
            }
            return finish(GameOrder(kind: .emergency, target: "HOME", mission: EmergencyStep.declare.rawValue, detail: reason.rawValue),
                          target: gs.getPlayerCountry()?.name ?? "Home")
        }

        // One target.
        guard let raw = intent.confirmedTargets?.first ?? intent.targets.first.map(CommandParser.sanitize), !raw.isEmpty else {
            return .rejected("Name a nation or land, for example \"\(example(verb))\".")
        }
        let id: String
        if let picked = intent.confirmedTargets?.first {
            id = picked
        } else {
            switch resolvePowerTarget(raw, verb: verb, in: gs) {
            case .failure(let why): return .rejected(why)
            case .choices(let options):
                return .clarify(Clarification(question: "Which one do you mean?", options: options.map { t in
                    var i = intent
                    i.confirmedTargets = [t.id]
                    i.targets = []
                    return ClarifyOption(label: CommandTargets.label(t, in: gs), intent: i)
                }, source: source))
            case .found(let found, let note):
                id = found
                if let note { plan.warnings.append(CommandWarning(text: note, level: 0)) }
            }
        }

        if let step = verb.campaignStep {
            let open = openCampaign(id) ?? gs.shadow.powerPlays.campaigns.last { $0.owner == id && $0.stage.isOpen }
            let land = step == .offer ? id : (open?.land ?? id)
            if let p = campaignProblem(land, step: step) { return .rejected(p) }
            guard let t = acquisitionTarget(land) ?? open.flatMap({ c in gs.getCountry(id: c.owner).map { (c.kind, $0, c.label) } }) else {
                return .rejected("That is not a land or nation another power holds.")
            }
            let c = open ?? AcquisitionCampaign(land: land, owner: t.owner.id, kind: t.kind, label: t.label, started: gs.currentDate, lastMove: gs.currentDate,
                                                stage: .offered, price: acquisitionPrice(land, kind: t.kind, owner: t.owner),
                                                objectors: campaignObjectors(owner: t.owner, land: land))
            let objectors = c.objectors.compactMap { gs.getCountry(id: $0)?.name }
            switch step {
            case .offer:
                plan.committed = ["Offer \(t.owner.name) $\(ChatTools.round1(c.price))B for \(t.label)."]
                if t.kind == .nation { plan.committed.append("A whole nation: it would become your territory, with its people's consent or not.") }
                if !objectors.isEmpty { plan.heldBack.append("Likely objectors: \(PowerPlay.list(objectors)).") }
            case .pressure:
                let b = legalBases(for: .tariff).first
                let hit = c.objectors.filter { liveEmergencyOrder(.tariff, target: $0) == nil }.prefix(4).compactMap { gs.getCountry(id: $0)?.name }
                plan.committed = ["Tariffs on \(PowerPlay.list(hit.isEmpty ? [t.owner.name] : hit))\(b.map { " under \($0.title)" } ?? "")."]
            case .posture:
                plan.committed = ["Move forces toward \(t.label) and refuse to rule out force."]
            case .deal:
                plan.committed = ["Accept a framework deal with \(t.owner.name) on \(t.label) and lift the campaign's tariffs."]
            case .escalate:
                plan.committed = ["Declare war on \(t.owner.name) to take \(t.label)."]
            }
            plan.committed.append("Leverage \(Int(c.leverage)) of \(Int(campaignResistance(c))) resistance so far.")
            warn(campaignWarnings(land, step: step))
            if step == .escalate { plan.warnings += consequenceWarnings(t.owner, in: gs, nuclear: false) }
            return finish(GameOrder(kind: .acquire, target: land, mission: step.rawValue), target: t.label)
        }

        guard let nation = gs.getCountry(id: id) else { return .rejected("No nation called that in \(gs.currentYear).") }
        switch verb {
        case .emergencyTariffs:
            let asked = intent.detail.flatMap(LegalBasis.init(rawValue:))
            let open = legalBases(for: .tariff, target: id)
            let emergencyFirst = open.first { $0.needsEmergency }
            guard let basis = asked ?? emergencyFirst ?? open.first else { return .rejected("No authority lets you impose tariffs on \(nation.name) now.") }
            if let why = emergencyTariffProblem(id, basis: basis) { return .rejected(why) }
            let score = courtScore(basis, kind: .tariff, target: id)
            plan.committed = ["Tariffs on \(nation.name) under \(basis.title).",
                              basis.investigationDays > 0 ? "They take effect after a \(basis.investigationDays)-day investigation." : "They take effect at once."]
            plan.committed.append("\(PowerPlay.counsel): \(score >= EmergencyPowers.passMark ? "likely upheld" : "likely struck down") when the courts rule in about \(max(1, basis.courtDays / 30)) months. \(basis.note)")
            let others = open.filter { $0 != basis }.prefix(3).map { "\($0.short) (\(courtScore($0, kind: .tariff, target: id) >= EmergencyPowers.passMark ? "holds" : "weak"))" }
            if !others.isEmpty { plan.heldBack.append("Other authorities: \(others.joined(separator: ", ")). Say \"under …\" to choose.") }
            plan.warnings.append(CommandWarning(text: "\(powerPlayStateWho): \(nation.name) will retaliate in kind; relations fall.", level: 1))
            if gs.getPlayerCountry()?.alliances.contains(id) == true {
                plan.warnings.append(CommandWarning(text: "\(nation.name) is an ally.", level: 1))
            }
            return finish(GameOrder(kind: .emergency, target: id, mission: EmergencyStep.tariff.rawValue, detail: basis.rawValue), target: nation.name)
        case .reissue:
            guard let old = gs.shadow.powerPlays.orders.last(where: { $0.target == id && ($0.status == .struckDown || $0.status == .lapsed) }) else {
                return .rejected("No order on \(nation.name) has been struck down.")
            }
            let banned = Set(old.struckBases + (old.status == .struckDown ? [old.basis] : []))
            let open = (old.kind == .tariff ? legalBases(for: .tariff, target: id) : legalBases(for: old.kind)).filter { !banned.contains($0) }
            guard let basis = intent.detail.flatMap(LegalBasis.init(rawValue:)) ?? open.first else {
                return .rejected("No other authority is left for the \(old.subject).")
            }
            let tries = gs.shadow.powerPlays.orders.filter { $0.root == old.root }.count
            plan.committed = ["Reissue the \(old.subject) under \(basis.title).",
                              "\(PowerPlay.counsel): \(courtScore(basis, kind: old.kind, target: old.kind == .tariff ? id : nil) >= EmergencyPowers.passMark ? "should hold this time" : "likely struck down again")."]
            plan.warnings.append(CommandWarning(text: "Vice President: going around the courts costs Congress \(3 * tries) and approval \(tries).", level: 1))
            return finish(GameOrder(kind: .emergency, target: old.targetToken, mission: EmergencyStep.reissue.rawValue, detail: basis.rawValue),
                          target: nation.name)
        case .captureLeader:
            plan.committed = ["Special forces raid on \(nation.capital) to seize the head of government of \(nation.name). Odds \(Int(captureOdds(id) * 100))%.",
                              "If it works, you choose \(nation.name)'s next government."]
            warn(captureWarnings(id))
            plan.warnings += consequenceWarnings(nation, in: gs, nuclear: false)   // Consequences.swift
            return finish(GameOrder(kind: .captureLeader, target: id), target: nation.name)
        case .limitedStrike:
            let kind = intent.detail.flatMap(StrikeKind.init(rawValue:)) ?? .precision
            plan.committed = ["\(kind.title) on \(nation.name). Hit odds \(Int(strikeOdds(id, kind: kind) * 100))%. Cost $\(ChatTools.round1(kind.cost))B.",
                              "No declaration of war."]
            if let me = gs.getPlayerCountry(), me.nuclearWarheads > 0 { plan.heldBack.append("Nuclear: all \(me.nuclearWarheads.formatted()) warheads held back.") }
            warn(strikeWarnings(id, kind: kind))
            plan.warnings += consequenceWarnings(nation, in: gs, nuclear: false)
            return finish(GameOrder(kind: .limitedStrike, target: id, mission: kind.rawValue), target: nation.name)
        default:
            return nil
        }
    }

    /// The card for renaming a sea, mountain or department (no action spent).
    func planRenamePlace(_ intent: CommandIntent, source: CommandSource) -> CommandOutcome {
        guard let gs = gameState else { return .rejected("No game in progress.") }
        let raw = intent.targets.first ?? ""
        guard let (id, old) = MapFeatures.match(raw, in: gs).map({ ($0.id, MapFeatures.shownName($0, in: gs)) })
                ?? Departments.match(raw, in: gs).map({ ($0.id, Departments.shownName($0, in: gs)) }) else {
            return .rejected("No sea, strait, mountain or department called \"\(String(raw.prefix(40)))\" in \(gs.currentYear).")
        }
        let new = intent.detail ?? ""
        let o = GameOrder(kind: .renamePlace, target: id, detail: new)
        if let p = powerPlayProblem(o) { return .rejected(p) }
        var plan = CommandPlan(title: "RENAME", target: "\(old), \(gs.currentYear)", orders: [o], committed: ["Rename \(old) to \(new) (no action)."],
                               heldBack: [], warnings: [], actionsNeeded: 0, actionsLeft: gs.actionsRemaining, source: source)
        plan.warnings = renamePlaceWarnings(id).map { CommandWarning(text: "\($0.who): \($0.text)", level: $0.level) }
        return .plan(plan)
    }

    enum PowerTarget {
        case found(String, note: String?)
        case choices([ResolvedTarget])
        case failure(String)
    }

    /// Resolve a power play's target: the usual resolver, then (for acquisitions) a land the map draws under another
    /// nation ("Greenland").
    func resolvePowerTarget(_ raw: String, verb: CommandVerb, in gs: GameState) -> PowerTarget {
        if verb.campaignStep != nil, let id = acquisitionID(raw, in: gs) {
            if case .one(let t, _) = CommandTargets.resolve(raw, in: gs), t.id != id { return .found(t.id, note: nil) }
            return .found(id, note: nil)
        }
        switch CommandTargets.resolve(raw, in: gs) {
        case .one(let t, let note):
            if case .nation = t { return .found(t.id, note: note) }
            return .failure("\(CommandTargets.label(t, in: gs)) is not a nation in \(gs.currentYear).")
        case .many(let o): return .choices(o)
        case .none: return .failure("No nation or land called \"\(String(raw.prefix(40)))\" in \(gs.currentYear).")
        }
    }

    /// The land or nation id an acquisition means, including lands with no country of their own.
    func acquisitionID(_ raw: String, in gs: GameState) -> String? {
        if case .one(let t, _) = CommandTargets.resolve(raw, in: gs), acquisitionTarget(t.id) != nil || openCampaign(t.id) != nil
            || gs.shadow.powerPlays.campaigns.contains(where: { $0.owner == t.id && $0.stage.isOpen }) { return t.id }
        if let id = CommandTargets.modernNames[CommandParser.normalize(raw)], acquisitionTarget(id) != nil || openCampaign(id) != nil { return id }
        let n = CommandParser.normalize(raw)
        if let t = Consequences.dependentLands.values.flatMap({ $0 }).first(where: { CommandParser.normalize($0.name) == n }),
           acquisitionTarget(t.id) != nil || openCampaign(t.id) != nil { return t.id }
        let upper = raw.uppercased()
        if gs.shadow.powerPlays.campaigns.contains(where: { $0.land == upper && $0.stage.isOpen }) { return upper }
        return nil
    }

    private func example(_ v: CommandVerb) -> String {
        switch v {
        case .acquire: return "offer to buy Greenland"
        case .pressure: return "pressure Greenland"
        case .posture: return "threaten Denmark"
        case .frameworkDeal: return "take the framework deal on Greenland"
        case .escalateCampaign: return "escalate over Greenland"
        case .emergencyTariffs: return "emergency tariffs on Canada under section 232"
        case .reissue: return "reissue the tariffs on Canada under national security"
        case .captureLeader: return "capture the leader of Panama"
        default: return "precision strike on Libya"
        }
    }
}

// MARK: - Chief of staff

extension ChatTools {
    /// A power-play step from `propose_orders`: the verb, at most one target, and `detail` (a strike kind, a legal
    /// authority, or an emergency's reason), each checked against its closed list.
    static func powerPlayIntent(_ verb: CommandVerb, _ o: [String: Any]) throws -> CommandIntent {
        var targets: [String] = []
        if let t = o["targets"] as? [Any] { targets = t.compactMap { $0 as? String } }
        else if let t = (o["targets"] ?? o["target"]) as? String { targets = [t] }
        targets = targets.prefix(1).map { String(CommandParser.sanitize($0).prefix(maxArgString)) }.filter { !$0.isEmpty }
        if targets.isEmpty && verb != .emergency && verb != .endEmergency { throw ChatToolError(message: "name the target nation or land.") }
        var detail: String?
        if let d = o["detail"] as? String {
            let s = CommandParser.sanitize(d)
            switch verb {
            case .limitedStrike: detail = (StrikeKind(rawValue: s) ?? PowerPlayParser.strikeKind(in: " " + CommandParser.normalize(s) + " ")).rawValue
            case .emergency: detail = (EmergencyReason(rawValue: s) ?? PowerPlayParser.reason(in: " " + CommandParser.normalize(s) + " ")).rawValue
            case .renamePlace: detail = String(s.prefix(maxArgString))
            case .emergencyTariffs, .reissue:
                guard let b = LegalBasis(rawValue: s) ?? PowerPlayParser.basis(in: s) else {
                    throw ChatToolError(message: "detail must be a legal authority: \(LegalBasis.allCases.map(\.rawValue).joined(separator: ", ")).")
                }
                detail = b.rawValue
            default: break
            }
        }
        return CommandIntent(verb: verb, targets: targets, detail: detail)
    }

    /// The power plays under way, for the `power_plays` tool. Read-only.
    static func powerPlays(_ e: GameEngine, _ gs: GameState) -> [String: Any] {
        let pp = gs.shadow.powerPlays
        func name(_ id: String) -> String { gs.getCountry(id: id)?.name ?? id }
        var d: [String: Any] = [:]
        if let em = pp.emergency { d["national_emergency"] = "in force since \(GameCalendar.format(em.declared)) over \(em.reason.title)" }
        d["emergency_orders"] = pp.orders.suffix(12).map { o -> String in
            var s = "\(o.subject): \(o.basis.short), \(o.status.label.lowercased())"
            if let days = e.daysToRuling(o) { s += ", ruling in \(days) days" }
            return s
        }
        d["campaigns"] = pp.campaigns.filter(\.stage.isOpen).map { c in
            "\(c.label) (held by \(name(c.owner))): \(c.stage.label.lowercased()), leverage \(Int(c.leverage)) of \(Int(e.campaignResistance(c))), protests \(Int(c.protests))"
        }
        d["recent_strikes"] = pp.strikes.suffix(8).map { "\(GameCalendar.format($0.date)): \($0.kind.title) on \(name($0.target)), \($0.hit ? "hit" : "missed")" }
        d["raids"] = pp.raids.suffix(5).map { "\(GameCalendar.format($0.date)): \(name($0.target)), \($0.outcome.title.lowercased())" }
        d["renamed"] = (pp.featureNames.map { "\(MapFeatures.feature($0.key).map { $0.name(in: gs.currentYear) } ?? $0.key) → \($0.value), used by \(pp.featureRecognition[$0.key]?.count ?? 0) nation(s)" }
                        + pp.departmentNames.map { "\(Departments.department($0.key)?.name ?? $0.key) → \($0.value)" }).sorted()
        d["strike_votes"] = pp.strikeVotes.suffix(5).map { "\(name($0.target)): \($0.overridden ? "veto overridden, strikes barred" : ($0.passed ? "passed, vetoed" : "failed"))" }
        d["verbs"] = "acquire, pressure, posture, frameworkDeal, escalateCampaign (one target: the land or its owner); emergency (detail: reason), endEmergency; emergencyTariffs and reissue (detail: legal authority); captureLeader; limitedStrike (detail: precision, boats, facility, nuclearFacility); renamePlace (target: a sea, strait, mountain or department; detail: the new name)."
        return d
    }
}
