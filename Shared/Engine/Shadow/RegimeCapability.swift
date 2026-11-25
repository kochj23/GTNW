//
//  RegimeCapability.swift
//  Global Thermal Nuclear War
//
//  3.37.0: what the player's nation can actually do (see Regime.swift for its words).
//    • A nation with no meaningful military (militaryStrength under 5 and no warheads: the Vatican, Monaco, San
//      Marino, Liechtenstein, Andorra, Nauru…) cannot strike, invade or blockade. Its military orders and crisis
//      options become a request to the nearest friendly power that can act (Italy, for the Vatican); the ally
//      decides, by its relations with both sides, and nothing is rolled. No government uses weapons of mass
//      destruction on another's behalf.
//    • A crisis option that needs a nuclear arsenal is dropped for a nation without one.
//    • "Restart" a chemical or biological program only where the nation had one (publicly documented programs);
//      anywhere else it is "Start a secret program", with a longer timeline.
//  All of it is filtered at the shared points: the crisis desk (`CrisisManager.adapt`), the order executor
//  (`executeShadowPresidentAction`) and the order's title (`PresidentialAction.title(in:)`). The United States is
//  never changed.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum RegimeCapability {
    /// Below this military strength, with no warheads, a nation has no forces to send.
    static let meaningfulMilitary = 5

    static func hasMeaningfulMilitary(_ c: Country) -> Bool {
        c.id == "USA" || c.militaryStrength >= meaningfulMilitary || c.nuclearWarheads > 0
    }

    /// The smallest force that can carry out a request: an ally must have at least this much.
    static let capableAlly = 25

    /// Nations with a publicly documented chemical weapons program at some point (state declarations to the OPCW,
    /// historical use), and with a documented biological one. Anyone else starts from nothing.
    static let formerChemical: Set<String> = ["USA", "RUS", "GBR", "FRA", "DEU", "ITA", "JPN", "IRQ", "SYR", "LBY", "EGY", "ZAF",
                                              "PRK", "IRN", "CHN", "IND", "KOR", "ALB", "CAN"]
    static let formerBiological: Set<String> = ["USA", "RUS", "GBR", "FRA", "DEU", "JPN", "CAN", "ZAF", "IRQ"]

    static func hadProgram(_ kind: WMDKind, _ country: String) -> Bool {
        (kind == .chemical ? formerChemical : formerBiological).contains(country)
    }

    /// A program started from nothing takes twice as long as a restart (design choice).
    static func startLeadYears(_ kind: WMDKind) -> Int { ArsenalCatalog.restartLeadYears(kind) * 2 }

    /// Orders that need forces of one's own.
    static let forceActions: Set<PresidentialAction> = [.navalBlockade, .airPatrol, .bombardment, .airStrike, .groundInvasion,
                                                        .amphAssault, .specialForces, .noFlyZone, .deployTroops]
    static let massDestruction: Set<PresidentialAction> = [.chemicalAttack, .biologicalAttack, .launchNukes, .preemptive,
                                                           .firstStrike, .strategicNuke, .tacticalNuke, .retaliate]

    /// True when the player's nation would have to ask an ally to carry this order out.
    static func needsAlly(_ action: PresidentialAction, in gs: GameState) -> Bool {
        guard gs.playerCountryID != "USA", let me = gs.getPlayerCountry(), !hasMeaningfulMilitary(me) else { return false }
        return forceActions.contains(action) || massDestruction.contains(action)
    }

    /// The nearest friendly power able to act, for the player: allied or not hostile (0 or better), strong enough, not
    /// the target or the target's ally, not at war with the player. Ties break on the id.
    static func nearestCapableAlly(_ gs: GameState, target: String?) -> Country? {
        guard let me = gs.getPlayerCountry() else { return nil }
        let candidates = gs.liveCountries.filter { c in
            c.id != me.id && c.id != target && c.militaryStrength >= capableAlly && !c.atWarWith.contains(me.id)
                && (c.alliances.contains(me.id) || (c.diplomaticRelations[me.id] ?? 0) >= 0)
                && !(target.map { c.alliances.contains($0) } ?? false)
        }
        return candidates.min { a, b in
            let da = Reach.distanceKm(me.coordinates, a.coordinates), db = Reach.distanceKm(me.coordinates, b.coordinates)
            return da == db ? a.id < b.id : da < db
        }
    }

    /// The ally's answer, from its relations alone: yes when it is allied with the player or close (+60) and not
    /// close to the target (under +30); never for weapons of mass destruction.
    static func allyAnswer(_ ally: Country, player: String, target: Country?, massDestruction: Bool) -> (agrees: Bool, reason: String) {
        if massDestruction { return (false, "\(ally.name) will not use weapons of mass destruction on another nation's behalf.") }
        let close = ally.alliances.contains(player) || (ally.diplomaticRelations[player] ?? 0) >= 60
        if !close { return (false, "\(ally.name) is not close enough to us to go to war on our account.") }
        if let t = target, !ally.atWarWith.contains(t.id), (ally.diplomaticRelations[t.id] ?? 0) >= 30 {
            return (false, "\(ally.name) values its own ties with \(t.name) too much to act against it.")
        }
        return (true, "\(ally.name) agrees to act.")
    }

    // MARK: Crisis cards

    enum Need { case none, military, nuclear }

    /// What a crisis option takes, from its title.
    static func need(_ o: CrisisOption) -> Need {
        let t = o.title.lowercased()
        if t.contains("cyber") { return .none }
        if ["counterstrike", "limited strike", "prepare for launch", "nuclear strike", "first strike", "launch nukes"].contains(where: t.contains) {
            return .nuclear
        }
        if ["military", "strike", "emp", "special forces", "deploy", "troops", "invasion", "invade", "bomb", "blockade",
            "peacekeeping force", "containment", "commando", "raid", "naval", "navy", "marines", "secure nuclear"].contains(where: t.contains) {
            return .military
        }
        return .none
    }

    /// A card in the player government's words, with only the options the nation can carry out: a nuclear option
    /// without an arsenal is dropped; a military one without forces becomes a request to the nearest capable friend,
    /// whose answer is decided here from relations (the card shows the request; the outcome is the ally's).
    static func adapt(_ card: CrisisEvent, in gs: GameState) -> CrisisEvent {
        guard gs.playerCountryID != "USA", let me = gs.getPlayerCountry() else { return card }
        var c = card
        if let r = gs.shadow.regime {
            c.title = r.localize(c.title)
            c.description = r.localize(c.description)
            c.options = c.options.map { o in
                var o = o
                o.title = r.localize(o.title)
                o.description = r.localize(o.description)
                o.advisorRecommendation = o.advisorRecommendation.map(r.localize)
                o.consequences.message = r.localize(o.consequences.message)
                return o
            }
        }
        let armed = hasMeaningfulMilitary(me), nuclear = me.nuclearWarheads > 0
        let target = c.affectedCountries.first.flatMap { gs.getCountry(id: $0) }
        let ally = armed ? nil : nearestCapableAlly(gs, target: target?.id)
        var out: [CrisisOption] = []
        for o in c.options {
            switch need(o) {
            case .none:
                out.append(o)
            case .nuclear where nuclear:
                out.append(o)
            case .military where armed:
                out.append(o)
            case .nuclear:
                continue   // no arsenal to use
            case .military:
                guard let ally else { continue }
                out.append(askAlly(o, ally: ally, player: me.id, target: target))
            }
        }
        if out.isEmpty {
            out = [CrisisOption(title: "Issue a Statement and Wait", description: "We have no means to act ourselves",
                                consequences: CrisisConsequences(message: "\(me.name) states its position and waits on events."))]
        }
        c.options = out
        return c
    }

    /// "Ask Italy: EMP Strike on Silo" — the same option, carried out by the ally if it agrees.
    static func askAlly(_ o: CrisisOption, ally: Country, player: String, target: Country?) -> CrisisOption {
        let answer = allyAnswer(ally, player: player, target: target, massDestruction: false)
        let title = "Ask \(ally.name): \(o.title)"
        let description = "\(ally.name) decides whether to act, not us. \(o.description)"
        guard answer.agrees else {
            return CrisisOption(title: title, description: description, advisorRecommendation: o.advisorRecommendation,
                                consequences: CrisisConsequences(approvalChange: -2, message: "\(ally.name) declines. \(answer.reason)"))
        }
        var k = o.consequences
        // The ally carries it out and takes most of the anger; we asked.
        k.relationshipChanges = k.relationshipChanges.mapValues { $0 / 2 }
        k.message = "\(ally.name) agrees and acts. " + k.message
        return CrisisOption(title: title, description: description, advisorRecommendation: o.advisorRecommendation,
                            consequences: k, successChance: o.successChance)
    }
}

