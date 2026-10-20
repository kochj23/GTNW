//
//  SituationRoomView.swift
//  Global Thermal Nuclear War
//
//  The home screen (see Documentation/UI_STRATEGY_2026-10.md): the map in the middle, the seven advisors on the left,
//  the selected country's dossier on the right, the escalation ladder and news ticker along the bottom, and a top bar
//  with the date, popularity / days to election, DEFCON and the world peace level. Works in both skins.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

struct SituationRoomView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var gameState: GameState
    @ObservedObject private var themes = ThemeManager.shared

    @State private var selectedCountryID: String?
    @State private var zoom: MapZoom = .world
    @State private var filter: MapFilter = .alignment
    @State private var ladderRung: EscalationRung?
    @State private var briefingRole: String?
    @State private var sheet: SituationSheet?

    enum SituationSheet: String, Identifiable {
        case budget, aid, evaluation, city, warRoom, saves, nameClaim, rename
        var id: String { rawValue }
    }

    private var selected: Country? { selectedCountryID.flatMap { gameState.getCountry(id: $0) } }
    /// The selected map outline when it is unclaimed land (3.3.0).
    private var selectedLand: String? { selectedCountryID.flatMap { gameState.unclaimedLandIDs.contains($0) ? $0 : nil } }

    @State private var compactPanel = 0

    var body: some View {
        GeometryReader { geo in
            Group {
                if geo.size.width < FontScale.w(1000) { compactLayout } else { wideLayout }
            }
        }
        .padding(8)
        .background(Theme.isRetro ? EGA.darkGray : Color.clear)
        .background(GTNWColors.spaceBackground.ignoresSafeArea())
        .onAppear { if selectedCountryID == nil { selectedCountryID = gameState.playerCountryID } }
        .sheet(item: $ladderRung) { rung in
            if let target = selected, let player = gameState.getPlayerCountry() {
                ActionLadderSheet(rung: rung, player: player, target: target, gameState: gameState)
                    .environmentObject(gameEngine)
            }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .budget: BudgetView(gameState: gameState).environmentObject(gameEngine)
            case .aid: AidSheet(gameState: gameState, countryID: selectedCountryID ?? gameState.playerCountryID).environmentObject(gameEngine)
            case .evaluation: WorldEvaluationView(gameState: gameState)
            case .city: CityView(gameState: gameState, countryID: selectedCountryID ?? gameState.playerCountryID)
            case .warRoom: WarRoomView(gameState: gameState).environmentObject(gameEngine)
            case .saves: SaveLoadView().environmentObject(gameEngine)
            case .nameClaim, .rename:
                TerritoryNameSheet(gameState: gameState, countryID: selectedCountryID ?? "", newlyClaimed: s == .nameClaim)
                    .environmentObject(gameEngine)
            }
        }
        .sheet(item: Binding(get: { briefingRole.map(BriefingRole.init) }, set: { briefingRole = $0?.id })) { role in
            AdvisorBriefingSheet(role: role.id, gameState: gameState, country: selected).environmentObject(gameEngine)
        }
    }

    /// Phones and narrow windows: map on top, then a switchable dossier / advisor panel.
    private var compactLayout: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) { SituationTopBar(gameState: gameState, onSheet: { sheet = $0 }) }
            mapControls
            VectorWorldMap(gameState: gameState, selectedCountryID: $selectedCountryID, zoom: $zoom, filter: $filter)
                .frame(minHeight: FontScale.h(220))
            ScaledSegmentedPicker(selection: $compactPanel, options: [(0, "Dossier"), (1, "Advisors")])
            Group {
                if compactPanel == 0 {
                    CountryDossier(gameState: gameState, country: selected, onSheet: { sheet = $0 }, unclaimedID: selectedLand)
                } else {
                    AdvisorRail(gameState: gameState, selected: selected, briefingRole: $briefingRole)
                }
            }
            .frame(maxHeight: .infinity)
            ScrollView(.horizontal, showsIndicators: false) {
                ActionLadder(gameState: gameState, target: selected, onRung: { ladderRung = $0 }).frame(minWidth: FontScale.w(900))
            }
            NewsTicker(items: gameState.shadow.ticker)
        }
    }

    private var wideLayout: some View {
        VStack(spacing: 6) {
            SituationTopBar(gameState: gameState, onSheet: { sheet = $0 })
            HStack(alignment: .top, spacing: 6) {
                AdvisorRail(gameState: gameState, selected: selected, briefingRole: $briefingRole)
                    .frame(width: FontScale.w(190))
                VStack(spacing: 4) {
                    mapControls
                    VectorWorldMap(gameState: gameState, selectedCountryID: $selectedCountryID, zoom: $zoom, filter: $filter)
                        .overlay(Rectangle().stroke(Theme.isRetro ? EGA.lightGray : Color.cyan.opacity(0.4), lineWidth: Theme.isRetro ? 3 : 1))
                    MapLegend(filter: filter, showUnclaimed: !gameState.unclaimedLandIDs.isEmpty).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(6)
                .themedPanel(retroFill: EGA.lightGray)
                CountryDossier(gameState: gameState, country: selected, onSheet: { sheet = $0 }, unclaimedID: selectedLand)
                    .frame(width: FontScale.w(300))
            }
            ActionLadder(gameState: gameState, target: selected, onRung: { ladderRung = $0 })
            NewsTicker(items: gameState.shadow.ticker)
        }
    }

    private var mapControls: some View {
        HStack(spacing: 8) {
            // Retro draws these on the light-gray EGA panel: dark text there.
            ScaledSegmentedPicker(selection: $zoom, options: MapZoom.allCases.map { ($0, $0.rawValue) },
                                  textColor: Theme.isRetro ? .black : .primary)
                .fixedSize()
            Text("Filter").font(ThemeFont.mono(12)).foregroundColor(Theme.isRetro ? .black : .primary)
            ScaledMenuPicker(selection: $filter, options: MapFilter.allCases.map { ($0, $0.rawValue) },
                             textColor: Theme.isRetro ? .black : .primary)
                .frame(width: FontScale.of(150))
            Spacer()
            Button { sheet = .warRoom } label: { Label("War Room", systemImage: "shield.lefthalf.filled") }
                .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed))
            Button { sheet = .evaluation } label: { Label("World", systemImage: "globe") }
                .buttonStyle(ThemedButtonStyle())
        }
        .font(ThemeFont.mono(11))
    }
}

