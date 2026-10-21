//
//  SituationSheets.swift
//  Global Thermal Nuclear War
//
//  Deep views opened from the Situation Room: Federal Budget, Foreign Aid, World Evaluation (with the Presidency
//  Summary), City View, Save / Load / Scenarios, and the election-night result.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

// MARK: - Shared chrome

private struct SheetFrame<Content: View>: View {
    let title: String
    var icon: String = "doc.text"
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                Text(title.uppercased())
                Spacer()
                Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle())
            }
            .font(ThemeFont.mono(15, .bold))
            .foregroundColor(GTNWColors.terminalAmber)
            content
        }
        .padding(16)
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}

// MARK: - Budget

struct BudgetView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var gameState: GameState
    @State private var draft = FederalBudget()
    @State private var loaded = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let proj = BudgetModel.project(draft, atWar: !(gameState.getPlayerCountry()?.atWarWith.isEmpty ?? true))
        SheetFrame(title: "Federal Budget \(gameState.currentYear)", icon: "building.columns") {
            if gameState.shadow.budgetReviewPending {
                Text("The budget for the new year is about to be processed. Accept it as is, or adjust it first.")
                    .font(ThemeFont.mono(11)).foregroundColor(GTNWColors.terminalGreen)
            }
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("INCOME (TAX RATES)").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.neonCyan)
                    slider("Personal income tax", \.personalTax, step: 1)
                    slider("Corporate tax", \.corporateTax, step: 1)
                    slider("Sales tax", \.salesTax, step: 0.5)
                    slider("Import tariff", \.tariff, step: 1)
                    Text("SPENDING (% OF GDP)").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.neonCyan).padding(.top, 6)
                    slider("Defense", \.defense, step: 0.25)
                    slider("Social programs", \.social, step: 0.25)
                    slider("Research & investment", \.research, step: 0.1)
                    slider("Foreign aid", \.foreignAid, step: 0.05)
                }
                .frame(width: FontScale.w(400))
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROJECTION").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.neonCyan)
                    row("Revenue", String(format: "%.1f%% of GDP", proj.revenue))
                    row("Spending", String(format: "%.1f%% of GDP", proj.spending))
                    row(proj.deficit >= 0 ? "Deficit" : "Surplus", String(format: "%.1f%% of GDP", abs(proj.deficit)), bad: proj.deficit > 4)
                    row("GDP growth", String(format: "%+.1f%% / yr", proj.growth), bad: proj.growth < 1)
                    row("Quality of life", String(format: "%+.1f / yr", proj.qualityOfLifeChange), bad: proj.qualityOfLifeChange < 0)
                    row("Military strength", String(format: "%+.1f / yr", proj.militaryChange), bad: proj.militaryChange < 0)
                    row("Popularity at year end", String(format: "%+.1f", proj.popularityChange), bad: proj.popularityChange < 0)
                    row("Foreign-aid pool", String(format: "$%.1fB", draft.aidPool(gdpTrillions: gameState.getPlayerCountry()?.gdp ?? 1)))
                    budgetBars(proj)
                    Spacer()
                }
            }
            HStack {
                Button("RESET") { draft = FederalBudget.forYear(gameState.currentYear) }.buttonStyle(ThemedButtonStyle())
                Spacer()
                Button("ENACT BUDGET") { gameEngine.applyBudget(draft); dismiss() }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen, prominent: true))
            }
        }
        .frame(width: FontScale.w(820), height: FontScale.h(560))
        .onAppear { if !loaded { draft = gameState.shadow.budget; loaded = true } }
    }

    private func slider(_ label: String, _ key: WritableKeyPath<FederalBudget, Double>, step: Double) -> some View {
        let range = FederalBudget.limits[key] ?? 0...100
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label).font(ThemeFont.mono(10)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                Spacer()
                Text(String(format: "%.2f%%", draft[keyPath: key])).font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber)
            }
            Slider(value: Binding(get: { draft[keyPath: key] }, set: { draft.set(key, $0) }), in: range, step: step)
        }
    }

    private func row(_ label: String, _ value: String, bad: Bool = false) -> some View {
        HStack {
            Text(label).font(ThemeFont.mono(11)).foregroundColor(GTNWColors.neonCyan)
            Spacer()
            Text(value).font(ThemeFont.mono(11, .bold)).foregroundColor(bad ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
        }
    }

    private func budgetBars(_ p: BudgetProjection) -> some View {
        let parts: [(String, Double, Color)] = [
            ("DEF", draft.defense, GTNWColors.terminalRed), ("SOC", draft.social, GTNWColors.terminalGreen),
            ("R&D", draft.research, GTNWColors.neonCyan), ("AID", draft.foreignAid, GTNWColors.terminalAmber),
            ("FIX", FederalBudget.fixedObligations, Theme.isRetro ? EGA.lightGray : .gray),
        ]
        return VStack(alignment: .leading, spacing: 3) {
            Text("WHERE THE MONEY GOES").font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.neonCyan).padding(.top, 8)
            GeometryReader { g in
                HStack(spacing: 1) {
                    ForEach(parts, id: \.0) { part in
                        Rectangle().fill(part.2).frame(width: max(2, g.size.width * part.1 / max(0.1, p.spending)))
                            .overlay(Text(part.0).font(ThemeFont.mono(8, .bold)).foregroundColor(.black))
                    }
                }
            }
            .frame(height: FontScale.h(18))
        }
    }
}

// MARK: - Foreign aid

struct AidSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var gameState: GameState
    let countryID: String
    @State private var package = AidVector()
    @State private var result: AidOutcome?

    var body: some View {
        let c = gameState.getCountry(id: countryID)
        SheetFrame(title: "Foreign Aid — \(c?.name ?? countryID)", icon: "shippingbox") {
            if let c {
                Text(String(format: "Aid budget remaining this year: $%.1fB", gameState.shadow.aidRemaining))
                    .font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalGreen)
                ForEach(AidCategory.allCases) { cat in
                    HStack(spacing: 10) {
                        Image(systemName: cat.icon).frame(width: FontScale.w(18))
                        Text(cat.label).frame(width: FontScale.w(120), alignment: .leading)
                        Text(String(format: "needs $%.1fB", c.profile.aidNeed[cat])).frame(width: FontScale.w(110), alignment: .leading)
                            .foregroundColor(GTNWColors.neonCyan)
                        Stepper(String(format: "$%.1fB", package[cat]), value: Binding(get: { package[cat] }, set: { package[cat] = max(0, $0) }), in: 0...50, step: 0.5)
                            .frame(width: FontScale.w(160))
                        let sent = gameState.shadow.aidSent[countryID]?[cat] ?? 0
                        if sent > 0 { Text(String(format: "sent $%.1fB", sent)).foregroundColor(GTNWColors.terminalAmber) }
                    }
                    .font(ThemeFont.mono(11))
                    .foregroundColor(Theme.isRetro ? EGA.white : .white)
                }
                HStack {
                    Text(String(format: "Package: $%.1fB", package.total)).font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber)
                    Spacer()
                    Button("CLEAR") { package = AidVector() }.buttonStyle(ThemedButtonStyle())
                    Button("SEND AID") {
                        result = gameEngine.sendAid(package, to: countryID)
                        package = AidVector()
                    }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen, prominent: true))
                    .disabled(package.total <= 0 || package.total > gameState.shadow.aidRemaining + 0.0001)
                }
                if let r = result {
                    Text("\(r.reaction.label.uppercased()): \(r.message)")
                        .font(ThemeFont.mono(11, .bold))
                        .foregroundColor(r.reaction == .thanks ? GTNWColors.terminalGreen : (r.reaction == .partial ? GTNWColors.terminalAmber : GTNWColors.terminalRed))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .frame(width: FontScale.w(640), height: FontScale.h(420))
    }
}

// MARK: - World evaluation

