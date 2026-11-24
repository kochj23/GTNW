//
//  HomeFrontSheet.swift
//  Global Thermal Nuclear War
//
//  The Situation Room's HOME FRONT sheet (3.36.0): the power plays at home in one place. The economy as the
//  government reports it (OFFICIAL) beside what leaked (LEAKED), and one panel per play with its state and its
//  orders. Every button plans the order through the command box and shows the same confirmation card (EXECUTE /
//  CANCEL; a nuclear test needs a second press); nothing runs until EXECUTE. Both skins, any text size, VoiceOver.
//  Repository: https://github.com/kochj23/GTNW
//

#if !GTNW_CORE
import SwiftUI

struct HomeFrontSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    /// Offscreen snapshots can't render scroll views (or text fields); they pass false.
    var scrolls = true

    @State private var plan: CommandPlan?
    @State private var armed = false
    @State private var result: GameEngine.CommandExecution?
    @State private var refusal: String?
    @State private var industry = "steel"
    @State private var stateName = ""

    private var hf: HomeFrontState { gameState.shadow.homeFront }
    private var year: Int { gameState.currentYear }
    private var text: Color { Theme.isRetro ? EGA.white : .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.columns")
                Text("HOME FRONT")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if let plan {
                CommandCard(plan: plan, armed: armed, onExecute: execute, onEdit: { self.plan = nil }, onCancel: { self.plan = nil; armed = false })
            } else if let result {
                CommandResultView(result: result)
                    .padding(8).themedPanel(retroFill: EGA.black)
                Button("OK") { self.result = nil }.buttonStyle(ThemedButtonStyle())
            }
            if let refusal {
                Text(verbatim: refusal).font(ThemeFont.mono(11)).foregroundColor(GTNWColors.terminalRed)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Refused: \(refusal)")
            }
            if scrolls { ScrollView { panels } } else { panels }
            HStack { Spacer(); Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle()) }
        }
        .padding(16)
        .frame(width: FontScale.w(720))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }

    private var panels: some View {
        VStack(alignment: .leading, spacing: 8) {
            economyPanel
            panel("TROOPS IN YOUR STATES", troopsBody)
            panel("THE NUMBERS", numbersBody)
            panel("THE CENTRAL BANK", bankBody)
            panel("EQUITY STAKES", stakesBody)
            panel("STAYING IN POWER", powerBody)
            panel("MISSILE SHIELD", shieldBody)
            panel("NUCLEAR TESTS", testsBody)
        }
    }

    // MARK: Economy (official vs leaked)

    private var economyPanel: some View {
        let official = gameState.officialEconomy
        let cooked = gameState.numbersCooked
        return VStack(alignment: .leading, spacing: 3) {
            Text(cooked ? "ECONOMY: OFFICIAL FIGURES" : "ECONOMY").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.neonCyan)
            figure("GDP growth", official.growth, leaked: hf.leakedGrowth, cooked: cooked)
            if hf.inflation != nil || cooked {
                figure("Inflation", official.inflation, leaked: hf.leakedInflation, cooked: cooked)
                figure("Borrowing cost", official.borrowing, leaked: nil, cooked: cooked)
            }
            if cooked {
                Text(hf.numbersLeaked == nil ? "The statistician was fired: these figures may not be true."
                     : "The true figures leaked on \(GameCalendar.format(hf.numbersLeaked ?? gameState.currentDate)).")
                    .font(ThemeFont.mono(9)).foregroundColor(GTNWColors.terminalAmber)
            }
        }
        .padding(6).frame(maxWidth: .infinity, alignment: .leading).themedPanel(retroFill: EGA.black)
    }

    private func figure(_ label: String, _ value: Double, leaked: Double?, cooked: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label).font(ThemeFont.mono(11)).foregroundColor(text).frame(width: FontScale.w(150), alignment: .leading)
            Text(verbatim: "\(HomeFrontModel.one(value))%").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalGreen)
            if cooked { tag("OFFICIAL", GTNWColors.terminalAmber) }
            if let leaked {
                Text(verbatim: "\(HomeFrontModel.one(leaked))%").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalRed)
                tag("LEAKED", GTNWColors.terminalRed)
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(HomeFrontModel.one(value)) percent\(cooked ? ", official" : "")\(leaked.map { ", leaked figure \(HomeFrontModel.one($0)) percent" } ?? "")")
    }

    private func tag(_ s: String, _ c: Color) -> some View {
        Text(s).font(ThemeFont.mono(8, .bold)).foregroundColor(c)
            .padding(.horizontal, 3).overlay(RoundedRectangle(cornerRadius: 2).stroke(c, lineWidth: 1))
    }

    // MARK: Panels

    private var troopsBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            if gameState.playerCountryID != "USA" {
                line("Only the United States' states are modeled for this order.")
            } else {
                ForEach(hf.deployments, id: \.state) { d in
                    HStack {
                        line("\(gameEngine.homeStateName(d.state) ?? d.state): \(Int(d.troops))K since \(GameCalendar.format(d.since)), unrest \(Int(gameEngine.homeStateUnrest(d.state).rounded()))")
                        Spacer()
                        order("WITHDRAW", .troopsHome, "withdraw", d.state)
                    }
                }
                if scrolls {
                    HStack {
                        TextField("State", text: $stateName).textFieldStyle(.roundedBorder).font(ThemeFont.mono(11)).frame(width: FontScale.w(200))
                            .accessibilityLabel("State to send federal troops into")
                        order("DEPLOY OVER THE GOVERNOR", .troopsHome, "deploy", stateName, color: GTNWColors.terminalRed)
                    }
                }
            }
        }
    }

    private var numbersBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            line(hf.statisticianFired.map { "Statistician fired \(GameCalendar.format($0)). Official figures diverge from the truth, more each month." }
                 ?? "\(HomeFrontModel.statsOffice(year: year).prefix(1).uppercased() + HomeFrontModel.statsOffice(year: year).dropFirst()) is independent.")
            HStack {
                order("FIRE THE STATISTICIAN", .fixNumbers, "fire", nil, color: GTNWColors.terminalRed)
                order("REHIRE AN INDEPENDENT ONE", .fixNumbers, "restore", nil)
            }
        }
    }

    private var bankBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let bank = HomeFrontModel.centralBank(year: year, nation: gameState.playerCountryID) {
                line("\(bank.prefix(1).uppercased() + bank.dropFirst()): \(hf.bankOverruled ? "overruled; rates set by the President" : "independent")"
                     + (hf.bankPressure > 0.05 ? ", rates \(HomeFrontModel.one(hf.bankPressure)) points below normal" : "") + ".")
                HStack {
                    order("PRESSURE TO CUT", .leanOnBank, "pressure", nil, color: GTNWColors.terminalAmber)
                    order("OVERRULE", .leanOnBank, "overrule", nil, color: GTNWColors.terminalRed)
                    order("RESTORE INDEPENDENCE", .leanOnBank, "release", nil)
                }
            } else {
                line(HomeFrontModel.noBankReason(year: year, nation: gameState.playerCountryID))
            }
        }
    }

    private var stakesBody: some View {
        let open = HomeFrontModel.industries.filter { $0.exists(in: year) && !hf.stakes.map(\.industry).contains($0.id) }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(hf.stakes, id: \.industry) { s in
                HStack {
                    line("\(HomeFrontModel.industry(s.industry)?.name ?? s.industry): \(HomeFrontModel.billions(s.value)) since \(GameCalendar.format(s.bought))")
                    Spacer()
                    order("SELL", .buyStake, "sell", s.industry)
                }
            }
            if hf.stakeIncome > 0 || hf.scandals > 0 {
                line("Paid so far: \(HomeFrontModel.billions(hf.stakeIncome)). Conflict-of-interest scandals: \(hf.scandals).")
            }
            if !open.isEmpty {
                HStack {
                    ScaledMenuPicker(selection: Binding(get: { open.contains { $0.id == industry } ? industry : open[0].id }, set: { industry = $0 }),
                                     options: open.map { ($0.id, $0.name) }, textColor: text)
                        .frame(width: FontScale.w(240))
                        .accessibilityLabel("Industry")
                    order("BUY A STAKE", .buyStake, "buy", open.contains { $0.id == industry } ? industry : open[0].id, color: GTNWColors.terminalAmber)
                }
            }
        }
    }

    private var powerBody: some View {
        let next = gameState.nextPresidentialYear
        let limited = ElectionCycle.termLimited(gameState.shadow.campaign, termsWon: gameState.shadow.termsWon, year: next)
        return VStack(alignment: .leading, spacing: 4) {
            if let bid = hf.bid {
                line("Under way since \(GameCalendar.format(bid.started)): \(bid.stage) of \(HomeFrontModel.stages(route: bid.route).count) hurdles passed.")
            } else if hf.termLimitRepealed {
                line("The 22nd Amendment is repealed: you may run again.")
            } else {
                line(ElectionRules(year: next).termLimited ? (limited ? "The 22nd Amendment bars you from the \(next) ballot." : "You may run again in \(next).")
                     : "No amendment limits terms before 1951; a third term is legal but breaks tradition.")
            }
            HStack {
                order("DEFY THE LIMIT", .stayInPower, "defy", nil, color: GTNWColors.terminalRed)
                order("POSTPONE THE ELECTION", .stayInPower, "postpone", nil, color: GTNWColors.terminalRed)
            }
            HStack {
                order("SEEK REPEAL", .stayInPower, "amendment", nil, color: GTNWColors.terminalAmber)
                order("THIRD TERM (PRE-1951)", .stayInPower, "thirdTerm", nil)
            }
        }
    }

    private var shieldBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let ready = hf.shieldReady, hf.shieldStarted != nil {
                line(gameState.currentDate >= ready
                     ? "Operational: stops about \(Int((HomeFrontModel.interceptRate(year: year) * 100).rounded()))% of incoming warheads. \(hf.shieldIntercepted) stopped so far."
                     : "Under construction, ready \(GameCalendar.format(ready)). \(HomeFrontModel.billions(hf.shieldSpent)) spent.")
            } else {
                line(year < HomeFrontModel.shieldFrom ? "No ballistic missiles to stop until 1957." : "No missile shield.")
            }
            HStack {
                order("BUILD THE SHIELD", .missileShield, "start", nil, color: GTNWColors.terminalAmber)
                order("CANCEL", .missileShield, "cancel", nil)
            }
        }
    }

    private var testsBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            line(hf.tests.isEmpty ? "No tests ordered." : "\(hf.tests.count) test\(hf.tests.count == 1 ? "" : "s") ordered; last \(GameCalendar.format(hf.tests.last?.date ?? gameState.currentDate)).")
            HStack {
                order("UNDERGROUND TEST", .nuclearTest, "underground", nil, color: GTNWColors.terminalRed)
                order("ATMOSPHERIC TEST", .nuclearTest, "atmospheric", nil, color: GTNWColors.terminalRed)
            }
        }
    }

    // MARK: Pieces

    private func panel<V: View>(_ title: String, _ content: V) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber).accessibilityAddTraits(.isHeader)
            content
        }
        .padding(6).frame(maxWidth: .infinity, alignment: .leading).themedPanel(retroFill: EGA.black)
    }

    private func line(_ s: String) -> some View {
        Text(verbatim: s).font(ThemeFont.mono(10)).foregroundColor(text).fixedSize(horizontal: false, vertical: true)
    }

    private func order(_ label: String, _ play: HomePlay, _ mode: String, _ arg: String?, color: Color = GTNWColors.neonCyan) -> some View {
        Button(label) { propose(play, mode, arg) }
            .buttonStyle(ThemedButtonStyle(color: color))
            .accessibilityLabel("\(label.capitalized): plan the order and show the confirmation card")
    }

    private func propose(_ play: HomePlay, _ mode: String, _ arg: String?) {
        guard let verb = CommandVerb(rawValue: play.rawValue) else { return }
        result = nil
        armed = false
        let intent = CommandIntent(verb: verb, targets: [mode] + (arg.map { [$0] } ?? []))
        switch gameEngine.planCommand(intent, source: .parser) {
        case .plan(let p): plan = p; refusal = nil
        case .rejected(let why): plan = nil; refusal = why
        case .clarify(let c): plan = nil; refusal = c.question
        case .answer(let lines): plan = nil; refusal = lines.joined(separator: " ")
        }
    }

    private func execute() {
        guard let p = plan else { return }
        if p.nuclear && !armed { armed = true; return }
        result = gameEngine.executeCommand(p.orders, source: p.source)
        plan = nil
        armed = false
    }
}
#endif
