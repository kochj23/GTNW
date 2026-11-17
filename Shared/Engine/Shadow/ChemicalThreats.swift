//
//  ChemicalThreats.swift
//  Global Thermal Nuclear War
//
//  Chemical weapons in other hands (3.31.0). Two threats the President can only answer, never order:
//  • Chemical terrorism by non-state groups, after the Tokyo subway attack (20 March 1995). From the 1990s a cult
//    or cell may attack a city's transit or a public space somewhere in the world, the President's own country
//    included. The odds at home fall with his intelligence posture (raised by intelligence sharing and by expanded
//    surveillance, which costs civil liberties and approval).
//  • State chemical attacks on civilians, after Halabja (16 March 1988, during the Anfal campaign). A computer-run
//    government facing an insurgency may turn chemical weapons on a minority or rebel region. The world's reaction
//    hardens after the Chemical Weapons Convention; the record of the age keeps the perpetrator's name. The player
//    has no such order against anyone, his own people above all.
//  Both real events are in the record of the age (WorldPolitics.atrocities). Abstract by design: no agent, method or
//  quantity appears. Game-balance numbers are design choices.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum ChemicalThreats {
    static let terrorFrom = 1990
    static let stateFrom = 1920
    /// Under tests these don't fire unless a test asks.
    nonisolated(unsafe) static var enabled = !GameStoreService.isTestOrSmokeRun

    /// Chance a year of a chemical terror attack somewhere in the world (design choice).
    static let terrorAnnual = 0.15
    /// Share of those attacks aimed at the President's country, before his intelligence posture.
    static let homeShare = 0.15
    /// Each point of intelligence posture (0–3) removes a quarter of the home risk.
    static func homeShare(posture: Double) -> Double { homeShare * max(0.25, 1 - 0.25 * posture) }

    /// Chance a year that a government facing an insurgency uses chemical weapons on its own region.
    static let stateAnnual = 0.04

    /// A government that might: computer-run, not a democracy, facing an insurgency (unrest ≥ 60 or stability ≤ 25).
    static func candidates(_ gs: GameState) -> [Country] {
        gs.countries.filter { c in
            !c.isDestroyed && !c.isTerritory && c.id != gs.playerCountryID && !c.isPlayerControlled
                && c.government != .democracy && (c.profile.outcry >= 60 || c.stability <= 25)
        }
    }
}

extension GameEngine {
    /// Each turn: perhaps a chemical terror attack, perhaps a state attack on civilians. `roll`s for tests.
    func processChemicalThreats(terrorRoll: Double? = nil, stateRoll: Double? = nil, pickRoll: Double? = nil) {
        guard let gs = gameState, ChemicalThreats.enabled || terrorRoll != nil || stateRoll != nil else { return }
        gs.shadow.intelPosture = max(0, gs.shadow.intelPosture - 0.25 * gs.turnLength.yearFraction)   // posture lapses without effort
        let y = gs.currentYear
        if y >= ChemicalThreats.terrorFrom {
            let r = terrorRoll ?? Double.random(in: 0..<1, using: &gs.rng)
            if r < gs.scale.probability(annual: ChemicalThreats.terrorAnnual) {
                let p = pickRoll ?? Double.random(in: 0..<1, using: &gs.rng)
                chemicalTerrorAttack(home: p < ChemicalThreats.homeShare(posture: gs.shadow.intelPosture), pick: p)
            }
        }
        if y >= ChemicalThreats.stateFrom, let g = gameState {
            let r = stateRoll ?? Double.random(in: 0..<1, using: &g.rng)
            let cands = ChemicalThreats.candidates(g)
            if !cands.isEmpty, r < g.scale.probability(annual: ChemicalThreats.stateAnnual * WorldPolitics.activity(g.difficultyLevel)) {
                stateChemicalAttack(by: cands[Int((pickRoll ?? r) * 7919) % cands.count].id)
            }
        }
    }

