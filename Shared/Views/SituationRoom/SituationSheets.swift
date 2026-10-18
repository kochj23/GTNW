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