private struct BriefingRole: Identifiable { let id: String }

// MARK: - Top bar

struct SituationTopBar: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var gameState: GameState
    let onSheet: (SituationRoomView.SituationSheet) -> Void
    /// `.auto` in the app; layout tests measure each half on its own.
    enum Part { case auto, statsOnly, controlsOnly }
    var part: Part = .auto

    var body: some View {
        let eval = WorldEvaluation.evaluate(gameState)
        Group {
            if part == .statsOnly {
                HStack(spacing: 14) { stats(eval) }
            } else if part == .controlsOnly {
                HStack(spacing: 14) { controls }
            } else {
                autoBar(eval)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .themedPanel()
    }

    /// At large text sizes the bar no longer fits one row: wrap the controls onto a second row instead of
    /// pushing the whole Situation Room wider than the window. (A plain function: ViewThatFits needs iOS 16.)
    private func autoBar(_ eval: WorldEvaluation) -> AnyView {
        if #available(macOS 13, iOS 16, *) {
            return AnyView(ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { stats(eval); Spacer(minLength: 14); controls }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 14) { stats(eval); Spacer(minLength: 0) }
                    HStack(spacing: 14) { Spacer(minLength: 0); controls }
                }
            })
        }
        return AnyView(HStack(spacing: 14) { stats(eval); Spacer(minLength: 14); controls })
    }

    @ViewBuilder private func stats(_ eval: WorldEvaluation) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(gameState.currentDateLabel.uppercased())
                    .font(ThemeFont.mono(18, .bold))
                    .foregroundColor(Theme.isRetro ? EGA.yellow : GTNWColors.neonCyan)
                Text("\(gameState.turnLength.displayName.uppercased()) \(gameState.turn + 1) · \(gameState.actionsRemaining)/\(gameState.actionsPerTurn) ACTIONS LEFT")
                    .font(ThemeFont.mono(10))
                    .foregroundColor(GTNWColors.terminalGreen)
            }
            divider
            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "POPULARITY %.0f%%", gameState.shadow.popularity))
                    .font(ThemeFont.mono(13, .bold))
                    .foregroundColor(gameState.shadow.popularity >= 45 ? GTNWColors.terminalGreen : (gameState.shadow.popularity >= 30 ? GTNWColors.terminalAmber : GTNWColors.terminalRed))
                Text(electionLine)
                    .font(ThemeFont.mono(10))
                    .foregroundColor(GTNWColors.neonCyan)
            }
            divider
            Text("DEFCON \(gameState.defconLevel.rawValue)")
                .font(ThemeFont.mono(15, .bold))
                .foregroundColor(Theme.isRetro ? EGA.black : .black)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(AppSettings.color(for: gameState.defconLevel))
            divider
            VStack(alignment: .leading, spacing: 0) {
                Text(eval.peaceLevel.label.uppercased())
                    .font(ThemeFont.mono(13, .bold))
                    .foregroundColor(MapFilter.rampColor(band: min(6, eval.peaceLevel.rawValue + 1)))
                Text("WORLD PEACE \(Int(eval.peaceIndex))").font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            }
            if gameState.shadow.impeachmentStage > 0 {
                Text("IMPEACHMENT \(gameState.shadow.impeachmentStage)/3").font(ThemeFont.mono(11, .bold))
                    .foregroundColor(GTNWColors.terminalRed)
            }
    }

    @ViewBuilder private var controls: some View {
            StoreStatusBadge().fixedSize()
            if gameState.shadow.budgetReviewPending {
                Button("BUDGET READY") { onSheet(.budget) }.buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalAmber, prominent: true))
            } else {
                Button("BUDGET") { onSheet(.budget) }.buttonStyle(ThemedButtonStyle())
            }
            Button("SAVE / LOAD") { onSheet(.saves) }.buttonStyle(ThemedButtonStyle())
            Button(gameEngine.isProcessingAITurn ? "WORLD RESOLVING…" : "END \(gameState.turnLength.displayName.uppercased())") {
                gameEngine.endTurn()
            }
            .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen, prominent: true))
            .disabled(gameEngine.isProcessingAITurn || gameState.gameOver)
    }

    private var divider: some View {
        Rectangle().fill(Theme.isRetro ? EGA.lightGray : Color.cyan.opacity(0.3)).frame(width: 1, height: FontScale.h(30))
    }

    private var electionLine: String {
        guard gameState.shadow.electionsEnabled else { return "ELECTIONS OFF" }
        let next = GameCalendar.nextElection(after: gameState.currentDate)
        let days = GameCalendar.days(from: gameState.currentDate, to: next)
        return "\(days) DAYS TO ELECTION"
    }
}

