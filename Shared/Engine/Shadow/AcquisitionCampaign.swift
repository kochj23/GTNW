//
//  AcquisitionCampaign.swift
//  Global Thermal Nuclear War
//
//  3.36.0: a pressure campaign to acquire a land or a whole nation without a war. Four steps, one action each:
//    1. OFFER to buy it (the price from the land's value or the nation's output, and relations);
//    2. PRESSURE: emergency tariffs on the nations that object (they go through EmergencyPowers, so the courts can
//       strike them down);
//    3. POSTURE: military posturing, a threat;
//    4. then either a FRAMEWORK deal (back down with what the talks will give) or ESCALATE (war on the owner, through
//       `declareWar`, so the alliance fallout follows).
//  Each step adds leverage; each also raises protests in the land and the objectors' solidarity, which add to its
//  resistance. The owner sells the moment leverage reaches resistance. Deterministic: no dice, only the formulas
//  below (DESIGN CHOICES). Targets: another power's colony or territory (the 3.28.2 colony path), a land the map draws
//  under another nation (Greenland under Denmark), or a whole independent nation.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum AcquisitionKind: String, Codable, Sendable {
    /// A whole independent nation.
    case nation
    /// Another power's colony or territory.
    case colony
    /// A land the map draws under another nation, with no government of its own in the game.
    case land
}

enum CampaignStage: String, Codable, Sendable {
    case offered, tariffs, posturing, deal, acquired, escalated, lapsed
    var isOpen: Bool { self == .offered || self == .tariffs || self == .posturing }
    var label: String {
        switch self {
        case .offered: return "OFFER MADE"
        case .tariffs: return "TARIFFS ON OBJECTORS"
        case .posturing: return "MILITARY POSTURING"
        case .deal: return "FRAMEWORK DEAL"
        case .acquired: return "ACQUIRED"
        case .escalated: return "ESCALATED TO WAR"
        case .lapsed: return "LAPSED"
        }
    }
}

/// A step the President can take in a campaign (`GameOrder.mission`).
enum CampaignStep: String, Codable, CaseIterable, Sendable {
    case offer, pressure, posture, deal, escalate
    var title: String {
        switch self {
        case .offer: return "OFFER TO BUY"
        case .pressure: return "TARIFFS ON OBJECTORS"
        case .posture: return "MILITARY POSTURING"
        case .deal: return "FRAMEWORK DEAL"
        case .escalate: return "ESCALATE"
        }
    }
}

struct AcquisitionCampaign: Codable, Equatable, Identifiable {
    var id: String { land + "@" + String(Int(started.timeIntervalSince1970)) }
    var land: String
    var owner: String
    var kind: AcquisitionKind
    var label: String
    var started: Date
    var lastMove: Date
    var stage: CampaignStage
    /// $B offered.
    var price: Double
    var leverage: Double = 0
    /// Protests in the land, 0…100.
    var protests: Double = 0
    /// Extra resistance from the objectors standing together.
    var solidarity: Double = 0
    var objectors: [String] = []
    /// Emergency orders (tariffs) the campaign issued.
    var tariffOrders: [Int] = []
}

enum AcquisitionModel {
    /// Months without a step before a campaign lapses.
    static let lapseDays = 365

    static func baseResistance(_ k: AcquisitionKind) -> Double {
        switch k {
        case .nation: return 85
        case .land: return 55
        case .colony: return 35
        }
    }

    /// How hard the owner holds on. Pure.
    static func resistance(kind: AcquisitionKind, protests: Double, solidarity: Double, ownerMilitary: Int, objectors: Int,
                           relation: Int, ownerNuclear: Bool, year: Int) -> Double {
        let r = baseResistance(kind) + protests * 0.5 + solidarity + Double(ownerMilitary) * 0.15 + Double(objectors) * 5
            - Double(relation) / 4 + (ownerNuclear ? 15 : 0) + (year >= 1945 ? 10 : 0)
        return (max(0, r) * 10).rounded() / 10
    }

