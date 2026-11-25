//
//  AntarcticaQuery.swift
//  GTNWCore
//
//  `{"q":"antarctica"}` (3.37): the Antarctic programme as the app's AntarcticPanel shows it in the Antarctica dossier
//  (AntarcticStoryline.swift, 3.36.0): the treaty standing and stations, who holds the ice, and the four orders
//  (build a station, leave / rejoin / renegotiate the treaty) with the cost, why each can't be given now, and the
//  hint the button carries. An order is the `antarcticOrder` verb; each uses one action.
//

#if GTNW_CORE
import Foundation

enum AntarcticaQuery: BridgeQuery {
    static let name = "antarctica"

    struct Order: Encodable {
        var op: String
        var label: String
        var title: String
        /// "calm", "caution", "danger".
        var tone: String
        var problem: String?
        var hint: String
    }

    struct Station: Encodable { var site: String; var year: Int }

    struct Result: Encodable {
        var id: String
        var name: String
        var year: Int
        var lines: [String]
        var standing: String
        var owner: String?
        var ownerName: String?
        var stations: [Station]
        var stationCost: Double
        var orders: [Order]
        var busy: Bool
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let year = gs.currentYear
        let cost = Antarctica.stationCost(year: year)
        let standing = gs.antarcticStanding
        var orders: [Order] = []
        func add(_ op: AntarcticOrder, _ label: String, _ tone: String, _ hint: String) {
            orders.append(Order(op: op.rawValue, label: label, title: op.title, tone: tone, problem: e.antarcticProblem(op), hint: hint))
        }
        if year >= Antarctica.firstStationYear {
            add(.station, String(format: "BUILD %@ ($%.2fB)", year < 1946 ? "BASE" : "RESEARCH STATION", cost), "calm",
                "Science prestige now and every year. On ice you hold, each station counts as one INVEST of development.")
        }
        switch standing {
        case .noTreaty: break
        case .party:
            add(.leave, "LEAVE TREATY", "danger", "Notice of withdrawal: it takes effect in two years. The signatories will not like it.")
            add(.renegotiate, "RENEGOTIATE", "calm", e.renegotiationOutlook(gs).why)
        default:
            add(.join, "REJOIN TREATY", "calm", "Sign the Antarctic Treaty again; the signatories welcome it.")
        }
        let standingWord: String
        switch standing {
        case .noTreaty: standingWord = "none"
        case .party: standingWord = "party"
        case .withdrawing: standingWord = "withdrawing"
        case .withdrawn: standingWord = "withdrawn"
        }
        let owner = gs.antarcticaOwner
        return Result(id: Antarctica.id, name: gs.getCountry(id: Antarctica.id)?.name ?? "Antarctica", year: year,
                      lines: Antarctica.programLines(gs), standing: standingWord, owner: owner,
                      ownerName: owner.map { gs.getCountry(id: $0)?.name ?? $0 },
                      stations: gs.shadow.antarctic.stations.map { Station(site: $0.site, year: GameCalendar.year(of: $0.built)) },
                      stationCost: cost, orders: orders,
                      busy: gs.actionsRemaining == 0 || e.isProcessingAITurn || gs.gameOver)
    }
}
#endif