// MARK: - Advisor rail

struct AdvisorRail: View {
    @ObservedObject var gameState: GameState
    let selected: Country?
    @Binding var briefingRole: String?
    /// Offscreen snapshots can't render scroll views; they pass false.
    var scrolls = true

    var body: some View {
        Group {
            if scrolls { ScrollView { rail } } else { rail }
        }
        .themedPanel(retroFill: EGA.lightGray)
    }

    private var rail: some View {
            VStack(spacing: 5) {
                Text(Theme.isRetro ? "CABINET" : "ADVISORS")
                    .font(ThemeFont.mono(11, .bold))
                    .foregroundColor(GTNWColors.terminalAmber)
                ForEach(AdviceEngine.roleOrder, id: \.self) { role in
                    let adv = AdviceEngine.advisor(for: role, in: gameState.advisors)
                    let departed = gameState.advisors.last { $0.roleKey == role && !$0.isActive }
                    Button { briefingRole = role } label: {
                        HStack(spacing: 6) {
                            AdvisorPortrait(title: adv?.title ?? AdviceEngine.roleTitle(role), name: adv?.name ?? "Vacant",
                                            size: 38, status: adv == nil ? departed?.status : nil)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(AdviceEngine.roleTitle(role).uppercased())
                                    .font(ThemeFont.mono(8, .bold))
                                    .foregroundColor(GTNWColors.neonCyan)
                                    .lineLimit(2)
                                Text(adv?.name ?? "VACANT")
                                    .font(ThemeFont.mono(9))
                                    .foregroundColor(adv == nil ? GTNWColors.terminalRed : (Theme.isRetro ? EGA.white : .white))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(4)
                        .themedPanel(accent: GTNWColors.neonCyan, retroFill: EGA.blue)
                    }
                    .buttonStyle(.plain)
                    .help(AdviceEngine.briefing(role: role, country: selected, gameState: gameState))
                }
            }
            .padding(4)
    }
}

struct AdvisorBriefingSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let role: String
    @ObservedObject var gameState: GameState
    let country: Country?

