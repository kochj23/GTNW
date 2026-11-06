//
//  WorldWatch.swift
//  Global Thermal Nuclear War
//
//  3.20.0: the world's news reaches the President as decisions. Every turn the watch compares the world with the
//  last turn and turns what changed — a new war, a coup, an annexation, a liberation — into a crisis card with
//  immediate choices. World emergencies (hurricanes, earthquakes, epidemics, famines, blackouts, coups at sea…)
//  strike real nations of the era, each with the responses a head of state actually has: relief, airlift,
//  hospital ships, evacuation, sanctions, loans. Every card carries an epigraph (Quotations).
//  Created by Jordan Koch.
//

import Foundation

enum WorldWatch {

    // MARK: - Snapshot / diff

    struct Snapshot {
        /// "A|B" for every pair at war (sorted ids).
        var wars: Set<String>
        /// id -> "owner|government" for every nation not destroyed.
        var rule: [String: String]
    }

    static func snapshot(_ gs: GameState) -> Snapshot {
        var wars = Set<String>(), rule: [String: String] = [:]
        for c in gs.countries where !c.isDestroyed {
            rule[c.id] = "\(c.territoryOf ?? "")|\(c.government.rawValue)"
            for e in c.atWarWith { wars.insert(pairKey(c.id, e)) }
        }
        return Snapshot(wars: wars, rule: rule)
    }

    static func pairKey(_ a: String, _ b: String) -> String { a < b ? "\(a)|\(b)" : "\(b)|\(a)" }

    /// At most this many decisions per turn from wars and changes of power; the rest go to the ticker only.
    static let maxDecisionsPerTurn = 2

    /// What changed since `old`: decision cards (most important first) and ticker headlines for everything.
    static func changes(from old: Snapshot, to gs: GameState) -> (decisions: [CrisisEvent], headlines: [String]) {
        let now = snapshot(gs)
        var decisions: [(Int, CrisisEvent)] = [], headlines: [String] = []

        for key in now.wars.subtracting(old.wars).sorted() {
            let ids = key.split(separator: "|").map(String.init)
            guard ids.count == 2, let a = gs.getCountry(id: ids[0]), let b = gs.getCountry(id: ids[1]) else { continue }
            // The aggressor is whoever the war record says; otherwise the stronger side.
            let war = gs.activeWars.last { Set([$0.aggressor, $0.defender]) == Set(ids) }
            let (agg, def) = war.map { $0.aggressor == a.id ? (a, b) : (b, a) } ?? (a.militaryStrength >= b.militaryStrength ? (a, b) : (b, a))
            headlines.append("⚔️ WAR: \(agg.name) and \(def.name) are at war.")
            if let c = warCrisis(aggressor: agg, defender: def, gs: gs) {
                decisions.append(((agg.isPlayerControlled || def.isPlayerControlled) ? 0 : 2, c))
            }
        }

        for (id, rule) in now.rule.sorted(by: { $0.key < $1.key }) {
            guard let before = old.rule[id], before != rule, let c = gs.getCountry(id: id) else { continue }
            let (oldOwner, oldGov) = split(before), (newOwner, newGov) = split(rule)
            if c.isPlayerControlled { continue }                       // domestic endings handle the President's own nation
            if newOwner == gs.playerCountryID { continue }                // the President annexed it and knows
            if oldOwner == newOwner && !newOwner.isEmpty { continue }     // a territory's government follows its owner
            if newOwner.isEmpty == false, oldOwner != newOwner, let owner = gs.getCountry(id: newOwner) {
                headlines.append("🏴 \(c.name) has fallen under the control of \(owner.name).")
                decisions.append((1, annexationCrisis(country: c, owner: owner, gs: gs)))
            } else if newOwner.isEmpty, !oldOwner.isEmpty {
                headlines.append("🕊️ \(c.name) has regained its independence.")
                decisions.append((3, liberationCrisis(country: c, formerOwner: gs.getCountry(id: oldOwner), gs: gs)))
            } else if oldGov != newGov {
                headlines.append("⚖️ Change of power in \(c.name): \(oldGov) → \(newGov).")
                decisions.append((c.profile.strategicValue > 60 ? 1 : 3, regimeCrisis(country: c, from: oldGov, to: newGov, gs: gs)))
            }
        }
        let ranked = decisions.sorted { $0.0 < $1.0 }.prefix(maxDecisionsPerTurn).map(\.1)
        return (Array(ranked), headlines)
    }