    /// Leverage one step adds. `econShare` and `milShare` are the player's share of the two economies and militaries.
    static func leverage(_ step: CampaignStep, econShare: Double, milShare: Double, tariffed: Int, nuclearEdge: Bool) -> Double {
        let v: Double
        switch step {
        case .offer: v = 8 + 12 * econShare
        case .pressure: v = 10 + 20 * econShare + 3 * Double(tariffed)
        case .posture: v = 12 + 25 * milShare + (nuclearEdge ? 8 : 0)
        case .deal, .escalate: v = 0
        }
        return (v * 10).rounded() / 10
    }

    /// Protests one step adds in the land.
    static func protests(_ step: CampaignStep) -> Double {
        switch step {
        case .offer: return 10
        case .pressure: return 15
        case .posture: return 25
        case .deal, .escalate: return 0
        }
    }
}

// MARK: - Engine

extension GameEngine {

    /// What acquiring `id` means: the kind, who holds it and its name now. Nil when it isn't something to acquire.
    func acquisitionTarget(_ id: String) -> (kind: AcquisitionKind, owner: Country, label: String)? {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return nil }
        if let col = colonyTarget(id) { return (.colony, col.owner, col.label) }
        if let c = gs.getCountry(id: id) {
            guard !c.isDestroyed, c.territoryOf == nil, c.id != me.id else { return nil }
            return (.nation, c, c.name)
        }
        guard gs.preState(id) == nil, let t = WorldCountriesDatabase.template(id: id),
              let o = WorldMapData.owner(of: id, in: Set(gs.countries.map(\.id)), year: gs.currentYear), o != me.id,
              let owner = gs.getCountry(id: o), !owner.isDestroyed, owner.territoryOf == nil else { return nil }
        return (.land, owner, t.name)
    }

    /// The campaign open on a land, if any.
    func openCampaign(_ land: String) -> AcquisitionCampaign? {
        gameState?.shadow.powerPlays.campaigns.last { $0.land == land && $0.stage.isOpen }
    }

    /// The nations that object publicly: the owner's allies and the region's powers on good terms with it, strongest
    /// first, at most five. Deterministic.
    func campaignObjectors(owner: Country, land: String) -> [String] {
        guard let gs = gameState else { return [] }
        let me = gs.playerCountryID
        let region = gs.getCountry(id: land)?.region ?? owner.region
        let candidates = gs.countries.filter { c in
            !c.isDestroyed && c.territoryOf == nil && c.id != me && c.id != owner.id && c.id != land
                && (owner.alliances.contains(c.id) || (c.region == region && (c.diplomaticRelations[owner.id] ?? 0) > 30))
        }
        return candidates.sorted { $0.powerScore != $1.powerScore ? $0.powerScore > $1.powerScore : $0.id < $1.id }.prefix(5).map(\.id)
    }

    /// The owner's resistance now (or for a campaign not yet begun).
    func campaignResistance(_ c: AcquisitionCampaign) -> Double {
        guard let gs = gameState, let owner = gs.getCountry(id: c.owner) else { return 999 }
        return AcquisitionModel.resistance(kind: c.kind, protests: c.protests, solidarity: c.solidarity, ownerMilitary: owner.militaryStrength,
                                           objectors: c.objectors.count, relation: owner.diplomaticRelations[gs.playerCountryID] ?? 0,
                                           ownerNuclear: owner.nuclearWarheads > 0 && gs.currentYear >= 1945, year: gs.currentYear)
    }

    /// The price offered ($B): ten years of a land's value, or two years of a nation's output, cheaper among friends.
    func acquisitionPrice(_ land: String, kind: AcquisitionKind, owner: Country) -> Double {
        guard let gs = gameState else { return 0 }
        let rel = owner.diplomaticRelations[gs.playerCountryID] ?? 0
        if kind == .nation { return ((owner.gdp * 2000 * (1 - Double(rel) / 200)) * 10).rounded() / 10 }
        return (PreStateModel.price(land, year: gs.currentYear, relation: rel) * 10).rounded() / 10
    }

    /// Leverage the next step would add.
    func campaignLeverage(_ c: AcquisitionCampaign, step: CampaignStep) -> Double {
        guard let gs = gameState, let me = gs.getPlayerCountry(), let owner = gs.getCountry(id: c.owner) else { return 0 }
        let econ = me.gdp / max(0.001, me.gdp + owner.gdp)
        let mil = Double(me.militaryStrength) / Double(max(1, me.militaryStrength + owner.militaryStrength))
        let tariffed = step == .pressure ? c.objectors.filter { liveEmergencyOrder(.tariff, target: $0) == nil }.prefix(4).count : 0
        let nuclearEdge = gs.currentYear >= 1945 && me.nuclearWarheads > 0 && owner.nuclearWarheads == 0
        return AcquisitionModel.leverage(step, econShare: econ, milShare: mil, tariffed: tariffed, nuclearEdge: nuclearEdge)
    }

    func campaignProblem(_ land: String, step: CampaignStep) -> String? {
        guard let gs = gameState else { return "No game." }
        if gs.gameOver { return "The game is over." }
        if gs.actionsRemaining < 1 { return "No actions left." }
        let open = openCampaign(land)
        switch step {
        case .offer:
            if open != nil { return "A campaign for it is already under way. Turn up the pressure, or take a deal." }
            guard let t = acquisitionTarget(land) else { return "That is not a land or nation another power holds." }
            if t.owner.atWarWith.contains(gs.playerCountryID) { return "You are at war with \(t.owner.name): no offer will be heard." }
            return nil
        case .pressure:
            guard let c = open else { return "Make an offer first." }
            return c.stage == .offered ? nil : "The tariffs are already on."
        case .posture:
            guard let c = open else { return "Make an offer first." }
            return c.stage == .posturing ? "The forces are already posturing." : nil
        case .deal, .escalate:
            return open == nil ? "No campaign is under way for it." : nil
        }
    }

    /// The cabinet's read-out on a campaign step.
    func campaignWarnings(_ land: String, step: CampaignStep) -> [AdvisorWarning] {
        guard let gs = gameState, let t = acquisitionTarget(land) ?? openCampaign(land).flatMap({ c in gs.getCountry(id: c.owner).map { (c.kind, $0, c.label) } }) else { return [] }
        var c = openCampaign(land) ?? AcquisitionCampaign(land: land, owner: t.owner.id, kind: t.kind, label: t.label, started: gs.currentDate,
                                                          lastMove: gs.currentDate, stage: .offered, price: acquisitionPrice(land, kind: t.kind, owner: t.owner),
                                                          objectors: campaignObjectors(owner: t.owner, land: land))
        let gain = campaignLeverage(c, step: step)
        c.protests = min(100, c.protests + AcquisitionModel.protests(step))
        if step == .pressure { c.solidarity += 3 * Double(min(4, c.objectors.count)) }
        let res = campaignResistance(c)
        let after = c.leverage + gain
        let objectors = c.objectors.compactMap { gs.getCountry(id: $0)?.name }
        var out: [AdvisorWarning] = []
        switch step {
        case .offer, .pressure, .posture:
            let verdict = after >= res ? "\(t.owner.name) would sell." : "\(t.owner.name) holds out: leverage \(Int(after)) against resistance \(Int(res))."
            out.append(AdvisorWarning(who: "Chief of Staff", text: "Leverage +\(Int(gain)). \(verdict)", level: after >= res ? 0 : 1))
        case .deal:
            let ok = c.leverage >= 0.6 * campaignResistance(c)
            out.append(AdvisorWarning(who: "Chief of Staff", text: ok ? "\(t.owner.name) will sign a framework: a trade agreement and access, not the land." : "Not enough leverage for a framework: the talks end with nothing.",
                                      level: ok ? 0 : 1))
        case .escalate:
            out.append(AdvisorWarning(who: "Joint Chiefs", text: "This means war with \(t.owner.name)\(t.owner.nuclearWarheads > 0 ? ", a nuclear power" : "").", level: 2))
        }
        switch step {
        case .offer:
            out.append(AdvisorWarning(who: powerPlayStateWho, text: objectors.isEmpty ? "Nobody else is likely to object." : "Expect objections from \(PowerPlay.list(objectors)).", level: 0))
        case .pressure:
            out.append(AdvisorWarning(who: powerPlayStateWho, text: "Tariffs on \(PowerPlay.list(objectors.isEmpty ? [t.owner.name] : objectors)): they will close ranks behind \(t.owner.name).", level: 1))
            if let b = legalBases(for: .tariff).first {
                out.append(AdvisorWarning(who: PowerPlay.counsel, text: "The tariffs rest on \(b.title); the courts will rule in about \(b.courtDays / 30) months.", level: courtScore(b, kind: .tariff, target: nil) < EmergencyPowers.passMark ? 1 : 0))
            }
        case .posture:
            let mine = c.objectors.filter { gs.getPlayerCountry()?.alliances.contains($0) ?? false }.compactMap { gs.getCountry(id: $0)?.name }
            out.append(AdvisorWarning(who: powerPlayStateWho, text: "A threat against \(t.owner.name). \(mine.isEmpty ? "Its friends will push back hard." : "Our own allies \(PowerPlay.list(mine)) will push back.")", level: 2))
            if gs.currentYear >= 1945 {
                out.append(AdvisorWarning(who: PowerPlay.counsel, text: "The UN Charter bars the threat of force against another state's territory.", level: 1))
            }
        case .deal:
            out.append(AdvisorWarning(who: powerPlayStateWho, text: "The tariffs on the objectors come off.", level: 0))
        case .escalate:
            out.append(AdvisorWarning(who: powerPlayStateWho, text: "\(t.owner.name)'s allies may come to its defense.", level: 2))
        }
        out.append(powerPlayPolitics(dPop: step == .deal ? 1 : (step == .escalate ? -4 : -1), dRuth: step == .posture ? 4 : (step == .escalate ? 10 : 1),
                                     hostilities: step == .escalate ? t.owner.id : nil))
        return out
    }

    /// Take one step of a campaign (one action). Returns whether it went through.
    @discardableResult
    func campaignStep(_ land: String, step: CampaignStep) -> Bool {
        guard campaignProblem(land, step: step) == nil, let gs = gameState, let me = gs.getPlayerCountry() else { return false }
        if step == .offer {
            guard let t = acquisitionTarget(land) else { return false }
            let c = AcquisitionCampaign(land: land, owner: t.owner.id, kind: t.kind, label: t.label, started: gs.currentDate, lastMove: gs.currentDate,
                                        stage: .offered, price: acquisitionPrice(land, kind: t.kind, owner: t.owner),
                                        objectors: campaignObjectors(owner: t.owner, land: land))
            gs.shadow.powerPlays.campaigns.append(c)
            self.gameState = gs
        }
        guard let ci = gs.shadow.powerPlays.campaigns.lastIndex(where: { $0.land == land && $0.stage.isOpen }),
              let owner = gs.getCountry(id: gs.shadow.powerPlays.campaigns[ci].owner) else { return false }
        var c = gs.shadow.powerPlays.campaigns[ci]
        let objectorNames = c.objectors.compactMap { gs.getCountry(id: $0)?.name }
        c.lastMove = gs.currentDate
        switch step {
        case .offer:
            c.leverage += campaignLeverage(c, step: .offer)
            gs.shadow.post("\(me.name) offers to buy \(c.label) from \(owner.name) for $\(ChatTools.round1(c.price))B. \(owner.name): \"It is not for sale.\"",
                           date: gs.currentDate, severity: 2)
            for o in c.objectors { modifyDiplomaticRelation(from: o, to: me.id, by: -2) }
            modifyDiplomaticRelation(from: owner.id, to: me.id, by: -5)
        case .pressure:
            let gain = campaignLeverage(c, step: .pressure)
            var tariffed: [String] = []
            for o in c.objectors where liveEmergencyOrder(.tariff, target: o) == nil && tariffed.count < 4 {
                guard let b = legalBases(for: .tariff, target: o).first, let order = emergencyTariffs(on: o, basis: b, spendAction: false) else { continue }
                c.tariffOrders.append(order.id)
                tariffed.append(o)
            }
            if tariffed.isEmpty, liveEmergencyOrder(.tariff, target: owner.id) == nil,
               let b = legalBases(for: .tariff, target: owner.id).first, let order = emergencyTariffs(on: owner.id, basis: b, spendAction: false) {
                c.tariffOrders.append(order.id)
                tariffed.append(owner.id)
            }
            c.leverage += gain
            c.solidarity += 3 * Double(tariffed.count)
            c.stage = .tariffs
            for o in c.objectors { modifyDiplomaticRelation(from: o, to: me.id, by: -6) }
            let names = tariffed.compactMap { gs.getCountry(id: $0)?.name }
            gs.shadow.post("Tariffs on \(PowerPlay.list(names)) for standing with \(owner.name) over \(c.label). They close ranks.", date: gs.currentDate, severity: 2)
        case .posture:
            c.leverage += campaignLeverage(c, step: .posture)
            c.stage = .posturing
            if let oi = gs.countries.firstIndex(where: { $0.id == owner.id }) {
                gs.countries[oi].profile.anxieties.military = min(100, gs.countries[oi].profile.anxieties.military + 25)
                gs.countries[oi].warSupport = min(100, gs.countries[oi].warSupport + 10)
            }
            modifyDiplomaticRelation(from: owner.id, to: me.id, by: -15)
            for o in c.objectors { modifyDiplomaticRelation(from: o, to: me.id, by: -10) }
            let allies = c.objectors.filter { me.alliances.contains($0) }.compactMap { gs.getCountry(id: $0)?.name }
            gs.shadow.post("\(me.name) will not rule out force to take \(c.label). Forces move toward it.", date: gs.currentDate, severity: 3)
            if !allies.isEmpty {
                gs.shadow.post("Our own allies \(PowerPlay.list(allies)) stand with \(owner.name) and say so in public.", date: gs.currentDate, severity: 2)
            }
            gs.shadow.ruthlessness += 4
        case .deal:
            let ok = c.leverage >= 0.6 * campaignResistance(c)
            c.stage = .deal
            if ok {
                if !gs.treaties.contains(where: { $0.type == .tradeAgreement && Set($0.signatories) == [me.id, owner.id] }) {
                    gs.treaties.append(Treaty(type: .tradeAgreement, signatories: [me.id, owner.id], turn: gs.turn))
                }
                gs.shadow.acquisitionIncome += c.kind == .nation ? 1 : 0.5
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 2)
                modifyDiplomaticRelation(from: owner.id, to: me.id, by: 10)
                for o in c.objectors { modifyDiplomaticRelation(from: o, to: me.id, by: 5) }
                gs.shadow.post("A framework deal on \(c.label): access and trade, not the land. \(owner.name) keeps it; both sides claim a win.",
                               date: gs.currentDate, severity: 2)
            } else {
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 3)
                modifyDiplomaticRelation(from: owner.id, to: me.id, by: 5)
                gs.shadow.post("The campaign for \(c.label) ends without a deal. \(owner.name) keeps it.", date: gs.currentDate, severity: 2)
            }
            c.protests = max(0, c.protests - 20)
        case .escalate:
            c.stage = .escalated
        }
        if step != .deal && step != .escalate {
            c.protests = min(100, c.protests + AcquisitionModel.protests(step))
            if let li = gs.countries.firstIndex(where: { $0.id == land }) {
                gs.countries[li].profile.outcry = max(gs.countries[li].profile.outcry, c.protests)
                gs.countries[li].stability = max(1, gs.countries[li].stability - Int(AcquisitionModel.protests(step) / 5))
            }
            if c.protests >= 40 { gs.shadow.post("Protests grow in \(c.label) against the sale: \"We are not for sale.\"", date: gs.currentDate, severity: 1) }
        }
        gs.shadow.powerPlays.campaigns[ci] = c
        self.gameState = gs
        logPlayEvent("acquisition_campaign", detail: ["land": land, "owner": owner.id, "kind": c.kind.rawValue, "step": step.rawValue,
                                                      "leverage": PlayHistory.num(c.leverage), "resistance": PlayHistory.num(campaignResistance(c)),
                                                      "objectors": objectorNames.count, "game_date": PlayHistory.day(gs.currentDate)])
        recordPlayerAction(rung: step == .posture || step == .escalate ? .military : .economic, hostile: step != .deal, detected: false)
        if step == .deal { endCampaignTariffs(ci) }
        if step == .escalate {
            gs.shadow.post("The campaign for \(c.label) turns to force: \(me.name) declares war on \(owner.name).", date: gs.currentDate, severity: 3)
            self.gameState = gs
            declareWar(aggressor: me.id, defender: owner.id)
        } else if step != .deal, c.leverage >= campaignResistance(c) {
            completeAcquisition(ci)
        }
        completePlayerAction()
        return true
    }

    /// Withdraw the tariffs a campaign imposed.
    func endCampaignTariffs(_ ci: Int) {
        guard let gs = gameState, gs.shadow.powerPlays.campaigns.indices.contains(ci) else { return }
        for id in gs.shadow.powerPlays.campaigns[ci].tariffOrders { _ = rescindEmergencyOrder(id) }
    }

    /// The owner sells: the land or nation becomes the President's, paid for at the offered price.
    func completeAcquisition(_ ci: Int) {
        guard let gs = gameState, gs.shadow.powerPlays.campaigns.indices.contains(ci), let me = gs.getPlayerCountry() else { return }
        var c = gs.shadow.powerPlays.campaigns[ci]
        let owner = gs.getCountry(id: c.owner)
        spendFunds(c.price)
        let outcry = min(95, c.protests)
        switch c.kind {
        case .colony:
            if let col = colonyTarget(c.land) { takeColony(c.land, col, troops: 1, stability: 55, outcry: outcry) }
        case .land:
            annexLand(c.land, troops: 1, stability: 55, outcry: outcry)
        case .nation:
            guard let li = gs.countries.firstIndex(where: { $0.id == c.land }) else { break }
            var n = gs.countries[li]
            let seized = CombatModel.annex(&n, to: me)
            n.stability = 50
            n.profile.outcry = outcry
            gs.countries[li] = n
            if let pi = gs.countries.firstIndex(where: { $0.id == me.id }) {
                gs.countries[pi].nuclearWarheads += seized
                gs.countries[pi].alliances.insert(n.id)
                gs.countries[pi].diplomaticRelations[n.id] = 100
            }
            for i in gs.countries.indices where gs.countries[i].territoryOf == n.id { gs.countries[i].territoryOf = me.id }
            gs.shadow.garrisons[n.id] = 1
            gs.shadow.expansionLog.append(gs.currentDate)
            gs.shadow.claimDates[n.id] = gs.currentDate
            gs.shadow.ruthlessness += 3
            self.gameState = gs
            for x in gs.countries where !x.isDestroyed && !x.isTerritory && x.id != me.id {
                modifyDiplomaticRelation(from: x.id, to: me.id, by: x.alliances.contains(me.id) ? -2 : (x.alignment != me.alignment ? -8 : -4))
            }
        }
        c.stage = .acquired
        gs.shadow.powerPlays.campaigns[ci] = c
        gs.shadow.post("\(owner?.name ?? c.owner) gives way: \(c.label) passes to \(me.name) for $\(ChatTools.round1(c.price))B. Its people did not choose it.",
                       date: gs.currentDate, severity: 3)
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(c.label) acquired from \(owner?.name ?? c.owner) under pressure.")
        logPlayEvent("acquisition_completed", detail: ["land": c.land, "owner": c.owner, "kind": c.kind.rawValue, "price_b": PlayHistory.num(c.price),
                                                       "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        endCampaignTariffs(ci)
    }

    /// Each turn: protests cool a little, a campaign left alone for a year lapses (its tariffs come off), and a land
    /// already lost to a war or a treaty closes its campaign.
    func processCampaigns() {
        guard let gs = gameState else { return }
        let months = gs.scale.yearFraction * 12
        for ci in gs.shadow.powerPlays.campaigns.indices where gs.shadow.powerPlays.campaigns[ci].stage.isOpen {
            let c = gs.shadow.powerPlays.campaigns[ci]
            if acquisitionTarget(c.land) == nil {
                gs.shadow.powerPlays.campaigns[ci].stage = gs.getCountry(id: c.land)?.territoryOf == gs.playerCountryID ? .acquired : .lapsed
                continue
            }
            gs.shadow.powerPlays.campaigns[ci].protests = max(0, c.protests - 3 * months)
            if GameCalendar.days(from: c.lastMove, to: gs.currentDate) >= AcquisitionModel.lapseDays {
                gs.shadow.powerPlays.campaigns[ci].stage = .lapsed
                gs.shadow.post("The campaign for \(c.label) has gone quiet and lapses.", date: gs.currentDate, severity: 1)
                self.gameState = gs
                endCampaignTariffs(ci)
            }
        }
        self.gameState = gs
    }
}