    var body: some View {
        let adv = AdviceEngine.advisor(for: role, in: gameState.advisors)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AdvisorPortrait(title: adv?.title ?? AdviceEngine.roleTitle(role), name: adv?.name ?? "Vacant", size: 90)
                VStack(alignment: .leading, spacing: 4) {
                    Text(AdviceEngine.roleTitle(role).uppercased()).font(ThemeFont.mono(14, .bold)).foregroundColor(GTNWColors.terminalAmber)
                    Text(adv?.name ?? "This post is vacant").font(ThemeFont.mono(12)).foregroundColor(GTNWColors.neonCyan)
                    if let a = adv {
                        Text("Loyalty \(a.loyalty) · Expertise \(a.expertise) · Hawkishness \(a.hawkishness)")
                            .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.terminalGreen)
                    }
                }
            }
            Text(AdviceEngine.briefing(role: role, country: country, gameState: gameState))
                .font(ThemeFont.mono(13))
                .foregroundColor(Theme.isRetro ? EGA.white : .white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedPanel()
            let departed = gameState.advisors.filter { $0.roleKey == role && !$0.isActive }
            if !departed.isEmpty {
                Text("FORMER: " + departed.map { "\($0.name) (\(($0.status ?? .active).label.lowercased()))" }.joined(separator: "; "))
                    .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.terminalRed)
            }
            HStack {
                if let a = adv, !a.title.contains("President") {
                    Button("FIRE") {
                        if let i = gameState.advisors.firstIndex(where: { $0.id == a.id }) {
                            gameEngine.departAdvisor(index: i, status: .fired, reason: "\(a.name) has been dismissed as \(a.title).")
                        }
                        dismiss()
                    }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed))
                }
                Spacer()
                Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle(prominent: true))
            }
        }
        .padding(16)
        .frame(width: FontScale.w(520))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}

// MARK: - Dossier