struct WorldEvaluationView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        let e = WorldEvaluation.evaluate(gameState)
        SheetFrame(title: "World Evaluation", icon: "globe") {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    meter("U.S. LEADERSHIP EFFECTIVENESS", e.leadership)
                    meter("U.S. SHARE OF WORLD INFLUENCE", min(100, e.influenceShare * 4), label: String(format: "%.1f%%", e.influenceShare))
                    meter("U.S. QUALITY OF LIFE", e.usQualityOfLife)
                    meter("WORLD QUALITY OF LIFE", e.worldQualityOfLife)
                }
                .frame(width: FontScale.w(360))
                VStack(alignment: .leading, spacing: 4) {
                    Text("WORLD PEACE LEVEL").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.neonCyan)
                    ForEach(PeaceLevel.allCases.reversed(), id: \.rawValue) { level in
                        HStack {
                            Rectangle().fill(MapFilter.rampColor(band: min(6, level.rawValue + 1))).frame(width: FontScale.w(26), height: FontScale.h(18))
                                .overlay(level == e.peaceLevel ? Text("◀").font(ThemeFont.mono(12, .bold)).foregroundColor(.white).offset(x: 24) : nil)
                            Text(level.label.uppercased()).font(ThemeFont.mono(11, level == e.peaceLevel ? .bold : .regular))
                                .foregroundColor(level == e.peaceLevel ? GTNWColors.terminalAmber : (Theme.isRetro ? EGA.lightGray : .gray))
                                .padding(.leading, 18)
                        }
                    }
                }
            }
            if let start = gameState.shadow.startSnapshot {
                let now = e.snapshot(date: gameState.currentDate, popularity: gameState.shadow.popularity)
                Text("PRESIDENCY SUMMARY  \(GameCalendar.format(start.date)) → \(gameState.currentDateLabel)")
                    .font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.neonCyan).padding(.top, 8)
                summary("Popularity", start.popularity, now.popularity)
                summary("U.S. quality of life", start.usQualityOfLife, now.usQualityOfLife)
                summary("World quality of life", start.worldQualityOfLife, now.worldQualityOfLife)
                summary("World peace", start.worldPeace, now.worldPeace)
                summary("Leadership", start.leadership, now.leadership)
            }
            Spacer()
        }
        .frame(width: FontScale.w(720), height: FontScale.h(520))
    }

    private func meter(_ title: String, _ v: Double, label: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.neonCyan)
                Spacer()
                Text(label ?? "\(Int(v))").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.isRetro ? EGA.black : Color.white.opacity(0.08))
                    Rectangle().fill(MapFilter.rampColor(band: 6 - min(6, Int(max(0, min(99.9, v)) / 100 * 7)))).frame(width: g.size.width * max(0, min(1, v / 100)))
                }
            }
            .frame(height: FontScale.h(12))
        }
    }

    private func summary(_ label: String, _ a: Double, _ b: Double) -> some View {
        HStack {
            Text(label).frame(width: FontScale.w(200), alignment: .leading).foregroundColor(Theme.isRetro ? EGA.white : .white)
            Text(String(format: "%.0f", a)).frame(width: FontScale.w(60)).foregroundColor(GTNWColors.neonCyan)
            Text("→").foregroundColor(GTNWColors.neonCyan)
            Text(String(format: "%.0f", b)).frame(width: FontScale.w(60)).foregroundColor(b >= a ? GTNWColors.terminalGreen : GTNWColors.terminalRed)
        }
        .font(ThemeFont.mono(11))
    }
}

// MARK: - City view

/// A small isometric-ish skyline for one country: tiles grow with GDP, quality of life, industry, the military and
/// the nuclear program, and burn after a nuclear strike. Pack sprites in Retro when available; drawn tiles otherwise.
struct CityView: View {
    @ObservedObject var gameState: GameState
    let countryID: String

    var body: some View {
        let c = gameState.getCountry(id: countryID)
        SheetFrame(title: "City View — \(c?.capital ?? "") , \(c?.name ?? "")", icon: "building.2") {
            if let c {
                let layout = CityLayout.layout(for: c, strikes: gameState.nuclearStrikes)
                ZStack {
                    (Theme.isRetro ? EGA.cyan : Color(red: 0.05, green: 0.1, blue: 0.2))
                    VStack(spacing: -12) {
                        Spacer()
                        HStack(alignment: .bottom, spacing: 6) {
                            tile(.military, layout).frame(width: FontScale.w(104))
                            tile(.downtown, layout).frame(width: FontScale.w(151))
                            tile(.industry, layout).frame(width: FontScale.w(78))
                            tile(.nuclear, layout).frame(width: FontScale.w(67))
                        }
                        HStack(alignment: .bottom, spacing: 6) {
                            tile(.housing, layout).frame(width: FontScale.w(157))
                            tile(.parks, layout).frame(width: FontScale.w(154))
                            tile(.airport, layout).frame(width: FontScale.w(111))
                        }
                        Rectangle().fill(Theme.isRetro ? EGA.green : Color.green.opacity(0.35)).frame(height: FontScale.h(14))
                    }
                    .scaleEffect(1.35, anchor: .bottom)
                    if layout.burning { BurningOverlay() }
                }
                .frame(height: FontScale.h(380))
                .clipped()
                HStack(spacing: 14) {
                    ForEach(CityTile.allCases) { t in
                        Text("\(t.rawValue.uppercased()) \(layout.levels[t] ?? 0)/\(t.maxLevel)").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                    }
                }
            }
        }
        .frame(width: FontScale.w(760), height: FontScale.h(500))
    }

    @ViewBuilder
    private func tile(_ t: CityTile, _ layout: CityLayout) -> some View {
        let level = layout.levels[t] ?? 0
        if Theme.isRetro {
            PackImage("city.\(t.rawValue).\(level)") { DrawnCityTile(tile: t, level: level) }
        } else {
            DrawnCityTile(tile: t, level: level)
        }
    }
}

/// Drawn stand-in for a city tile: a cluster of blocks whose height and count follow the level.
struct DrawnCityTile: View {
    let tile: CityTile
    let level: Int

    var body: some View {
        let frac = Double(level) / Double(max(1, tile.maxLevel))
        Canvas { ctx, size in
            let n = max(1, min(6, 1 + level / 2))
            let w = size.width / CGFloat(n)
            for i in 0..<n {
                let jitter: Double = Double((i * 37 + level * 11) % 10) / 10
                let share: Double = 0.15 + frac * (0.35 + 0.5 * jitter)
                let h: CGFloat = size.height * CGFloat(share)
                let r = CGRect(x: CGFloat(i) * w + 1, y: size.height - h, width: w - 2, height: h)
                ctx.fill(Path(r), with: .color(color))
                var y = r.minY + 4
                while y < r.maxY - 4 && tile != .parks {
                    let window = CGRect(x: r.minX + 3, y: y, width: max(1, r.width - 6), height: 2)
                    ctx.fill(Path(window), with: .color(windowColor))
                    y += 6
                }
            }
        }
        .frame(height: CGFloat(30 + 70 * frac))
    }

    private var windowColor: Color { Theme.isRetro ? EGA.yellow : Color.yellow.opacity(0.6) }

    private var color: Color {
        switch tile {
        case .downtown: return Theme.isRetro ? EGA.lightGray : Color(white: 0.7)
        case .housing: return Theme.isRetro ? EGA.brown : Color(red: 0.6, green: 0.4, blue: 0.3)
        case .industry: return Theme.isRetro ? EGA.darkGray : Color(white: 0.4)
        case .military: return Theme.isRetro ? EGA.green : Color(red: 0.3, green: 0.4, blue: 0.25)
        case .parks: return Theme.isRetro ? EGA.lightGreen : Color.green.opacity(0.7)
        case .nuclear: return Theme.isRetro ? EGA.yellow : Color.yellow.opacity(0.8)
        case .airport: return Theme.isRetro ? EGA.white : Color(white: 0.85)
        }
    }
}

struct BurningOverlay: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { ctx in
            Canvas { g, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.35)))
                for i in 0..<40 {
                    let x = (Double(i * 97 % 100) / 100) * size.width
                    let flicker = (sin(t * 7 + Double(i)) + 1) / 2
                    let h = size.height * (0.15 + 0.25 * flicker)
                    let r = CGRect(x: x, y: size.height - h, width: 14, height: h)
                    g.fill(Path(ellipseIn: r), with: .color(i % 2 == 0 ? (Theme.isRetro ? EGA.lightRed : .red) : (Theme.isRetro ? EGA.yellow : .orange)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Save / load / scenarios

struct SaveLoadView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var slots: [SaveSlotInfo] = []
    @State private var message = ""
    private let manager = GameStoreService.shared.local.saves

    var body: some View {
        SheetFrame(title: "Save / Load", icon: "externaldrive") {
            ForEach(1...SaveManager.slotCount, id: \.self) { slot in
                let info = slots.first { $0.slot == slot }
                HStack {
                    Text(info?.label ?? "Slot \(slot) — empty").font(ThemeFont.mono(11))
                        .foregroundColor(Theme.isRetro ? EGA.white : .white)
                    Spacer()
                    Button("SAVE") { run { try gameEngine.saveGame(slot: slot, manager: manager) } }
                        .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen))
                        .disabled(gameEngine.gameState == nil)
                    Button("LOAD") { run { try gameEngine.loadGame(slot: slot, manager: manager) }; dismiss() }
                        .buttonStyle(ThemedButtonStyle()).disabled(info == nil)
                }
            }
            if let auto = slots.first(where: { $0.slot == 0 }) {
                HStack {
                    Text(auto.label).font(ThemeFont.mono(11)).foregroundColor(GTNWColors.terminalAmber)
                    Spacer()
                    Button("LOAD") { run { try gameEngine.loadGame(slot: 0, manager: manager) }; dismiss() }.buttonStyle(ThemedButtonStyle())
                }
            }
            Text("SCENARIOS").font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.neonCyan).padding(.top, 8)
            ScenarioList { s in gameEngine.startScenario(s); dismiss() }
            if !message.isEmpty { Text(message).font(ThemeFont.mono(10)).foregroundColor(GTNWColors.terminalRed) }
            Spacer()
        }
        .frame(width: FontScale.w(660), height: FontScale.h(600))
        .onAppear { slots = manager.list() }
    }

    private func run(_ f: () throws -> Void) {
        do { try f(); message = ""; slots = manager.list() } catch { message = "Failed: \(error.localizedDescription)" }
    }
}

