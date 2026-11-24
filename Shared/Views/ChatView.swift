//
//  ChatView.swift
//  Global Thermal Nuclear War
//
//  3.35.0: the conversation with the chief of staff, opened from the prompt line under the map or its shortcut (⌘K by
//  default). Modern skin: a briefing-room chat; Retro skin: a terminal transcript. Replies stream in; orders arrive
//  as a numbered plan card (EXECUTE ALL, one step at a time, remove a step, EDIT, CANCEL; a nuclear order needs a
//  second press). Clarifying questions come back as choices. Both skins, any text size, VoiceOver, Reduce Motion.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var session: ChatSession
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Rectangle().fill(GTNWColors.neonCyan.opacity(0.4)).frame(height: 1).accessibilityHidden(true)
            transcript
            inputRow
            footer
        }
        .padding(14)
        #if os(macOS)
        .frame(width: FontScale.w(820), height: FontScale.h(680))
        #endif
        .background(CommandBoxStyle.background)
        .onAppear {
            session.attach(gameEngine)
            if !GameStoreService.isTestOrSmokeRun { DispatchQueue.main.async { focused = true } }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Theme.isRetro ? "CHIEF OF STAFF — SECURE LINE" : "CHIEF OF STAFF")
                .font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("CLOSE") { dismiss() }
                .buttonStyle(ThemedButtonStyle())
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close the conversation")
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if session.entries.isEmpty { ChatWelcome() }
                    ForEach(session.entries) { e in
                        VStack(alignment: .leading, spacing: 6) {
                            ChatLine(entry: e)
                            if let id = e.planID, let plan = session.plans[id] {
                                ChatPlanCard(plan: plan, session: session)
                            } else if let s = e.planSummary, e.planID == nil || session.plans[e.planID ?? -1] == nil {
                                Text(verbatim: "Plan: \(s)").font(ThemeFont.mono(10)).foregroundColor(CommandBoxStyle.text.opacity(0.6))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .id(e.id)
                    }
                    if session.busy { ChatDraft(text: session.draft).id("draft") }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: session.entries.count) { _ in scrollToEnd(proxy) }
            .onChange(of: session.draft) { _ in scrollToEnd(proxy) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        if session.busy { proxy.scrollTo("draft", anchor: .bottom) } else if let last = session.entries.last { proxy.scrollTo(last.id, anchor: .bottom) }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            Text(verbatim: CommandBoxStyle.prompt).font(ThemeFont.mono(14, .bold)).foregroundColor(GTNWColors.terminalAmber)
                .accessibilityHidden(true)
            TextField("Talk to your chief of staff", text: $session.input)
                .textFieldStyle(.plain)
                .font(ThemeFont.mono(14))
                .foregroundColor(GTNWColors.terminalGreen)
                .focused($focused)
                .disableAutocorrection(true)
                .onSubmit { session.send() }
                .onChange(of: session.input) { v in
                    if v.count > ChatRequestScreen.maxInput { session.input = String(v.prefix(ChatRequestScreen.maxInput)) }
                }
                .accessibilityLabel("Message to your chief of staff")
                .accessibilityHint("Ask a question, think out loud or give an order, then press Return.")
            if session.busy {
                Button("STOP") { session.stop() }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed))
                    .accessibilityLabel("Stop the reply")
            } else {
                Button("SEND") { session.send() }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen, prominent: true))
                    .disabled(session.input.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Send the message")
            }
        }
        .padding(8)
        .overlay(Rectangle().stroke(Theme.isRetro ? EGA.lightGray : GTNWColors.neonCyan.opacity(0.5), lineWidth: 1))
    }

    private var footer: some View {
        HStack {
            Text("Nothing runs until you press EXECUTE.")
            Spacer()
            if let l = session.lastLatency {
                Text(verbatim: l.first.map { String(format: "first word %.1f s · reply %.1f s", $0, l.total) } ?? String(format: "reply %.1f s", l.total))
            }
        }
        .font(ThemeFont.mono(9)).foregroundColor(CommandBoxStyle.text.opacity(0.6))
    }
}