    private static func split(_ rule: String) -> (String, String) {
        let p = rule.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        return (p.first ?? "", p.count > 1 ? p[1] : "")
    }

    /// A queued decision the world has overtaken is dropped instead of shown.
    static func stillRelevant(_ c: CrisisEvent, in gs: GameState) -> Bool {
        switch c.type {
        case .warOutbreak:
            guard c.affectedCountries.count >= 2,
                  let a = gs.getCountry(id: c.affectedCountries[0]) else { return false }
            return a.atWarWith.contains(c.affectedCountries[1])
        default:
            return c.affectedCountries.allSatisfy { id in gs.getCountry(id: id).map { !$0.isDestroyed } ?? false }
        }
    }

    // MARK: - Helpers

    private static func relation(_ gs: GameState, _ id: String) -> Int {
        gs.getCountry(id: gs.playerCountryID)?.diplomaticRelations[id] ?? 0
    }
    private static func isAlly(_ gs: GameState, _ id: String) -> Bool {
        gs.getCountry(id: gs.playerCountryID)?.alliances.contains(id) ?? false
    }
    /// Era money: the standard diplomacy amount (in $B, the unit crisis consequences spend).
    static func aidBillions(_ gs: GameState, scale: Double) -> Int {
        max(1, Int((Double(gs.eraDiplomacyAmount) / 1_000_000_000 * scale).rounded()))
    }
    private static func money(_ gs: GameState, _ scale: Double) -> String {
        let amount = Double(gs.eraDiplomacyAmount) * scale
        if amount >= 1_000_000_000 { return "$\(Int((amount / 1_000_000_000).rounded()))B" }
        if amount >= 1_000_000 { return "$\(Int((amount / 1_000_000).rounded()))M" }
        return "$\(Int((amount / 1_000).rounded()))K"
    }

    // MARK: - War