struct ScenarioList: View {
    let onStart: (ScenarioDefinition) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(ScenarioDefinition.all) { s in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(s.title.uppercased())  ·  \(GameCalendar.format(s.startDate))  ·  \(s.suggestedTurnLength.displayName) turns")
                            .font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber)
                        Text(s.summary).font(ThemeFont.mono(10)).foregroundColor(Theme.isRetro ? EGA.white : .white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("START") { onStart(s) }.buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen, prominent: true))
                }
                .padding(6)
                .themedPanel()
            }
        }
    }
}

// MARK: - Election night & domestic endings

struct ElectionNightView: View {
    let result: ElectionResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            PackAnimationView("anim.election.cuts", loop: true) {
                Image(systemName: "checkmark.seal.fill").font(.scaled(size: 60)).foregroundColor(GTNWColors.terminalAmber)
            }
            .frame(height: FontScale.h(120))
            Text("ELECTION NIGHT — \(GameCalendar.format(result.date).uppercased())").font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            HStack(spacing: 30) {
                VStack { Text("YOU").font(ThemeFont.mono(12)); Text(String(format: "%.1f%%", result.playerShare)).font(ThemeFont.mono(26, .bold)) }
                    .foregroundColor(result.won ? GTNWColors.terminalGreen : GTNWColors.terminalRed)
                VStack { Text(result.opponentName.uppercased()).font(ThemeFont.mono(12)); Text(String(format: "%.1f%%", result.opponentShare)).font(ThemeFont.mono(26, .bold)) }
                    .foregroundColor(result.won ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
            }
            Text(result.won ? "Four more years. The Situation Room stays yours — don't waste it." : "The voters have chosen someone else. Your access ends on Inauguration Day.")
                .font(ThemeFont.mono(12)).foregroundColor(Theme.isRetro ? EGA.white : .white).multilineTextAlignment(.center)
            Button("CONTINUE") { dismiss() }.buttonStyle(ThemedButtonStyle(prominent: true))
        }
        .padding(24)
        .frame(width: FontScale.w(560))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}

/// Header art for a domestic game over (impeachment lock-out, assassination) — pack screen or a drawn stand-in.
struct DomesticEndingBanner: View {
    let ending: DomesticEnding

    var body: some View {
        Group {
            switch ending {
            case .impeached:
                PackImage("screen.impeachment_lockout.aspect4x3", "screen.impeachment_lockout") { drawn("lock.fill", "ACCESS DENIED") }
            case .assassinated:
                PackImage("screen.assassination_player.aspect4x3", "screen.assassination_player") { drawn("scope", "THE PRESIDENT IS DEAD") }
            case .lostElection:
                drawn("person.crop.circle.badge.xmark", "DEFEATED AT THE POLLS")
            case .civilWar:
                drawn("flame.fill", "CIVIL WAR")
            case .noConfidence: drawn("hand.thumbsdown.fill", "NO CONFIDENCE")
            case .coup: drawn("shield.slash.fill", "COUP D'ÉTAT")
            case .revolution: drawn("flag.fill", "REVOLUTION")
            case .partyCongress: drawn("person.3.fill", "REMOVED BY THE PARTY")
            case .juntaDecision: drawn("star.slash.fill", "REPLACED BY THE JUNTA")
            case .royalDismissal: drawn("crown.fill", "DISMISSED BY THE CROWN")
            }
        }
        .frame(maxHeight: FontScale.h(220))
    }

    private func drawn(_ icon: String, _ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.scaled(size: 54))
            Text(text).font(ThemeFont.mono(20, .bold))
        }
        .foregroundColor(GTNWColors.terminalRed)
        .frame(maxWidth: .infinity, minHeight: FontScale.h(160))
        .themedPanel(retroFill: EGA.black)
    }
}

// MARK: - Terms of surrender (3.2.0)

/// After a U.S. victory: annex the vanquished country as a U.S. territory, or let it form a new government of the
/// President's choosing. The cabinet weighs in on each option. The sheet can't be swiped away; an unanswered choice
/// defaults to the pre-3.2 settlement at the next turn.
struct SettlementSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var gameState: GameState
    let settlement: PostWarSettlement
    /// Offscreen snapshots can't render scroll views (or text fields); they pass false.
    var scrolls = true
    /// Optional new name for the country if annexed (3.3.0); blank keeps its name.
    @State private var annexName = ""

    var body: some View {
        let loser = gameState.getCountry(id: settlement.loser)
        let owner = gameState.getPlayerCountry()
        let territory = CombatModel.territoryTitle(ownerID: owner?.id ?? "USA", ownerName: owner?.name ?? "")
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flag.2.crossed")
                Text("TERMS OF SURRENDER")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(17, .bold))
            .foregroundColor(GTNWColors.terminalAmber)
            Text("> \(loser?.flag ?? "") \((loser?.name ?? settlement.loser).uppercased()) HAS SURRENDERED. WHAT ARE YOUR ORDERS, MR. PRESIDENT?")
                .font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.neonCyan)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Group { if scrolls { ScrollView { options(loser: loser, territory: territory) } } else { options(loser: loser, territory: territory) } }
        }
        .padding(16)
        .frame(minWidth: FontScale.w(640), minHeight: FontScale.h(600))
        .background(Theme.isRetro ? EGA.blue : Color.black)
        .interactiveDismissDisabled()
        .onAppear { ShadowPack.shared.play("sfx.warroom_enter") }
    }

    private func options(loser: Country?, territory: String) -> some View {
                VStack(alignment: .leading, spacing: 8) {
                    option(title: "ANNEX AS \(territory) — \((loser?.name ?? "").uppercased())",
                           summary: "Its arsenal is seized and it flies our flag on the map. Occupation means insurgents, lost output "
                                  + "while it is rebuilt, and anger abroad: rivals by 20, the rest of the world by 10.",
                           choice: .annex, button: "ANNEX", color: GTNWColors.terminalRed)
                    TerritoryNameField(text: $annexName, placeholder: "Rename it (optional) — blank keeps \(loser?.name ?? "its name")", live: scrolls)
                    CabinetWarningsView(warnings: gameEngine.advisorWarnings(for: .annex(country: settlement.loser)))
                    Text("OR LET \((loser?.name ?? "IT").uppercased()) FORM A NEW GOVERNMENT:")
                        .font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber).padding(.top, 6)
                    ForEach(PostWarGovernment.allCases) { g in
                        option(title: g.title.uppercased(), summary: g.summary, choice: .government(g), button: "INSTALL",
                               color: GTNWColors.terminalGreen)
                    }
                }
    }

    private func option(title: String, summary: String, choice: SettlementChoice, button: String, color: Color) -> some View {
        let take = CombatModel.advisorTake(on: choice)
        let who = AdviceEngine.advisor(for: take.role, in: gameState.advisors)?.name ?? AdviceEngine.roleTitle(take.role)
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(ThemeFont.mono(12, .bold)).foregroundColor(color)
                Text(summary).font(ThemeFont.mono(10)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(who.uppercased()): \u{201C}\(take.text)\u{201D}").font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(button) {
                let rename = choice == .annex && !annexName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if gameEngine.settle(settlement.id, choice: choice), rename { gameEngine.renameTerritory(settlement.loser, to: annexName) }
            }
                .buttonStyle(ThemedButtonStyle(color: color, prominent: true))
                .disabled(choice == .annex && !annexName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          && CombatModel.validTerritoryName(annexName) == nil)
                .accessibilityLabel("\(button) — \(title)")
        }
        .padding(8)
        .themedPanel()
    }
}

// MARK: - Naming a territory (3.3.0)

/// The name box used by the naming sheet and the annex option. Offscreen snapshots can't render text fields, so
/// `live: false` draws the same box as plain text.
struct TerritoryNameField: View {
    @Binding var text: String
    let placeholder: String
    var live = true

    var body: some View {
        let invalid = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && CombatModel.validTerritoryName(text) == nil
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if live {
                    TextField(placeholder, text: $text).textFieldStyle(.plain)
                } else {
                    Text(verbatim: text.isEmpty ? placeholder : text).opacity(text.isEmpty ? 0.5 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(ThemeFont.mono(13, .bold))
            .foregroundColor(Theme.isRetro ? EGA.yellow : .white)
            .padding(6)
            .background(Theme.isRetro ? EGA.black : Color.white.opacity(0.08))
            .overlay(Rectangle().stroke(invalid ? GTNWColors.terminalRed : GTNWColors.neonCyan, lineWidth: 1))
            if invalid {
                Text("1–\(CombatModel.maxTerritoryNameLength) characters on one line.")
                    .font(ThemeFont.mono(9)).foregroundColor(GTNWColors.terminalRed)
            }
        }
    }
}

/// Name a territory: right after an unclaimed land is taken (`newlyClaimed`), or to rename any U.S. territory from
/// its dossier. Prefilled with the current name (a claimed land starts with its modern name); KEEP leaves it as is.
struct TerritoryNameSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    let countryID: String
    var newlyClaimed = false
    /// Offscreen snapshots can't render text fields; they pass false.
    var live = true
    @State private var name: String

