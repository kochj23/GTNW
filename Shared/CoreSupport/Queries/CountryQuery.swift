//
//  CountryQuery.swift
//  GTNWCore
//
//  `{"q":"country","id":"FRA"}`: the dossier for one map selection (the app's CountryDossier): a nation in the game,
//  a colony or indigenous land (pre-state), or unclaimed land. Foreign forces come as the National Intelligence
//  Estimate the President sees (a range until the era's collection is good), never the true figure.
//

#if GTNW_CORE
import Foundation

enum CountryQuery: BridgeQuery {
    static let name = "country"

    struct Args: Decodable { var id: String }

    struct Estimate: Encodable { var text: String; var tag: String }

    struct Nation: Encodable {
        var id: String
        var name: String
        var flag: String
        var region: String
        var capital: String
        var government: String
        var alignment: String
        var ideology: String
        var leader: String?
        var isPlayer: Bool
        var destroyed: Bool
        /// "U.S. TERRITORY" etc. when the land belongs to another nation in the game.
        var territoryOf: String?
        var territoryLabel: String?
        var relationToPlayer: Int?
        var ambition: Int
        var ambitionName: String
        var ethic: Int
        var ethicName: String
        var leadership: Double
        var qualityOfLife: Double
        var influence: Int
        var unrest: Double
        var stability: Int
        var approval: Int
        var gdp: Double
        var population: Int
        /// Foreign forces: the estimate. The player's own: exact ("CONFIRMED").
        var military: Estimate
        var warheads: Estimate?
        var nuclearStatus: String
        var anxieties: [String: Double]
        var aidNeed: [String: Double]
        var aidNeedTotal: Double
        var atWarWith: [String]
        var allies: [String]
        var intel: String?
        var corruption: Int
        var pressFreedom: Int
        var literacy: Int
        var landlocked: Bool
    }

    struct Land: Encodable {
        var id: String
        var name: String
        /// colony, indigenous, unclaimed
        var kind: String
        /// "Kingdom of Hawaii" or "Puerto Rico (Spain)"
        var label: String
        var owner: String?
        var ownerName: String?
        var since: Int?
        var resistance: Int?
        var island: Bool
        var uninhabited: Bool
    }

    struct Result: Encodable {
        var nation: Nation?
        var land: Land?
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let me = gs.getPlayerCountry()
        if let st = gs.preState(args.id) {
            let tpl = WorldCountriesDatabase.template(id: args.id) ?? PreStateModel.template(args.id)
            let colony = st.era.kind == .colony
            return Result(nation: nil, land: Land(
                id: args.id, name: tpl?.name ?? st.era.name, kind: colony ? "colony" : "indigenous", label: st.label,
                owner: colony ? st.era.owner : nil, ownerName: colony ? gs.getCountry(id: st.era.owner)?.name : nil,
                since: colony ? st.era.from : nil, resistance: colony ? nil : st.era.extra,
                island: Islands.byID[args.id] != nil, uninhabited: Islands.uninhabited(args.id)))
        }
        guard let c = gs.getCountry(id: args.id) else {
            guard gs.unclaimedLandIDs.contains(args.id) else { throw QueryError("no country or land \(args.id)") }
            let tpl = WorldCountriesDatabase.template(id: args.id)
            let name = args.id == Antarctica.id ? "Antarctica" : (Islands.byID[args.id]?.name ?? tpl?.name ?? args.id)
            return Result(nation: nil, land: Land(id: args.id, name: name, kind: "unclaimed", label: name, owner: nil, ownerName: nil,
                                                 since: nil, resistance: nil, island: Islands.byID[args.id] != nil,
                                                 uninhabited: Islands.uninhabited(args.id)))
        }
        let p = c.profile
        let mine = c.id == gs.playerCountryID
        let recon = (gs.shadow.satellites["recon"] ?? 0) > 0
        func estimate(_ v: Int) -> Estimate {
            if mine { return Estimate(text: "\(v)", tag: "CONFIRMED") }
            let l = IntelligenceModel.label(trueValue: v, year: gs.currentYear, recon: recon)
            return Estimate(text: l.text, tag: l.tag)
        }
        let leader = mine ? (gs.shadow.playerLeader ?? gs.shadow.leaderNames[c.id]) : gs.shadow.leaderNames[c.id]
        let fb = c.factbook
        let nation = Nation(
            id: c.id, name: c.name, flag: c.flag, region: c.region.rawValue, capital: c.capital, government: c.governmentLine,
            alignment: c.alignment.rawValue, ideology: p.ideology.rawValue, leader: leader, isPlayer: mine, destroyed: c.isDestroyed,
            territoryOf: c.territoryOf, territoryLabel: c.territoryOf == nil ? nil : gs.territoryLabel(c),
            relationToPlayer: mine ? nil : me?.diplomaticRelations[c.id] ?? 0,
            ambition: p.ambition, ambitionName: p.ambitionName, ethic: p.ethic, ethicName: p.ethicName,
            leadership: QueryText.round2(p.leadership), qualityOfLife: QueryText.round2(p.qualityOfLife), influence: c.powerScore,
            unrest: QueryText.round2(p.outcry), stability: c.stability, approval: c.publicApproval,
            gdp: c.gdp, population: c.population,
            military: estimate(c.militaryStrength),
            warheads: c.nuclearWarheads > 0 && gs.currentYear >= 1945 ? estimate(c.nuclearWarheads) : nil,
            nuclearStatus: c.nuclearStatus.rawValue,
            anxieties: Dictionary(uniqueKeysWithValues: ThreatAnxieties.Kind.allCases.map { ($0.rawValue, QueryText.round2(p.anxieties[$0])) }),
            aidNeed: Dictionary(uniqueKeysWithValues: AidCategory.allCases.map { ($0.rawValue, QueryText.round2(p.aidNeed[$0])) }),
            aidNeedTotal: QueryText.round2(p.aidNeed.total),
            atWarWith: c.atWarWith.sorted(), allies: c.alliances.sorted(),
            intel: e.intelLine(about: c.id),
            corruption: fb.corruptionIndex, pressFreedom: fb.pressFreedomIndex, literacy: fb.literacyRate, landlocked: fb.isLandlocked)
        return Result(nation: nation, land: nil)
    }
}
#endif