    static func warCrisis(aggressor a: Country, defender d: Country, gs: GameState) -> CrisisEvent? {
        let me = gs.playerCountryID
        if a.id == me { return nil }                                     // the President started it and knows
        if d.id == me {
            let allies = gs.getCountry(id: me)?.alliances.filter { gs.getCountry(id: $0)?.isDestroyed == false } ?? []
            return CrisisEvent(
                type: .warOutbreak, severity: .critical,
                title: "⚔️ \(a.name.uppercased()) HAS ATTACKED US",
                description: "\(a.flag) \(a.name) has gone to war against us. The nation looks to its President. The cabinet is assembled; the choices are yours.",
                affectedCountries: [a.id, d.id], turn: gs.turn, timeLimit: nil,
                options: [
                    CrisisOption(title: "Rally our allies", description: "Invoke every treaty; ask for troops, money and bases",
                                 advisorRecommendation: "Secretary of State",
                                 consequences: CrisisConsequences(approvalChange: 4, message: "Allied capitals answer the call. The nation is not alone.",
                                                                  mutualRelations: Dictionary(uniqueKeysWithValues: allies.map { ($0, 10) }))),
                    CrisisOption(title: "Full mobilization", description: "Call up the reserves and put industry on a war footing",
                                 advisorRecommendation: "Secretary of Defense",
                                 consequences: CrisisConsequences(approvalChange: 5, economicImpact: -aidBillions(gs, scale: 1), militaryImpact: 6,
                                                                  message: "The country rallies around the flag. Factories retool overnight.")),
                    CrisisOption(title: "Seek a UN-brokered ceasefire", description: "Take it to the Security Council before the shooting spreads",
                                 consequences: CrisisConsequences(approvalChange: -3, message: "The guns fall silent — for now.",
                                                                  ceasefireBetween: [a.id, d.id]), successChance: 0.35),
                    CrisisOption(title: "Fight on as planned", description: "The War Room has the plans; let the generals work",
                                 consequences: CrisisConsequences(message: "The war goes on.")),
                ])
        }
        var options: [CrisisOption] = [
            CrisisOption(title: "Condemn \(a.name) and impose sanctions", description: "Freeze assets, cut trade, rally the world against the aggressor",
                         advisorRecommendation: "Secretary of State",
                         consequences: CrisisConsequences(approvalChange: 1, message: "Sanctions bite. \(a.name) protests; \(d.name) is grateful.",
                                                          mutualRelations: [a.id: -15, d.id: 5], countryEconomy: [a.id: -4])),
            CrisisOption(title: "Arm \(d.name) (\(money(gs, 0.6)) in weapons)", description: "Lend-lease: rifles, artillery, air defense — but no troops",
                         advisorRecommendation: "Secretary of Defense",
                         consequences: CrisisConsequences(economicImpact: -aidBillions(gs, scale: 0.6),
                                                          message: "Weapons reach the front. \(d.name) fights on; \(a.name) is furious.",
                                                          mutualRelations: [d.id: 15, a.id: -25], countryMilitary: [d.id: 8])),
            CrisisOption(title: "Broker a ceasefire", description: "Send the Secretary of State to both capitals",
                         consequences: CrisisConsequences(approvalChange: 3, message: "A ceasefire holds. The world credits American diplomacy.",
                                                          mutualRelations: [a.id: 3, d.id: 3], ceasefireBetween: [a.id, d.id]), successChance: 0.45),
        ]
        if isAlly(gs, d.id) || relation(gs, d.id) >= 60 {
            options.append(CrisisOption(title: "Go to war alongside \(d.name)", description: "Honor the commitment — American forces join the fight",
                                        consequences: CrisisConsequences(approvalChange: -2, defconChange: -1,
                                                                         message: "We are at war with \(a.name).",
                                                                         mutualRelations: [d.id: 25], joinWarAgainst: a.id)))
        }
        if isAlly(gs, a.id) || relation(gs, a.id) >= 60 {
            options.append(CrisisOption(title: "Back our partner \(a.name)", description: "Quiet support: intelligence, spare parts, a veto at the UN",
                                        consequences: CrisisConsequences(approvalChange: -2, message: "\(a.name) knows who its friends are. Much of the world does not approve.",
                                                                         mutualRelations: [a.id: 15, d.id: -25], countryMilitary: [a.id: 5])))
        }
        options.append(CrisisOption(title: "Stay out of it", description: "Not our war",
                                    consequences: CrisisConsequences(message: "We watch from a distance. \(d.name) remembers who did not come.",
                                                                     mutualRelations: [d.id: -5])))
        return CrisisEvent(type: .warOutbreak, severity: (a.nuclearWarheads > 0 || d.nuclearWarheads > 0) ? .critical : .serious,
                           title: "⚔️ WAR: \(a.name.uppercased()) ATTACKS \(d.name.uppercased())",
                           description: "\(a.flag) \(a.name) has gone to war against \(d.flag) \(d.name)." +
                               ((a.nuclearWarheads > 0 || d.nuclearWarheads > 0) ? " A nuclear power is involved; the world holds its breath." : "") +
                               " The world is waiting to see what the United States will do.",
                           affectedCountries: [a.id, d.id], turn: gs.turn, timeLimit: nil, options: options)
    }

    // MARK: - Changes of power

    static func annexationCrisis(country c: Country, owner o: Country, gs: GameState) -> CrisisEvent {
        CrisisEvent(type: .regimeChange, severity: .serious,
                    title: "🏴 \(c.name.uppercased()) FALLS TO \(o.name.uppercased())",
                    description: "\(c.flag) \(c.name) is now under the control of \(o.flag) \(o.name). Its government is gone; its people are not. Recognize the new order — or don't.",
                    affectedCountries: [c.id, o.id], turn: gs.turn, timeLimit: nil,
                    options: [
                        CrisisOption(title: "Refuse to recognize the annexation", description: "A formal non-recognition doctrine; the embassy-in-exile stays open",
                                     advisorRecommendation: "Secretary of State",
                                     consequences: CrisisConsequences(approvalChange: 1, message: "Washington will not recognize the seizure of \(c.name).",
                                                                      mutualRelations: [o.id: -10])),
                        CrisisOption(title: "Sanction \(o.name)", description: "Make the occupation expensive",
                                     consequences: CrisisConsequences(message: "Sanctions follow. \(o.name) calls it interference.",
                                                                      mutualRelations: [o.id: -20], countryEconomy: [o.id: -4])),
                        CrisisOption(title: "Arm the resistance (\(money(gs, 0.4)))", description: "Covertly supply those still fighting",
                                     advisorRecommendation: "Director of Central Intelligence",
                                     consequences: CrisisConsequences(economicImpact: -aidBillions(gs, scale: 0.4),
                                                                      message: "Crates arrive by night. The occupation is not secure.",
                                                                      mutualRelations: [o.id: -25], countryStability: [c.id: -10]), successChance: 0.7),
                        CrisisOption(title: "Accept the fait accompli", description: "Realpolitik: the map has changed",
                                     consequences: CrisisConsequences(approvalChange: -1, message: "We accept the new borders. \(o.name) takes note.",
                                                                      mutualRelations: [o.id: 5])),
                    ])
    }

