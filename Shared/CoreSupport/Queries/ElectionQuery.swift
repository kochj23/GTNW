//
//  ElectionQuery.swift
//  GTNWCore
//
//  `{"q":"election"}`: the presidential election cycle under the law of its year (ElectionRules, ElectionCycle):
//  every stage with its date or why that year's law has none, the campaign so far, the last result (the app's
//  ElectionNightView) and a domestic ending (DomesticEndingBanner). The stages' choices themselves arrive as crisis
//  cards (`state.crisis`), as in the app.
//

#if GTNW_CORE
import Foundation

enum ElectionQuery: BridgeQuery {
    static let name = "election"

    struct Stage: Encodable {
        var id: String
        var label: String
        var year: Int
        /// nil: this year's law has no such step.
        var date: String?
        var daysAway: Int?
        /// past, next, upcoming, none
        var status: String
    }

    struct Rules: Encodable {
        var year: Int
        var nomination: String
        var electors: Int
        var majority: Int
        var popularVote: Bool
        var ticket: Bool
        var debates: Bool
        var vpDebate: Bool
        var termLimited: Bool
        var electionDay: String
        var electorsMeet: String
        var count: String
        var inauguration: String
        var notes: [String]
    }

    struct Campaign: Encodable {
        var running: Bool
        var party: String
        var incumbent: String
        var opponent: String?
        var runningMate: String?
        var challenger: String?
        var momentum: Double
        var delegateShare: Double?
        var termsWon: Int
        var leaveOfficeOn: String?
        var leaveReason: String?
        var midterms: [String]
    }

    struct Night: Encodable {
        var date: String
        var won: Bool
        var playerName: String
        var opponentName: String
        var playerFigure: String
        var opponentFigure: String
        var playerEV: Int?
        var opponentEV: Int?
        var thirdEV: Int?
        var totalEV: Int?
        var majority: Int?
        var detail: String?
        var verdict: String
    }

    struct Result: Encodable {
        var usa: Bool
        var electionsEnabled: Bool
        var electionLine: String
        var rules: Rules?
        var stages: [Stage]
        var campaign: Campaign?
        var lastElection: Night?
        var ending: String?
        var endingTitle: String?
        var endingHeadline: String?
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let usa = gs.playerCountryID == "USA"
        let now = gs.currentDate
        var stages: [Stage] = []
        var rules: Rules?
        var campaign: Campaign?
        if usa {
            let y = GameCalendar.year(of: GameCalendar.nextElection(after: now))
            let r = ElectionRules(year: y)
            rules = Rules(year: y, nomination: nominationLabel(r.nomination), electors: r.electors, majority: r.majority,
                          popularVote: r.hasPopularVote, ticket: r.hasTicket, debates: r.hasDebates, vpDebate: r.hasVPDebate,
                          termLimited: r.termLimited, electionDay: GameCalendar.format(r.electionDay),
                          electorsMeet: GameCalendar.format(r.electorsMeet), count: GameCalendar.format(r.countDay),
                          inauguration: GameCalendar.format(r.inauguration), notes: notes(r))
            var rows: [(ElectionStage, Int)] = []
            if y - 2 >= 1790 { rows += [(.midtermCampaign, y - 2), (.midtermNight, y - 2)] }
            rows += ElectionStage.allCases.filter { !$0.isMidterm }.map { ($0, y) }
            var nextMarked = false
            for (s, year) in rows {
                let d = ElectionCycle.date(of: s, year: year)
                var status = "none"
                if let d {
                    if d <= now { status = "past" } else if !nextMarked { status = "next"; nextMarked = true } else { status = "upcoming" }
                }
                // Midterms already behind the cycle are only shown when they happened in this game.
                if s.isMidterm, status == "past", gs.shadow.campaign.midtermResults[year] == nil { continue }
                stages.append(Stage(id: s.rawValue, label: s.label(year: year), year: year, date: d.map(GameCalendar.format),
                                    daysAway: d.map { GameCalendar.days(from: now, to: $0) }, status: status))
            }
            let c = gs.shadow.campaign
            campaign = Campaign(running: c.running, party: c.party.name, incumbent: c.incumbent, opponent: c.opponent, runningMate: c.runningMate,
                                challenger: c.challenger, momentum: QueryText.round2(c.momentum), delegateShare: c.delegateShare.map(QueryText.round2),
                                termsWon: gs.shadow.termsWon, leaveOfficeOn: c.leaveOfficeOn.map(GameCalendar.format),
                                leaveReason: c.leaveReason?.headline,
                                midterms: c.midtermResults.keys.sorted().map { "\($0): \(seats(c.midtermResults[$0] ?? 0))" })
        }
        let ending = gs.shadow.domesticEnding
        return Result(usa: usa, electionsEnabled: gs.shadow.electionsEnabled, electionLine: TopBarQuery.electionLine(gs),
                      rules: rules, stages: stages, campaign: campaign, lastElection: gs.shadow.lastElection.map(night),
                      ending: ending?.rawValue, endingTitle: ending.map(endingTitle), endingHeadline: ending?.headline)
    }