    init(gameState: GameState, countryID: String, newlyClaimed: Bool = false, live: Bool = true, name: String? = nil) {
        self.gameState = gameState
        self.countryID = countryID
        self.newlyClaimed = newlyClaimed
        self.live = live
        _name = State(initialValue: name ?? gameState.getCountry(id: countryID)?.name ?? "")
    }

    var body: some View {
        let c = gameState.getCountry(id: countryID)
        let owner = gameState.getPlayerCountry()
        let title = CombatModel.territoryTitle(ownerID: owner?.id ?? "USA", ownerName: owner?.name ?? "")
        let valid = CombatModel.validTerritoryName(name)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: newlyClaimed ? "flag.fill" : "pencil")
                Text(newlyClaimed ? "NAME THE NEW TERRITORY" : "RENAME TERRITORY")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(17, .bold))
            .foregroundColor(GTNWColors.terminalAmber)
            Text(verbatim: newlyClaimed
                 ? "> THE FLAG FLIES OVER \((c?.name ?? countryID).uppercased()). IT IS NOW A \(title). WHAT SHALL WE CALL IT, MR. PRESIDENT?"
                 : "> \((c?.name ?? countryID).uppercased()) IS A \(title). WHAT SHOULD IT BE CALLED?")
                .font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.neonCyan)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            TerritoryNameField(text: $name, placeholder: "Territory name", live: live)
            HStack {
                Button { dismiss() } label: { Text(verbatim: "KEEP \((c?.name ?? "").uppercased())").lineLimit(1) }
                    .buttonStyle(ThemedButtonStyle())
                Spacer()
                Button(newlyClaimed ? "NAME IT" : "RENAME") {
                    if gameEngine.renameTerritory(countryID, to: name) { dismiss() }
                }
                .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen, prominent: true))
                .disabled(valid == nil || c?.territoryOf != gameState.playerCountryID)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: FontScale.w(560))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}

// MARK: - Sizing an offensive (3.4.0)

/// The sizing step shown before an offensive: presets plus one slider per force the attack uses, bounded by what
/// the U.S. has free, and a read-out of what the size changes (odds, losses, world reaction, escalation).
struct AttackSizingPanel: View {
    let action: PresidentialAction
    @Binding var size: AttackSize
    @ObservedObject var gameState: GameState
    let target: Country?
    /// Offscreen snapshots can't render sliders; they pass false.
    var live = true

