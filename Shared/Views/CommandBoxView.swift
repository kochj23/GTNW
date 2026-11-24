//
//  CommandBoxView.swift
//  Global Thermal Nuclear War
//
//  3.34.0: the command box. A prompt line under the Situation Room map (and a rebindable shortcut, ⌘K by default)
//  opens it; the player types an order or a question. The built-in parser reads common phrasings; the local model
//  translates the rest. Orders come back as a confirmation card (target, forces committed and held back, warnings)
//  with EXECUTE, EDIT and CANCEL; nuclear orders need a second confirmation; ambiguous names come back as a question.
//  Questions are answered from the game state. Works in both skins, at any text size, with VoiceOver and Reduce Motion.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

// MARK: - Model

@MainActor
final class CommandBoxModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case thinking
        case answer([String])
        case clarify(Clarification)
        /// `armed`: a nuclear plan's first EXECUTE; the second carries it out.
        case confirm(CommandPlan, armed: Bool)
        case done(GameEngine.CommandExecution)
        case rejected(String)
    }

    @Published var text = ""
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var history: [String] = []
    /// Seconds the local model took on the last command it translated.
    @Published private(set) var lastLatency: TimeInterval?
    private var historyIndex: Int?
    private(set) var lastSubmitted = ""

    weak var engine: GameEngine?
    /// The local-model reader; tests inject a stub. Created on first use.
    var translator: CommandTranslating?

    static let historyCap = 50

    init(engine: GameEngine? = nil, translator: CommandTranslating? = nil) {
        self.engine = engine
        self.translator = translator
    }

    /// Read the command: the built-in parser first, the local model only when the parser can't place it.
    func submit() async {
        let raw = CommandParser.sanitize(text)
        guard !raw.isEmpty, let engine, let gs = engine.gameState else { return }
        remember(raw)
        lastSubmitted = raw
        text = ""
        if let intent = CommandParser.parse(raw) {
            phase = Self.phase(for: engine.planCommand(intent, source: .parser))
            return
        }
        phase = .thinking
        let t: CommandTranslating
        if let translator { t = translator } else { let o = OllamaCommandTranslator(); translator = o; t = o }
        let result = await t.translate(raw, context: CommandContext(year: gs.currentYear, playerName: gs.getPlayerCountry()?.name ?? ""))
        switch result {
        case .intent(let intent, let latency):
            lastLatency = latency
            phase = Self.phase(for: engine.planCommand(intent, source: .model))
        case .unknown(let latency):
            lastLatency = latency
            phase = .rejected("No order or question the game knows matches that. Type HELP for examples.")
        case .unavailable(let why):
            phase = .rejected("The built-in reader didn't recognize that, and \(why), so only the built-in phrasings work right now. "
                              + "Try \"attack France with air forces\", \"sanction Spain\" or HELP.")
        }
    }

    static func phase(for outcome: CommandOutcome) -> Phase {
        switch outcome {
        case .plan(let p): return .confirm(p, armed: false)
        case .clarify(let c): return .clarify(c)
        case .answer(let lines): return .answer(lines)
        case .rejected(let why): return .rejected(why)
        }
    }

    func choose(_ option: ClarifyOption) {
        guard case .clarify(let c) = phase, let engine else { return }
        phase = Self.phase(for: engine.planCommand(option.intent, source: c.source))
    }

    /// EXECUTE. A nuclear plan arms on the first press and is carried out on the second.
    func execute() {
        guard case .confirm(let plan, let armed) = phase, let engine else { return }
        if plan.nuclear && !armed {
            phase = .confirm(plan, armed: true)
            return
        }
        phase = .done(engine.executeCommand(plan.orders, source: plan.source))
    }

    /// EDIT: the command back in the field.
    func edit() {
        text = lastSubmitted
        phase = .idle
    }

    func cancel() {
        phase = .idle
        text = ""
    }

    // MARK: History (up / down arrow)

    private func remember(_ s: String) {
        if history.last != s { history.append(s) }
        if history.count > Self.historyCap { history.removeFirst(history.count - Self.historyCap) }
        historyIndex = nil
    }

    func historyUp() {
        guard !history.isEmpty else { return }
        let i = max(0, (historyIndex ?? history.count) - 1)
        historyIndex = i
        text = history[i]
    }

    func historyDown() {
        guard let i = historyIndex else { return }
        if i + 1 < history.count {
            historyIndex = i + 1
            text = history[i + 1]
        } else {
            historyIndex = nil
            text = ""
        }
    }
}

