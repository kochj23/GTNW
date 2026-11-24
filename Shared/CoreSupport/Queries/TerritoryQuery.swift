//
//  TerritoryQuery.swift
//  GTNWCore
//
//  `{"q":"territory","id":"USA_AK","troops":5}`: what the President can do with one piece of land, from the app's
//  CountryDossier land sections and GovernSheet: claim unclaimed land, take or buy a colony, back its independence,
//  seize another power's territory, develop an island, govern a territory (garrison, government, statehood) and
//  rename it. `troops` is the expedition size in thousands (default the 5K standard).
//

#if GTNW_CORE
import Foundation

enum TerritoryQuery: BridgeQuery {
    static let name = "territory"

    struct Args: Decodable {
        var id: String
        var troops: Double?
    }

    /// Take it: an unclaimed land, a people's land, a colony or another power's territory.
    struct Take: Encodable {
        /// claim (unclaimed land), plant (an empty island), peoples (take by force), colony (seize), territory (seize)
        var kind: String
        var label: String
        var odds: Double?
        var troops: Double
        var freeTroops: Double
        var step: Double
        var problem: String?
        var notes: [String]
        var warnings: [Warning]
    }

    struct Deal: Encodable {
        var buyLabel: String
        var buyOdds: Double
        var price: Double
        var refuses: String?
        var independenceLabel: String
        var independenceOdds: Double
    }

    struct Warning: Encodable {
        var who: String
        var text: String
        var level: Int
    }

    struct Project: Encodable {
        var id: String
        var title: String
        var blurb: String
        var cost: Double
        var built: Bool
        var available: Bool
        var problem: String?
    }

    struct Govern: Encodable {
        var admitted: String?
        var insurgency: Double
        var stability: Int
        var income: Double
        var garrison: Double
        var needed: Double
        var freeTroops: Double
        var governance: String
        var governments: [[String: String]]
        var statehoodUSA: Bool
        var statehoodProblems: [String]
        var statehoodLine: String
    }

    struct Result: Encodable {
        var id: String
        var name: String
        var flag: String
        /// unclaimed, peoples, colony, territory (another power's), mine (the player's territory), nation, none
        var kind: String
        var badge: String
        var description: [String]
        var take: Take?
        var deal: Deal?
        var yieldLine: String?
        var islandTitle: String?
        var projects: [Project]
        var govern: Govern?
        var canRename: Bool
        var titleWord: String
        var actionsRemaining: Int
        var fleetOrders: Bool
        /// 3.36.0: when the land develops and what it will pay ("develops in N months…"), or that it pays nothing.
        var developNote: String? = nil
        /// 3.36.0: the INVEST order on the player's own land: its cost, and why not (nil = it can be given).
        var investCost: Double? = nil
        var investProblem: String? = nil
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let id = args.id
        let me = gs.getPlayerCountry()
        let free = AttackSizing.freeTroops(gs)
        let troops = max(1, args.troops ?? AttackSizing.expeditionStandard)
        let titleWord = CombatModel.territoryTitle(ownerID: me?.id ?? "USA", ownerName: me?.name ?? "")
        let fleet = gs.playerCountryID == "USA" && !NavalModel.isLandlocked(id) && !NavalModel.fleets(in: gs.currentYear).isEmpty
        func shortTroops(_ need: Double) -> String? {
            guard need > free else { return nil }
            return free < 1 ? "No free troops: every soldier is on a front or a garrison." : "Only \(Int(free))K free: lower the expedition."
        }
        var out = Result(id: id, name: id, flag: "🏳", kind: "none", badge: "", description: [], take: nil, deal: nil, yieldLine: nil,
                         islandTitle: nil, projects: [], govern: nil, canRename: false, titleWord: titleWord,
                         actionsRemaining: gs.actionsRemaining, fleetOrders: false)

