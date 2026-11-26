//
//  HolySeeSheet.swift
//  Global Thermal Nuclear War
//
//  3.37.0: the Situation Room's HOLY SEE sheet, offered only when the player leads Vatican City (HolySee.swift).
//  The record the game is scored on, then the Holy See's statecraft by kind: peace (mediation, talks, a back
//  channel, envoys, a prisoner exchange, each on a pair of nations picked from the wars and disputes on the board),
//  crisis (an appeal for peace at DEFCON 2 or 1), teaching and treaties, humanitarian work, visits and relations, the
//  world stage, and resigning (which asks once more). Every button says why it can't be used now, carries the
//  historical precedent as its hint, and has a VoiceOver label with its cost. Both skins; no animation.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

struct HolySeeSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    /// Offscreen snapshots can't render scroll views; they pass false.
    var scrolls = true

    @State private var warPair = ""
    @State private var disputePair = ""
    @State private var nation = ""
    @State private var theme: TeachingTheme = .peace
    @State private var treaty = ""
    @State private var confirmResign = false
    @State private var lastResult: HolySeeResult?

    private var text: Color { Theme.isRetro ? EGA.white : .white }
    private var busy: Bool { gameState.actionsRemaining == 0 || gameEngine.isProcessingAITurn || gameState.gameOver }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.columns")
                Text(verbatim: "THE HOLY SEE — SECRETARIAT OF STATE")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            .accessibilityElement(children: .combine)
            Text("\(gameState.actionsRemaining) action(s) left. No forces of its own: the Holy See's levers are diplomacy and humanitarian work.")
                .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan).fixedSize(horizontal: false, vertical: true)
            let content = VStack(alignment: .leading, spacing: 10) {
                recordSection
                if let r = lastResult {
                    ForEach(Array(r.lines.enumerated()), id: \.offset) { _, l in
                        Text(verbatim: l).font(ThemeFont.mono(10)).foregroundColor(r.success ? GTNWColors.terminalGreen : GTNWColors.terminalAmber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                peaceSection
                crisisSection
                teachingSection
                humanitarianSection
                visitsSection
                worldSection
                resignSection
            }
            if scrolls { ScrollView { content } } else { content }
            HStack { Spacer(); Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle()) }
        }
        .padding(16)
        .frame(width: FontScale.w(720))
        .frame(minHeight: FontScale.h(420))
        .background(Theme.isRetro ? EGA.blue : Color.black)
        .alert("Resign the papacy?", isPresented: $confirmResign) {
            Button("RESIGN", role: .destructive) { run(HolySeeOrder(action: .resignOffice)) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The game ends here and is scored on the Holy See's record so far. \(HolySeeAction.resignOffice.precedent)")
        }
    }

    // MARK: Pieces

    private func heading(_ s: String) -> some View {
        Text(s).font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber).accessibilityAddTraits(.isHeader)
    }

    private func run(_ o: HolySeeOrder) { lastResult = gameEngine.runHolySee(o) }

    /// One action's button: disabled with the reason when it can't be used, the precedent as its hint.
    private func actionButton(_ o: HolySeeOrder, _ label: String, color: Color = GTNWColors.neonCyan) -> some View {
        let problem = gameEngine.holySeeProblem(o)
        return VStack(alignment: .leading, spacing: 2) {
            Button(label) { run(o) }
                .buttonStyle(ThemedButtonStyle(color: color))
                .disabled(busy || problem != nil)
                .help(problem ?? o.action.precedent)
                .accessibilityLabel(o.action.title.capitalized + ", one action")
                .accessibilityHint((problem.map { $0 + " " } ?? "") + o.action.summary + " " + o.action.precedent)
            Text(verbatim: problem ?? o.action.summary).font(ThemeFont.mono(9))
                .foregroundColor(problem == nil ? text : GTNWColors.terminalAmber).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pairs(wars: Bool, disputes: Bool) -> [(id: String, label: String)] {
        HolySeeModel.pairs(gameState, wars: wars, disputes: disputes).map { a, b in
            ("\(a.id)|\(b.id)", "\(a.name) – \(b.name)" + (a.atWarWith.contains(b.id) ? " (at war)" : " (relations \(HolySeeModel.mutual(gameState, a.id, b.id)))"))
        }
    }

    private func split(_ key: String) -> (String?, String?) {
        let p = key.split(separator: "|").map(String.init)
        return p.count == 2 ? (p[0], p[1]) : (nil, nil)
    }

    // MARK: Sections

    private var recordSection: some View {
        let r = gameState.shadow.holySee.record
        let problem = HolySeeModel.victoryProblem(gameState)
        return VStack(alignment: .leading, spacing: 3) {
            heading("THE RECORD · \(r.points) OF \(HolySeeModel.victoryPoints) POINTS")
            Text(verbatim: "Treaties signed at the Vatican \(r.treatiesAtVatican) · ceasefires \(r.ceasefires) · nuclear crises eased \(r.crisesDefused) · "
                 + "wars averted \(r.warsAverted) (delayed \(r.warsDelayed)) · thaws \(r.thaws)")
                .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.terminalGreen).fixedSize(horizontal: false, vertical: true)
            Text(verbatim: "People traced, sheltered or brought home \(r.livesSaved) · arms treaties ratified \(r.treatiesRatified) (\(r.treatyJoiners) nations joined) · "
                 + String(format: "debt relieved $%.1fB", r.debtRelievedB) + " · relations opened \(r.relationsOpened) · reforms \(r.reforms)")
                .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.terminalGreen).fixedSize(horizontal: false, vertical: true)
            Text(verbatim: problem.map { "Honest Broker: \($0)." } ?? "Honest Broker: the record is enough to win.")
                .font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
        }
        .padding(5).themedPanel(retroFill: EGA.black)
        .accessibilityElement(children: .combine)
    }

    private var peaceSection: some View {
        let wars = pairs(wars: true, disputes: false)
        let disputes = pairs(wars: true, disputes: true)
        let w = split(warPair.isEmpty ? (wars.first?.id ?? "") : warPair)
        let d = split(disputePair.isEmpty ? (disputes.first?.id ?? "") : disputePair)
        return VStack(alignment: .leading, spacing: 4) {
            heading("PEACE")
            if disputes.isEmpty {
                Text("No wars or bitter disputes on the board.").font(ThemeFont.mono(9)).foregroundColor(text)
            } else {
                Picker("Dispute", selection: $disputePair) {
                    ForEach(disputes, id: \.id) { p in Text(verbatim: p.label).tag(p.id) }
                }
                .fixedSize().accessibilityLabel("Nations in a dispute or at war")
                actionButton(HolySeeOrder(action: .mediate, first: d.0, second: d.1), "MEDIATE")
                actionButton(HolySeeOrder(action: .backChannel, first: d.0, second: d.1), "BACK CHANNEL")
                actionButton(HolySeeOrder(action: .sendEnvoys, first: d.0, second: d.1), "SEND ENVOYS")
            }
            if !wars.isEmpty {
                Picker("War", selection: $warPair) {
                    ForEach(wars, id: \.id) { p in Text(verbatim: p.label).tag(p.id) }
                }
                .fixedSize().accessibilityLabel("Nations at war")
                actionButton(HolySeeOrder(action: .hostTalks, first: w.0, second: w.1), "HOST PEACE TALKS")
                actionButton(HolySeeOrder(action: .prisonerExchange, first: w.0, second: w.1), "PRISONER EXCHANGE")
            }
        }
        .padding(5).themedPanel(retroFill: EGA.black)
    }

    private var crisisSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            heading("CRISIS · \(gameState.defconName) \(gameState.defconLevel.rawValue)")
            actionButton(HolySeeOrder(action: .appealForPeace), "APPEAL FOR PEACE", color: GTNWColors.terminalGreen)
        }
        .padding(5).themedPanel(retroFill: EGA.black)
    }

    private var teachingSection: some View {
        let open = HolySeeModel.openTreaties(gameState)
        let pick = treaty.isEmpty ? (open.first?.id ?? "") : treaty
        return VStack(alignment: .leading, spacing: 4) {
            heading("TEACHING AND TREATIES")
            Picker("Theme", selection: $theme) {
                ForEach(TeachingTheme.allCases, id: \.self) { t in Text(verbatim: t.title.capitalized).tag(t) }
            }
            .fixedSize().accessibilityLabel("Theme of the teaching document")
            actionButton(HolySeeOrder(action: .encyclical, option: theme.rawValue), "ISSUE A TEACHING DOCUMENT")
            ForEach(gameState.shadow.holySee.teachings.filter { gameState.currentDate < $0.until }, id: \.issued) { t in
                Text(verbatim: "In effect until \(GameCalendar.format(t.until)): \(t.theme.title).").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.terminalGreen)
            }
            if open.isEmpty {
                Text("No arms treaty is open for the Holy See to ratify in \(gameState.currentYear).").font(ThemeFont.mono(9)).foregroundColor(text)
            } else {
                Picker("Treaty", selection: $treaty) {
                    ForEach(open, id: \.id) { t in Text(verbatim: t.name).tag(t.id) }
                }
                .fixedSize().accessibilityLabel("Treaty to ratify")
                actionButton(HolySeeOrder(action: .ratifyTreaty, option: pick), "RATIFY AND PRESS OTHERS TO JOIN")
            }
        }
        .padding(5).themedPanel(retroFill: EGA.black)
    }

    private var humanitarianSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            heading("HUMANITARIAN WORK")
            actionButton(HolySeeOrder(action: .tracePrisoners), "TRACE THE MISSING", color: GTNWColors.terminalGreen)
            actionButton(HolySeeOrder(action: .shelterRefugees), "SHELTER REFUGEES", color: GTNWColors.terminalGreen)
            Text(verbatim: "A prisoner exchange is under PEACE, on the war picked there.").font(ThemeFont.mono(9)).foregroundColor(text)
        }
        .padding(5).themedPanel(retroFill: EGA.black)
    }

    private var visitsSection: some View {
        let nations = gameState.liveCountries.filter { $0.id != HolySeeModel.id }.sorted { $0.name < $1.name }
        let pick = nation.isEmpty ? (nations.first?.id ?? "") : nation
        return VStack(alignment: .leading, spacing: 4) {
            heading("VISITS AND RELATIONS")
            Picker("Nation", selection: $nation) {
                ForEach(nations, id: \.id) { c in Text(verbatim: c.name).tag(c.id) }
            }
            .fixedSize().accessibilityLabel("Nation to visit or open relations with")
            actionButton(HolySeeOrder(action: .pastoralVisit, first: pick), "PASTORAL VISIT")
            actionButton(HolySeeOrder(action: .openRelations, first: pick), "ESTABLISH RELATIONS")
        }
        .padding(5).themedPanel(retroFill: EGA.black)
    }

    private var worldSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            heading("THE WORLD STAGE")
            actionButton(HolySeeOrder(action: .interfaithGathering), "INTERFAITH GATHERING FOR PEACE")
            actionButton(HolySeeOrder(action: .debtRelief), "DEBT RELIEF CAMPAIGN")
            actionButton(HolySeeOrder(action: .addressUN), "ADDRESS THE UNITED NATIONS")
        }
        .padding(5).themedPanel(retroFill: EGA.black)
    }

    private var resignSection: some View {
        let problem = gameEngine.holySeeProblem(HolySeeOrder(action: .resignOffice))
        return VStack(alignment: .leading, spacing: 4) {
            heading("RESIGN")
            Button("RESIGN THE PAPACY…") { confirmResign = true }
                .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed))
                .disabled(gameEngine.isProcessingAITurn || problem != nil)
                .help(problem ?? HolySeeAction.resignOffice.precedent)
                .accessibilityLabel("Resign the papacy; ends the game")
                .accessibilityHint(HolySeeAction.resignOffice.summary + " " + HolySeeAction.resignOffice.precedent)
            Text(verbatim: HolySeeAction.resignOffice.summary).font(ThemeFont.mono(9)).foregroundColor(text)
        }
        .padding(5).themedPanel(retroFill: EGA.black)
    }
}