// MARK: - Look

enum CommandBoxStyle {
    static var prompt: String { Theme.isRetro ? "C:\\GTNW>" : ">" }
    static var cursor: String { Theme.isRetro ? "█" : "_" }
    static var background: Color { Theme.isRetro ? EGA.black : Color.black }
    static var text: Color { Theme.isRetro ? EGA.lightGray : Color.white }

    static func color(level: Int) -> Color {
        switch level {
        case 2: return GTNWColors.terminalRed
        case 1: return GTNWColors.terminalAmber
        default: return GTNWColors.neonCyan
        }
    }
}

/// The terminal cursor. Blinks; holds still with Reduce Motion.
struct BlinkingCursor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let period = 0.53

    var body: some View {
        Group {
            if reduceMotion || Motion.reduced {
                Text(CommandBoxStyle.cursor)
            } else {
                TimelineView(.periodic(from: .now, by: Self.period)) { ctx in
                    Text(CommandBoxStyle.cursor)
                        .opacity(Int(ctx.date.timeIntervalSinceReferenceDate / Self.period) % 2 == 0 ? 1 : 0)
                }
            }
        }
        .font(ThemeFont.mono(13, .bold))
        .foregroundColor(GTNWColors.terminalGreen)
        .accessibilityHidden(true)
    }
}

/// The prompt line under the map. Opens the command box.
struct CommandPromptBar: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var keys = KeyBindingStore.shared

    var body: some View {
        let key = keys.binding(for: .commandBox)
        Button { gameEngine.commandBoxOpen = true } label: {
            HStack(spacing: 6) {
                Text(verbatim: CommandBoxStyle.prompt).font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber)
                BlinkingCursor()
                Text("Talk to your chief of staff")
                    .font(ThemeFont.mono(11)).foregroundColor(CommandBoxStyle.text.opacity(0.75))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(verbatim: key.display).font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.neonCyan)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CommandBoxStyle.background)
            .overlay(Rectangle().stroke(Theme.isRetro ? EGA.lightGray : GTNWColors.neonCyan.opacity(0.4), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chief of staff")
        .accessibilityHint("Talk it through, ask, or give an order. Shortcut \(key.spoken).")
        #if os(iOS)
        .gameShortcut(.commandBox, store: keys)
        #endif
    }
}

// MARK: - The box