/// The empty transcript: what the chief of staff can do.
struct ChatWelcome: View {
    var body: some View {
        CommandLines(lines: [
            "Talk it through. Ask what you'd ask a chief of staff:",
            "  How do we stand with France? · Who can hit us, and with what? · Why did my approval drop?",
            "  Strike their air bases, then blockade, then offer terms. · Do the same to Cuba. · How'd that go?",
            "Every order comes back as a card. Nothing runs until you press EXECUTE.",
        ], color: CommandBoxStyle.text.opacity(0.8))
    }
}

/// One line of the conversation.
struct ChatLine: View {
    let entry: ChatEntry

    var body: some View {
        if Theme.isRetro { retro } else { modern }
    }

    private var who: String {
        switch entry.role {
        case .player: return "You"
        case .staff: return "Chief of staff"
        case .note: return "Record"
        }
    }

    /// The terminal transcript.
    private var retro: some View {
        let prefix: String
        let color: Color
        switch entry.role {
        case .player: prefix = CommandBoxStyle.prompt + " "; color = EGA.lightGray
        case .staff: prefix = "COS> "; color = GTNWColors.terminalGreen
        case .note: prefix = "*** "; color = GTNWColors.terminalAmber
        }
        return Text(verbatim: prefix + entry.text).font(ThemeFont.mono(12)).foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .accessibilityLabel("\(who): \(entry.text)")
    }

    private var modern: some View {
        HStack {
            if entry.role == .player { Spacer(minLength: FontScale.w(80)) }
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: entry.role == .note ? "\(who) · \(entry.gameDate)" : who)
                    .font(ThemeFont.mono(9, .bold)).foregroundColor(CommandBoxStyle.text.opacity(0.6))
                Text(verbatim: entry.text).font(ThemeFont.mono(entry.role == .note ? 11 : 13))
                    .foregroundColor(entry.role == .note ? GTNWColors.terminalAmber : CommandBoxStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(entry.role == .player ? GTNWColors.neonCyan.opacity(0.15) : Color.white.opacity(0.05)))
            if entry.role != .player { Spacer(minLength: FontScale.w(40)) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(who): \(entry.text)")
    }
}

/// The reply as it streams in.
struct ChatDraft: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if text.isEmpty {
                ProgressView().controlSize(.small)
                Text("Checking the reports…").font(ThemeFont.mono(12)).foregroundColor(GTNWColors.neonCyan)
            } else {
                Text(verbatim: (Theme.isRetro ? "COS> " : "") + text).font(ThemeFont.mono(13)).foregroundColor(CommandBoxStyle.text.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                BlinkingCursor()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text.isEmpty ? "Your chief of staff is checking the reports" : "Reply in progress: \(text)")
    }
}

/// A numbered plan: each step's card, and the buttons. Nothing runs until EXECUTE (twice for nuclear).
struct ChatPlanCard: View {
    let plan: ChatPlan
    @ObservedObject var session: ChatSession

    private var armedAll: Bool { session.isArmed(plan: plan.id, step: nil) }
    private var ready: Bool { plan.steps.contains(where: \.isReady) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: plan.steps.count == 1 ? "ORDER FOR CONFIRMATION" : "PLAN: \(plan.steps.count) STEPS")
                .font(ThemeFont.mono(13, .bold)).foregroundColor(GTNWColors.terminalAmber)
                .accessibilityAddTraits(.isHeader)
            ForEach(plan.steps) { step in
                ChatStepView(planID: plan.id, step: step, numbered: plan.steps.count > 1, session: session)
            }
            if ready {
                Text(verbatim: "Uses \(plan.actionsNeeded) action\(plan.actionsNeeded == 1 ? "" : "s"); \(gameActionsLeft) left.")
                    .font(ThemeFont.mono(11)).foregroundColor(CommandBoxStyle.text.opacity(0.8))
                if armedAll {
                    Text("Nuclear release armed. Press CONFIRM NUCLEAR RELEASE to launch, or CANCEL.")
                        .font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    Button(plan.nuclear ? (armedAll ? "CONFIRM NUCLEAR RELEASE" : "EXECUTE (NUCLEAR)") : (plan.steps.count > 1 ? "EXECUTE ALL" : "EXECUTE")) {
                        session.execute(plan: plan.id)
                    }
                    .buttonStyle(ThemedButtonStyle(color: plan.nuclear ? GTNWColors.terminalRed : GTNWColors.terminalGreen, prominent: true))
                    .accessibilityLabel(plan.nuclear ? (armedAll ? "Confirm nuclear release" : "Execute nuclear orders, first confirmation") : "Execute the plan")
                    Button("EDIT") { session.edit(plan: plan.id) }.buttonStyle(ThemedButtonStyle())
                        .accessibilityLabel("Edit the plan in words")
                    Button("CANCEL") { session.cancel(plan: plan.id) }.buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed))
                        .accessibilityLabel("Cancel the plan")
                }
            }
        }
        .padding(12)
        .themedPanel(accent: plan.nuclear ? GTNWColors.terminalRed : GTNWColors.neonCyan, retroFill: EGA.blue)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Plan for confirmation")
    }

    private var gameActionsLeft: Int { session.engine?.gameState?.actionsRemaining ?? 0 }
}