// MARK: - Orders

extension PresidentialAction {
    /// The order as the player's nation would give it: "Start a Secret Chemical Program" where there was never one,
    /// "Ask Italy: Air Strike" where there are no forces. The raw name everywhere for the United States.
    func title(in gs: GameState?) -> String {
        guard let gs, gs.playerCountryID != "USA" else { return rawValue }
        if let k = wmd, self == .restartChemical || self == .restartBiological, !RegimeCapability.hadProgram(k, gs.playerCountryID) {
            return "Start a Secret \(k.title) Program"
        }
        if RegimeCapability.needsAlly(self, in: gs), let ally = RegimeCapability.nearestCapableAlly(gs, target: nil) {
            return "Ask \(ally.name): \(rawValue)"
        }
        return rawValue
    }

    /// The one-line description, to match `title(in:)`.
    func description(in gs: GameState?) -> String {
        guard let gs, gs.playerCountryID != "USA" else { return description }
        if let k = wmd, self == .restartChemical || self == .restartBiological, !RegimeCapability.hadProgram(k, gs.playerCountryID) {
            return "Secretly build a \(k.title.lowercased()) arsenal from nothing (\(RegimeCapability.startLeadYears(k)) years; may be discovered)"
        }
        if RegimeCapability.needsAlly(self, in: gs) {
            return "We have no forces of our own: ask the nearest friendly power to act. The decision is theirs."
        }
        return description
    }
}