    var body: some View {
        let kinds = AttackSizing.kinds(for: action)
        let m = AttackSizing.scale(size, for: action, in: gameState)
        VStack(alignment: .leading, spacing: 6) {
            Text("FORCE SIZE").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber)
            HStack(spacing: 6) {
                ForEach(AttackPreset.allCases) { p in
                    let s = AttackSizing.preset(p, for: action, in: gameState)
                    Button(p.title.uppercased()) { size = s }
                        .buttonStyle(ThemedButtonStyle(color: p == .overwhelming ? GTNWColors.terminalRed : GTNWColors.neonCyan, prominent: s == size))
                }
            }
            ForEach(kinds) { k in
                let cap = AttackSizing.available(k, in: gameState)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(k.label.uppercased()).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                        Spacer()
                        Text(cap > 0 ? "\(Int(size.amount(k))) OF \(Int(cap)) FREE" : "NONE AVAILABLE IN \(gameState.currentYear)")
                            .font(ThemeFont.mono(9, .bold)).foregroundColor(cap > 0 ? (Theme.isRetro ? EGA.white : .white) : GTNWColors.terminalRed)
                    }
                    if cap >= 2 {
                        if live {
                            Slider(value: Binding(get: { size.amount(k) }, set: { size.set(k, $0) }), in: 1...cap, step: 1)
                        } else {
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Theme.isRetro ? EGA.black : Color.white.opacity(0.1))
                                    Rectangle().fill(GTNWColors.terminalAmber).frame(width: g.size.width * min(1, size.amount(k) / cap))
                                }
                            }
                            .frame(height: FontScale.h(8))
                        }
                    }
                }
            }
            Text(readout(kinds: kinds, scale: m))
                .font(ThemeFont.mono(10)).foregroundColor(AttackSizing.escalates(scale: m) ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .themedPanel(retroFill: EGA.black)
    }

    /// Honest numbers from the same functions the engine uses.
    private func readout(kinds: [ForceKind], scale m: Double) -> String {
        var parts: [String] = []
        if kinds.contains(.troops), let t = target, let p = gameState.getPlayerCountry() {
            parts.append("Opening odds \(Int(AttackSizing.invasionOdds(troops: size.troops, attacker: p, defender: t) * 100))%")
        } else {
            parts.append("Success \(Int(AttackSizing.successOdds(scale: m) * 100))%")
        }
        if kinds.contains(.aircraft), let t = target {
            parts.append("~\(AttackSizing.aircraftLost(sorties: size.aircraft, against: t)) aircraft lost")
        }
        if kinds.contains(.warheads) {
            parts.append("Up to \((size.warheads * 1_000_000).formatted()) casualties before defences; retaliation up to \(size.warheads * 2) warheads")
        }
        let hit = AttackSizing.worldHit(scale: m)
        parts.append(hit > 0 ? "World opinion −\(hit)" : "No extra world reaction")
        if AttackSizing.escalates(scale: m) { parts.append("ESCALATION: DEFCON rises") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Fleet orders (3.5.0)

/// Send a named U.S. fleet of the era to the selected target: pick the fleet, the mission and how much of it to
/// commit; the sheet shows ships, transit time, expected losses and why an order isn't possible. Fleets already out
/// are listed with RECALL.
struct FleetOrderSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    let targetID: String
    /// Offscreen snapshots can't render scroll views; they pass false.
    var scrolls = true
    @State private var fleetID: String?
    @State private var mission: NavalMission = .showOfForce
    @State private var preset: AttackPreset = .standard

    init(gameState: GameState, targetID: String, scrolls: Bool = true, fleetID: String? = nil, mission: NavalMission = .showOfForce) {
        self.gameState = gameState
        self.targetID = targetID
        self.scrolls = scrolls
        _fleetID = State(initialValue: fleetID)
        _mission = State(initialValue: mission)
    }

    private var targetName: String {
        gameState.getCountry(id: targetID)?.name ?? WorldCountriesDatabase.template(id: targetID)?.name ?? targetID
    }

    var body: some View {
        let fleets = NavalModel.fleets(in: gameState.currentYear)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "ferry.fill")
                Text(verbatim: "FLEET ORDERS — \(targetName.uppercased())")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            if fleets.isEmpty {
                Text("The United States has no navy in \(gameState.currentYear).").font(ThemeFont.mono(12)).foregroundColor(GTNWColors.terminalRed)
            } else {
                Group { if scrolls { ScrollView { content(fleets) } } else { content(fleets) } }
            }
            HStack {
                Spacer()
                Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle())
            }
        }
        .padding(16)
        .frame(width: FontScale.w(720), height: FontScale.h(620))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }

    @ViewBuilder
    private func content(_ fleets: [USFleet]) -> some View {
        let year = gameState.currentYear
        let chosen = fleetID ?? fleets.first { f in !gameState.shadow.fleetDeployments.contains { $0.fleetID == f.id } }?.id
        VStack(alignment: .leading, spacing: 8) {
            Text("FLEET").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber)
            ForEach(fleets) { f in
                let comp = NavalModel.composition(f, year: year)
                let out = gameState.shadow.fleetDeployments.first { $0.fleetID == f.id }
                Button { fleetID = f.id } label: {
                    HStack {
                        Text(f.name.uppercased()).font(ThemeFont.mono(11, .bold))
                        Text("· \(f.period(in: year)?.home ?? "")").font(ThemeFont.mono(10))
                        Spacer()
                        Text(out != nil ? (out!.status == .underway ? "UNDER WAY" : "ON STATION") : shipLine(comp)).font(ThemeFont.mono(9))
                    }
                    .padding(4)
                    .foregroundColor(chosen == f.id ? (Theme.isRetro ? EGA.black : .black) : (Theme.isRetro ? EGA.white : .white))
                    .background(chosen == f.id ? GTNWColors.terminalAmber : Color.clear)
                }
                .buttonStyle(.plain)
            }
            Text("MISSION").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber)
            HStack(spacing: 6) {
                ForEach(NavalMission.allCases) { m in
                    Button(m.title.uppercased()) { mission = m }
                        .buttonStyle(ThemedButtonStyle(color: m == .showOfForce ? GTNWColors.neonCyan : GTNWColors.terminalRed, prominent: mission == m))
                }
            }
            Text(mission.summary).font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            Text("COMMIT").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber)
            HStack(spacing: 6) {
                ForEach(AttackPreset.allCases) { p in
                    Button("\(p.title.uppercased()) (\(Int(NavalMission.commitment(p) * 100))%)") { preset = p }
                        .buttonStyle(ThemedButtonStyle(color: p == .overwhelming ? GTNWColors.terminalRed : GTNWColors.neonCyan, prominent: preset == p))
                }
            }
            if let id = chosen, let f = NavalModel.fleet(id: id) {
                readout(f)
                let problem = gameEngine.fleetOrderProblem(fleetID: id, target: targetID, mission: mission)
                if let problem { Text(verbatim: problem).font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalRed) }
                let warnings = gameEngine.advisorWarnings(for: .fleet(fleetID: id, target: targetID, mission: mission, preset: preset))
                CabinetWarningsView(warnings: warnings)
                Button(CabinetWarningsView.proceedTitle(warnings, default: "ORDER \(f.name.uppercased()) OUT")) {
                    if gameEngine.orderFleet(id, to: targetID, mission: mission, preset: preset) != nil { dismiss() }
                }
                .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed, prominent: true))
                .disabled(problem != nil)
            }
            if !gameState.shadow.fleetDeployments.isEmpty {
                Text("FLEETS OUT").font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber).padding(.top, 6)
                ForEach(gameState.shadow.fleetDeployments) { d in
                    HStack {
                        let name = NavalModel.fleet(id: d.fleetID)?.name ?? d.fleetID
                        let where_ = gameState.getCountry(id: d.target)?.name ?? WorldCountriesDatabase.template(id: d.target)?.name ?? d.target
                        Text(verbatim: "\(name) — \(d.mission.title) — \(where_) — \(d.status == .underway ? "arrives \(GameCalendar.format(d.arrives))" : "on station") — \(d.shipsAfloat) ships")
                            .font(ThemeFont.mono(10)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                        Spacer()
                        Button("RECALL") { gameEngine.recallFleet(d.id) }.buttonStyle(ThemedButtonStyle())
                    }
                }
            }
        }
    }

    private func shipLine(_ c: FleetComposition) -> String {
        var parts: [String] = []
        if c.carriers > 0 { parts.append("\(c.carriers) CV") }
        parts.append("\(c.surface) SURFACE")
        if c.submarines > 0 { parts.append("\(c.submarines) SUB") }
        if c.amphibious > 0 { parts.append("\(c.amphibious) AMPHIB") }
        return parts.joined(separator: " · ")
    }

    /// The same numbers the engine will use.
    private func readout(_ f: USFleet) -> some View {
        let year = gameState.currentYear
        let ships = NavalModel.composition(f, year: year).scaled(NavalMission.commitment(preset))
        let home = f.period(in: year)
        let to = gameState.getCountry(id: targetID).map { ($0.coordinates.lat, $0.coordinates.lon) }
            ?? WorldCountriesDatabase.template(id: targetID).map { ($0.lat, $0.lon) } ?? (0, 0)
        let km = NavalModel.distanceKm(lat1: home?.lat ?? 0, lon1: home?.lon ?? 0, lat2: to.0, lon2: to.1)
        let days = NavalModel.transitDays(km: km, year: year)
        let probe = FleetDeployment(fleetID: f.id, target: targetID, mission: mission, commitment: NavalMission.commitment(preset), ships: ships,
                                    fromLat: 0, fromLon: 0, toLat: 0, toLon: 0, departed: Date(), arrives: Date())
        let lost = mission == .showOfForce ? 0 : NavalModel.shipsLost(probe, defence: NavalModel.defence(gameState.getCountry(id: targetID), year: year))
        var line = "\(ships.total) ships (\(shipLine(ships))) · \(Int(km)) km, about \(days) days at sea · expected losses on arrival ~\(lost)"
        if mission == .strike { line += " · weapons: \(NavalModel.strikeWeapon(year: year))" }
        if mission == .amphibious { line += " · lands ~\(Int(NavalModel.landingTroops(ships, year: year)))K troops" }
        return Text(line).font(ThemeFont.mono(10)).foregroundColor(GTNWColors.terminalGreen).fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Era arsenal line (3.6.0)

/// Under an action: what the U.S. actually had for it this year, its legal status and treaty (restricted and banned
/// options are labelled, never hidden), and why a chemical / biological order can't go ahead yet.
struct ArsenalLine: View {
    let action: PresidentialAction
    @ObservedObject var gameState: GameState
    var problem: String?

    var body: some View {
        let year = gameState.currentYear
        let examples = ArsenalCatalog.examples(for: action, year: year)
        let status = action.wmd.map { ArsenalCatalog.legalStatus($0, on: gameState.currentDate) } ?? ArsenalCatalog.status(for: action, year: year)
        let treaty = action.wmd.map { ArsenalCatalog.treatyLabel($0, year: year) }
            ?? ArsenalCatalog.optionIDs(for: action).first.flatMap(ArsenalCatalog.option)?.note(in: year)
                .map { note in String((note.components(separatedBy: ". ").first ?? note).components(separatedBy: "; ").first!.prefix(110)) }
        VStack(alignment: .leading, spacing: 3) {
            if !examples.isEmpty {
                Text(verbatim: "ARSENAL \(year): " + examples.prefix(4).joined(separator: " · "))
                    .font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan).fixedSize(horizontal: false, vertical: true)
            }
            if let status, status != .legal || action.wmd != nil {
                Text(verbatim: "\(status.label.uppercased())\(treaty.map { " — \($0)" } ?? "")")
                    .font(ThemeFont.mono(10, .bold))
                    .foregroundColor(status == .legal ? GTNWColors.terminalAmber : GTNWColors.terminalRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let problem {
                Text(verbatim: problem).font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalRed)
            }
        }
    }
}

// MARK: - Territory wealth and impeachment risk (3.7.0)

/// Top-bar read-out of Congress's mood: the same pressure Congress acts on at each monthly poll, and the approval
/// floor above which (with the outrage faded) any impeachment is dropped.
struct ImpeachmentRiskBadge: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        let p = ExpansionModel.impeachmentPressure(popularity: gameState.shadow.popularity, ruthlessness: gameState.shadow.ruthlessness,
                                                   congress: gameState.getPlayerCountry()?.congressionalSupport ?? 50)
        let risk = ExpansionModel.risk(pressure: p)
        let color = risk == .high ? GTNWColors.terminalRed : (risk == .rising ? GTNWColors.terminalAmber : GTNWColors.terminalGreen)
        VStack(alignment: .leading, spacing: 0) {
            let mech = gameState.getPlayerCountry().map { NationModel.removal($0, on: gameState.currentDate) } ?? .impeachment
            Text(mech == .impeachment ? "IMPEACH RISK \(risk.rawValue)" : "\(mech.title.uppercased()) RISK \(risk.rawValue)")
                .font(ThemeFont.mono(11, .bold)).foregroundColor(color)
            Text(gameState.shadow.impeachmentStage > 0 ? "STAGE: \(CongressModel.impeachmentStageName(gameState.shadow.impeachmentStage))"
                 : "APPROVAL FLOOR \(Int(ExpansionModel.popularityFloor))%")
                .font(ThemeFont.mono(9, gameState.shadow.impeachmentStage > 0 ? .bold : .regular))
                .foregroundColor(gameState.shadow.impeachmentStage > 0 ? GTNWColors.terminalRed : GTNWColors.neonCyan)
        }
        .help(String(format: "Congress's pressure %.0f (it acts above %.0f at the monthly poll)", p, ExpansionModel.impeachmentThreshold))
    }
}

/// Income from every U.S. territory: what it produces this year, how well it is held, and the total.
/// 3.13.1: the cash lands in your spendable funds; set each territory's extraction rate or levy it here.
struct ResourcesSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    /// Offscreen snapshots can't render scroll views; they pass false.
    var scrolls = true

    var body: some View {
        let rows = ExpansionModel.ledger(gameState)
        let total = rows.reduce(0) { $0 + $1.income }
        let strategic = ExpansionModel.strategic(gameState)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shippingbox.fill")
                Text("TERRITORY RESOURCES")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            Text(String(format: "THIS TURN +$%.2fB · FUNDS $%.1fB · TERRITORY CASH GOES STRAIGHT INTO YOUR FUNDS",
                        gameState.shadow.lastTurnCash, gameState.shadow.aidRemaining))
                .font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber)
            Text(String(format: "TOTAL $%.1fB A YEAR · EARNED SO FAR $%.1fB · APPROVAL +%.1f FROM PROSPERITY", total,
                        gameState.shadow.resourceEarnings, ExpansionModel.prosperityBonus(incomePerYear: total)))
                .font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalGreen)
            if !strategic.isEmpty {
                Text("STRATEGIC: " + strategic.map { k in
                    switch k {
                    case .oil: return "oil fuels the fleet and air arm"
                    case .uranium: return "uranium speeds the bomb"
                    default: return "rubber keeps the wartime army moving"
                    }
                }.sorted().joined(separator: " · ")).font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            }
            Group { if scrolls { ScrollView { table(rows) } } else { table(rows) } }
            HStack { Spacer(); Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle()) }
        }
        .padding(16)
        .frame(width: FontScale.w(640), height: FontScale.h(560))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }

    private func table(_ rows: [(country: Country, income: Double, resources: [ResourceKind])]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if rows.isEmpty {
                Text("No territories yet.").font(ThemeFont.mono(11)).foregroundColor(GTNWColors.neonCyan)
            }
            ForEach(rows, id: \.country.id) { r in
                let id = r.country.id
                let wait = ExpansionModel.monthsUntilProducing(id, in: gameState)
                let cooldown = ExpansionModel.levyCooldown(id, in: gameState)
                let current = ExpansionModel.rate(id, in: gameState)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(verbatim: r.country.name.uppercased()).font(ThemeFont.mono(11, .bold)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                        Text(verbatim: r.resources.map(\.title).joined(separator: ", ")).font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
                        Spacer()
                        let starting = wait == 0 && r.income < 0.005   // the ramp-up's first month rounds to $0.00B
                        Text(wait > 0 ? "PRODUCING IN \(wait) MONTH\(wait == 1 ? "" : "S")" : (starting ? "FIRST INCOME NEXT MONTH" : String(format: "$%.2fB/yr", r.income)))
                            .font(ThemeFont.mono(10, .bold)).foregroundColor(wait > 0 || starting ? GTNWColors.terminalAmber : GTNWColors.terminalGreen)
                    }
                    HStack(spacing: 4) {
                        ForEach(ExtractionRate.allCases) { rate in
                            Button(rate.title.uppercased()) { gameEngine.setExtraction(id, rate) }
                                .buttonStyle(ThemedButtonStyle(color: rate.insurgencyShift > 0 ? GTNWColors.terminalRed : GTNWColors.neonCyan, prominent: current == rate))
                        }
                        Spacer()
                        Button(cooldown > 0 ? "LEVY IN \(cooldown)MO" : String(format: "COLLECT $%.1fB", ExpansionModel.levyAmount(r.country, in: gameState))) {
                            gameEngine.collectLevy(id)
                        }
                        .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalAmber)).disabled(cooldown > 0)
                    }
                    if let limit = ExpansionModel.limit(r.country, in: gameState) {
                        Text(verbatim: limit).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.terminalRed)
                    }
                }
                .padding(4).themedPanel(retroFill: EGA.black)
            }
        }
    }
}