    static func seats(_ n: Int) -> String { n == 0 ? "no change in seats" : (n > 0 ? "gained \(n) seats" : "lost \(-n) seats") }

    static func nominationLabel(_ m: NominationMethod) -> String {
        switch m {
        case .acclamation: return "No parties: the electors choose (acclamation)"
        case .congressionalCaucus: return "Congressional caucus (\"King Caucus\")"
        case .stateLegislatures: return "State legislatures and mass meetings"
        case .convention: return "National conventions (delegates chosen by party leaders)"
        case .conventionAndPrimaries: return "Conventions, with a few binding primaries"
        case .primaries: return "Binding primaries and caucuses"
        }
    }

    static func notes(_ r: ElectionRules) -> [String] {
        var out: [String] = []
        if !r.hasPopularVote { out.append("Most electors are chosen by state legislatures; no national popular vote is recorded.") }
        if !r.hasTicket { out.append("Before the 12th Amendment the runner-up becomes Vice President.") }
        if r.termLimited { out.append("The 22nd Amendment: no one is elected President more than twice.") }
        if r.hasDebates { out.append(r.hasVPDebate ? "Televised debates, including the running mates." : "Televised debates between the nominees.") }
        if r.year < 1845 { out.append("States choose electors over several weeks; there is no single election day.") }
        return out
    }

    /// ElectionNightView's figures, detail line and verdict.
    static func night(_ r: ElectionResult) -> Night {
        func figure(_ ev: Int?, _ share: Double) -> String {
            if let ev { return r.popularVoteRecorded == false ? "\(ev) EV" : String(format: "%d EV · %.1f%%", ev, share) }
            return String(format: "%.1f%%", share)
        }
        var detail: String?
        if let total = r.totalEV {
            var parts = ["\(total / 2 + 1) electoral votes to win, of \(total)"]
            if let n = r.thirdName, let x = r.thirdEV { parts.append(String(format: "%@ %d EV, %.1f%%", n, x, r.thirdShare ?? 0)) }
            if r.popularVoteRecorded == false { parts.append("most electors chosen by state legislatures; no national popular vote") }
            if let by = r.decidedBy { parts.append("decided by \(by)") }
            detail = parts.joined(separator: " · ")
        }
        let verdict: String
        if r.playerName != nil {
            verdict = r.won ? "Your party holds the White House. Your own term still ends on Inauguration Day." : "Your party loses the White House. Your term ends on Inauguration Day."
        } else {
            verdict = r.won ? "Four more years. The Situation Room stays yours — don't waste it." : "The voters have chosen someone else. You are a lame duck until Inauguration Day."
        }
        return Night(date: GameCalendar.format(r.date), won: r.won, playerName: r.playerName ?? "You", opponentName: r.opponentName,
                     playerFigure: figure(r.playerEV, r.playerShare), opponentFigure: figure(r.opponentEV, r.opponentShare),
                     playerEV: r.playerEV, opponentEV: r.opponentEV, thirdEV: r.thirdEV, totalEV: r.totalEV,
                     majority: r.totalEV.map { $0 / 2 + 1 }, detail: detail, verdict: verdict)
    }

    /// DomesticEndingBanner's drawn caption.
    static func endingTitle(_ e: DomesticEnding) -> String {
        switch e {
        case .impeached: return "ACCESS DENIED"
        case .assassinated: return "THE PRESIDENT IS DEAD"
        case .lostElection: return "DEFEATED AT THE POLLS"
        case .termLimited: return "TERM-LIMITED"
        case .retired: return "RETIRED FROM OFFICE"
        case .deniedRenomination: return "DENIED RENOMINATION"
        case .civilWar: return "CIVIL WAR"
        case .noConfidence: return "NO CONFIDENCE"
        case .coup: return "COUP D'ÉTAT"
        case .revolution: return "REVOLUTION"
        case .partyCongress: return "REMOVED BY THE PARTY"
        case .juntaDecision: return "REPLACED BY THE JUNTA"
        case .royalDismissal: return "DISMISSED BY THE CROWN"
        }
    }
}
#endif