extension GameEngine {
    /// A military order from a nation with no forces goes to the nearest capable friend, who decides. True when the
    /// order was handled here (asked, agreed or declined); false to carry it out as usual.
    func askAllyIfUnarmed(_ action: PresidentialAction, from playerID: String, to targetID: String) -> Bool {
        guard let gs = gameState, playerID == gs.playerCountryID, RegimeCapability.needsAlly(action, in: gs) else { return false }
        let target = gs.getCountry(id: targetID)
        let tName = target?.name ?? targetID
        guard let ally = RegimeCapability.nearestCapableAlly(gs, target: targetID) else {
            addLog("❌ \(action.rawValue): we have no forces, and no friendly power is able to act for us.", type: .error)
            return true
        }
        let answer = RegimeCapability.allyAnswer(ally, player: playerID, target: target,
                                                 massDestruction: RegimeCapability.massDestruction.contains(action))
        guard answer.agrees else {
            addLog("❌ \(ally.name) declines to carry out \(action.rawValue.lowercased()) against \(tName) for us. \(answer.reason)", type: .error)
            gs.shadow.post("\(ally.name) turns down a request from \(gs.getPlayerCountry()?.name ?? playerID) to act against \(tName).",
                           date: gs.currentDate, severity: 1)
            return true
        }
        addLog("🤝 \(ally.name) agrees to act for us: \(action.rawValue.lowercased()) against \(tName).", type: .warning)
        gs.shadow.post("At the request of \(gs.getPlayerCountry()?.name ?? playerID), \(ally.name) acts against \(tName).", date: gs.currentDate, severity: 2)
        modifyDiplomaticRelation(from: targetID, to: playerID, by: -20)   // they know who asked
        modifyDiplomaticRelation(from: targetID, to: ally.id, by: -30)
        if action != .deployTroops && action != .airPatrol { declareWar(aggressor: ally.id, defender: targetID) }
        return true
    }

    /// Advisor read-outs in the player government's words ("General Staff", "Commander of the Swiss Guard").
    func localizedWarnings(_ ws: [AdvisorWarning]) -> [AdvisorWarning] {
        guard let gs = gameState, let r = gs.shadow.regime else { return ws }
        return ws.map { w in
            var w = w
            w.who = (r.kind == .papacy && w.who == "Joint Chiefs") ? r.terms.defenseMinister : r.localize(w.who)
            w.text = r.localize(w.text)
            return w
        }
    }

    /// The three lines for a major action. Empty when there is no game.
    func advisorWarnings(for action: MajorAction) -> [AdvisorWarning] { localizedWarnings(rawAdvisorWarnings(for: action)) }
    func strikeWarnings(_ target: String, kind: StrikeKind) -> [AdvisorWarning] { localizedWarnings(rawStrikeWarnings(target, kind: kind)) }
    func captureWarnings(_ target: String) -> [AdvisorWarning] { localizedWarnings(rawCaptureWarnings(target)) }
    func renamePlaceWarnings(_ id: String) -> [AdvisorWarning] { localizedWarnings(rawRenamePlaceWarnings(id)) }
    func campaignWarnings(_ land: String, step: CampaignStep) -> [AdvisorWarning] { localizedWarnings(rawCampaignWarnings(land, step: step)) }
}
