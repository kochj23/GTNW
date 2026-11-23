//
//  IntelQuery.swift
//  GTNWCore
//
//  `{"q":"intel"}`: the app's Intelligence tab (IntelligenceView): the world's status (wars, nuclear powers,
//  warheads, radiation, casualties, treaties), every active conflict with its intensity and start, the nuclear
//  powers by arsenal, and the player's relations with every live nation, warmest first.
//

#if GTNW_CORE
import Foundation

enum IntelQuery: BridgeQuery {
    static let name = "intel"

    struct War: Encodable {
        var aggressor: String
        var aggressorName: String
        var defender: String
        var defenderName: String
        var intensity: Int
        var since: String
    }

    struct Power: Encodable {
        var id: String
        var name: String
        var flag: String
        var warheads: Int
    }

    struct Relation: Encodable {
        var id: String
        var name: String
        var flag: String
        var value: Int
        var label: String
    }

    struct Result: Encodable {
        var activeWars: Int
        var nuclearPowers: Int
        var totalWarheads: Int
        var radiation: Int
        var casualties: Int
        var treaties: Int
        var wars: [War]
        var powers: [Power]
        var relations: [Relation]
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let name = { (id: String) in gs.getCountry(id: id)?.name ?? id }
        let wars = gs.activeWars.compactMap { w -> War? in
            guard gs.getCountry(id: w.aggressor) != nil, gs.getCountry(id: w.defender) != nil else { return nil }
            return War(aggressor: w.aggressor, aggressorName: name(w.aggressor), defender: w.defender, defenderName: name(w.defender),
                       intensity: w.intensity, since: gs.dateLabel(forTurn: w.startTurn))
        }
        let powers = gs.countries.filter { $0.nuclearWarheads > 0 }.sorted { $0.nuclearWarheads > $1.nuclearWarheads }
            .map { Power(id: $0.id, name: $0.name, flag: $0.flag, warheads: $0.nuclearWarheads) }
        var relations: [Relation] = []
        if let p = gs.getPlayerCountry() {
            relations = gs.countries.filter { !$0.isPlayerControlled && !$0.isDestroyed }
                .sorted { (p.diplomaticRelations[$0.id] ?? 0, $1.name) > (p.diplomaticRelations[$1.id] ?? 0, $0.name) }
                .map { c in
                    let v = p.diplomaticRelations[c.id] ?? 0
                    return Relation(id: c.id, name: c.name, flag: c.flag, value: v, label: label(v))
                }
        }
        return Result(activeWars: gs.activeWars.count, nuclearPowers: gs.countries.filter { $0.nuclearStatus != .none }.count,
                      totalWarheads: gs.countries.reduce(0) { $0 + $1.nuclearWarheads }, radiation: gs.globalRadiation,
                      casualties: gs.totalCasualties, treaties: gs.treaties.count, wars: wars, powers: powers, relations: relations)
    }

    /// IntelligenceView.relationshipText.
    static func label(_ v: Int) -> String {
        switch v {
        case 75...: return "Allied"
        case 50..<75: return "Friendly"
        case 25..<50: return "Cooperative"
        case -25..<25: return "Neutral"
        case -50..<(-25): return "Tense"
        case -75..<(-50): return "Hostile"
        default: return "Enemies"
        }
    }
}
#endif