        if let c = gs.getCountry(id: id) {
            out.name = c.name
            out.flag = c.flag
            out.kind = "nation"
            guard let owner = c.territoryOf else { return out }
            out.badge = gs.territoryLabel(c)
            out.yieldLine = String(format: "LAND $%.2fB/YR · %@", ExpansionModel.landYield(c, in: gs),
                                   ExpansionModel.landResources(c.id, year: gs.currentYear).map(\.rawValue).joined(separator: ", ").uppercased())
            if owner == gs.playerCountryID {
                out.developNote = LandDevelopment.note(c, in: gs)
                if LandDevelopment.canDevelop(c.id, in: gs) {
                    out.investCost = QueryText.round2(LandDevelopment.investCost(c, in: gs))
                    out.investProblem = LandDevelopment.problem(c.id, in: gs)
                }
                out.kind = "mine"
                out.canRename = !c.isDestroyed
                if Islands.byID[c.id] != nil {
                    out.islandTitle = Islands.uninhabited(c.id) ? "DEVELOP · only our people live here, so it will not revolt" : "DEVELOP"
                    let built = gs.shadow.islandProjects[c.id, default: []]
                    out.projects = IslandProject.allCases.map { p in
                        Project(id: p.rawValue, title: p.title, blurb: p.blurb, cost: p.cost, built: built.contains(p),
                                available: gs.currentYear >= p.from, problem: built.contains(p) ? nil : e.islandProjectProblem(p, on: c.id))
                    }
                }
                out.govern = govern(c, gs: gs, free: free)
            } else if let col = e.colonyTarget(c.id), let me {
                out.kind = "territory"
                let defenders = PreStateModel.garrison(owner: col.owner)
                let odds = PreStateModel.seizeOdds(troops: troops, attackerStrength: me.militaryStrength, defenders: max(0.5, defenders),
                                                   defenderStrength: col.owner.militaryStrength)
                out.description = ["Held by \(col.owner.name). Seizing it means war with \(col.owner.name)."]
                out.take = Take(kind: "territory", label: "SEIZE BY FORCE (\(Int(odds * 100))%)", odds: QueryText.round2(odds), troops: troops,
                                freeTroops: free, step: 5, problem: shortTroops(troops), notes: [], warnings: [])
                out.deal = deal(c.id, col, me: me, gs: gs)
            }
            out.fleetOrders = false
            return out
        }

        if let st = gs.preState(id) {
            let owner = gs.getCountry(id: st.era.owner)
            let tpl = PreStateModel.template(id)
            let island = Islands.byID[id] != nil, empty = Islands.uninhabited(id)
            out.name = st.label
            out.flag = st.era.kind == .colony ? (owner?.flag ?? "🏳") : "🏳"
            out.badge = st.era.kind == .colony ? (island ? "ISLAND" : "COLONY") : (island ? (empty ? "UNINHABITED · UNCLAIMED" : "UNCLAIMED ISLAND") : "PEOPLES NOT MODELLED AS A STATE")
            out.description = ["Today: \(tpl?.name ?? id)"]
            out.fleetOrders = fleet
            if st.era.kind == .colony, let owner {
                out.kind = "colony"
                out.description.append("Held by \(owner.name) since \(st.era.from == 1789 ? "before 1789" : String(st.era.from))"
                    + (st.era.extra >= 9999 ? ". Seizing it means war with \(owner.name)." : "; historically independent or transferred \(st.era.extra)."))
            } else if empty {
                out.kind = "peoples"
                out.description.append("Nobody lives here and no nation has claimed it. An expedition simply plants the flag: no resistance, and no uprising later, because the only people on it will be ours. Once it is yours, develop it: airstrip, naval station, military base, farms, fishery, radar.")
            } else {
                out.kind = "peoples"
                out.description.append("Home to its own peoples and rulers, whom the game does not model as a state. They will resist (strength \(st.era.extra)); taking their land brings unrest and, after 1945, condemnation.")
            }
            if let me {
                let defenders = st.era.kind == .colony ? owner.map(PreStateModel.garrison) ?? 1 : PreStateModel.resistanceTroops(st.era.extra)
                let odds = PreStateModel.seizeOdds(troops: troops, attackerStrength: me.militaryStrength, defenders: max(0.5, defenders),
                                                   defenderStrength: owner?.militaryStrength ?? 30)
                out.take = Take(kind: st.era.kind == .colony ? "colony" : (empty ? "plant" : "peoples"),
                                label: st.era.kind == .colony ? "SEIZE BY FORCE (\(Int(odds * 100))%)" : empty ? "PLANT THE FLAG" : "TAKE BY FORCE (\(Int(odds * 100))%)",
                                odds: QueryText.round2(odds), troops: troops, freeTroops: free, step: 5, problem: shortTroops(troops), notes: [], warnings: [])
                if st.era.kind == .colony, let col = e.colonyTarget(id) { out.deal = deal(id, col, me: me, gs: gs) }
            }
            return out
        }