// MARK: - Advisor warnings and Congress (3.8.0)

/// The cabinet's three-line risk read-out before a major action (hidden when the setting is off).
struct CabinetWarningsView: View {
    let warnings: [AdvisorWarning]

    var body: some View {
        if AdvisorWarnings.enabled() && !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("BEFORE YOU DECIDE").font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber)
                ForEach(warnings, id: \.self) { w in
                    Text(verbatim: "\(w.who.uppercased()): \u{201C}\(w.text)\u{201D}")
                        .font(ThemeFont.mono(9, w.level == 2 ? .bold : .regular))
                        .foregroundColor(w.level == 2 ? GTNWColors.terminalRed : (w.level == 1 ? GTNWColors.terminalAmber : GTNWColors.neonCyan))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedPanel(retroFill: EGA.black)
        }
    }

    /// "OVERRULE & PROCEED" when a danger line is showing.
    static func proceedTitle(_ warnings: [AdvisorWarning], default title: String) -> String {
        AdvisorWarnings.enabled() && warnings.contains(where: { $0.level == 2 }) ? "OVERRULE & PROCEED" : title
    }
}

/// Ask Congress for a declaration of war or an authorization to use force, with the odds by chamber.
struct CongressSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    let targetID: String

    var body: some View {
        let name = gameState.getCountry(id: targetID)?.name ?? targetID
        let p = gameState.getPlayerCountry()
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "building.columns.fill")
                Text(verbatim: "ASK CONGRESS — \(name.uppercased())")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            if let p {
                Text(String(format: "SUPPORT: HOUSE %.0f%% · SENATE %.0f%% · PUBLIC WAR SUPPORT %d%%",
                            CongressModel.house(congress: p.congressionalSupport, popularity: gameState.shadow.popularity),
                            CongressModel.senate(congress: p.congressionalSupport, popularity: gameState.shadow.popularity), p.warSupport))
                    .font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.neonCyan)
            }
            if gameEngine.isAuthorized(targetID) {
                Text("Congress has already authorized hostilities against \(name).").font(ThemeFont.mono(11)).foregroundColor(GTNWColors.terminalGreen)
            }
            ForEach(WarAuthorizationKind.allCases) { kind in
                if let o = gameEngine.authorizationOdds(target: targetID, kind: kind) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title.uppercased()).font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber)
                            Text(String(format: "Odds %.0f%% · expected yes: House %.0f%%, Senate %.0f%% · casus belli %@", o.odds * 100, o.house, o.senate,
                                        o.casusBelli >= 0.7 ? "strong" : (o.casusBelli > 0 ? "some" : "none")))
                                .font(ThemeFont.mono(10)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                        }
                        Spacer()
                        Button("REQUEST") { if gameEngine.requestAuthorization(target: targetID, kind: kind) != nil { dismiss() } }
                            .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalAmber, prominent: true))
                            .disabled(gameState.actionsRemaining == 0 || gameEngine.isAuthorized(targetID))
                    }
                    .padding(6).themedPanel()
                }
            }
            Text(gameState.currentDate >= CongressModel.warPowersResolution
                 ? "War Powers Resolution (1973): hostilities without authorization start a 60-day clock, then 30 days to withdraw."
                 : "Before the War Powers Resolution (1973) Presidents often fought without asking; asking still rallies the country.")
                .font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan).fixedSize(horizontal: false, vertical: true)
            let votes = gameState.shadow.authorizations.filter { $0.target == targetID }
            ForEach(votes) { v in
                Text(verbatim: "\(GameCalendar.format(v.date)): \(v.kind.title) \(v.passed ? "PASSED" : "FAILED") (House \(v.houseYes)%, Senate \(v.senateYes)%)")
                    .font(ThemeFont.mono(9)).foregroundColor(v.passed ? GTNWColors.terminalGreen : GTNWColors.terminalRed)
            }
            HStack { Spacer(); Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle()) }
        }
        .padding(16)
        .frame(width: FontScale.w(640))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}

/// Top-bar read-out: Congress by chamber, and any War Powers clock running.
struct CongressBadge: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        let p = gameState.getPlayerCountry()
        let h = CongressModel.house(congress: p?.congressionalSupport ?? 50, popularity: gameState.shadow.popularity)
        let s = CongressModel.senate(congress: p?.congressionalSupport ?? 50, popularity: gameState.shadow.popularity)
        let clock = gameState.shadow.warPowersClocks.values.min { $0.started < $1.started }
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: "CONGRESS H %.0f · S %.0f", h, s)).font(ThemeFont.mono(11, .bold))
                .foregroundColor(min(h, s) < 34 ? GTNWColors.terminalRed : (min(h, s) < 50 ? GTNWColors.terminalAmber : GTNWColors.terminalGreen))
            if let c = clock {
                let days = GameCalendar.days(from: c.started, to: gameState.currentDate)
                let left = CongressModel.clockDays - days
                Text(left > 0 ? "WAR POWERS: \(left) DAYS" : "WAR POWERS: WITHDRAW \(max(0, left + CongressModel.withdrawalDays)) DAYS")
                    .font(ThemeFont.mono(9, .bold)).foregroundColor(GTNWColors.terminalRed)
            } else {
                Text("WAR POWERS: CLEAR").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
            }
        }
    }
}

// MARK: - Governing territories and manpower (3.9.0)