struct ChatStepView: View {
    let planID: Int
    let step: ChatPlanStep
    let numbered: Bool
    @ObservedObject var session: ChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            switch step.outcome {
            case .plan(let p):
                Text(verbatim: (numbered ? "\(step.id). " : "") + "\(p.title): \(p.target)")
                    .font(ThemeFont.mono(13, .bold)).foregroundColor(p.nuclear ? GTNWColors.terminalRed : GTNWColors.terminalAmber)
                    .fixedSize(horizontal: false, vertical: true)
                lines(p.committed, GTNWColors.terminalGreen)
                lines(p.heldBack, GTNWColors.neonCyan)
                lines(p.warnings.map { "! " + $0.text }, nil, levels: p.warnings.map(\.level))
                if let r = step.execution {
                    Text(verbatim: r.carried.isEmpty ? "NOT CARRIED OUT" : "CARRIED OUT: \(r.carried.count) order\(r.carried.count == 1 ? "" : "s")"
                         + (r.refused.isEmpty ? "" : " · \(r.refused.count) refused") + (r.notReached.isEmpty ? "" : " · \(r.notReached.count) not reached"))
                        .font(ThemeFont.mono(11, .bold)).foregroundColor(r.carried.isEmpty ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
                } else if numbered {
                    HStack(spacing: 8) {
                        let armed = session.isArmed(plan: planID, step: step.id)
                        Button(p.nuclear ? (armed ? "CONFIRM RELEASE" : "EXECUTE STEP (NUCLEAR)") : "EXECUTE STEP") {
                            session.execute(plan: planID, step: step.id)
                        }
                        .buttonStyle(ThemedButtonStyle(color: p.nuclear ? GTNWColors.terminalRed : GTNWColors.terminalGreen))
                        .accessibilityLabel("Execute step \(step.id) only")
                        Button("REMOVE") { session.remove(plan: planID, step: step.id) }
                            .buttonStyle(ThemedButtonStyle())
                            .accessibilityLabel("Remove step \(step.id)")
                    }
                }
            case .clarify(let c):
                ClarificationView(clarification: c, onPick: { session.choose(plan: planID, step: step.id, option: $0) },
                                  onCancel: { session.remove(plan: planID, step: step.id) })
            case .rejected(let why):
                Text(verbatim: (numbered ? "\(step.id). " : "") + "Not possible: \(why)").font(ThemeFont.mono(12)).foregroundColor(GTNWColors.terminalAmber)
                    .fixedSize(horizontal: false, vertical: true)
            case .answer(let l):
                CommandLines(lines: l, color: CommandBoxStyle.text)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func lines(_ ls: [String], _ color: Color?, levels: [Int] = []) -> some View {
        ForEach(Array(ls.enumerated()), id: \.offset) { i, l in
            Text(verbatim: l).font(ThemeFont.mono(12))
                .foregroundColor(color ?? CommandBoxStyle.color(level: levels.indices.contains(i) ? levels[i] : 0))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