struct CommandBoxView: View {
    @ObservedObject var model: CommandBoxModel
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("COMMAND").font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("CLOSE") { dismiss() }
                    .buttonStyle(ThemedButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close the command box")
            }
            promptRow
            Text("Orders and questions in plain English. HELP lists examples. Nothing runs until you press EXECUTE.")
                .font(ThemeFont.mono(10)).foregroundColor(CommandBoxStyle.text.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(GTNWColors.neonCyan.opacity(0.4)).frame(height: 1).accessibilityHidden(true)
            ScrollView {
                CommandOutputView(model: model)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(width: FontScale.w(760), height: FontScale.h(560))
        #endif
        .background(CommandBoxStyle.background)
        .onAppear {
            if model.engine == nil { model.engine = gameEngine }
            // Offscreen renders (tests) have no window to focus; SwiftUI warns if they try.
            if !GameStoreService.isTestOrSmokeRun { DispatchQueue.main.async { focused = true } }
        }
    }

    private var promptRow: some View {
        HStack(spacing: 8) {
            Text(verbatim: CommandBoxStyle.prompt).font(ThemeFont.mono(14, .bold)).foregroundColor(GTNWColors.terminalAmber)
                .accessibilityHidden(true)
            TextField("attack France with all non-nuclear forces", text: $model.text)
                .textFieldStyle(.plain)
                .font(ThemeFont.mono(14))
                .foregroundColor(GTNWColors.terminalGreen)
                .focused($focused)
                .disableAutocorrection(true)
                .onSubmit { Task { await model.submit() } }
                .modifier(HistoryKeys(up: { model.historyUp() }, down: { model.historyDown() }))
                .onChange(of: model.text) { v in
                    if v.count > CommandParser.maxInput { model.text = String(v.prefix(CommandParser.maxInput)) }
                }
                .accessibilityLabel("Command")
                .accessibilityHint("Type an order or a question, then press Return. Up arrow recalls earlier commands.")
            Button { model.historyUp() } label: { Image(systemName: "arrow.up") }
                .buttonStyle(ThemedButtonStyle())
                .disabled(model.history.isEmpty)
                .accessibilityLabel("Previous command")
            Button("RUN") { Task { await model.submit() } }
                .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen, prominent: true))
                .disabled(model.phase == .thinking)
                .accessibilityLabel("Run the command")
        }
        .padding(8)
        .overlay(Rectangle().stroke(Theme.isRetro ? EGA.lightGray : GTNWColors.neonCyan.opacity(0.5), lineWidth: 1))
    }
}

/// Up / down arrow in the command field walk the history.
private struct HistoryKeys: ViewModifier {
    let up: () -> Void
    let down: () -> Void

    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            content
                .onKeyPress(.upArrow) { up(); return .handled }
                .onKeyPress(.downArrow) { down(); return .handled }
        } else {
            content.onMoveCommand { d in
                if d == .up { up() } else if d == .down { down() }
            }
        }
        #else
        if #available(iOS 17.0, *) {
            content
                .onKeyPress(.upArrow) { up(); return .handled }
                .onKeyPress(.downArrow) { down(); return .handled }
        } else {
            content
        }
        #endif
    }
}

/// Whatever the last command produced.
struct CommandOutputView: View {
    @ObservedObject var model: CommandBoxModel

    var body: some View {
        switch model.phase {
        case .idle:
            CommandLines(lines: model.history.isEmpty ? Array(CommandHelp.lines.prefix(4)) : ["Ready."], color: CommandBoxStyle.text.opacity(0.8))
        case .thinking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Asking the local model to read that…").font(ThemeFont.mono(12)).foregroundColor(GTNWColors.neonCyan)
            }
            .accessibilityElement(children: .combine)
        case .answer(let lines):
            CommandLines(lines: lines, color: CommandBoxStyle.text)
        case .rejected(let why):
            CommandLines(lines: [why], color: GTNWColors.terminalAmber)
                .accessibilityLabel("Not carried out. \(why)")
        case .clarify(let c):
            ClarificationView(clarification: c, onPick: { model.choose($0) }, onCancel: { model.cancel() })
        case .confirm(let plan, let armed):
            VStack(alignment: .leading, spacing: 6) {
                CommandCard(plan: plan, armed: armed, onExecute: { model.execute() }, onEdit: { model.edit() }, onCancel: { model.cancel() })
                if plan.source == .model, let l = model.lastLatency {
                    Text("Read by the local model in \(String(format: "%.1f", l)) s; checked by the game.")
                        .font(ThemeFont.mono(9)).foregroundColor(CommandBoxStyle.text.opacity(0.6))
                }
            }
        case .done(let r):
            CommandResultView(result: r)
        }
    }
}

