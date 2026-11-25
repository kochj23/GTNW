//
//  HeldLands.swift
//  Global Thermal Nuclear War
//
//  3.37.0: the one definition of the land the President holds abroad.
//    • His territories (`territoryOf` is the player: annexed, claimed, bought, seized), as before.
//    • Governments he installed (puppets): a vanquished nation whose new government he chose at the settlement (any
//      of the seven, or the victor's model when he let the deadline pass), and a regime that fell to a capture raid
//      and was settled the same way. It counts while that government stands (the same form of government), it is
//      not at war with him, it is not destroyed or annexed (then it is a territory anyway), and it is still
//      friendly: relations with him of 20 or more. A communist state or a theocracy he installs starts cool, so it
//      does not count until relations warm. A government that falls, turns on him or cools past 20 is gone from the
//      list for good, with a line in the news.
//  Every place that measures "held land" asks `GameState.isHeldByPlayer` / `heldLands`: the score's land tally,
//  the empire goals (Manifest Destiny, the Sun Never Sets), renaming (he may rename a puppet), the names that label
//  the map, the presidential library and "fifty years later", the epilogue's count, and income.
//  Income: a puppet is not governed (no garrison, no extraction rate, no statehood, no INVEST), so it pays tribute
//  instead of a territory's output: half of what the same land's base output would pay as a territory (its resource
//  table, or 2% of its GDP), with no ramp-up and nothing from the land's own yield. Design choice: tribute is what
//  a client regime can send home without losing its own people.
//  Older saves: no record of installed governments, so nothing counts until the next one is installed.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// A government the President installed (saved, keyed by the nation's id).
struct InstalledGovernment: Codable, Equatable {
    var date: Date
    /// The form of government installed; a coup or revolution that changes it ends the arrangement.
    var government: GovernmentType

    init(date: Date, government: GovernmentType) {
        self.date = date; self.government = government
    }

    enum CodingKeys: String, CodingKey { case date, government }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = (try? c.decodeIfPresent(Date.self, forKey: .date)) ?? GameCalendar.inauguration(year: 2025)
        government = (try? c.decodeIfPresent(GovernmentType.self, forKey: .government)) ?? .authoritarian
    }
}

enum HeldLands {
    /// Relations with the President an installed government needs to count as his.
    static let puppetMinRelation = 20
    /// A puppet's tribute as a share of the land's base output as a territory (design choice).
    static let tributeShare = 0.5

    /// $B a year an installed government sends home: half the land's base output, no ramp-up, no garrison.
    static func tribute(_ c: Country, in gs: GameState) -> Double {
        let tabled = ExpansionModel.deposits[c.id] != nil || WorldCountriesDatabase.postColonialAfrica.contains(c.id)
        let base = tabled ? ExpansionModel.deposits(for: c.id, year: gs.currentYear).reduce(0) { $0 + LandDevelopment.money($1) }
                          : c.gdp * 1000 * 0.02
        return max(0, base * tributeShare)
    }

    /// Tribute from every installed government that still answers to the President, $B a year.
    static func totalTribute(_ gs: GameState) -> Double {
        gs.puppets.reduce(0) { $0 + tribute($1, in: gs) }
    }

    /// Why an installed government no longer counts, or nil while it does.
    static func lapse(_ id: String, in gs: GameState) -> String? {
        guard let r = gs.shadow.installedGovernments[id], let c = gs.getCountry(id: id) else { return "gone" }
        if c.isDestroyed { return "destroyed" }
        if c.territoryOf != nil { return "annexed" }
        if c.government != r.government { return "its government fell" }
        if c.atWarWith.contains(gs.playerCountryID) || (gs.getPlayerCountry()?.atWarWith.contains(id) ?? false) { return "at war with you" }
        if (c.diplomaticRelations[gs.playerCountryID] ?? 0) < puppetMinRelation { return "relations cooled" }
        return nil
    }
}

extension GameState {
    /// The installed government still answers to the President (see HeldLands.swift).
    func isPuppet(_ id: String) -> Bool {
        shadow.installedGovernments[id] != nil && HeldLands.lapse(id, in: self) == nil
    }

    /// Installed governments that still answer to the President, by id.
    var puppets: [Country] {
        shadow.installedGovernments.keys.sorted().filter(isPuppet).compactMap { getCountry(id: $0) }
    }

    /// The President holds this land abroad: his territory (still standing) or a government he installed that still
    /// answers to him. His own nation is not "held land"; callers that mean it too check it themselves.
    func isHeldByPlayer(_ id: String) -> Bool {
        guard id != playerCountryID, let c = getCountry(id: id), !c.isDestroyed else { return false }
        return c.territoryOf == playerCountryID || isPuppet(id)
    }

    /// Every land the President holds abroad, in board order: territories and installed governments.
    var heldLands: [Country] {
        countries.filter { isHeldByPlayer($0.id) }
    }
}

extension GameEngine {
    /// A settlement installed a government in a nation the President beat: remember it, so it counts as held land.
    func noteInstalledGovernment(_ id: String) {
        guard let gs = gameState, let c = gs.getCountry(id: id), c.territoryOf == nil, !c.isDestroyed else { return }
        gs.shadow.installedGovernments[id] = InstalledGovernment(date: gs.currentDate, government: c.government)
        self.gameState = gs
    }

    /// Each turn: drop installed governments that no longer answer to the President, with a line in the news, and
    /// return the tribute the rest pay this year ($B a year). No RNG.
    func reviewInstalledGovernments() -> Double {
        guard let gs = gameState else { return 0 }
        for id in gs.shadow.installedGovernments.keys.sorted() {
            guard let why = HeldLands.lapse(id, in: gs) else { continue }
            gs.shadow.installedGovernments[id] = nil
            guard let c = gs.getCountry(id: id), why != "annexed", why != "gone" else { continue }
            let name = c.name
            switch why {
            case "destroyed": break
            case "its government fell":
                gs.shadow.post("The government you installed in \(name) has fallen; \(name) no longer takes your orders.", date: gs.currentDate, severity: 2)
            case "at war with you":
                gs.shadow.post("\(name) has turned on the government you installed; it is no longer yours.", date: gs.currentDate, severity: 2)
            default:
                gs.shadow.post("\(name)'s government has drifted away from you; it no longer pays tribute.", date: gs.currentDate, severity: 1)
            }
            logPlayEvent("puppet_lost", detail: ["land": id, "name": PlayHistory.text(name), "reason": why,
                                                 "game_date": PlayHistory.day(gs.currentDate)])
        }
        self.gameState = gs
        return HeldLands.totalTribute(gs)
    }
}