    static func liberationCrisis(country c: Country, formerOwner: Country?, gs: GameState) -> CrisisEvent {
        var withhold: [String: Int] = [c.id: -10]
        if let f = formerOwner { withhold[f.id] = 5 }
        return CrisisEvent(type: .regimeChange, severity: .moderate,
                           title: "🕊️ \(c.name.uppercased()) IS FREE",
                           description: "\(c.flag) \(c.name) has thrown off \(formerOwner.map { "the rule of \($0.name)" } ?? "foreign rule") and declared independence. The new government asks for recognition and help.",
                           affectedCountries: [c.id], turn: gs.turn, timeLimit: nil,
                           options: [
                            CrisisOption(title: "Recognize and send aid (\(money(gs, 0.4)))", description: "First to recognize; reconstruction money and advisers",
                                         advisorRecommendation: "Secretary of State",
                                         consequences: CrisisConsequences(approvalChange: 2, economicImpact: -aidBillions(gs, scale: 0.4),
                                                                          message: "The new nation will remember who came first.",
                                                                          mutualRelations: [c.id: 20], countryStability: [c.id: 5])),
                            CrisisOption(title: "Recognize the new government", description: "Open an embassy; nothing more yet",
                                         consequences: CrisisConsequences(message: "Recognition granted.", mutualRelations: [c.id: 10])),
                            CrisisOption(title: "Withhold recognition", description: "Don't anger \(formerOwner?.name ?? "the former power")",
                                         consequences: CrisisConsequences(message: "We wait and see.", mutualRelations: withhold)),
                           ])
    }

    static func regimeCrisis(country c: Country, from old: String, to new: String, gs: GameState) -> CrisisEvent {
        CrisisEvent(type: .regimeChange, severity: c.profile.strategicValue > 60 ? .serious : .moderate,
                    title: "⚖️ NEW REGIME IN \(c.name.uppercased())",
                    description: "\(c.flag) \(c.name) has a new government: the \(old.lowercased()) has given way to a \(new.lowercased()). Its ambassador is waiting in the State Department lobby.",
                    affectedCountries: [c.id], turn: gs.turn, timeLimit: nil,
                    options: [
                        CrisisOption(title: "Recognize the new government", description: "Business as usual",
                                     consequences: CrisisConsequences(message: "Relations continue.", mutualRelations: [c.id: 10])),
                        CrisisOption(title: "Recognize it and offer aid (\(money(gs, 0.3)))", description: "Buy goodwill early",
                                     advisorRecommendation: "Secretary of State",
                                     consequences: CrisisConsequences(economicImpact: -aidBillions(gs, scale: 0.3),
                                                                      message: "The new leaders are grateful — for now.",
                                                                      mutualRelations: [c.id: 20], countryStability: [c.id: 8])),
                        CrisisOption(title: "Withhold recognition", description: "Demand elections and the rule of law first",
                                     consequences: CrisisConsequences(approvalChange: 1, message: "Washington withholds recognition.",
                                                                      mutualRelations: [c.id: -10])),
                        CrisisOption(title: "Back the opposition covertly", description: "Money and radios to those who would overturn it",
                                     advisorRecommendation: "Director of Central Intelligence",
                                     consequences: CrisisConsequences(message: "The new regime is shaky — and suspects us.",
                                                                      mutualRelations: [c.id: -20], countryStability: [c.id: -12]), successChance: 0.6),
                    ])
    }

    // MARK: - World emergencies