/// One territory's government: garrison, insurgency, governance, income, and the road to statehood.
struct GovernSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    let countryID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let c = gameState.getCountry(id: countryID) {
                let policy = gameState.shadow.territoryPolicies[c.id]
                let garrison = gameState.shadow.garrisons[c.id] ?? OccupationModel.neededGarrison(c)
                let needed = OccupationModel.neededGarrison(c)
                let state = gameState.shadow.statesAdmitted.first { $0.id == c.id }
                HStack {
                    Image(systemName: "building.2.fill")
                    Text(verbatim: "GOVERN — \(c.name.uppercased())")
                    Spacer()
                    Text(gameState.territoryLabel(c)).font(ThemeFont.mono(11, .bold))
                }
                .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
                if let s = state {
                    Text(verbatim: "Admitted \(GameCalendar.format(s.date)) as the \(OccupationModel.ordinal(s.number)) state.")
                        .font(ThemeFont.mono(12)).foregroundColor(GTNWColors.terminalGreen)
                } else {
                    Text(String(format: "INSURGENCY %.0f · STABILITY %d · INCOME $%.2fB/yr", c.profile.outcry, c.stability,
                                ExpansionModel.annualIncome(c, in: gameState)))
                        .font(ThemeFont.mono(11, .bold)).foregroundColor(c.profile.outcry > 60 ? GTNWColors.terminalRed : GTNWColors.neonCyan)
                    HStack(spacing: 6) {
                        Text("GARRISON").font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
                        Button("−") { gameEngine.setGarrison(c.id, thousands: max(0.5, garrison - 1)) }.buttonStyle(ThemedButtonStyle())
                        Text("\(Int(garrison))K of \(Int(needed.rounded()))K needed").font(ThemeFont.mono(11, .bold))
                            .foregroundColor(garrison >= needed ? GTNWColors.terminalGreen : GTNWColors.terminalAmber)
                        Button("+") { gameEngine.setGarrison(c.id, thousands: garrison + 1) }.buttonStyle(ThemedButtonStyle())
                        Text("\(Int(AttackSizing.freeTroops(gameState)))K FREE").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                    }
                    Text("GOVERNMENT").font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber)
                    HStack(spacing: 6) {
                        ForEach(TerritoryGovernance.allCases) { g in
                            Button(g.title.uppercased()) { gameEngine.setGovernance(c.id, g) }
                                .buttonStyle(ThemedButtonStyle(color: GTNWColors.neonCyan, prominent: (policy?.governance ?? .militaryGovernor) == g))
                        }
                    }
                    Text("A military governor provokes insurgency; elections calm it; self-rule calms it most but keeps 40% of the wealth at home. A territory left boiling for a year without enough troops will break away.")
                        .font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan).fixedSize(horizontal: false, vertical: true)
                    if gameState.playerCountryID == "USA" {   // statehood is a U.S. process (3.11.0)
                    Text("STATEHOOD").font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber)
                    let problems = OccupationModel.statehoodProblems(c: c, policy: policy, heldSince: gameState.shadow.claimDates[c.id], now: gameState.currentDate)
                    let yes = OccupationModel.statehoodYes(congress: gameState.getPlayerCountry()?.congressionalSupport ?? 50, stability: c.stability)
                    Text(problems.isEmpty ? String(format: "Ready. Congress's odds %.0f%%. It would be the %@ state.", CongressModel.passOdds(expectedYes: yes) * 100,
                                                   OccupationModel.ordinal(OccupationModel.historicalStates(year: gameState.currentYear) + gameState.shadow.statesAdmitted.count + 1))
                         : "Not yet: " + problems.joined(separator: "; ") + ".")
                        .font(ThemeFont.mono(10)).foregroundColor(problems.isEmpty ? GTNWColors.terminalGreen : (Theme.isRetro ? EGA.white : .white))
                        .fixedSize(horizontal: false, vertical: true)
                    Button("PETITION CONGRESS FOR STATEHOOD") { if gameEngine.petitionStatehood(c.id) != nil { dismiss() } }
                        .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen, prominent: true))
                        .disabled(!problems.isEmpty || gameState.actionsRemaining == 0)
                    }
                }
            }
            HStack { Spacer(); Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle()) }
        }
        .padding(16)
        .frame(width: FontScale.w(640))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}

/// U.S. troops: the era's standing force, any draft in force, what's committed, and calling up more.
struct ManpowerSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState

    var body: some View {
        let date = gameState.currentDate, year = gameState.currentYear
        let total = AttackSizing.troopPool(gameState), free = AttackSizing.freeTroops(gameState)
        let atWar = !(gameState.getPlayerCountry()?.atWarWith.isEmpty ?? true)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.3.fill")
                Text("MANPOWER")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            Text("TROOPS \(Int(total))K · FREE \(Int(free))K · GARRISONS \(Int(gameState.shadow.garrisons.values.reduce(0, +)))K")
                .font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalGreen)
            Text("Standing force \(Int(ManpowerModel.standing(year: year)))K (regulars and Guard of the era).")
                .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            if let h = ManpowerModel.historicalDraft(on: date) {
                Text(verbatim: "In force: \(h.name), \(GameCalendar.format(h.from))–\(GameCalendar.format(h.to)).")
                    .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            } else if date >= ManpowerModel.allVolunteer {
                Text("All-volunteer force since 27 Jan 1973.").font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            }
            ForEach([ManpowerKind.draft, .mobilization], id: \.self) { kind in
                let cost = ManpowerModel.callCost(kind, atWar: atWar)
                let called = gameState.shadow.mobilizations.first { $0.kind == kind }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ManpowerModel.title(kind, year: year).uppercased()).font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber)
                        Text(String(format: "+%dK over %.0f month%@ · approval %+.0f · Congress %+d", Int(ManpowerModel.callUpSize(kind, year: year).rounded()),
                                    ManpowerModel.trainingMonths(kind), ManpowerModel.trainingMonths(kind) == 1 ? "" : "s", cost.popularity, cost.congress))
                            .font(ThemeFont.mono(10)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                        if let c = called {
                            Text(String(format: "Called %@; %.0f%% trained.", GameCalendar.format(c.started), ManpowerModel.trained(since: c.started, now: date, kind: kind) * 100))
                                .font(ThemeFont.mono(9)).foregroundColor(GTNWColors.terminalGreen)
                        } else if let problem = gameEngine.callUpProblem(kind) {
                            Text(verbatim: problem).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.terminalRed)
                        }
                    }
                    Spacer()
                    if called != nil {
                        Button("STAND DOWN") { gameEngine.standDown(kind) }.buttonStyle(ThemedButtonStyle())
                    } else {
                        Button("CALL") { gameEngine.callUp(kind) }.buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed, prominent: true))
                            .disabled(gameEngine.callUpProblem(kind) != nil)
                    }
                }
                .padding(6).themedPanel()
            }
            HStack { Spacer(); Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle()) }
        }
        .padding(16)
        .frame(width: FontScale.w(620))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}

// MARK: - Group actions (3.10.0)