struct CountryDossier: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var gameState: GameState
    let country: Country?
    let onSheet: (SituationRoomView.SituationSheet) -> Void
    /// Offscreen snapshots can't render scroll views; they pass false.
    var scrolls = true
    /// Set when the selection is unclaimed land rather than a country (3.3.0).
    var unclaimedID: String? = nil

    var body: some View {
        Group {
            if scrolls { ScrollView { dossier } } else { dossier }
        }
        .themedPanel(retroFill: EGA.blue)
    }

    /// Unclaimed land (3.3.0): nobody to talk to, nobody to fight. One action sends an expedition to take it.
    private func landDossier(_ id: String) -> some View {
        let land = WorldCountriesDatabase.template(id: id)
        let owner = gameState.getPlayerCountry()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🏳").font(.scaled(size: 30))
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: (land?.name ?? id).uppercased()).font(ThemeFont.mono(13, .bold)).foregroundColor(GTNWColors.terminalAmber).lineLimit(2)
                    Text(verbatim: land?.region.rawValue ?? "").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                }
            }
            Text("UNCLAIMED")
                .font(ThemeFont.mono(11, .bold)).foregroundColor(.black)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(VectorWorldMap.claimableColor)
            Text("Unclaimed land — no government, no army.")
                .font(ThemeFont.mono(11)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                .fixedSize(horizontal: false, vertical: true)
            Text("An expedition takes it at once as a \(owner.map { $0.id == "USA" ? "U.S." : $0.name } ?? "U.S.") territory. "
                 + "Costs one action and a little goodwill abroad: rivals by 5, the rest of the world by 2.")
                .font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                .fixedSize(horizontal: false, vertical: true)
            Button("SEND EXPEDITION") { if gameEngine.claimLand(id) { onSheet(.nameClaim) } }
                .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalAmber, prominent: true))
                .disabled(gameState.actionsRemaining == 0 || gameEngine.isProcessingAITurn || gameState.gameOver)
                .accessibilityLabel("Send an expedition to claim \(land?.name ?? id)")
        }
        .padding(8)
    }

    @ViewBuilder
    private var dossier: some View {
            if let c = country {
                let p = c.profile
                let player = gameState.getPlayerCountry()
                let rel = player?.diplomaticRelations[c.id] ?? 0
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(c.flag).font(.scaled(size: 30))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(c.name.uppercased()).font(ThemeFont.mono(13, .bold)).foregroundColor(GTNWColors.terminalAmber).lineLimit(2)
                            Text("\(c.region.rawValue) · \(p.ideology.rawValue)").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                            Text(c.government.rawValue.uppercased()).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                        }
                    }
                    if let o = c.territoryOf {
                        HStack {
                            Text(CombatModel.territoryTitle(ownerID: o, ownerName: gameState.getCountry(id: o)?.name ?? ""))
                                .font(ThemeFont.mono(11, .bold)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.isRetro ? EGA.lightBlue : Color.blue.opacity(0.7))
                            Spacer()
                            if o == gameState.playerCountryID {
                                Button("RENAME") { onSheet(.rename) }.buttonStyle(ThemedButtonStyle())
                                    .accessibilityLabel("Rename \(c.name)")
                            }
                        }
                    }
                    if !c.isPlayerControlled {
                        gauge("RELATIONS", Double(rel + 100) / 200, text: "\(rel)", good: true)
                    }
                    pips("AMBITION", p.ambition, p.ambitionName)
                    pips("ETHIC", p.ethic, p.ethicName)
                    gauge("LEADERSHIP", p.leadership / 100, text: "\(Int(p.leadership))", good: true)
                    gauge("QUALITY OF LIFE", p.qualityOfLife / 100, text: "\(Int(p.qualityOfLife))", good: true)
                    gauge("INFLUENCE", Double(c.powerScore) / 100, text: "\(c.powerScore)", good: true)
                    gauge("UNREST", p.outcry / 100, text: "\(Int(p.outcry))", good: false)
                    Text("WHAT WORRIES THEM").font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber).padding(.top, 4)
                    ForEach(ThreatAnxieties.Kind.allCases) { k in
                        gauge(k.label.uppercased(), p.anxieties[k] / 100, text: "\(Int(p.anxieties[k]))", good: false)
                    }
                    Text(String(format: "AID NEEDED  $%.1fB / yr", p.aidNeed.total)).font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber).padding(.top, 4)
                    ForEach(AidCategory.allCases) { cat in
                        HStack {
                            Text(cat.label).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                            Spacer()
                            Text(String(format: "$%.1fB", p.aidNeed[cat])).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.terminalGreen)
                        }
                    }
                    if !c.atWarWith.isEmpty {
                        Text("AT WAR WITH: " + c.atWarWith.compactMap { gameState.getCountry(id: $0)?.name }.sorted().joined(separator: ", "))
                            .font(ThemeFont.mono(9, .bold)).foregroundColor(GTNWColors.terminalRed)
                    }
                    HStack(spacing: 6) {
                        if !c.isPlayerControlled {
                            Button("SEND AID") { onSheet(.aid) }.buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen))
                        }
                        Button("CITY VIEW") { onSheet(.city) }.buttonStyle(ThemedButtonStyle())
                    }
                    .padding(.top, 4)
                }
                .padding(8)
            } else if let id = unclaimedID {
                landDossier(id)
            } else {
                Text("Select a country on the map.").font(ThemeFont.mono(12)).foregroundColor(GTNWColors.neonCyan).padding()
            }
    }

    private func gauge(_ label: String, _ v: Double, text: String, good: Bool) -> some View {
        let clamped = max(0, min(1, v))
        let band = min(6, Int(clamped * 7))
        return VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(label).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                Spacer()
                Text(text).font(ThemeFont.mono(9, .bold)).foregroundColor(Theme.isRetro ? EGA.white : .white)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.isRetro ? EGA.black : Color.white.opacity(0.08))
                    Rectangle().fill(MapFilter.rampColor(band: good ? 6 - band : band)).frame(width: g.size.width * clamped)
                }
            }
            .frame(height: FontScale.h(7))
        }
    }

    private func pips(_ label: String, _ value: Int, _ name: String) -> some View {
        HStack(spacing: 3) {
            Text(label).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan).frame(width: FontScale.w(70), alignment: .leading)
            ForEach(1...6, id: \.self) { i in
                Rectangle().fill(i <= value ? GTNWColors.terminalAmber : (Theme.isRetro ? EGA.black : Color.white.opacity(0.1)))
                    .frame(width: FontScale.w(10), height: FontScale.h(8))
            }
            Text(name.uppercased()).font(ThemeFont.mono(9, .bold)).foregroundColor(Theme.isRetro ? EGA.white : .white)
        }
    }
}

