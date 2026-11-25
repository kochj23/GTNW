//
//  HomeFrontQuery.swift
//  GTNWCore
//
//  `{"q":"homeFront"}` (3.37): the Situation Room's HOME FRONT sheet (HomeFrontSheet.swift, 3.36.0) as data: the
//  economy as the government reports it beside what leaked, and one panel per power play at home with its state
//  lines and its orders. As on the Mac, every order is planned through the command box: the front end sends the
//  `command` query with the order's `intent` (verb: play, targets: [mode, arg?]), shows the confirmation card, and EXECUTE is the
//  `executeCommand` verb (a nuclear test asks twice). `states` and `industries` are the choices the two orders that
//  take an argument accept.
//

#if GTNW_CORE
import Foundation

enum HomeFrontQuery: BridgeQuery {
    static let name = "homeFront"

    struct Figure: Encodable {
        var label: String
        var value: Double
        var leaked: Double?
    }

    struct Order: Encodable {
        var label: String
        /// The command verb (HomePlay raw value) and the intent's targets: the mode, then the argument if any.
        var play: String
        var mode: String
        var arg: String?
        /// "calm", "caution", "danger": the button's color on the Mac.
        var tone: String
        /// The argument comes from a choice list (`states`, `industries`) instead of being fixed: append the chosen id
        /// to the intent's targets.
        var pick: String?
        /// The `command` query's `intent`, ready to send.
        var intent: CommandIntent
    }

    struct Panel: Encodable {
        var id: String
        var title: String
        var lines: [String]
        var orders: [Order]
    }

    struct Choice: Encodable { var id: String; var name: String }

    struct Result: Encodable {
        var cooked: Bool
        var figures: [Figure]
        var economyNote: String?
        var panels: [Panel]
        var states: [Choice]
        var industries: [Choice]
        var actionsRemaining: Int
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let hf = gs.shadow.homeFront
        let year = gs.currentYear
        let official = gs.officialEconomy
        let cooked = gs.numbersCooked
        func one(_ v: Double) -> Double { (v * 10).rounded() / 10 }
        var figures = [Figure(label: "GDP growth", value: one(official.growth), leaked: hf.leakedGrowth.map(one))]
        if hf.inflation != nil || cooked {
            figures.append(Figure(label: "Inflation", value: one(official.inflation), leaked: hf.leakedInflation.map(one)))
            figures.append(Figure(label: "Borrowing cost", value: one(official.borrowing), leaked: nil))
        }
        var note: String?
        if cooked {
            note = hf.numbersLeaked == nil ? "The statistician was fired: these figures may not be true."
                : "The true figures leaked on \(GameCalendar.format(hf.numbersLeaked ?? gs.currentDate))."
        }
        func order(_ label: String, _ play: HomePlay, _ mode: String, _ arg: String? = nil, _ tone: String = "calm", pick: String? = nil) -> Order {
            Order(label: label, play: play.rawValue, mode: mode, arg: arg, tone: tone, pick: pick,
                  intent: CommandIntent(verb: CommandVerb(rawValue: play.rawValue), targets: [mode] + (arg.map { [$0] } ?? [])))
        }
        func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
        var panels: [Panel] = []

        // Troops in your states.
        var states: [Choice] = []
        if gs.playerCountryID != "USA" {
            panels.append(Panel(id: "troops", title: "TROOPS IN YOUR STATES", lines: ["Only the United States' states are modeled for this order."], orders: []))
        } else {
            var lines: [String] = [], orders: [Order] = []
            for d in hf.deployments {
                lines.append("\(e.homeStateName(d.state) ?? d.state): \(Int(d.troops))K since \(GameCalendar.format(d.since)), unrest \(Int(e.homeStateUnrest(d.state).rounded()))")
                orders.append(order("WITHDRAW FROM \((e.homeStateName(d.state) ?? d.state).uppercased())", .troopsHome, "withdraw", d.state))
            }
            states = (Subdivisions.byNation["USA"] ?? []).compactMap { s in e.homeStateName(s.id).map { Choice(id: s.id, name: $0) } }
                .sorted { $0.name < $1.name }
            if lines.isEmpty { lines.append("No federal troops in your states.") }
            orders.append(order("DEPLOY OVER THE GOVERNOR", .troopsHome, "deploy", nil, "danger", pick: "states"))
            panels.append(Panel(id: "troops", title: "TROOPS IN YOUR STATES", lines: lines, orders: orders))
        }

        // The numbers.
        let office = HomeFrontModel.statsOffice(year: year)
        panels.append(Panel(id: "numbers", title: "THE NUMBERS",
                            lines: [hf.statisticianFired.map { "Statistician fired \(GameCalendar.format($0)). Official figures diverge from the truth, more each month." }
                                    ?? "\(cap(office)) is independent."],
                            orders: [order("FIRE THE STATISTICIAN", .fixNumbers, "fire", nil, "danger"),
                                     order("REHIRE AN INDEPENDENT ONE", .fixNumbers, "restore")]))