/// Act on many nations at once: choose the group, the action and the amount, check the per-nation breakdown and
/// total, then confirm once.
struct GroupActionSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    /// Offscreen snapshots can't render scroll views or text fields; they pass false.
    var live = true

    enum Pick: Hashable { case territories, allies, region, handPicked, saved(String) }
    @State var pick: Pick = .allies
    @State var region: WorldRegion = .europe
    @State var handPicked: Set<String> = []
    @State var kind: GroupActionKind = .message
    @State var amount: Double = 10
    @State var garrison: Double = 5
    @State var split: AidSplit = .byNeed
    @State var rate: ExtractionRate = .normal
    @State var saveName = ""

    private var selector: GroupSelector {
        switch pick {
        case .territories: return .territories
        case .allies: return .allies
        case .region: return .region(region)
        case .handPicked: return .custom(name: "Hand-picked", ids: handPicked.sorted())
        case .saved(let name): return .custom(name: name, ids: gameState.shadow.savedGroups[name] ?? [])
        }
    }

    var body: some View {
        let members = gameEngine.groupMembers(selector)
        let plan = gameEngine.planGroupAction(kind, members: members, amount: kind == .garrison ? garrison : amount, split: split, rate: rate)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                Text("GROUP ACTION")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            Text("GROUP").font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber)
            HStack(spacing: 6) {
                pickButton("TERRITORIES", .territories)
                pickButton("ALLIES", .allies)
                pickButton("REGION", .region)
                pickButton("HAND-PICK", .handPicked)
                ForEach(gameState.shadow.savedGroups.keys.sorted(), id: \.self) { name in pickButton(name.uppercased(), .saved(name)) }
            }
            if pick == .region {
                HStack(spacing: 4) {
                    ForEach(WorldRegion.allCases, id: \.self) { r in
                        Button(r.rawValue.uppercased()) { region = r }.buttonStyle(ThemedButtonStyle(prominent: region == r))
                    }
                }
            }
            if pick == .handPicked {
                let all = gameState.countries.filter { !$0.isDestroyed && $0.id != gameState.playerCountryID }.sorted { $0.name < $1.name }
                Group {
                    if live {
                        ScrollView { picker(all) }.frame(height: FontScale.h(110))
                    } else {
                        picker(Array(all.prefix(18)))
                    }
                }
                HStack(spacing: 6) {
                    TerritoryNameField(text: $saveName, placeholder: "Save this group as…", live: live)
                    Button("SAVE GROUP") { if gameEngine.saveGroup(name: saveName, ids: handPicked.sorted()) { pick = .saved(saveName.trimmingCharacters(in: .whitespacesAndNewlines)) } }
                        .buttonStyle(ThemedButtonStyle())
                        .disabled(handPicked.isEmpty || CombatModel.validTerritoryName(saveName) == nil)
                }
            }
            Text("ACTION").font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber)
            HStack(spacing: 6) {
                ForEach(GroupActionKind.allCases) { k in
                    Button(k.title.uppercased()) { kind = k }
                        .buttonStyle(ThemedButtonStyle(color: k == .sanctions || k == .recall ? GTNWColors.terminalRed : GTNWColors.neonCyan, prominent: kind == k))
                }
            }
            if kind == .money || kind == .aid {
                HStack(spacing: 6) {
                    Button("−") { amount = max(1, amount - 1) }.buttonStyle(ThemedButtonStyle())
                    Text(String(format: "$%.0fB TOTAL", amount)).font(ThemeFont.mono(12, .bold)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                    Button("+") { amount += 1 }.buttonStyle(ThemedButtonStyle())
                    ForEach(AidSplit.allCases) { s in
                        Button(s.title.uppercased()) { split = s }.buttonStyle(ThemedButtonStyle(prominent: split == s))
                    }
                    Text(String(format: "$%.1fB LEFT THIS YEAR", gameState.shadow.aidRemaining)).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                }
            }
            if kind == .garrison {
                HStack(spacing: 6) {
                    Button("−") { garrison = max(0.5, garrison - 1) }.buttonStyle(ThemedButtonStyle())
                    Text("\(Int(garrison))K EACH").font(ThemeFont.mono(12, .bold)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                    Button("+") { garrison += 1 }.buttonStyle(ThemedButtonStyle())
                    Text("\(Int(AttackSizing.freeTroops(gameState)))K FREE").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                }
            }
            if kind == .extraction {
                HStack(spacing: 6) {
                    ForEach(ExtractionRate.allCases, id: \.self) { r in
                        Button(r.title.uppercased()) { rate = r }.buttonStyle(ThemedButtonStyle(color: r.insurgencyShift > 0 ? GTNWColors.terminalRed : GTNWColors.neonCyan, prominent: rate == r))
                    }
                }
            }
            // The confirmation: per-nation breakdown and total.
            Text(String(format: "%d NATION%@ · TOTAL %@", plan.lines.count, plan.lines.count == 1 ? "" : "S",
                        kind == .garrison ? "\(Int(plan.total))K MORE TROOPS" : String(format: "$%.2fB", plan.total)))
                .font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalGreen)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(plan.lines.prefix(12), id: \.self) { l in
                    Text(verbatim: "\(l.name): \(l.detail)").font(ThemeFont.mono(9)).foregroundColor(Theme.isRetro ? EGA.white : .white).lineLimit(1)
                }
                if plan.lines.count > 12 { Text("…and \(plan.lines.count - 12) more").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan) }
            }
            if let problem = plan.problem { Text(verbatim: problem).font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalRed) }
            HStack {
                Button("CANCEL") { dismiss() }.buttonStyle(ThemedButtonStyle())
                Spacer()
                Button("CONFIRM \(kind.title.uppercased()) FOR \(plan.lines.count)") {
                    if gameEngine.executeGroupAction(kind, members: members, amount: kind == .garrison ? garrison : amount, split: split,
                                                     groupName: selector.title, rate: rate) != nil { dismiss() }
                }
                .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalAmber, prominent: true))
                .disabled(plan.problem != nil)
            }
        }
        .padding(16)
        .frame(width: FontScale.w(820))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }

    private func pickButton(_ title: String, _ p: Pick) -> some View {
        Button(title) { pick = p }.buttonStyle(ThemedButtonStyle(prominent: pick == p))
    }

    private func picker(_ all: [Country]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 2) {
            ForEach(all, id: \.id) { c in
                Button { if handPicked.contains(c.id) { handPicked.remove(c.id) } else { handPicked.insert(c.id) } } label: {
                    Text(verbatim: "\(handPicked.contains(c.id) ? "☑" : "☐") \(c.name)").font(ThemeFont.mono(9))
                        .foregroundColor(handPicked.contains(c.id) ? GTNWColors.terminalAmber : (Theme.isRetro ? EGA.white : .white)).lineLimit(1)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Coalitions and scenario scorecards (3.12.0)

/// Ask allies and friends to join an operation against the selected country: each with its odds of joining.
struct CoalitionSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    let targetID: String

    var body: some View {
        let odds = gameEngine.coalitionOdds(against: targetID)
        let current = gameState.shadow.coalitions[targetID]
        let name = gameState.getCountry(id: targetID)?.name ?? targetID
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.3.sequence.fill")
                Text(verbatim: "COALITION AGAINST \(name.uppercased())")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            Text("Members send troops to the front and share the world's reaction. Authorization from the legislature and a real casus belli help; chemical or biological weapons drive allies away. Those who refuse cool a little.")
                .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan).fixedSize(horizontal: false, vertical: true)
            if let c = current, !c.members.isEmpty {
                Text(verbatim: "IN THE COALITION: " + c.members.compactMap { gameState.getCountry(id: $0)?.name }.joined(separator: ", "))
                    .font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalGreen).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 1) {
                ForEach(odds.prefix(16), id: \.id) { o in
                    HStack {
                        Text(verbatim: gameState.getCountry(id: o.id)?.name ?? o.id).font(ThemeFont.mono(10)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                        Spacer()
                        Text("\(Int(o.odds * 100))%").font(ThemeFont.mono(10, .bold))
                            .foregroundColor(o.odds >= 0.5 ? GTNWColors.terminalGreen : (o.odds >= 0.2 ? GTNWColors.terminalAmber : GTNWColors.terminalRed))
                    }
                }
                if odds.count > 16 { Text("…and \(odds.count - 16) more").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan) }
                if odds.isEmpty { Text("Nobody to ask: no allies or friends outside the target's camp.").font(ThemeFont.mono(10)).foregroundColor(GTNWColors.terminalRed) }
            }
            HStack {
                Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle())
                Spacer()
                Button("ASK \(odds.count) NATION\(odds.count == 1 ? "" : "S") TO JOIN") { if gameEngine.requestCoalition(against: targetID) != nil { dismiss() } }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalAmber, prominent: true))
                    .disabled(odds.isEmpty || gameState.actionsRemaining == 0)
            }
        }
        .padding(16)
        .frame(width: FontScale.w(640))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}

/// A historical scenario's scorecard: history against this game, line by line.
struct ScorecardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState

    var body: some View {
        let id = gameState.shadow.scenarioID ?? ""
        let lines = Scorecard.lines(for: id, in: gameState)
        let score = Scorecard.score(lines)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.bullet.clipboard.fill")
                Text(verbatim: "SCORECARD — \((ScenarioDefinition.find(id)?.title ?? "SANDBOX").uppercased())")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            Text("YOU MATCHED HISTORY ON \(score.matched) OF \(score.total)").font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalGreen)
            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                Text("HISTORY").frame(width: FontScale.w(230), alignment: .leading)
                Text("THIS GAME").frame(width: FontScale.w(90), alignment: .leading)
            }
            .font(ThemeFont.mono(9, .bold)).foregroundColor(GTNWColors.neonCyan)
            ForEach(lines, id: \.self) { l in
                HStack(alignment: .top) {
                    Text(verbatim: l.label).font(ThemeFont.mono(11, .bold)).foregroundColor(Theme.isRetro ? EGA.white : .white).frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: l.historical).font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan).frame(width: FontScale.w(230), alignment: .leading)
                    Text(verbatim: l.player + (l.matchesHistory == false ? " ≠" : "")).font(ThemeFont.mono(11, .bold))
                        .foregroundColor(l.matchesHistory == false ? GTNWColors.terminalAmber : GTNWColors.terminalGreen).frame(width: FontScale.w(90), alignment: .leading)
                }
            }
            if lines.isEmpty { Text("No scorecard for a sandbox game.").font(ThemeFont.mono(11)).foregroundColor(GTNWColors.neonCyan) }
            HStack { Spacer(); Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle()) }
        }
        .padding(16)
        .frame(width: FontScale.w(700))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}

// MARK: - Historical acquisitions (3.13.0)

/// Purchases open in their real windows (Louisiana 1803, Florida 1819, Gadsden 1853, Alaska 1867, the Danish West
/// Indies 1917): accept one for its historical price.
struct AcquisitionSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState

    var body: some View {
        let offers = gameEngine.openAcquisitions()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "signature")
                Text("LAND FOR SALE")
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(11, .bold))
            }
            .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            if offers.isEmpty { Text("No offers on the table this year.").font(ThemeFont.mono(11)).foregroundColor(GTNWColors.neonCyan) }
            ForEach(offers) { a in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: a.name.uppercased()).font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalGreen)
                        Text(verbatim: "Seller: \(gameState.getCountry(id: a.owner)?.name ?? a.owner) · price \(a.price) · window \(a.from)–\(a.to - 1)")
                            .font(ThemeFont.mono(10)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                        Text(a.land.isEmpty ? "Inside today's U.S. outline: adds its resources and score." : "Adds the land as U.S. territory.")
                            .font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                    }
                    Spacer()
                    Button("ACCEPT") { if gameEngine.acceptAcquisition(a.id) { dismiss() } }
                        .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen, prominent: true))
                        .disabled(gameState.actionsRemaining == 0)
                }
                .padding(6).themedPanel()
            }
            HStack { Spacer(); Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle()) }
        }
        .padding(16)
        .frame(width: FontScale.w(620))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}

// MARK: - Treaty offers (3.14.0)

/// Treaties other nations have proposed: accept or decline each (they lapse after three months).
struct TreatyOffersSheet: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TREATY OFFERS").font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
            if gameState.shadow.treatyOffers.isEmpty {
                Text("No offers on the table.").font(ThemeFont.mono(11)).foregroundColor(GTNWColors.neonCyan)
            }
            ForEach(gameState.shadow.treatyOffers) { o in
                HStack {
                    Text(verbatim: "\(gameState.getCountry(id: o.from)?.name ?? o.from): \(o.type.rawValue)")
                        .font(ThemeFont.mono(11, .bold)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                    Spacer()
                    Button("ACCEPT") { gameEngine.answerTreaty(o.id, accept: true) }
                        .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen, prominent: true))
                    Button("DECLINE") { gameEngine.answerTreaty(o.id, accept: false) }.buttonStyle(ThemedButtonStyle())
                }
                .padding(4).themedPanel(retroFill: EGA.black)
            }
            HStack { Spacer(); Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle()) }
        }
        .padding(16)
        .frame(width: FontScale.w(560))
        .background(Theme.isRetro ? EGA.blue : Color.black)
    }
}