// MARK: - Action ladder & ticker

struct ActionLadder: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var gameState: GameState
    let target: Country?
    let onRung: (EscalationRung) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(target.map { "TARGET: \($0.flag) \($0.name.uppercased())" } ?? "SELECT A TARGET")
                .font(ThemeFont.mono(11, .bold))
                .foregroundColor(GTNWColors.terminalAmber)
                .frame(width: FontScale.w(230), alignment: .leading)
                .lineLimit(1)
            ForEach(EscalationRung.allCases) { rung in
                Button { onRung(rung) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: rung.icon)
                        Text(rung.title.uppercased())
                        if rung != .nuclear { Image(systemName: "chevron.right").font(.scaled(size: 9)) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ThemedButtonStyle(color: color(rung), prominent: false))
                .disabled(target == nil || target?.isPlayerControlled == true || gameState.actionsRemaining == 0
                          || gameEngine.isProcessingAITurn || gameState.gameOver)
            }
        }
        .padding(6)
        .themedPanel()
    }

    private func color(_ r: EscalationRung) -> Color {
        switch r {
        case .social: return GTNWColors.terminalGreen
        case .economic: return GTNWColors.neonCyan
        case .covert: return GTNWColors.neonPurple
        case .military: return GTNWColors.terminalAmber
        case .nuclear: return GTNWColors.terminalRed
        }
    }
}

struct NewsTicker: View {
    let items: [TickerItem]
    @State private var start = Date()

    var body: some View {
        let recent = Array(items.suffix(8).reversed())
        let line = recent.map { "\(GameCalendar.format($0.date)): \($0.text)" }.joined(separator: "   ◆   ")
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            GeometryReader { g in
                let speed = 60.0
                let width = max(g.size.width, CGFloat(line.count) * 7.2 * FontScale.factor)
                let offset = CGFloat(ctx.date.timeIntervalSince(start) * speed).truncatingRemainder(dividingBy: width + g.size.width)
                Text(line.isEmpty ? "NO NEWS" : line)
                    .font(ThemeFont.mono(12, .bold))
                    .foregroundColor(recent.first.map { $0.severity >= 3 } == true ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
                    .fixedSize()
                    .offset(x: g.size.width - offset)
            }
        }
        .frame(height: FontScale.h(22))
        .clipped()
        .padding(.horizontal, 6)
        .themedPanel(retroFill: EGA.black)
    }
}