    /// How a head of state can respond to an emergency abroad.
    enum Response: String, CaseIterable {
        case relief        // money, supplies, rescue teams
        case military      // airlift, hospital ship, engineers
        case health        // vaccines, CDC teams, field hospitals
        case refugees      // asylum, camps, resettlement
        case technical     // experts: nuclear, dam, cyber, grid
        case evacuation    // get Americans (and others) out
        case security      // naval escort, special forces, counter-terror
        case economic      // loans, IMF backing, debt relief
    }

    struct Emergency {
        let kind: String           // e.g. "Hurricane"
        let emoji: String
        let headline: String       // "{C}" = country name
        let detail: String
        let severity: CrisisSeverity
        let hotspots: [String]     // ISO3 ids; empty = anywhere
        let responses: [Response]
        let tags: Set<QuoteTag>
        let earliestYear: Int      // e.g. cyberattacks need computers
        init(_ kind: String, _ emoji: String, _ headline: String, _ detail: String, _ severity: CrisisSeverity,
             _ hotspots: [String], _ responses: [Response], _ tags: Set<QuoteTag> = [.disaster, .mercy], since: Int = 0) {
            self.kind = kind; self.emoji = emoji; self.headline = headline; self.detail = detail; self.severity = severity
            self.hotspots = hotspots; self.responses = responses; self.tags = tags; self.earliestYear = since
        }
    }

    /// About how many emergencies strike other nations in a game year. (3.21.1: 10 was several a month once wars,
    /// coups and random crises were added on top — far too many.)
    static let emergenciesPerYear = 4.0
    /// At most this many per turn, however long the turn.
    static let maxEmergenciesPerTurn = 1
    /// When this many decisions are already waiting, a new emergency is news on the ticker, not another card.
    static let busyDesk = 2

    static func disasterCrisis(gameState gs: GameState, roll: () -> Double = { Double.random(in: 0..<1) }) -> CrisisEvent? {
        let year = gs.currentYear
        let live = gs.liveCountries.filter { !$0.isPlayerControlled }
        let ids = Set(live.map(\.id))
        let eligible = EmergencyCatalog.all.filter { $0.earliestYear <= year && ($0.hotspots.isEmpty || !ids.isDisjoint(with: $0.hotspots)) }
        guard !eligible.isEmpty else { return nil }
        let e = eligible[min(eligible.count - 1, Int(roll() * Double(eligible.count)))]
        let pool = e.hotspots.isEmpty ? live : live.filter { e.hotspots.contains($0.id) }
        guard !pool.isEmpty else { return nil }
        let c = pool[min(pool.count - 1, Int(roll() * Double(pool.count)))]
        return emergencyCrisis(e, in: c, gs: gs)
    }

