//
//  StateElection.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the Electoral College, state by state. The national two-party share (the popularity model, the campaign,
//  the debates) is the starting point in every state; each state then leans its own way (a steady lean for a
//  generation, then a realignment), swings a little on the night, and swings against a President it is restless
//  under or whose name for it it never chose. Winner takes all, so a close national vote is decided by a handful of
//  close states. Electors are the real ones for each election (`USStatesHistory`); a state the Union does not hold
//  (seceded, or under another flag) casts none, and a state the President admitted casts three. Deterministic: the
//  only draw is the existing night-of noise, and the leans come from a fixed hash of the state and the era.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

extension ElectionCycle {
    /// The states with electors in an election year, as history had them.
    static func historicalElectorate(year: Int) -> [String: Int] {
        var out: [String: Int] = [:]
        for id in USStatesHistory.electors.keys {
            if let e = USStatesHistory.electors(id, year: year), e > 0 { out[id] = e }
        }
        return out
    }

    /// A state's steady lean (points toward the President's ticket, before centering): it holds for a generation.
    static func lean(_ id: String, year: Int) -> Double {
        6 * Subdivisions.unit("lean:\(id):\(year / 24)")
    }

    static func stateTally(year: Int, share: Double, thirdPopular: Double, stateNoise: Double, electorate: [String: Int],
                           swing: [String: Double]) -> Tally {
        let ids = electorate.keys.sorted()
        let electors = electorate.values.reduce(0, +)
        // Leans are centered on the electors, so the states together vote about as the nation does.
        let leans = Dictionary(uniqueKeysWithValues: ids.map { ($0, lean($0, year: year)) })
        let mean = ids.reduce(0) { $0 + leans[$1]! * Double(electorate[$1]!) } / Double(max(1, electors))
        let night = Int((stateNoise * 1000).rounded())
        var shares: [String: Double] = [:]
        for id in ids {
            let s = share + leans[id]! - mean + 2.5 * unitNight(id, year, night) + stateNoise * 1.5 + (swing[id] ?? 0)
            shares[id] = min(95, max(5, (s * 10).rounded() / 10))
        }
        // A strong third candidate carries states where it runs best (a fixed regional pull), up to its share.
        var thirdStates: Set<String> = []
        if thirdPopular >= 10 {
            let target = Int((Double(electors) * (thirdPopular - 8) * 1.2 / 100).rounded())
            var got = 0
            for id in ids.sorted(by: { (Subdivisions.unit("third:\($0):\(year / 24)"), $0) > (Subdivisions.unit("third:\($1):\(year / 24)"), $1) }) {
                guard got < target else { break }
                thirdStates.insert(id)
                got += electorate[id]!
            }
        }
        var pEV = 0, oEV = 0, tEV = 0
        for id in ids {
            let e = electorate[id]!
            if thirdStates.contains(id) { tEV += e } else if shares[id]! > 50 { pEV += e } else { oEV += e }
        }
        let scale = (100 - thirdPopular) / 100
        return Tally(playerEV: pEV, opponentEV: oEV, thirdEV: tEV,
                     playerPopular: share * scale, opponentPopular: (100 - share) * scale, thirdPopular: thirdPopular,
                     electors: electors, majority: electors / 2 + 1,
                     shares: shares, stateElectors: electorate, thirdStates: thirdStates)
    }

    /// The night's own swing in one state, -1…1.
    private static func unitNight(_ id: String, _ year: Int, _ night: Int) -> Double {
        Subdivisions.unit("night:\(id):\(year):\(night)")
    }

    /// The state that put the winner over the top: the winner's states from safest to closest, until a majority.
    static func tippingState(_ t: Tally) -> String? {
        let winnerIsPlayer = t.outcome == .won
        guard t.outcome != .noMajority else { return nil }
        let theirs = t.shares.filter { !t.thirdStates.contains($0.key) && (winnerIsPlayer ? $0.value > 50 : $0.value <= 50) }
        let order = theirs.sorted { a, b in
            let ma = winnerIsPlayer ? a.value : 100 - a.value, mb = winnerIsPlayer ? b.value : 100 - b.value
            return (ma, b.key) > (mb, a.key)
        }
        var sum = 0
        for (id, _) in order {
            sum += t.stateElectors[id] ?? 0
            if sum >= t.majority { return id }
        }
        return nil
    }
}

extension GameState {
    /// The states that vote on an election day: states of the Union the U.S. holds (the historical electors for the
    /// year; the District from 1964), and three electors for each land the President had admitted. Nil when the
    /// player is not the United States (history's electorate is used).
    func electorate(on day: Date) -> [String: Int]? {
        guard playerCountryID == "USA" else { return nil }
        let year = GameCalendar.year(of: day)
        var out: [String: Int] = [:]
        for s in Subdivisions.byNation["USA"] ?? [] where provinceOwner(s.id) == "USA" {
            guard Subdivisions.isUSState(s.id, on: day) || s.id == "US-DC" else { continue }
            if let e = USStatesHistory.electors(s.id, year: year), e > 0 { out[s.id] = e }
        }
        for r in shadow.statesAdmitted where out[r.id] == nil { out[r.id] = 3 }
        return out
    }

    /// Each state's own swing against the President: restless states, and states he renamed.
    func stateSwing() -> [String: Double] {
        var out: [String: Double] = [:]
        for s in Subdivisions.byNation["USA"] ?? [] {
            let v = -(shadow.provinces.unrest[s.id] ?? 0) * 0.06 - (shadow.provinces.names[s.id] != nil ? 2 : 0)
            if v != 0 { out[s.id] = v }
        }
        return out
    }
}

extension GameEngine {
    /// Keep the night's state map (for the end screen and the map) and tell the news which state decided it.
    func recordStateResults(_ t: ElectionCycle.Tally, year: Int, opponent: String, on day: Date) {
        guard let gs = gameState, !t.shares.isEmpty else { return }
        gs.shadow.provinces.lastElection = t.shares
        gs.shadow.provinces.lastElectionYear = year
        gs.shadow.provinces.thirdCarried = t.thirdStates
        let carried = t.shares.filter { !t.thirdStates.contains($0.key) && $0.value > 50 }.count
        let lost = t.shares.count - carried - t.thirdStates.count
        func name(_ id: String) -> String { gs.getCountry(id: id)?.name ?? gs.provinceName(id) }
        if let tip = ElectionCycle.tippingState(t), let s = t.shares[tip] {
            let close = abs(s - 50) < 1.5 ? "by a whisker, " : ""
            gs.shadow.post(String(format: "Election map: %d states for you, %d for %@%@. It turned on %@, %@%.1f%% to %.1f%%.",
                                  carried, lost, opponent, t.thirdStates.isEmpty ? "" : ", \(t.thirdStates.count) for the third candidate",
                                  name(tip), close, s, 100 - s), date: day, severity: 2)
        } else {
            gs.shadow.post("Election map: \(carried) states for you, \(lost) for \(opponent), \(t.thirdStates.count) for the third candidate.",
                           date: day, severity: 2)
        }
        self.gameState = gs
    }
}