struct CommandLines: View {
    let lines: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(verbatim: line).font(ThemeFont.mono(12)).foregroundColor(color)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ClarificationView: View {
    let clarification: Clarification
    let onPick: (ClarifyOption) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: clarification.question).font(ThemeFont.mono(13, .bold)).foregroundColor(GTNWColors.terminalAmber)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(clarification.options) { o in
                Button { onPick(o) } label: {
                    Text(verbatim: o.label).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                }
                .buttonStyle(ThemedButtonStyle())
                .accessibilityLabel("Choose \(o.label)")
            }
            Button("CANCEL") { onCancel() }.buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed))
                .accessibilityLabel("Cancel the command")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Question")
    }
}

/// The confirmation card: nothing runs until EXECUTE (twice for nuclear orders).
struct CommandCard: View {
    let plan: CommandPlan
    let armed: Bool
    let onExecute: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void

    private var executeTitle: String {
        plan.nuclear ? (armed ? "CONFIRM NUCLEAR RELEASE" : "EXECUTE (NUCLEAR)") : "EXECUTE"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "\(plan.title): \(plan.target)").font(ThemeFont.mono(14, .bold)).foregroundColor(GTNWColors.terminalAmber)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            section("COMMITTED", plan.committed.map { ($0, GTNWColors.terminalGreen) })
            if !plan.heldBack.isEmpty { section("HELD BACK", plan.heldBack.map { ($0, GTNWColors.neonCyan) }) }
            if !plan.warnings.isEmpty { section("WARNINGS", plan.warnings.map { ("! " + $0.text, CommandBoxStyle.color(level: $0.level)) }) }
            Text(verbatim: "Uses \(plan.actionsNeeded) action\(plan.actionsNeeded == 1 ? "" : "s"); \(plan.actionsLeft) left.")
                .font(ThemeFont.mono(11)).foregroundColor(CommandBoxStyle.text.opacity(0.8))
            if armed {
                Text("Nuclear release armed. Press CONFIRM NUCLEAR RELEASE to launch, or CANCEL.")
                    .font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button(executeTitle) { onExecute() }
                    .buttonStyle(ThemedButtonStyle(color: plan.nuclear ? GTNWColors.terminalRed : GTNWColors.terminalGreen, prominent: true))
                    .accessibilityLabel(plan.nuclear ? (armed ? "Confirm nuclear release" : "Execute nuclear orders, first confirmation") : "Execute the orders")
                Button("EDIT") { onEdit() }.buttonStyle(ThemedButtonStyle())
                    .accessibilityLabel("Edit the command")
                Button("CANCEL") { onCancel() }.buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed))
                    .accessibilityLabel("Cancel the command")
            }
        }
        .padding(12)
        .themedPanel(accent: plan.nuclear ? GTNWColors.terminalRed : GTNWColors.neonCyan, retroFill: EGA.blue)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Order confirmation")
    }

    private func section(_ title: String, _ lines: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(ThemeFont.mono(10, .bold)).foregroundColor(CommandBoxStyle.text.opacity(0.7))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                Text(verbatim: l.0).font(ThemeFont.mono(12)).foregroundColor(l.1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CommandResultView: View {
    let result: GameEngine.CommandExecution

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.carried.isEmpty ? "NOTHING CARRIED OUT" : "CARRIED OUT: \(result.carried.count) order\(result.carried.count == 1 ? "" : "s")")
                .font(ThemeFont.mono(13, .bold))
                .foregroundColor(result.carried.isEmpty ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
            if !result.refused.isEmpty {
                Text("Refused by the engine: \(result.refused.count) (no action spent).").font(ThemeFont.mono(11)).foregroundColor(GTNWColors.terminalAmber)
            }
            if !result.notReached.isEmpty {
                Text("Not reached, out of actions: \(result.notReached.count).").font(ThemeFont.mono(11)).foregroundColor(GTNWColors.terminalAmber)
            }
            CommandLines(lines: result.lines.suffix(40).map { "> " + $0 }, color: CommandBoxStyle.text)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Result")
    }
}
