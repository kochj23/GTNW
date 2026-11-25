//
//  PowerPlaysSheet.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the Situation Room's POWER PLAYS sheet. For a foreign nation: an acquisition campaign (offer, tariffs on
//  the objectors, posturing, a framework deal or escalation), emergency tariffs under a chosen authority, limited
//  strikes and a leader-capture raid, each with the odds and the cabinet's read-out before the button. Always: the
//  national emergency and every emergency order with its legal authority, its court date and the ruling, with
//  REISSUE under another authority and WITHDRAW. Both skins; every control has a VoiceOver label; a risky order
//  (a raid, a nuclear-facility strike, escalation) asks once more.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

struct PowerPlaysSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    /// The nation (or land) the map has selected; the player's own country shows the emergency and names only.
    let targetID: String
    /// Offscreen snapshots can't render scroll views; they pass false.
    var scrolls = true

    @State private var basis: LegalBasis?
    @State private var reason: EmergencyReason = .trade
    @State private var confirm: PendingPlay?
    @State private var placeID = ""
    @State private var newName = ""

    /// A risky order waiting for the second press.
    struct PendingPlay: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let run: () -> Void
    }

    private var text: Color { Theme.isRetro ? EGA.white : .white }
    private var foreign: Bool { targetID != gameState.playerCountryID && gameState.getCountry(id: targetID)?.territoryOf != gameState.playerCountryID }
    private var name: String { gameEngine.acquisitionTarget(targetID)?.label ?? gameState.getCountry(id: targetID)?.name ?? targetID }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "crown")
                Text(verbatim: "POWER PLAYS\(foreign ? " — \(name.uppercased())" : "")")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            .accessibilityElement(children: .combine)
            Text("\(gameState.actionsRemaining) action(s) left").font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            let content = VStack(alignment: .leading, spacing: 10) {
                if foreign {
                    campaignSection
                    if gameState.getCountry(id: targetID).map({ !$0.isTerritory }) == true {
                        strikeSection
                        raidSection
                        tariffSection
                    }
                }
                emergencySection
                ordersSection
                if !foreign { namesSection }
            }
            if scrolls { ScrollView { content } } else { content }
            HStack { Spacer(); Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle()) }
        }
        .padding(16)
        .frame(width: FontScale.w(720))
        .frame(minHeight: FontScale.h(420))
        .background(Theme.isRetro ? EGA.blue : Color.black)
        .alert(item: $confirm) { p in
            Alert(title: Text(p.title), message: Text(p.message),
                  primaryButton: .destructive(Text("EXECUTE"), action: p.run), secondaryButton: .cancel())
        }
    }

    // MARK: Sections

    private func heading(_ s: String) -> some View {
        Text(s).font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber).accessibilityAddTraits(.isHeader)
    }

    private func warnings(_ ws: [AdvisorWarning]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(ws.enumerated()), id: \.offset) { _, w in
                Text(verbatim: "\(w.who): \(w.text)").font(ThemeFont.mono(9))
                    .foregroundColor(w.level >= 2 ? GTNWColors.terminalRed : (w.level == 1 ? GTNWColors.terminalAmber : text))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var campaignSection: some View {
        let open = gameEngine.openCampaign(targetID) ?? gameState.shadow.powerPlays.campaigns.last { $0.owner == targetID && $0.stage.isOpen }
        let land = open?.land ?? targetID
        let steps: [CampaignStep] = open == nil ? [.offer] : [.pressure, .posture, .deal, .escalate]
        return VStack(alignment: .leading, spacing: 4) {
            heading("ACQUISITION CAMPAIGN")
            if let c = open {
                Text(verbatim: "\(c.label) · \(c.stage.label) · leverage \(Int(c.leverage)) / resistance \(Int(gameEngine.campaignResistance(c))) · protests \(Int(c.protests))")
                    .font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.neonCyan)
                if !c.objectors.isEmpty {
                    Text(verbatim: "Objecting: \(PowerPlay.list(c.objectors.compactMap { gameState.getCountry(id: $0)?.name }))")
                        .font(ThemeFont.mono(9)).foregroundColor(text)
                }
            } else if gameEngine.acquisitionTarget(targetID) == nil {
                Text("Not something you can buy.").font(ThemeFont.mono(10)).foregroundColor(text)
            }
            ForEach(steps, id: \.self) { step in
                if gameEngine.acquisitionTarget(land) != nil || open != nil {
                    let problem = gameEngine.campaignProblem(land, step: step)
                    HStack(alignment: .top) {
                        warnings(problem == nil ? gameEngine.campaignWarnings(land, step: step).prefix(2).map { $0 } : [AdvisorWarning(who: "", text: problem ?? "", level: 0)])
                        Spacer()
                        Button(step.title) {
                            if step == .escalate || step == .posture {
                                confirm = PendingPlay(title: step.title, message: "\(name): this is a threat or a war. Proceed?") { gameEngine.campaignStep(land, step: step) }
                            } else {
                                gameEngine.campaignStep(land, step: step)
                            }
                        }
                        .buttonStyle(ThemedButtonStyle(color: step == .escalate ? GTNWColors.terminalRed : GTNWColors.terminalAmber))
                        .disabled(problem != nil)
                        .accessibilityLabel("\(step.title) for \(name)")
                    }
                    .padding(5).themedPanel(retroFill: EGA.black)
                }
            }
        }
    }

    private var strikeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            heading("LIMITED STRIKES · NO DECLARATION OF WAR")
            ForEach(StrikeKind.allCases) { k in
                let problem = gameEngine.strikeProblem(targetID, kind: k)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "\(k.title.uppercased())\(problem == nil ? " · HIT \(Int(gameEngine.strikeOdds(targetID, kind: k) * 100))%" : "")")
                            .font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.neonCyan)
                        if let problem { Text(verbatim: problem).font(ThemeFont.mono(9)).foregroundColor(text) }
                        else { warnings(gameEngine.strikeWarnings(targetID, kind: k).filter { $0.level > 0 }) }
                    }
                    Spacer()
                    Button("STRIKE") {
                        if k == .nuclearFacility {
                            confirm = PendingPlay(title: k.title, message: "\(name) may retaliate. Proceed?") { gameEngine.limitedStrike(targetID, kind: k) }
                        } else {
                            gameEngine.limitedStrike(targetID, kind: k)
                        }
                    }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed))
                    .disabled(problem != nil)
                    .accessibilityLabel("\(k.title) on \(name)")
                    .accessibilityValue(problem ?? "Hit odds \(Int(gameEngine.strikeOdds(targetID, kind: k) * 100)) percent")
                }
                .padding(5).themedPanel(retroFill: EGA.black)
            }
            if let e = gameState.shadow.powerPlays.escalation[targetID] {
                Text(verbatim: "Their escalation from strikes: \(Int(e)) of \(Int(LimitedStrikes.warThreshold)).")
                    .font(ThemeFont.mono(9)).foregroundColor(GTNWColors.terminalAmber)
            }
        }
    }

    private var raidSection: some View {
        let problem = gameEngine.captureProblem(targetID)
        return VStack(alignment: .leading, spacing: 4) {
            heading("LEADER CAPTURE RAID")
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    if let problem { Text(verbatim: problem).font(ThemeFont.mono(9)).foregroundColor(text) }
                    else { warnings(gameEngine.captureWarnings(targetID)) }
                }
                Spacer()
                Button("RAID") {
                    confirm = PendingPlay(title: "Leader capture raid", message: "Odds \(Int(gameEngine.captureOdds(targetID) * 100))%. Proceed?") {
                        gameEngine.captureLeader(targetID)
                    }
                }
                .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed, prominent: true))
                .disabled(problem != nil)
                .accessibilityLabel("Raid to capture the head of government of \(name)")
            }
            .padding(5).themedPanel(retroFill: EGA.black)
        }
    }

    private var tariffSection: some View {
        let bases = gameEngine.legalBases(for: .tariff, target: targetID)
        let pick = basis.flatMap { bases.contains($0) ? $0 : nil } ?? bases.first
        let problem = pick.map { gameEngine.emergencyTariffProblem(targetID, basis: $0) } ?? "No authority lets you impose tariffs now."
        return VStack(alignment: .leading, spacing: 4) {
            heading("EMERGENCY TARIFFS")
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Menu(pick?.title ?? "No authority") {
                        ForEach(bases) { b in
                            Button("\(b.title) (\(gameEngine.courtScore(b, kind: .tariff, target: targetID) >= EmergencyPowers.passMark ? "holds" : "weak"))") { basis = b }
                        }
                    }
                    .fixedSize()
                    .accessibilityLabel("Legal authority")
                    if let b = pick {
                        Text(verbatim: "\(b.note) Court: \(gameEngine.courtScore(b, kind: .tariff, target: targetID) >= EmergencyPowers.passMark ? "likely upheld" : "likely struck down") in about \(max(1, b.courtDays / 30)) months.")
                            .font(ThemeFont.mono(9)).foregroundColor(text).fixedSize(horizontal: false, vertical: true)
                    }
                    if let problem { Text(verbatim: problem).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.terminalAmber) }
                }
                Spacer()
                Button("IMPOSE") { if let b = pick { gameEngine.emergencyTariffs(on: targetID, basis: b) } }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalAmber))
                    .disabled(problem != nil)
                    .accessibilityLabel("Impose emergency tariffs on \(name)")
            }
            .padding(5).themedPanel(retroFill: EGA.black)
        }
    }

    private var emergencySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            heading("NATIONAL EMERGENCY")
            HStack {
                if let e = gameState.shadow.powerPlays.emergency {
                    Text(verbatim: "IN FORCE since \(GameCalendar.format(e.declared)): \(e.reason.title).")
                        .font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalRed)
                    Spacer()
                    Button("END IT") { gameEngine.endNationalEmergency() }
                        .buttonStyle(ThemedButtonStyle()).accessibilityLabel("End the national emergency")
                } else {
                    Picker("Reason", selection: $reason) {
                        ForEach(EmergencyReason.allCases) { r in Text(r.title).tag(r) }
                    }
                    .fixedSize()
                    .accessibilityLabel("Reason for the emergency")
                    Spacer()
                    Button("DECLARE") { gameEngine.declareNationalEmergency(reason) }
                        .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed))
                        .disabled(gameEngine.emergencyDeclareProblem(reason) != nil)
                        .accessibilityLabel("Declare a national emergency over \(reason.title)")
                }
            }
            .padding(5).themedPanel(retroFill: EGA.black)
        }
    }

    /// Seas, straits, mountains and the player's departments, renamed through the same check as every name.
    private var namesSection: some View {
        let features = MapFeatures.all.filter { $0.exists(in: gameState.currentYear) }
        let depts = Departments.current(in: gameState)
        let pick = placeID.isEmpty ? (depts.first?.id ?? features.first?.id ?? "") : placeID
        let problem = newName.isEmpty ? "Type a new name." : gameEngine.renamePlaceProblem(pick, to: newName)
        let provinces = gameState.renamableProvinces   // 3.36.0: the states and provinces the President holds
        func shown(_ id: String) -> String { RenameTarget.from(id: id, in: gameState).currentName(in: gameState) ?? id }
        return VStack(alignment: .leading, spacing: 4) {
            heading("NAMES · MAP AND GOVERNMENT")
            HStack {
                Menu(shown(pick)) {
                    Section("Government") { ForEach(depts) { d in Button(Departments.shownName(d, in: gameState)) { placeID = d.id } } }
                    Section("Map") { ForEach(features) { f in Button(MapFeatures.shownName(f, in: gameState)) { placeID = f.id } } }
                    if !provinces.isEmpty {
                        Section("States and provinces") { ForEach(provinces, id: \.id) { p in Button(gameState.provinceName(p.id)) { placeID = p.id } } }
                    }
                }
                .fixedSize()
                .accessibilityLabel("Place, department, state or province to rename")
                TextField("New name", text: $newName)
                    .textFieldStyle(.roundedBorder).font(ThemeFont.mono(11)).frame(maxWidth: FontScale.w(240))
                    .accessibilityLabel("New name")
                Spacer()
                Button("RENAME") { if gameEngine.renamePlace(pick, to: newName) { newName = "" } }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalAmber))
                    .disabled(problem != nil)
                    .accessibilityLabel("Rename \(shown(pick))")
            }
            .padding(5).themedPanel(retroFill: EGA.black)
            if !newName.isEmpty, let problem { Text(verbatim: problem).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.terminalAmber) }
            else if !newName.isEmpty { warnings(gameEngine.renamePlaceWarnings(pick)) }
            let renamed = gameState.shadow.powerPlays.featureNames.sorted { $0.key < $1.key }
            ForEach(renamed, id: \.key) { id, name in
                let real = MapFeatures.feature(id)?.name(in: gameState.currentYear) ?? id
                let used = gameState.shadow.powerPlays.featureRecognition[id]?.compactMap { gameState.getCountry(id: $0)?.name } ?? []
                Text(verbatim: "\(name) (\(real)): \(used.isEmpty ? "used by no other nation" : "used by \(PowerPlay.list(used))")")
                    .font(ThemeFont.mono(9)).foregroundColor(text)
            }
        }
    }

    private var ordersSection: some View {
        let orders = gameState.shadow.powerPlays.orders.suffix(12).reversed()
        return VStack(alignment: .leading, spacing: 4) {
            heading("EMERGENCY ORDERS · IN COURT")
            if orders.isEmpty {
                Text("None. Every order under emergency or trade powers is listed here with its authority and its court date.")
                    .font(ThemeFont.mono(9)).foregroundColor(text).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(orders)) { o in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: "\(o.subject.uppercased()) · \(o.status.label)")
                            .font(ThemeFont.mono(10, .bold))
                            .foregroundColor(o.status == .struckDown ? GTNWColors.terminalRed : (o.status.isLive ? GTNWColors.terminalGreen : GTNWColors.neonCyan))
                        Text(verbatim: "\(o.basis.title) · signed \(GameCalendar.format(o.issued))\(gameEngine.daysToRuling(o).map { " · ruling in \($0) days" } ?? "")")
                            .font(ThemeFont.mono(9)).foregroundColor(text)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    if o.status.isLive {
                        Button("WITHDRAW") { gameEngine.rescindEmergencyOrder(o.id) }
                            .buttonStyle(ThemedButtonStyle()).accessibilityLabel("Withdraw the \(o.subject)")
                    } else if o.status == .struckDown || o.status == .lapsed {
                        let options = LegalBasis.allCases.filter { gameEngine.reissueProblem(o.id, basis: $0) == nil }
                        if !options.isEmpty {
                            Menu("REISSUE") {
                                ForEach(options) { b in Button(b.title) { gameEngine.reissueEmergencyOrder(o.id, basis: b) } }
                            }
                            .fixedSize()
                            .accessibilityLabel("Reissue the \(o.subject) under another authority")
                        }
                    }
                }
                .padding(5).themedPanel(retroFill: EGA.black)
            }
        }
    }
}