    /// A chemical terror attack in the President's country (`home`) or another populous one.
    func chemicalTerrorAttack(home: Bool, pick: Double) {
        guard let gs = gameState else { return }
        let pool = gs.countries.filter { !$0.isDestroyed && !$0.isTerritory && $0.population >= 5 && $0.id != gs.playerCountryID }.sorted { $0.id < $1.id }
        guard let c = home ? gs.getPlayerCountry() : (pool.isEmpty ? nil : pool[Int(pick * 104_729) % pool.count]),
              let i = gs.countries.firstIndex(where: { $0.id == c.id }) else { return }
        gs.countries[i].stability = max(0, gs.countries[i].stability - 4)
        gs.countries[i].profile.anxieties.social += 10
        gs.totalCasualties += 20 + Int(pick * 80)
        gs.shadow.worldStats["chemical_terror", default: 0] += 1
        gs.shadow.post("A chemical attack on public transport in \(c.capital), \(c.name), kills and injures commuters. A group claims it.",
                       date: gs.currentDate, severity: home ? 3 : 2)
        if home { gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 3) }
        logPlayEvent("chemical_terror", detail: ["country": c.id, "home": home, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        crisisManager.presentCrisis(ChemicalThreats.terrorCard(c, home: home, in: gs))
    }

    /// A computer-run government uses chemical weapons on a rebel or minority region of its own country.
    func stateChemicalAttack(by actor: String) {
        guard let gs = gameState, actor != gs.playerCountryID, let i = gs.countries.firstIndex(where: { $0.id == actor }),
              !gs.countries[i].isPlayerControlled else { return }
        let c = gs.countries[i]
        let y = gs.currentYear
        gs.countries[i].profile.outcry = max(0, c.profile.outcry - 20)
        gs.totalCasualties += Int(Double(max(1, c.population)) * 150)
        let world = y >= 1997 ? 25 : (y >= 1945 ? 15 : 8)
        for o in gs.countries where o.id != actor && !o.isDestroyed && !o.isTerritory {
            modifyDiplomaticRelation(from: o.id, to: actor, by: -world)
        }
        if y >= 1997 { gs.countries[i].stability = max(0, gs.countries[i].stability - 5) }
        let text = "\(c.name)'s government attacks a rebel region of its own country with chemical weapons. Thousands of civilians are killed."
        let item = TickerItem(date: gs.currentDate, text: text, severity: 3)
        gs.shadow.ticker.append(item)
        gs.shadow.worldAtrocities.append(item)
        if gs.shadow.worldAtrocities.count > 40 { gs.shadow.worldAtrocities.removeFirst() }
        gs.shadow.worldStats["atrocities", default: 0] += 1
        gs.flash([actor], .hostile, "☣️ \(c.name) uses chemical weapons on its own people")
        logPlayEvent("state_chemical_attack", detail: ["actor": actor, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        crisisManager.presentCrisis(ChemicalThreats.stateCard(c, in: gs))
    }
}

// MARK: - Cards

extension ChemicalThreats {
    static func terrorCard(_ c: Country, home: Bool, in gs: GameState) -> CrisisEvent {
        func opt(_ title: String, _ desc: String, _ k: CrisisConsequences, _ choice: String? = nil) -> CrisisOption {
            var k = k
            k.shadowChoice = choice
            return CrisisOption(title: title, description: desc, consequences: k)
        }
        let allies = (gs.getPlayerCountry()?.alliances ?? []).sorted()
        let options: [CrisisOption] = home ? [
            opt("Emergency medical response", "Hospitals, decontamination teams and the Guard to the scene. $0.5B.",
                CrisisConsequences(approvalChange: 3, message: "Emergency teams treat the injured through the night."), "funds|0.5"),
            opt("Counterterrorism crackdown", "Raids on the group and its supporters. Order returns; some arrests will not stand up.",
                CrisisConsequences(approvalChange: 2, message: "Federal agents raid the group's premises nationwide.", countryStability: [c.id: 3]), "posture|0.5"),
            opt("Share intelligence with allies", "Pool what the services know about such groups.",
                CrisisConsequences(approvalChange: 1, message: "Allied services agree to share what they know.",
                                   mutualRelations: Dictionary(uniqueKeysWithValues: allies.map { ($0, 5) })), "posture|1"),
            opt("Expand surveillance powers", "Broad new powers. Safer, at a cost to civil liberties that voters will feel.",
                CrisisConsequences(approvalChange: -4, message: "Congress grants sweeping surveillance powers."), "posture|2"),
        ] : [
            opt("Send emergency medical teams", "Specialists and supplies to \(c.name). $0.3B.",
                CrisisConsequences(message: "American medical teams fly to \(c.name).", mutualRelations: [c.id: 10]), "funds|0.3"),
            opt("Offer intelligence sharing", "Help find the group and those like it.",
                CrisisConsequences(message: "Intelligence services begin sharing what they know.", mutualRelations: [c.id: 5]), "posture|1"),
            opt("A statement of condolence", "Words, and nothing else.", CrisisConsequences(message: "The President expresses the nation's condolences.")),
        ]
        return CrisisEvent(type: .terroristThreat, severity: home ? .critical : .serious, title: "CHEMICAL ATTACK IN \(c.capital.uppercased())",
                           description: "Commuters in \(c.capital) were attacked with chemical weapons in a crowded public space. Emergency services are overwhelmed. A group has claimed responsibility.",
                           affectedCountries: [c.id], turn: gs.turn, options: options)
    }

    static func stateCard(_ c: Country, in gs: GameState) -> CrisisEvent {
        let y = gs.currentYear
        var options: [CrisisOption] = [
            CrisisOption(title: "Condemn it", description: "A strong statement and a recalled ambassador.",
                         consequences: CrisisConsequences(approvalChange: 1, message: "The President condemns the attack.", mutualRelations: [c.id: -10])),
            CrisisOption(title: "Sanctions", description: "Cut trade and freeze assets.",
                         consequences: CrisisConsequences(approvalChange: 1, message: "Sanctions are imposed on \(c.name).", mutualRelations: [c.id: -25], countryEconomy: [c.id: -5])),
            {
                var k = CrisisConsequences(approvalChange: 2, message: "Aid and refugee resettlement are funded.")
                k.shadowChoice = "funds|1"
                return CrisisOption(title: "Aid and refugees", description: "Field hospitals and safe passage for survivors. $1B.", consequences: k)
            }(),
        ]
        if y >= 1991 {
            options.append(CrisisOption(title: "A protection mission", description: "A no-fly zone over the region, as over northern Iraq in 1991.",
                                        consequences: CrisisConsequences(approvalChange: 2, message: "Allied aircraft begin patrols over the region.",
                                                                         mutualRelations: [c.id: -40], countryMilitary: [c.id: -5])))
        }
        if y >= 1993 {
            options.append(CrisisOption(title: "Refer it to a war-crimes tribunal", description: "Build the case for international justice.",
                                        consequences: CrisisConsequences(approvalChange: 2, message: "The United States presses for an international tribunal.",
                                                                         mutualRelations: [c.id: -30], countryStability: [c.id: -5])))
        }
        var away = CrisisConsequences(approvalChange: -3, message: "Washington says little. \(c.name) remains a useful partner.", mutualRelations: [c.id: 10])
        away.shadowChoice = "ruthless|5"
        options.append(CrisisOption(title: "Look away", description: "Realpolitik, as in the Iran–Iraq war years: keep the relationship, lose the moral high ground.",
                                    consequences: away))
        return CrisisEvent(type: .regimeChange, severity: .critical, title: "CHEMICAL ATTACK ON CIVILIANS IN \(c.name.uppercased())",
                           description: "Survivors and journalists report that \(c.name)'s government has used chemical weapons against a rebel region of its own country. The dead are civilians.\(y >= 1997 ? " It is a breach of the Chemical Weapons Convention." : "")",
                           affectedCountries: [c.id], turn: gs.turn, options: options)
    }
}