        guard gs.unclaimedLandIDs.contains(id) else { return out }
        let land = WorldCountriesDatabase.template(id: id)
        out.kind = "unclaimed"
        out.name = land?.name ?? id
        out.badge = "UNCLAIMED"
        out.fleetOrders = fleet
        out.description = [id == Antarctica.id ? "Antarctica" : (land?.region.rawValue ?? ""), "Unclaimed land — no government, no army."]
        var notes: [String] = []
        if id == Antarctica.id {
            let claims = Antarctica.claims(by: gs.currentYear)
            notes.append(claims.isEmpty ? "No nation has claimed it yet." : "Overlapping claims, none sovereign: " + claims.joined(separator: ", ") + ".")
            notes.append("Pays no money once whaling ends unless developed: science brings prestige, not income.")   // 3.36.0
            if let line = Antarctica.statusLine(gs) { notes.append(line) }   // 3.36.0: the President's treaty standing
            notes += Antarctica.programLines(gs)
        }
        notes.append("An expedition takes it at once as a \(me.map { $0.id == "USA" ? "U.S." : $0.name } ?? "U.S.") territory. "
                     + "Costs one action and some goodwill abroad: rivals about 5, others about 2, more in a spree or after 1945.")
        let nth = ExpansionModel.takenLastYear(gs, before: gs.currentDate) + 1
        let politics = ExpansionModel.politics(year: gs.currentYear, nth: nth)
        notes.append(String(format: "Claim #%d this year: approval %+.1f, outrage +%.1f. Yields: %@.", nth, politics.popularity, politics.ruthlessness,
                            ExpansionModel.deposits(for: id, year: gs.currentYear).map(\.kind.title).joined(separator: ", ")))
        if e.pressureAfterNextClaim() > ExpansionModel.impeachmentThreshold {
            notes.append("CHIEF OF STAFF: \u{201C}One more and Congress moves against you at the next poll. Let the country cool off.\u{201D}")
        }
        let warnings = AdvisorWarnings.enabled() ? e.advisorWarnings(for: .claim(land: id, troops: troops)).map { Warning(who: $0.who, text: $0.text, level: $0.level) } : []
        out.take = Take(kind: "claim", label: "SEND EXPEDITION", odds: nil, troops: troops, freeTroops: free, step: 1, problem: nil, notes: notes, warnings: warnings)
        return out
    }

    /// Buy a colony or back its independence (CountryDossier.colonyDeals).
    static func deal(_ id: String, _ col: GameEngine.ColonyTarget, me: Country, gs: GameState) -> Deal {
        let rel = col.owner.diplomaticRelations[me.id] ?? 0
        let price = PreStateModel.price(id, year: gs.currentYear, relation: rel)
        let atWar = col.owner.atWarWith.contains(me.id)
        let sale = PreStateModel.saleOdds(relation: rel, atWar: atWar, historical: false)
        let revolt = PreStateModel.revoltOdds(year: gs.currentYear, independence: col.independence, ownerAtWarWithPlayer: atWar,
                                              ownerStability: col.owner.stability)
        return Deal(buyLabel: String(format: "OFFER TO BUY: $%.1fB (%d%%)", price, Int(sale * 100)), buyOdds: QueryText.round2(sale),
                    price: QueryText.round2(price), refuses: sale == 0 ? "\(col.owner.name) won't sell while we are at war." : nil,
                    independenceLabel: "BACK INDEPENDENCE ($2B, \(Int(revolt * 100))%)", independenceOdds: QueryText.round2(revolt))
    }

    /// GovernSheet.
    static func govern(_ c: Country, gs: GameState, free: Double) -> Govern {
        let policy = gs.shadow.territoryPolicies[c.id]
        let needed = OccupationModel.neededGarrison(c)
        let garrison = gs.shadow.garrisons[c.id] ?? needed
        let admitted = gs.shadow.statesAdmitted.first { $0.id == c.id }
        let problems = OccupationModel.statehoodProblems(c: c, policy: policy, heldSince: gs.shadow.claimDates[c.id], now: gs.currentDate)
        let yes = OccupationModel.statehoodYes(congress: gs.getPlayerCountry()?.congressionalSupport ?? 50, stability: c.stability)
        let line = problems.isEmpty
            ? String(format: "Ready. Congress's odds %.0f%%. It would be the %@ state.", CongressModel.passOdds(expectedYes: yes) * 100,
                     OccupationModel.ordinal(OccupationModel.historicalStates(year: gs.currentYear) + gs.shadow.statesAdmitted.count + 1))
            : "Not yet: " + problems.joined(separator: "; ") + "."
        return Govern(admitted: admitted.map { "Admitted \(GameCalendar.format($0.date)) as the \(OccupationModel.ordinal($0.number)) state." },
                      insurgency: QueryText.round2(c.profile.outcry), stability: c.stability,
                      income: QueryText.round2(ExpansionModel.annualIncome(c, in: gs)), garrison: garrison, needed: QueryText.round2(needed),
                      freeTroops: free, governance: (policy?.governance ?? .militaryGovernor).rawValue,
                      governments: TerritoryGovernance.allCases.map { ["id": $0.rawValue, "title": $0.title] },
                      statehoodUSA: gs.playerCountryID == "USA", statehoodProblems: problems, statehoodLine: line)
    }
}
#endif