        // The central bank.
        if let bank = HomeFrontModel.centralBank(year: year, nation: gs.playerCountryID) {
            panels.append(Panel(id: "bank", title: "THE CENTRAL BANK",
                                lines: ["\(cap(bank)): \(hf.bankOverruled ? "overruled; rates set by the President" : "independent")"
                                        + (hf.bankPressure > 0.05 ? ", rates \(HomeFrontModel.one(hf.bankPressure)) points below normal" : "") + "."],
                                orders: [order("PRESSURE TO CUT", .leanOnBank, "pressure", nil, "caution"),
                                         order("OVERRULE", .leanOnBank, "overrule", nil, "danger"),
                                         order("RESTORE INDEPENDENCE", .leanOnBank, "release")]))
        } else {
            panels.append(Panel(id: "bank", title: "THE CENTRAL BANK",
                                lines: [HomeFrontModel.noBankReason(year: year, nation: gs.playerCountryID)], orders: []))
        }

        // Equity stakes.
        let open = HomeFrontModel.industries.filter { $0.exists(in: year) && !hf.stakes.map(\.industry).contains($0.id) }
        var stakeLines: [String] = [], stakeOrders: [Order] = []
        for s in hf.stakes {
            let n = HomeFrontModel.industry(s.industry)?.name ?? s.industry
            stakeLines.append("\(n): \(HomeFrontModel.billions(s.value)) since \(GameCalendar.format(s.bought))")
            stakeOrders.append(order("SELL \(n.uppercased())", .buyStake, "sell", s.industry))
        }
        if hf.stakeIncome > 0 || hf.scandals > 0 {
            stakeLines.append("Paid so far: \(HomeFrontModel.billions(hf.stakeIncome)). Conflict-of-interest scandals: \(hf.scandals).")
        }
        if stakeLines.isEmpty { stakeLines.append("No government stakes in industry.") }
        if !open.isEmpty { stakeOrders.append(order("BUY A STAKE", .buyStake, "buy", nil, "caution", pick: "industries")) }
        panels.append(Panel(id: "stakes", title: "EQUITY STAKES", lines: stakeLines, orders: stakeOrders))

        // Staying in power.
        let next = gs.nextPresidentialYear
        let limited = ElectionCycle.termLimited(gs.shadow.campaign, termsWon: gs.shadow.termsWon, year: next)
        let powerLine: String
        if let bid = hf.bid {
            powerLine = "Under way since \(GameCalendar.format(bid.started)): \(bid.stage) of \(HomeFrontModel.stages(route: bid.route).count) hurdles passed."
        } else if hf.termLimitRepealed {
            powerLine = "The 22nd Amendment is repealed: you may run again."
        } else {
            powerLine = ElectionRules(year: next).termLimited ? (limited ? "The 22nd Amendment bars you from the \(next) ballot." : "You may run again in \(next).")
                : "No amendment limits terms before 1951; a third term is legal but breaks tradition."
        }
        panels.append(Panel(id: "power", title: "STAYING IN POWER", lines: [powerLine],
                            orders: [order("DEFY THE LIMIT", .stayInPower, "defy", nil, "danger"),
                                     order("POSTPONE THE ELECTION", .stayInPower, "postpone", nil, "danger"),
                                     order("SEEK REPEAL", .stayInPower, "amendment", nil, "caution"),
                                     order("THIRD TERM (PRE-1951)", .stayInPower, "thirdTerm")]))

        // Missile shield.
        let shieldLine: String
        if let ready = hf.shieldReady, hf.shieldStarted != nil {
            shieldLine = gs.currentDate >= ready
                ? "Operational: stops about \(Int((HomeFrontModel.interceptRate(year: year) * 100).rounded()))% of incoming warheads. \(hf.shieldIntercepted) stopped so far."
                : "Under construction, ready \(GameCalendar.format(ready)). \(HomeFrontModel.billions(hf.shieldSpent)) spent."
        } else {
            shieldLine = year < HomeFrontModel.shieldFrom ? "No ballistic missiles to stop until 1957." : "No missile shield."
        }
        panels.append(Panel(id: "shield", title: "MISSILE SHIELD", lines: [shieldLine],
                            orders: [order("BUILD THE SHIELD", .missileShield, "start", nil, "caution"), order("CANCEL", .missileShield, "cancel")]))

        // Nuclear tests.
        panels.append(Panel(id: "tests", title: "NUCLEAR TESTS",
                            lines: [hf.tests.isEmpty ? "No tests ordered."
                                    : "\(hf.tests.count) test\(hf.tests.count == 1 ? "" : "s") ordered; last \(GameCalendar.format(hf.tests.last?.date ?? gs.currentDate))."],
                            orders: [order("UNDERGROUND TEST", .nuclearTest, "underground", nil, "danger"),
                                     order("ATMOSPHERIC TEST", .nuclearTest, "atmospheric", nil, "danger")]))

        return Result(cooked: cooked, figures: figures, economyNote: note, panels: panels, states: states,
                      industries: open.map { Choice(id: $0.id, name: $0.name) }, actionsRemaining: gs.actionsRemaining)
    }
}
#endif