// MARK: - Action sheet with advice

struct ActionLadderSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let rung: EscalationRung
    let player: Country
    let target: Country
    @ObservedObject var gameState: GameState
    @State private var action: PresidentialAction?
    @State private var playingAnimation: String?

    private var actions: [PresidentialAction] {
        PresidentialAction.allCases.filter { $0.rung == rung && $0.eraAvailableYear <= gameState.currentYear }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: rung.icon)
                Text("\(rung.title.uppercased()) ACTIONS — \(target.flag) \(target.name.uppercased())")
                Spacer()
                Text("\(gameState.actionsRemaining) left this \(gameState.turnLength.displayName.lowercased())")
                    .font(ThemeFont.mono(10))
            }
            .font(ThemeFont.mono(14, .bold))
            .foregroundColor(GTNWColors.terminalAmber)
            HStack(alignment: .top, spacing: 10) {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(actions) { a in
                            Button { action = a } label: {
                                HStack {
                                    Circle().fill(a.isHostile ? GTNWColors.terminalRed : GTNWColors.terminalGreen).frame(width: FontScale.w(7), height: FontScale.h(7))
                                    Text(a.rawValue).font(ThemeFont.mono(11, .bold))
                                    Spacer()
                                }
                                .padding(5)
                                .foregroundColor(action == a ? (Theme.isRetro ? EGA.black : .black) : (Theme.isRetro ? EGA.white : .white))
                                .background(action == a ? GTNWColors.terminalAmber : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: FontScale.w(240))
                .themedPanel(retroFill: EGA.black)
                VStack(alignment: .leading, spacing: 10) {
                    if let a = action {
                        Text(a.rawValue.uppercased()).font(ThemeFont.mono(13, .bold)).foregroundColor(GTNWColors.neonCyan)
                        Text(a.description).font(ThemeFont.mono(11)).foregroundColor(GTNWColors.terminalGreen)
                        let advice = AdviceEngine.advise(action: a, player: player, target: target, gameState: gameState)
                        AdvicePanel(advice: advice)
                        HStack {
                            Button("CANCEL") {
                                gameEngine.declineAdvisedAction(advice: advice)
                                dismiss()
                            }
                            .buttonStyle(ThemedButtonStyle())
                            Spacer()
                            Button("DO IT") { perform(a, advice: advice) }
                                .buttonStyle(ThemedButtonStyle(color: a.isHostile ? GTNWColors.terminalRed : GTNWColors.terminalGreen, prominent: true))
                                .disabled(gameState.actionsRemaining == 0)
                        }
                    } else {
                        Text("Choose an action. The responsible advisor will tell you what they think before you commit.")
                            .font(ThemeFont.mono(11)).foregroundColor(GTNWColors.neonCyan)
                    }
                    Spacer()
                }
                .frame(width: FontScale.w(430))
            }
        }
        .padding(14)
        .frame(width: FontScale.w(720), height: FontScale.h(480))
        .background(Theme.isRetro ? EGA.blue : Color.black)
        .overlay {
            if let anim = playingAnimation {
                ZStack {
                    Color.black.opacity(0.9)
                    PackAnimationView(anim) { EmptyView() }.frame(maxWidth: FontScale.w(420), maxHeight: FontScale.h(420))
                }
                .onTapGesture { playingAnimation = nil; dismiss() }
            }
        }
    }

    private func perform(_ a: PresidentialAction, advice: ActionAdvice) {
        gameEngine.performAdvisedAction(a, targetID: target.id, advice: advice)
        let media = ShadowPack.media(forActionCase: String(describing: a))
        if let sound = media.sound { ShadowPack.shared.play(sound) }
        if let anim = media.animation, let clip = ShadowPack.shared.animation(anim) {
            playingAnimation = anim
            DispatchQueue.main.asyncAfter(deadline: .now() + min(clip.duration, 6)) {
                if playingAnimation == anim { playingAnimation = nil; dismiss() }
            }
        } else {
            dismiss()
        }
    }
}
