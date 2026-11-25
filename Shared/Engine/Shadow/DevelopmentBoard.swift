//
//  DevelopmentBoard.swift
//  Global Thermal Nuclear War
//
//  3.37.0: INVEST from the Govern sheet. The sheet lists the land being governed and every other land the President
//  holds that is still developing: what it pays now and once developed, the months left, what one INVEST costs, and
//  why it can't be ordered (no actions, not enough money, already developed). Its INVEST button issues the command
//  box's own order (`GameOrder(kind: .developLand)` through `executeCommand`), so the checks, the cost, the news,
//  the play history and the command log are the same as typing "invest in Madagascar".
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// One land on the Govern sheet's development list.
struct DevelopmentRow: Equatable, Identifiable {
    var id: String
    var name: String
    /// $B a year now, and at full development.
    var now: Double
    var full: Double
    /// Whole months to full output (0 = developed).
    var months: Int
    /// What one INVEST order costs, $B.
    var cost: Double
    /// Why INVEST can't be ordered now, or nil.
    var problem: String?

    var canInvest: Bool { problem == nil }

    /// "NOW $0.12B/YR · DEVELOPED $0.40B/YR · 14 MONTHS LEFT · INVEST $0.50B".
    var line: String {
        let left = months > 0 ? "\(months) MONTH\(months == 1 ? "" : "S") LEFT" : "DEVELOPED"
        return String(format: "NOW $%.2fB/YR · DEVELOPED $%.2fB/YR · %@ · INVEST $%.2fB", now, full, left, cost)
    }

    /// The VoiceOver label for the row's button.
    var spoken: String {
        let left = months > 0 ? "\(months) month\(months == 1 ? "" : "s") left" : "fully developed"
        return String(format: "Invest %.2f billion dollars in %@. Pays %.2f billion a year now, %.2f billion when developed; %@.",
                      cost, name, now, full, left)
    }
}

extension LandDevelopment {
    /// The development row for one land the President holds.
    static func row(_ c: Country, in gs: GameState) -> DevelopmentRow {
        let inc = income(c, in: gs)
        return DevelopmentRow(id: c.id, name: c.name, now: inc.now, full: inc.full, months: monthsToDevelop(c.id, in: gs),
                              cost: investCost(c, in: gs), problem: problem(c.id, in: gs))
    }

    /// The Govern sheet's list: the land being governed first (even when developed, so its button says why), then
    /// every other territory of the President's still developing, fewest months left first.
    static func governRows(first id: String?, in gs: GameState) -> [DevelopmentRow] {
        let mine = gs.countries.filter { $0.territoryOf == gs.playerCountryID && !$0.isDestroyed }
        var rows = mine.filter { $0.id != id && canDevelop($0.id, in: gs) }.map { row($0, in: gs) }
            .sorted { ($0.months, $0.name) < ($1.months, $1.name) }
        if let id, let c = mine.first(where: { $0.id == id }) { rows.insert(row(c, in: gs), at: 0) }
        return rows
    }
}

extension GameEngine {
    /// INVEST from a sheet: the command box's order, carried out the command box's way. True if it went through.
    @discardableResult
    func investFromSheet(_ id: String) -> Bool {
        !executeCommand([GameOrder(kind: .developLand, target: id)], source: .sheet).carried.isEmpty
    }
}
