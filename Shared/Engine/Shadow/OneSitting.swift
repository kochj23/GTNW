//
//  OneSitting.swift
//  Global Thermal Nuclear War
//
//  3.32.3: a game that finishes in one evening. It is not a new system — it is the dated scenarios and
//  techno-thrillers already in Scenarios.swift, started with the turn length the crisis actually ran at and a
//  stated number of turns, so the arc closes while you are still at the desk: six to ten turns, then the clock
//  stops, the scorecard is read against history (or against the thriller's objectives) and the debrief
//  (Chronicle.swift) says what was believed at the time and what was true.
//  You pick the crisis, not the century.
//  Turn counts and lengths are design choices, chosen so each crisis resolves inside its window.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// One crisis, sized for a single sitting.
struct OneSitting: Identifiable, Hashable {
    let id: String
    /// The scenario it is built on.
    let scenario: String
    let title: String
    /// What a sitting is judged on, in a line.
    let goal: String
    let turns: Int
    let turnLength: TurnLength

    var definition: ScenarioDefinition? { ScenarioDefinition.find(scenario) }

    static let all: [OneSitting] = [
        OneSitting(id: "sit_cuba", scenario: "cuba1962", title: "Thirteen Days",
                   goal: "Get the missiles out of Cuba without a war.", turns: 10, turnLength: .day),
        OneSitting(id: "sit_berlin", scenario: "berlin1948", title: "The Airlift",
                   goal: "Keep West Berlin fed and the Soviets out of it.", turns: 8, turnLength: .week),
        OneSitting(id: "sit_gulf", scenario: "gulf1990", title: "Desert Shield",
                   goal: "Get Iraq out of Kuwait and hold the coalition together.", turns: 10, turnLength: .week),
        OneSitting(id: "sit_korea", scenario: "korea1950", title: "The Pusan Perimeter",
                   goal: "Hold Korea without bringing China or the bomb into it.", turns: 10, turnLength: .week),
        OneSitting(id: "sit_sept11", scenario: "sept11_2001", title: "The Day After",
                   goal: "Answer the attack without losing the world's sympathy.", turns: 8, turnLength: .week),
        OneSitting(id: "sit_pearl", scenario: "pearl1941", title: "After Pearl Harbor",
                   goal: "Take the country to war and keep it together.", turns: 8, turnLength: .month),
        OneSitting(id: "sit_able", scenario: "ablearcher1983", title: "Able Archer",
                   goal: "Finish the exercise without convincing Moscow it is the real thing.", turns: 6, turnLength: .day),
        OneSitting(id: "sit_blackout", scenario: "blackout2026", title: "Blackout",
                   goal: "Find out who turned the lights off before you answer for it.", turns: 6, turnLength: .day),
    ]

    static func find(_ id: String) -> OneSitting? { all.first { $0.id == id } }
}

extension GameEngine {
    /// Start a one-sitting game: the scenario's board, its own turn length, and a stated number of turns.
    func startOneSitting(_ s: OneSitting, difficulty: DifficultyLevel = .normal, player: String = "USA") {
        guard let def = s.definition else { return }
        startScenario(def, difficulty: difficulty, turnLength: s.turnLength, player: player)
        guard let gs = gameState else { return }
        gs.shadow.sittingID = s.id
        gs.shadow.sittingTurns = s.turns
        gs.shadow.post("ONE SITTING: \(s.title). \(s.goal) You have \(s.turns) turns.", date: gs.currentDate, severity: 2)
        addLog("⏱ ONE SITTING — \(s.title.uppercased()): \(s.goal) \(s.turns) turns.", type: .system)
        logPlayEvent("one_sitting_start", detail: ["sitting": s.id, "scenario": s.scenario, "turns": s.turns,
                                                  "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
    }

    /// Each turn: has the sitting run out? If so, read the scorecard, write the debrief and close the presidency —
    /// a finish, not a defeat (3.28.0's served-out ending).
    func checkOneSitting() {
        guard let gs = gameState, let id = gs.shadow.sittingID, let s = OneSitting.find(id),
              gs.shadow.domesticEnding == nil, gs.turn >= s.turns else { return }
        let card = Scorecard.lines(for: s.scenario, in: gs)
        let met = card.filter { $0.matchesHistory == true }.count
        var out = ["ONE SITTING: \(s.title) — \(met) of \(card.count) lines match the goal."]
        out += card.map { "\($0.label): \($0.historical) · you: \($0.player)" }
        out += Debrief.lines(gs).map { "\($0.title): \($0.body)" }
        gs.shadow.sittingDebrief = out
        for line in out.prefix(12) { gs.shadow.post(line, date: gs.currentDate, severity: 1) }
        addLog("⏱ THE SITTING IS OVER — \(met)/\(card.count) against the goal.", type: .system)
        logPlayEvent("one_sitting_over", detail: ["sitting": s.id, "met": met, "lines": card.count,
                                                 "turns": gs.turn, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        endPresidency(.retired)
    }
}