    static func emergencyCrisis(_ e: Emergency, in c: Country, gs: GameState) -> CrisisEvent {
        let hostile = relation(gs, c.id) <= -40 || c.atWarWith.contains(gs.playerCountryID)
        let big = Double(e.severity.rawValue) / 3       // 0.33 … 1.67 × the era's standard aid package
        var options: [CrisisOption] = []
        for r in e.responses {
            switch r {
            case .relief:
                options.append(CrisisOption(
                    title: "Send a major relief package (\(money(gs, big)))", description: "Cash, food, water, tents and search-and-rescue teams",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(approvalChange: hostile ? -2 : 2, economicImpact: -aidBillions(gs, scale: big),
                        message: hostile ? "Aid to an adversary is unpopular at home — but in \(c.name), people saw the American flag on the crates."
                                         : "American aid arrives within days. \(c.name) will not forget.",
                        mutualRelations: [c.id: hostile ? 25 : 18], countryStability: [c.id: 6])))
            case .military:
                options.append(CrisisOption(
                    title: gs.currentYear >= 1950 ? "Dispatch the military: airlift and a hospital ship" : "Send the Navy with surgeons and engineers",
                    description: gs.currentYear >= 1950 ? "Transport planes, helicopters, engineers and a hospital ship" : "Warships loaded with food, medicine and work crews",
                    advisorRecommendation: "Secretary of Defense",
                    consequences: CrisisConsequences(approvalChange: 2, economicImpact: -aidBillions(gs, scale: big / 2), militaryImpact: -1,
                        message: "Navy helicopters fly rescue missions over \(c.name). It is the best of what a military can do.",
                        mutualRelations: [c.id: 22], countryStability: [c.id: 8])))
            case .health:
                options.append(CrisisOption(
                    title: "Send medical teams and supplies (\(money(gs, big / 2)))",
                    description: gs.currentYear >= 1950 ? "Epidemiologists, field hospitals and vaccine shipments" : "Doctors, nurses, quinine and disinfectant",
                    advisorRecommendation: "Secretary of Health",
                    consequences: CrisisConsequences(approvalChange: 1, economicImpact: -aidBillions(gs, scale: big / 2),
                        message: "The outbreak is contained faster than the models feared.",
                        mutualRelations: [c.id: 15], countryStability: [c.id: 5])))
            case .refugees:
                options.append(CrisisOption(
                    title: "Take in refugees and fund the camps", description: "Emergency visas and UNHCR money",
                    consequences: CrisisConsequences(approvalChange: -2, economicImpact: -aidBillions(gs, scale: big / 2),
                        message: "Families reach safety. Some at home grumble about the cost.",
                        mutualRelations: [c.id: 15], countryStability: [c.id: 4])))
            case .technical:
                options.append(CrisisOption(
                    title: "Send a technical team", description: "Engineers and specialists who know exactly this failure",
                    consequences: CrisisConsequences(economicImpact: -aidBillions(gs, scale: 0.2),
                        message: "Quiet expertise prevents a second disaster.", mutualRelations: [c.id: 10], countryStability: [c.id: 4]),
                    successChance: 0.8))
            case .evacuation:
                options.append(CrisisOption(
                    title: "Evacuate American citizens",
                    description: gs.currentYear >= 1950 ? "Charter flights and a Marine security detail for the embassy" : "A warship to take them off, Marines to guard the legation",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(approvalChange: 3, economicImpact: -aidBillions(gs, scale: 0.1),
                        message: "Every American who wanted out is out.")))
            case .security:
                options.append(CrisisOption(
                    title: "Send forces to restore security", description: "Naval escorts, special forces, intelligence sharing",
                    advisorRecommendation: "Secretary of Defense",
                    consequences: CrisisConsequences(approvalChange: 1, defconChange: 0, militaryImpact: -1,
                        message: "American forces stabilize the situation — and are now part of it.",
                        mutualRelations: [c.id: 12], countryStability: [c.id: 10]), successChance: 0.75))
            case .economic:
                options.append(CrisisOption(
                    title: gs.currentYear >= 1946 ? "Back an emergency IMF loan" : "Arrange an emergency loan",
                    description: "A bridge loan with reforms attached",
                    advisorRecommendation: "Secretary of the Treasury",
                    consequences: CrisisConsequences(economicImpact: -aidBillions(gs, scale: big / 3),
                        message: "Markets steady. \(c.name) swallows the conditions.",
                        mutualRelations: [c.id: 10], countryStability: [c.id: 6], countryEconomy: [c.id: 5])))
            }
        }
        options.append(CrisisOption(
            title: "Send condolences only", description: "A statement from the Rose Garden",
            consequences: CrisisConsequences(approvalChange: hostile ? 0 : -1, message: "Thoughts and prayers. \(c.name) notices what did not come.",
                                             mutualRelations: [c.id: hostile ? 0 : -4])))
        if hostile {
            options.append(CrisisOption(
                title: "Exploit the chaos", description: "Their weakness is our opportunity",
                advisorRecommendation: "Director of Central Intelligence",
                consequences: CrisisConsequences(approvalChange: -3, message: "We press our advantage. The world calls it heartless.",
                                                 mutualRelations: [c.id: -20], countryStability: [c.id: -10])))
        }
        let headline = e.headline.replacingOccurrences(of: "{C}", with: c.name.uppercased())
        var crisis = CrisisEvent(type: .worldDisaster, severity: e.severity,
                           title: "\(e.emoji) \(headline)",
                           description: "\(c.flag) \(e.detail.replacingOccurrences(of: "{C}", with: c.name))\n\n\(c.name) is asking the world for help. What will the United States do?",
                           affectedCountries: [c.id], turn: gs.turn, timeLimit: nil, options: options)
        crisis.quoteTags = e.tags
        return crisis
    }
}
