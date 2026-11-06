//
//  ElectionCycle.swift
//  Global Thermal Nuclear War
//
//  3.21.0: the whole American election, not one dice roll on a Tuesday in November. Each cycle walks the President
//  through the steps the law and the parties of that year actually had — the decision to run, the King Caucus or the
//  primaries (Iowa, New Hampshire, Super Tuesday), a challenger from their own party, the running mate, the
//  convention, the fall campaign, the debates, the October surprise, election night and the Electoral College,
//  a House contingent election or a contested count, the electors, the count in Congress, and Inauguration Day.
//  Midterms come every other November. Every step is a ticker notice; the ones that matter are decisions.
//  The 22nd Amendment (1951) ends a two-term presidency at the next inauguration — and the game tells you years ahead.
//  Created by Jordan Koch.
//

import Foundation

/// The steps of a presidential (and midterm) election cycle.
enum ElectionStage: String, Codable, CaseIterable {
    case decision, challenge, iowa, newHampshire, superTuesday, primariesEnd
    case runningMate, opponentConvention, convention, campaignLaunch
    case debate1, vpDebate, debate2, octoberSurprise
    case electionNight, electorsMeet, count, inauguration
    case midtermCampaign, midtermNight

    var isMidterm: Bool { self == .midtermCampaign || self == .midtermNight }

    /// Short label for the Situation Room countdown.
    func label(year: Int) -> String {
        switch self {
        case .decision: return "DECISION TO RUN"
        case .challenge: return "PRIMARY CHALLENGE"
        case .iowa: return "IOWA CAUCUSES"
        case .newHampshire: return "NEW HAMPSHIRE PRIMARY"
        case .superTuesday: return "SUPER TUESDAY"
        case .primariesEnd: return "FINAL PRIMARIES"
        case .runningMate: return "RUNNING MATE"
        case .opponentConvention: return "OPPOSITION CONVENTION"
        case .convention:
            switch NominationMethod.forYear(year) {
            case .congressionalCaucus: return "CONGRESSIONAL CAUCUS"
            case .stateLegislatures: return "NOMINATIONS"
            default: return "YOUR CONVENTION"
            }
        case .campaignLaunch: return "FALL CAMPAIGN"
        case .debate1: return "FIRST DEBATE"
        case .vpDebate: return "VP DEBATE"
        case .debate2: return "FINAL DEBATE"
        case .octoberSurprise: return "FINAL STRETCH"
        case .electionNight: return "ELECTION"
        case .electorsMeet: return "ELECTORS VOTE"
        case .count: return "CONGRESS COUNTS"
        case .inauguration: return "INAUGURATION"
        case .midtermCampaign: return "MIDTERM CAMPAIGN"
        case .midtermNight: return "MIDTERMS"
        }
    }
}

/// Everything the campaign remembers between turns. Lives on ShadowState.
struct CampaignState: Codable {
    var initialized = false
    /// Stages already fired, keyed "year.stage".
    var fired: Set<String> = []
    /// The election year now being contested.
    var year = 0
    /// Points of vote share earned (or lost) by campaign choices this cycle.
    var momentum: Double = 0
    var debatePrep: String?
    var debateScore: Double = 0
    /// False once the President retires, withdraws, is denied renomination, or is term-limited.
    var running = true
    var party: PartyCode = .none
    var incumbent: String = ""
    /// Presidential elections the President had already won when the game began (Reagan in 1985: one).
    var electedBeforeStart = 0
    var succeededMidTerm = false
    /// Served more than two years of someone else's term (22nd Amendment: may be elected only once).
    var inheritedOverTwoYears = false
    /// Truman was exempt from the 22nd Amendment as the sitting President when it was ratified.
    var exemptFromTermLimit = false
    var challenger: String?
    var challengerStrength: Double = 0
    /// Share of the delegates won so far against a challenger (nil until the first contest).
    var delegateShare: Double?
    var contests = 0
    var opponent: String?
    var runningMate: String?
    /// The day the President leaves office (a lame duck), and why.
    var leaveOfficeOn: Date?
    var leaveReason: DomesticEnding?
    /// Effort put into the midterms (House seats).
    var midtermEffort: Double = 0
    /// No candidate won a majority of electors: the House decides on the count day.
    var houseContingent = false
    var houseLobby: Double = 0
    var successorBoost: Double = 0
    /// House seats won or lost at each midterm, by year.
    var midtermResults: [Int: Int] = [:]
}

/// A one-shot election notice or decision produced when a stage fires.
struct ElectionBeat {
    var headline: String
    var severity: Int = 1
    var card: CrisisEvent?
}

enum ElectionCycle {

    // MARK: Schedule

    /// The date of a stage in election year `year`, or nil when that stage did not exist in that era.
    static func date(of stage: ElectionStage, year: Int) -> Date? {
        let r = ElectionRules(year: year)
        let midterm = year % 4 == 2, presidential = year % 4 == 0
        if stage.isMidterm != midterm || (!stage.isMidterm && !presidential) { return nil }
        let d = { (m: Int, day: Int) in GameCalendar.date(year: year, month: m, day: day) }
        let method = r.nomination
        switch stage {
        case .decision:
            switch year {
            case 1972...: return GameCalendar.date(year: year - 1, month: 4, day: 15)
            case 1912...1971: return GameCalendar.date(year: year - 1, month: 11, day: 15)
            default: return d(1, 15)
            }
        case .challenge:
            guard method != .acclamation else { return nil }
            return year >= 1912 ? GameCalendar.date(year: year - 1, month: 12, day: 1) : d(2, 1)
        case .iowa: return r.iowaFirst ? d(1, 20) : nil
        case .newHampshire: return r.newHampshirePrimary ? (year >= 1972 ? d(2, 20) : d(3, 10)) : nil
        case .superTuesday: return r.superTuesday ? d(3, 5) : nil
        case .primariesEnd: return year >= 1912 ? d(6, 5) : nil
        case .runningMate:
            guard r.hasTicket, let c = date(of: .convention, year: year) else { return nil }
            return GameCalendar.calendar.date(byAdding: .day, value: -10, to: c)
        case .opponentConvention:
            guard year >= 1832 else { return nil }
            return year >= 1952 ? d(7, 15) : (year >= 1900 ? d(7, 10) : d(6, 20))
        case .convention:
            switch method {
            case .acclamation: return nil
            case .congressionalCaucus: return d(2, 25)
            case .stateLegislatures: return d(6, 1)
            default: return year >= 2008 ? d(8, 22) : (year >= 1952 ? d(8, 20) : (year >= 1900 ? d(6, 25) : d(6, 5)))
            }
        case .campaignLaunch: return d(9, 5)
        case .debate1: return r.hasDebates ? (year == 1960 ? d(9, 26) : d(10, 1)) : nil
        case .vpDebate: return r.hasVPDebate ? d(10, 7) : nil
        case .debate2: return r.hasDebates ? d(10, 15) : nil
        case .octoberSurprise: return d(10, 22)
        case .electionNight: return r.electionDay
        case .electorsMeet: return year < 1845 ? nil : r.electorsMeet   // before 1845 the electors met on "election night"
        case .count: return r.countDay
        case .inauguration: return r.inauguration
        case .midtermCampaign: return d(9, 10)
        case .midtermNight: return GameCalendar.electionDay(year: year)
        }
    }

    /// Every stage falling in (from, to], oldest first, across the cycles that can touch that window.
    static func stages(from: Date, to: Date) -> [(year: Int, stage: ElectionStage, date: Date)] {
        let y0 = GameCalendar.year(of: from) - 1, y1 = GameCalendar.year(of: to) + 1
        var out: [(Int, ElectionStage, Date)] = []
        for y in y0...y1 {
            for s in ElectionStage.allCases {
                if let d = date(of: s, year: y), d > from, d <= to { out.append((y, s, d)) }
            }
        }
        return out.sorted { $0.2 < $1.2 }.map { (year: $0.0, stage: $0.1, date: $0.2) }
    }

    /// The next stage after `date` (for the countdown).
    static func next(after date: Date) -> (year: Int, stage: ElectionStage, date: Date)? {
        let horizon = GameCalendar.calendar.date(byAdding: .year, value: 3, to: date) ?? date
        return stages(from: date, to: horizon).first
    }

    static func key(_ year: Int, _ stage: ElectionStage) -> String { "\(year).\(stage.rawValue)" }

    // MARK: Eligibility

    /// Presidential elections the President has won, counting the ones before the game began.
    static func timesElected(_ c: CampaignState, termsWon: Int) -> Int { c.electedBeforeStart + termsWon }

    /// True when the 22nd Amendment bars the President from the `year` ballot.
    static func termLimited(_ c: CampaignState, termsWon: Int, year: Int) -> Bool {
        guard ElectionRules(year: year).termLimited, !c.exemptFromTermLimit else { return false }
        let elected = timesElected(c, termsWon: termsWon)
        return elected >= 2 || (c.inheritedOverTwoYears && elected >= 1)
    }

    /// Seed the campaign from the administration being played: party, name, and terms already won.
    static func seed(_ c: inout CampaignState, administration: Administration?, start: Date) {
        let startYear = GameCalendar.year(of: start)
        guard let admin = administration else { c.party = .republican; c.incumbent = "the President"; return }
        c.party = PartyCode.from(label: admin.party)
        c.incumbent = admin.president
        c.succeededMidTerm = ElectionHistory.successors.contains(admin.president)
        c.inheritedOverTwoYears = ElectionHistory.overTwoYearSuccessors.contains(admin.president)
        c.exemptFromTermLimit = admin.president == "Harry S. Truman"
        // A President elected in Y took office in Y+1; a successor's first own election came later.
        let firstElection = c.succeededMidTerm ? admin.startYear + 1 : admin.startYear - 1
        var won = 0
        var y = firstElection
        while y < startYear || (y == startYear && GameCalendar.electionDay(year: y) < start) {
            if y % 4 == 0 && y >= 1788 { won += 1 }
            y += 1
        }
        // Non-consecutive terms (Cleveland, Trump) are separate administrations: count the earlier ones too.
        for earlier in Advisor.allAdministrations() where earlier.president == admin.president && earlier.startYear < admin.startYear {
            won += stride(from: earlier.startYear - 1, to: earlier.endYear - 1, by: 1).filter { $0 % 4 == 0 }.count
        }
        c.electedBeforeStart = won
    }

    // MARK: Vote math

    struct Tally: Equatable {
        var playerEV: Int
        var opponentEV: Int
        var thirdEV: Int
        var playerPopular: Double
        var opponentPopular: Double
        var thirdPopular: Double
        var electors: Int
        var majority: Int

        var outcome: Outcome {
            if playerEV >= majority { return .won }
            if opponentEV >= majority { return .lost }
            return .noMajority
        }
        enum Outcome { case won, lost, noMajority }
    }

    /// Turn a two-party vote share (percent, for the President's ticket) into a popular vote and an Electoral
    /// College count. Winner-take-all states amplify a popular lead (a cube-law curve, exponent 6); `stateNoise` in
    /// -1…1 shifts the Electoral College against the popular vote by up to ±1.5 points, so a popular-vote winner can
    /// lose the College, as in 1824, 1876, 1888, 2000 and 2016.
    static func tally(year: Int, twoPartyShare share: Double, thirdPopular: Double = 0, stateNoise: Double = 0) -> Tally {
        let electors = ElectionHistory.electors(year)
        let thirdEV = thirdPopular >= 10 ? Int((Double(electors) * (thirdPopular - 8) * 1.2 / 100).rounded()) : 0
        let remaining = electors - thirdEV
        let s = min(0.99, max(0.01, share / 100 + stateNoise * 0.015))
        let k = 6.0
        let frac = pow(s, k) / (pow(s, k) + pow(1 - s, k))
        let pEV = Int((Double(remaining) * frac).rounded())
        let scale = (100 - thirdPopular) / 100
        return Tally(playerEV: pEV, opponentEV: remaining - pEV, thirdEV: thirdEV,
                     playerPopular: share * scale, opponentPopular: (100 - share) * scale, thirdPopular: thirdPopular,
                     electors: electors, majority: ElectionHistory.majority(year))
    }

    /// The President's two-party share on election night.
    static func voteShare(popularity: Double, termsWon: Int, campaign c: CampaignState, year: Int, noise: Double) -> Double {
        var s = PopularityModel.voteShare(popularity: popularity, termsWon: termsWon + c.electedBeforeStart, noise: noise)
        s += c.momentum + c.debateScore
        // Before the 22nd Amendment, breaking Washington's two-term tradition cost votes (FDR still won in 1940).
        if !ElectionRules(year: year).termLimited && timesElected(c, termsWon: termsWon) >= 2 { s -= 3 }
        return min(78, max(22, s))
    }

    /// One primary, caucus or convention ballot against a challenger: the President's share of the delegates.
    static func contestShare(popularity: Double, momentum: Double, strength: Double, noise: Double) -> Double {
        min(92, max(8, 50 + (popularity - 42) * 1.1 + momentum * 1.5 - strength * 22 + noise * 8))
    }

    /// House seats the President's party gains (+) or loses (−) at a midterm. Since 1946 the average is about −25;
    /// only 1934, 1998 and 2002 went the other way.
    static func midtermSeats(popularity: Double, effort: Double, atWar: Bool, noise: Double) -> Int {
        let base = -25 + (popularity - 50) * 1.3 + effort + (atWar && popularity > 50 ? 4 : 0) + noise * 10
        return Int(base.rounded())
    }

    /// Momentum carried by a party's choice of running mate etc. is a `gamble` choice: "gamble|good|bad|p|winText|loseText".
    static func gamble(_ good: Double, _ bad: Double, _ p: Double, _ win: String, _ lose: String) -> String {
        "gamble|\(good)|\(bad)|\(p)|\(win)|\(lose)"
    }

    // MARK: Opponents

    static func opponentName(year: Int, party: PartyCode, incumbent: String) -> String {
        let other = party.opposition(in: year)
        if let n = ElectionHistory.nominees[year]?[other], n != incumbent { return n }
        if let n = ElectionHistory.nominees[year]?.first(where: { $0.value != incumbent && $0.key != party })?.value { return n }
        return PopularityModel.challenger(for: year)
    }

    static func intraPartyChallenger(year: Int, party: PartyCode, popularity: Double, roll: Double) -> (String, Double)? {
        if let h = ElectionHistory.nominationChallengers["\(year)|\(party.rawValue)"] { return (h.name, h.strength) }
        guard year >= 1796 else { return nil }
        let p = min(0.85, max(0.03, (48 - popularity) / 28))
        guard roll < p else { return nil }
        let names = ["Sen. Lyle Brandvold", "Gov. Ada Pennington", "Rep. Silas Ortega", "Sen. Corinne Haverford",
                     "Gov. Ephraim Tull", "Sen. Naomi Ratcliffe", "Gov. Burke Delahunt", "Sen. Isadora Quell"]
        return (names[abs(year / 4) % names.count], min(0.8, 0.25 + max(0, 45 - popularity) / 45))
    }

    // MARK: Cards

    static func card(_ title: String, _ text: String, _ options: [CrisisOption], severity: CrisisSeverity = .serious, turn: Int) -> CrisisEvent {
        var c = CrisisEvent(type: .election, severity: severity, title: title, description: text,
                            affectedCountries: ["USA"], turn: turn, options: options)
        c.quoteTags = [.election, .leadership, .power]
        return c
    }

    static func option(_ title: String, _ text: String, momentum: Double = 0, approval: Int = 0, choice: String? = nil,
                       advisor: String? = nil) -> CrisisOption {
        CrisisOption(title: title, description: text, advisorRecommendation: advisor,
                     consequences: CrisisConsequences(approvalChange: approval, message: title,
                                                      campaign: momentum == 0 ? nil : momentum, electionChoice: choice))
    }
}

// MARK: - Engine wiring

extension GameEngine {

    /// Advance the election calendar for this turn: fire each stage that fell inside it.
    func processElectionCycle(from: Date, to: Date) {
        guard let gs = gameState, gs.shadow.electionsEnabled else { return }
        if !gs.shadow.campaign.initialized { initializeCampaign(asOf: from) }
        for s in ElectionCycle.stages(from: from, to: to) {
            guard gs.shadow.domesticEnding == nil else { break }
            let k = ElectionCycle.key(s.year, s.stage)
            guard !gs.shadow.campaign.fired.contains(k) else { continue }
            gs.shadow.campaign.fired.insert(k)
            fireElectionStage(s.stage, year: s.year, on: s.date)
        }
        self.gameState = gs
    }

    /// First call in a game (or an older save): learn who the President is and mark every past stage as done.
    func initializeCampaign(asOf date: Date) {
        guard let gs = gameState else { return }
        var c = CampaignState()
        let admin = Advisor.allAdministrations().last { $0.startYear <= gs.eraStartYear }
        ElectionCycle.seed(&c, administration: admin, start: gs.startDate)
        c.initialized = true
        let start = GameCalendar.date(year: 1780, month: 1, day: 1)
        for s in ElectionCycle.stages(from: start, to: date) { c.fired.insert(ElectionCycle.key(s.year, s.stage)) }
        gs.shadow.campaign = c
        // Tell the President where they stand right away.
        if let next = ElectionCycle.next(after: date) {
            let y = next.stage.isMidterm ? next.year + 2 : next.year
            if ElectionCycle.termLimited(c, termsWon: gs.shadow.termsWon, year: y) {
                gs.shadow.post("The 22nd Amendment: you cannot be elected again. Your presidency ends on \(GameCalendar.format(ElectionRules(year: y).inauguration)).", date: date, severity: 2)
            } else {
                gs.shadow.post("ELECTION CALENDAR: \(next.stage.label(year: next.year).capitalized) on \(GameCalendar.format(next.date)). Election Day \(y): \(GameCalendar.format(ElectionRules(year: y).electionDay)).", date: date, severity: 1)
            }
        }
        self.gameState = gs
    }

    private func announce(_ text: String, severity: Int = 1, on date: Date) {
        guard let gs = gameState else { return }
        gs.shadow.post(text, date: date, severity: severity)
        addLog("🗳️ \(text)", type: severity >= 2 ? .critical : .info)
    }

    private func decide(_ c: CrisisEvent) {
        crisisManager.presentCrisis(c)
        addLog("🗳️ DECISION: \(c.title)", type: .critical)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func fireElectionStage(_ stage: ElectionStage, year: Int, on date: Date) {
        guard let gs = gameState else { return }
        var c = gs.shadow.campaign
        let rules = ElectionRules(year: year)
        let pop = gs.shadow.popularity
        let turn = gs.turn
        let player = gs.getPlayerCountry()
        let atWar = !(player?.atWarWith.isEmpty ?? true)
        let party = c.party == .none ? "" : "\(ElectionHistory.partyLabel(c.party, year: year)) "
        defer { gs.shadow.campaign = c; self.gameState = gs }

        if !stage.isMidterm && c.year != year && stage == .decision {
            // A new cycle.
            let keepLeave = c.leaveOfficeOn.map { $0 > date } ?? false
            c.year = year; c.momentum = 0; c.debatePrep = nil; c.debateScore = 0; c.challenger = nil
            c.challengerStrength = 0; c.delegateShare = nil; c.contests = 0; c.houseContingent = false; c.houseLobby = 0
            c.successorBoost = 0
            c.running = !keepLeave
            c.opponent = ElectionCycle.opponentName(year: year, party: c.party, incumbent: c.incumbent)
        }
        if !stage.isMidterm && c.year != year { c.year = year; c.opponent = ElectionCycle.opponentName(year: year, party: c.party, incumbent: c.incumbent) }
        let opponent = c.opponent ?? "the opposition"
        let limited = ElectionCycle.termLimited(c, termsWon: gs.shadow.termsWon, year: year)

        switch stage {
        case .decision:
            if c.leaveOfficeOn != nil { return }
            if limited {
                c.running = false
                c.leaveReason = .termLimited
                c.leaveOfficeOn = rules.inauguration
                announce("THE 22ND AMENDMENT: you cannot stand for a third term. Your presidency ends at noon on \(GameCalendar.format(rules.inauguration)).", severity: 3, on: date)
                decide(ElectionCycle.card("Your Last Campaign Is Someone Else's",
                    "You are term-limited. Your party will nominate a successor for \(year), and you have a lame-duck year to spend. How much of yourself do you put into their campaign?",
                    [ElectionCycle.option("Campaign hard for the nominee", "Rallies, fundraisers and your record on the stump.", choice: "successor|3", advisor: "Chief of Staff"),
                     ElectionCycle.option("Stay presidential", "Govern; let the nominee run their own race.", approval: 2),
                     ElectionCycle.option("Keep your distance", "A divisive President can be a drag on the ticket.", choice: "successor|-2")],
                    severity: .moderate, turn: turn))
                return
            }
            var text = "The \(year) election is \(GameCalendar.days(from: date, to: rules.electionDay)) days away. Your approval stands at \(Int(pop))%."
            if !rules.termLimited && ElectionCycle.timesElected(c, termsWon: gs.shadow.termsWon) >= 2 {
                text += " No President has broken Washington's two-term tradition lightly; a third run will cost you."
            }
            switch rules.nomination {
            case .acclamation: text += " There are no parties yet — the electors are expected to choose the man, not a platform."
            case .congressionalCaucus: text += " Your party's members of Congress will meet in caucus to name its candidate."
            case .stateLegislatures: text += " State legislatures and mass meetings, not a national caucus, will put names forward."
            case .convention: text += " Your party's national convention will decide; the delegates answer to state bosses."
            case .conventionAndPrimaries: text += " A handful of primaries will test you, but the convention decides."
            case .primaries: text += " Since 1972 the nomination is won in binding primaries and caucuses, starting in \(rules.iowaFirst ? "Iowa" : "New Hampshire")."
            }
            decide(ElectionCycle.card("Will You Seek Another Term?", text, [
                ElectionCycle.option("Announce for re-election", "File the papers and build the campaign.", momentum: 0.5, choice: "run", advisor: "Chief of Staff"),
                ElectionCycle.option("Announce early with a war chest", "Scare off rivals before they start.", momentum: 1, approval: -1, choice: "run"),
                ElectionCycle.option("Retire after this term", "Leave on your own terms. Your presidency ends on \(GameCalendar.format(rules.inauguration)).", choice: "retire")],
                severity: .critical, turn: turn))

        case .challenge:
            guard c.running, rules.nomination != .acclamation else { return }
            if let (name, strength) = ElectionCycle.intraPartyChallenger(year: year, party: c.party, popularity: pop, roll: Double.random(in: 0..<1)) {
                c.challenger = name; c.challengerStrength = strength
                announce("\(name.uppercased()) CHALLENGES YOU for the \(party)nomination.", severity: 3, on: date)
                decide(ElectionCycle.card("A Challenge From Your Own Party",
                    "\(name) is running against you for the \(party)nomination. Incumbents who face a serious primary fight usually go on to lose in November (Ford 1976, Carter 1980, Bush 1992).",
                    [ElectionCycle.option("Crush them early", "Money, endorsements, and pressure on the delegates.", momentum: 1, approval: -1, choice: "challenge|-0.1"),
                     ElectionCycle.option("Rise above it — govern", "The Rose Garden strategy: be the President, not a candidate.", choice: "challenge|0"),
                     ElectionCycle.option("Court the challenger's wing", "Adopt their cause; it costs you with the middle.", momentum: -0.5, choice: "challenge|-0.2")],
                    turn: turn))
            } else {
                announce("No serious rival steps forward for the \(party)nomination. The \(year) ticket is yours to lose.", on: date)
            }

        case .iowa, .newHampshire, .superTuesday, .primariesEnd:
            guard c.running else { return }
            let names: [ElectionStage: String] = [.iowa: "Iowa caucuses", .newHampshire: "New Hampshire primary",
                                                  .superTuesday: "Super Tuesday", .primariesEnd: "final primaries"]
            let name = names[stage] ?? "primary"
            guard let rival = c.challenger else {
                announce("\(name.capitalized): you run essentially unopposed and collect the delegates.", on: date)
                return
            }
            let share = ElectionCycle.contestShare(popularity: pop, momentum: c.momentum, strength: c.challengerStrength, noise: Double.random(in: -1...1))
            let weight = stage == .superTuesday || stage == .primariesEnd ? 3.0 : 1.0
            let prior = (c.delegateShare ?? 0) * Double(c.contests)
            c.contests += Int(weight)
            c.delegateShare = (prior + share * weight) / Double(c.contests)
            let verdict = share >= 50 ? "You win" : "\(rival) beats you"
            announce(String(format: "%@: %@, %.0f%% to %.0f%%. Delegates so far: %.0f%% yours.", name.uppercased(), verdict, share, 100 - share, c.delegateShare ?? share),
                     severity: share >= 50 ? 1 : 3, on: date)
            if share < 50 && stage != .primariesEnd {
                decide(ElectionCycle.card("Wounded in the \(name.capitalized)",
                    "\(rival) has beaten you. Truman left the race after New Hampshire in 1952; Johnson after it in 1968. Ford and Carter fought on and won the nomination — then lost in November.",
                    [ElectionCycle.option("Fight on to the convention", "Every delegate, every state.", momentum: -0.5, choice: "stayIn"),
                     ElectionCycle.option("Go negative on \(rival)", "Hit them hard before the next contest.", choice: ElectionCycle.gamble(1.5, -1.5, 0.5, "The attacks land.", "The attacks backfire.")),
                     ElectionCycle.option("Withdraw from the race", "\"I shall not seek, and I will not accept…\" You serve out your term until \(GameCalendar.format(rules.inauguration)).", choice: "retire")],
                    severity: .critical, turn: turn))
            }

        case .runningMate:
            guard c.running else { return }
            let vp = gs.advisors.first { $0.title.contains("Vice President") }?.name ?? "your Vice President"
            decide(ElectionCycle.card("Choosing a Running Mate",
                "The convention will ratify your choice for Vice President. \(year < 1940 ? "By custom the convention, not the nominee, names the second spot — but your word carries." : "The choice is yours alone.")",
                [ElectionCycle.option("Keep \(vp)", "Continuity. No surprises.", choice: "vp|\(vp)"),
                 ElectionCycle.option("Balance the ticket", "A running mate from another region and the other wing of the party.", momentum: 1.5, choice: "vp|a regional balance pick"),
                 ElectionCycle.option("Pick a rising star", "Electrifying if they hold up under scrutiny.",
                                      choice: ElectionCycle.gamble(2.5, -2, 0.65, "Your running mate electrifies the convention.", "Your running mate's past surfaces within the week."))],
                severity: .moderate, turn: turn))

        case .opponentConvention:
            if c.running || c.leaveReason == .termLimited || c.leaveReason == .retired {
                let bounce = Int.random(in: 2...6)
                c.momentum -= Double(bounce) * 0.25
                announce("The \(ElectionHistory.partyLabel(c.party.opposition(in: year), year: year)) convention nominates \(opponent.uppercased()). They leave with a \(bounce)-point bounce\(rules.televised ? " and prime-time coverage" : "").", severity: 2, on: date)
            }

        case .convention:
            if !c.running {
                if c.leaveReason == .termLimited || c.leaveReason == .retired {
                    announce("Your party nominates your successor. You address the convention as its elder statesman.", on: date)
                }
                return
            }
            if let rival = c.challenger {
                let ballot = c.delegateShare ?? ElectionCycle.contestShare(popularity: pop, momentum: c.momentum, strength: c.challengerStrength, noise: Double.random(in: -1...1))
                if ballot < 50 {
                    c.running = false
                    c.leaveReason = .deniedRenomination
                    c.leaveOfficeOn = rules.inauguration
                    announce("THE CONVENTION NOMINATES \(rival.uppercased()). You are denied your party's nomination, as Fillmore, Pierce, Andrew Johnson and Arthur were. Your presidency ends \(GameCalendar.format(rules.inauguration)).", severity: 3, on: date)
                    return
                }
                announce(String(format: "Renominated with %.0f%% of the delegates after a bruising fight with %@.", ballot, rival), severity: 2, on: date)
                c.momentum -= c.challengerStrength * 2   // a divided party
            } else {
                switch rules.nomination {
                case .congressionalCaucus: announce("The congressional caucus renominates you without dissent.", on: date)
                case .stateLegislatures: announce("Legislatures across the Union put your name forward.", on: date)
                default: announce("Your party's convention renominates you by acclamation.", on: date)
                }
            }
            let peace = !atWar && gs.defconLevel.rawValue >= 4
            let speech = rules.acceptsInPerson ? "Your acceptance speech" : "Your letter of acceptance (nominees did not attend until 1932)"
            decide(ElectionCycle.card("The Nomination Is Yours",
                "\(speech) sets the theme for the fall\(rules.televised ? ", in front of the largest television audience of the year" : "").",
                [ElectionCycle.option("Peace and prosperity", peace ? "The country is at peace. Remind them." : "Hard to sell in wartime.", momentum: peace ? 2.5 : 0.5),
                 ElectionCycle.option("Strength and security", atWar ? "Don't change horses in midstream." : "A steady hand in a dangerous world.", momentum: atWar ? 2.5 : 1.2),
                 ElectionCycle.option("Unite the party", c.challenger == nil ? "One party, one ticket." : "Heal the wounds of the primary fight.", momentum: c.challenger == nil ? 1 : 2.5),
                 ElectionCycle.option("Go after \(opponent)", "Red meat for the base; the middle flinches.", momentum: 2.5, approval: -2)],
                severity: .serious, turn: turn))

        case .campaignLaunch:
            if !c.running {
                if c.leaveOfficeOn != nil { announce("The fall campaign begins. You are not on the ballot.", on: date) }
                return
            }
            c.momentum *= 0.6   // convention bounces fade
            var opts: [CrisisOption] = []
            if year < 1932 { opts.append(ElectionCycle.option("Front-porch campaign", "Let the delegations come to you, as McKinley did in 1896.", momentum: 1)) }
            if (1880...1968).contains(year) { opts.append(ElectionCycle.option("Whistle-stop tour", "Thirty thousand miles by rail; give 'em hell (Truman, 1948).", momentum: 2, approval: -1)) }
            if (1924...1960).contains(year) { opts.append(ElectionCycle.option("Radio addresses", "Speak to the nation in its living rooms.", momentum: 1.5)) }
            if year >= 1952 { opts.append(ElectionCycle.option(year >= 2008 ? "Digital and TV ad blitz" : "Television ad blitz", "Spots in every swing market.", momentum: 2)) }
            if year >= 1960 { opts.append(ElectionCycle.option("Swing-state ground game", "Knock doors where the Electoral College is decided.", momentum: 1.5, choice: "ground")) }
            opts.append(ElectionCycle.option("Rose Garden strategy", "Stay at your desk and look presidential.", momentum: (pop - 50) / 8))
            opts.append(ElectionCycle.option("Go negative", "Define \(opponent) before they define themselves.", momentum: 2.5, approval: -3))
            decide(ElectionCycle.card("The Fall Campaign Begins",
                "Labor Day: \(GameCalendar.days(from: date, to: rules.electionDay)) days to the election. \(opponent) is on the trail. How do you run?",
                Array(opts.suffix(4)), turn: turn))

        case .debate1:
            guard c.running else { return }
            decide(ElectionCycle.card("Debate Preparation",
                year == 1960 ? "The first televised presidential debate. Radio listeners may judge on substance; the television audience will judge on how you look." : "Tens of millions will watch you and \(opponent) side by side.",
                [ElectionCycle.option("Weeks of mock debates", "A stand-in for \(opponent), hostile questions, and rehearsed answers.", choice: "debate|mock", advisor: "Chief of Staff"),
                 ElectionCycle.option("Run on your record", "You are the President. Act like it.", choice: "debate|record"),
                 ElectionCycle.option("Prepare zingers", "\"There you go again.\" One line can decide it.", choice: "debate|zingers")],
                severity: .moderate, turn: turn))

        case .debate2:
            guard c.running else { return }
            let (mean, spread): (Double, Double) = {
                switch c.debatePrep {
                case "mock": return (1, 1)
                case "zingers": return (0.8, 3)
                default: return (0.2, 2)
                }
            }()
            let result = mean + Double.random(in: -spread...spread)
            c.debateScore += result
            announce(String(format: "DEBATES: snap polls say you %@ (%+.1f).", result >= 0 ? "won" : "lost", result), severity: 2, on: date)

        case .vpDebate:
            guard c.running else { return }
            let r = Double.random(in: -1...1)
            c.debateScore += r * 0.5
            announce("Vice-presidential debate: \(r >= 0 ? "your running mate holds their own" : "your running mate stumbles").", on: date)

        case .octoberSurprise:
            guard c.running else { return }
            announce("\(GameCalendar.days(from: date, to: rules.electionDay)) DAYS TO ELECTION DAY.", severity: 2, on: date)
            guard Double.random(in: 0..<1) < 0.75 else { return }
            let pick = Int.random(in: 0..<5)
            let relief = year >= 1979 ? "FEMA" : "federal relief"
            switch pick {
            case 0:
                decide(ElectionCycle.card("October Surprise: A Leak",
                    "A leaked memo suggests your administration knew more, and sooner, than it said about a foreign crisis.",
                    [ElectionCycle.option("Own it in a press conference", "Take the hit now.", momentum: -0.5, approval: -1),
                     ElectionCycle.option("Deny everything", "It may die before Election Day.", choice: ElectionCycle.gamble(0, -3, 0.5, "The story dies.", "A second document surfaces."))],
                    severity: .critical, turn: turn))
            case 1:
                decide(ElectionCycle.card("October Surprise: A Deal Abroad",
                    "A hostile government signals it will release detained Americans before the election — for concessions.",
                    [ElectionCycle.option("Make the deal", "Bring them home. Critics will call it ransom.", momentum: 2, approval: 1, choice: "gamble|0|-1|0.8|They come home to cheering crowds.|The deal collapses at the airport."),
                     ElectionCycle.option("Refuse to be blackmailed", "Principle over politics.", momentum: -0.5)],
                    severity: .critical, turn: turn))
            case 2:
                decide(ElectionCycle.card("October Surprise: Bad Numbers",
                    "The last economic report before the election shows the economy shrinking.",
                    [ElectionCycle.option("Announce emergency relief", "Spend now; argue about it later.", momentum: 1.5, choice: "spend"),
                     ElectionCycle.option("Stay the course", "Blame the business cycle.", momentum: -1.5)],
                    turn: turn))
            case 3:
                decide(ElectionCycle.card("October Surprise: Opposition Research",
                    "Your campaign has a damaging story about \(opponent).",
                    [ElectionCycle.option("Release it", "Let the voters decide what it means.", choice: ElectionCycle.gamble(2, -2, 0.55, "The story sticks to \(opponent).", "It looks like a smear — and it's traced to you.")),
                     ElectionCycle.option("Take the high road", "Bury it.", momentum: 0.5)],
                    turn: turn))
            default:
                decide(ElectionCycle.card("October Surprise: A Storm at Home",
                    "A hurricane slams the Gulf Coast two weeks before the election.",
                    [ElectionCycle.option("Fly in and take charge", "Boots on the ground and \(relief) behind you.", momentum: 1.5, choice: "spend"),
                     ElectionCycle.option("Let the states and \(relief) handle it", "Stay on the trail.", momentum: -2)],
                    severity: .critical, turn: turn))
            }

        case .electionNight:
            gs.shadow.campaign = c
            holdElection(on: date)
            c = gs.shadow.campaign

        case .electorsMeet:
            if let r = gs.shadow.lastElection, GameCalendar.year(of: r.date) == year, let p = r.playerEV, let o = r.opponentEV {
                announce("The Electoral College meets in the state capitals: \(p) for \(r.playerName ?? "you"), \(o) for \(r.opponentName).", on: date)
            }

        case .count:
            if c.houseContingent {
                c.houseContingent = false
                let chance = min(0.9, max(0.1, Double(player?.congressionalSupport ?? 50) / 100 + c.houseLobby))
                let won = Double.random(in: 0..<1) < chance
                if var r = gs.shadow.lastElection {
                    r.won = won; r.decidedBy = "the House of Representatives"
                    gs.shadow.lastElection = r
                }
                if won {
                    c.leaveOfficeOn = nil; c.leaveReason = nil
                    gs.shadow.termsWon += 1
                    announce("THE HOUSE DECIDES: voting by state delegations under the 12th Amendment, the House elects you President.", severity: 3, on: date)
                } else {
                    c.leaveReason = .lostElection; c.leaveOfficeOn = rules.inauguration
                    announce("THE HOUSE DECIDES: the state delegations choose \(opponent). Your presidency ends \(GameCalendar.format(rules.inauguration)).", severity: 3, on: date)
                }
            } else if let r = gs.shadow.lastElection, GameCalendar.year(of: r.date) == year {
                announce("Congress counts the electoral votes in joint session. \(r.won ? "You are declared re-elected." : "\(r.opponentName) is declared President-elect.")", on: date)
            }

        case .inauguration:
            if let leave = c.leaveOfficeOn, leave <= date.addingTimeInterval(86_400), let why = c.leaveReason {
                c.leaveOfficeOn = nil
                gs.shadow.campaign = c
                self.gameState = gs
                endPresidency(why)
            } else if gs.shadow.lastElection.map({ GameCalendar.year(of: $0.date) == year && $0.won }) == true {
                announce("INAUGURATION DAY: you take the oath for another term.", severity: 2, on: date)
            }

        case .midtermCampaign:
            guard c.leaveOfficeOn == nil else { return }
            decide(ElectionCycle.card("The Midterms",
                "Every House seat and a third of the Senate are on the ballot in November\(year < 1914 ? " (senators are still chosen by state legislatures until the 17th Amendment)" : ""). The President's party has lost House seats in almost every midterm since the Civil War.",
                [ElectionCycle.option("Campaign hard for the party", "Rallies in every competitive district.", approval: -1, choice: "midterm|8"),
                 ElectionCycle.option("Stay above the fray", "Govern; let candidates run their own races.", choice: "midterm|0"),
                 ElectionCycle.option(atWar ? "Make it a referendum on the war" : "Nationalize it on foreign policy", "Rally round the flag.", choice: atWar ? "midterm|4" : "midterm|-3")],
                severity: .moderate, turn: turn))

        case .midtermNight:
            guard let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
            let seats = ElectionCycle.midtermSeats(popularity: pop, effort: c.midtermEffort, atWar: atWar, noise: Double.random(in: -1...1))
            c.midtermEffort = 0
            c.midtermResults[year] = seats
            gs.countries[pi].congressionalSupport = max(5, min(95, gs.countries[pi].congressionalSupport + seats / 2))
            let verb = seats >= 0 ? "GAINS \(seats)" : "LOSES \(-seats)"
            announce("MIDTERMS: your party \(verb) House seats. Congressional support is now \(gs.countries[pi].congressionalSupport)%.", severity: 3, on: date)
            if seats <= -20 {
                decide(ElectionCycle.card("A Shellacking",
                    "The opposition will run the House. Every bill, budget and investigation now goes through them.",
                    [ElectionCycle.option("Reach across the aisle", "Triangulate: find the deals that can pass.", approval: 2, choice: "congress|6"),
                     ElectionCycle.option("Veto everything", "Run against a do-nothing Congress.", approval: -1, choice: "congress|-4"),
                     ElectionCycle.option("Govern by executive order", "Go around them.", choice: "congress|-2")],
                    severity: .serious, turn: turn))
            }
        }
    }

    /// Election night: count the votes, call the Electoral College, and start the transition.
    func holdElection(on day: Date) {
        guard let gs = gameState else { return }
        let year = GameCalendar.year(of: day)
        if !gs.shadow.campaign.initialized { initializeCampaign(asOf: gs.previousTurnDate) }
        if gs.shadow.campaign.opponent == nil || gs.shadow.campaign.year != year {
            gs.shadow.campaign.year = year
            gs.shadow.campaign.opponent = ElectionCycle.opponentName(year: year, party: gs.shadow.campaign.party, incumbent: gs.shadow.campaign.incumbent)
        }
        flushElectionCards(year: year)
        var c = gs.shadow.campaign
        let rules = ElectionRules(year: year)
        let opponent = c.opponent ?? PopularityModel.challenger(for: year)

        // Third candidates: history's, or (rarely) one born of an unhappy electorate.
        var third: (name: String, party: String, popular: Double)? = ElectionHistory.thirdParties[year]
        if third == nil, year > 2024 || ElectionHistory.nominees[year] == nil,
           Double.random(in: 0..<1) < (gs.shadow.popularity < 40 ? 0.3 : 0.1) {
            third = ("Gov. Mercer Vance", "Independent", Double.random(in: 4...16))
        }

        let share: Double
        let playerName: String?
        if c.running {
            share = ElectionCycle.voteShare(popularity: gs.shadow.popularity, termsWon: gs.shadow.termsWon, campaign: c, year: year, noise: Double.random(in: -1...1))
            playerName = nil
        } else {
            // Not on the ballot: your party's nominee runs on your record.
            share = min(75, max(25, 50 + (gs.shadow.popularity - 50) * 0.5 + c.successorBoost + Double.random(in: -3...3)))
            playerName = "Your party's nominee"
        }
        let t = ElectionCycle.tally(year: year, twoPartyShare: share, thirdPopular: third?.popular ?? 0, stateNoise: Double.random(in: -1...1))
        var result = ElectionResult(date: day, playerShare: t.playerPopular, opponentShare: t.opponentPopular,
                                    won: t.outcome == .won, opponentName: opponent)
        result.playerEV = t.playerEV; result.opponentEV = t.opponentEV; result.totalEV = t.electors
        result.thirdEV = t.thirdEV; result.thirdName = third?.name; result.thirdShare = third?.popular
        result.popularVoteRecorded = rules.hasPopularVote
        result.playerName = playerName
        gs.shadow.lastElection = result
        ShadowPack.shared.play("sfx.election_speech\(Int.random(in: 1...3))")

        let pop = rules.hasPopularVote ? String(format: " (popular vote %.1f%% to %.1f%%)", t.playerPopular, t.opponentPopular) : ""
        let ev = "\(t.playerEV) to \(t.opponentEV) electoral votes\(t.thirdEV > 0 ? ", \(t.thirdEV) for \(third?.name ?? "a third candidate")" : "")"

        guard c.running else {
            gs.shadow.post("ELECTION NIGHT: your party's nominee \(t.outcome == .won ? "wins" : "loses to \(opponent)"), \(ev)\(pop).", date: day, severity: 3)
            addLog("🗳️ Your successor \(t.outcome == .won ? "wins" : "loses"): \(ev).", type: .critical)
            gs.shadow.campaign = c
            self.gameState = gs
            return
        }

        switch t.outcome {
        case .won:
            gs.shadow.cabinetFollowsHistory = false   // 3.12.2: a re-elected leader writes their own history
            gs.shadow.termsWon += 1
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 5)
            let split = rules.hasPopularVote && t.playerPopular < t.opponentPopular ? " You lost the popular vote but won the Electoral College." : ""
            gs.shadow.post("ELECTION NIGHT: you win \(ev)\(pop). Four more years.\(split)", date: day, severity: 3)
            addLog(String(format: "🗳️ RE-ELECTED: %d electoral votes, %.1f%% of the vote.", t.playerEV, t.playerPopular), type: .critical)
        case .lost:
            c.leaveReason = .lostElection
            c.leaveOfficeOn = rules.inauguration
            gs.shadow.post("ELECTION NIGHT: \(opponent) wins \(t.opponentEV) to \(t.playerEV) electoral votes\(pop). You are a lame duck until \(GameCalendar.format(rules.inauguration)).", date: day, severity: 3)
            addLog("🗳️ DEFEATED: \(opponent) wins \(ev).", type: .critical)
            let close = abs(t.playerPopular - t.opponentPopular) < 1.5 || (t.opponentEV - t.majority) < 25
            if close && year >= 1876 {
                crisisManager.presentCrisis(ElectionCycle.card("Too Close to Call",
                    "\(opponent) leads, but the margin in the decisive states is razor-thin. In 1876 a commission settled it; in 2000 the Supreme Court did.",
                    [ElectionCycle.option("Concede graciously", "The peaceful transfer of power is the point.", approval: 3, choice: "concede"),
                     ElectionCycle.option("Demand recounts", "Every legal vote counted.", choice: "recount"),
                     ElectionCycle.option("Take it to the courts", "Lawsuits in every close state. It will divide the country.", approval: -4, choice: "court")],
                    severity: .catastrophic, turn: gs.turn))
            }
        case .noMajority:
            c.houseContingent = true
            gs.shadow.post("ELECTION NIGHT: no one wins a majority of the electors (\(ev); \(t.majority) needed). Under the 12th Amendment the House will choose, one vote per state, on \(GameCalendar.format(rules.countDay)).", date: day, severity: 3)
            crisisManager.presentCrisis(ElectionCycle.card("The House Will Decide",
                "For the first time since 1825, the presidency goes to the House of Representatives. Each state delegation casts one vote.",
                [ElectionCycle.option("Lobby the state delegations", "Patronage, promises, and phone calls — the 'corrupt bargain' charge will follow you.", approval: -2, choice: "house|0.15"),
                 ElectionCycle.option("Let the House decide on the merits", "Respect the process.", approval: 2, choice: "house|0")],
                severity: .catastrophic, turn: gs.turn))
        }
        gs.shadow.campaign = c
        self.gameState = gs
    }

    /// Election cards still unanswered on election night are decided by the campaign staff (option 1), so the vote
    /// counts what the President chose — or what their staff chose for them.
    func flushElectionCards(year: Int) {
        guard let gs = gameState else { return }
        var cards = crisisManager.pendingCrises.filter { $0.type == .election }
        crisisManager.pendingCrises.removeAll { $0.type == .election }
        if let a = crisisManager.activeCrisis, a.type == .election {
            cards.insert(a, at: 0)
            crisisManager.activeCrisis = nil
            crisisManager.presentNextPending(gameState: gs)
        }
        for card in cards {
            guard let first = card.options.first else { continue }
            gs.shadow.post("Your campaign staff decided \"\(card.title)\" for you: \(first.title).", date: gs.currentDate)
            ElectionCycle.apply(first.consequences, to: gs)
            if first.consequences.approvalChange != 0 {
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + Double(first.consequences.approvalChange))
            }
        }
        self.gameState = gs
    }
}

extension ElectionCycle {

    /// Apply the campaign side of a decision (called from CrisisManager.applyConsequences).
    static func apply(_ k: CrisisConsequences, to gs: GameState) {
        var c = gs.shadow.campaign
        c.momentum += k.campaign ?? 0
        let year = c.year
        let rules = ElectionRules(year: max(year, 1792))
        let parts = (k.electionChoice ?? "").split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        func num(_ i: Int) -> Double { i < parts.count ? Double(parts[i]) ?? 0 : 0 }
        let date = gs.currentDate
        switch parts.first ?? "" {
        case "run":
            c.running = true
            gs.shadow.post("You announce your candidacy for re-election in \(year).", date: date, severity: 2)
        case "retire":
            c.running = false
            c.leaveReason = .retired
            c.leaveOfficeOn = rules.inauguration
            gs.shadow.post("You will not seek another term. Your presidency ends on \(GameCalendar.format(rules.inauguration)).", date: date, severity: 3)
        case "successor": c.successorBoost += num(1)
        case "challenge": c.challengerStrength = max(0.05, c.challengerStrength + num(1))
        case "vp":
            c.runningMate = parts.count > 1 ? parts[1] : nil
        case "debate": c.debatePrep = parts.count > 1 ? parts[1] : nil
        case "gamble":
            let won = Double.random(in: 0..<1) < num(3)
            c.momentum += won ? num(1) : num(2)
            let text = won ? (parts.count > 4 ? parts[4] : "It pays off.") : (parts.count > 5 ? parts[5] : "It backfires.")
            gs.shadow.post("CAMPAIGN: \(text)", date: date, severity: 2)
        case "spend":
            gs.shadow.aidRemaining = max(0, gs.shadow.aidRemaining - max(1, gs.shadow.aidRemaining * 0.05))
        case "ground": c.momentum += 0.5
        case "recount", "court":
            let p = parts.first == "court" ? 0.25 : 0.15
            if Double.random(in: 0..<1) < p, var r = gs.shadow.lastElection {
                r.won = true
                r.decidedBy = parts.first == "court" ? "the courts" : "the recount"
                (r.playerEV, r.opponentEV) = (r.opponentEV, r.playerEV)
                gs.shadow.lastElection = r
                c.leaveOfficeOn = nil; c.leaveReason = nil
                gs.shadow.termsWon += 1
                gs.shadow.post("THE RESULT IS REVERSED: \(r.decidedBy ?? "the count") hands you the election.", date: date, severity: 3)
            } else {
                gs.shadow.post("The \(parts.first == "court" ? "courts uphold" : "recount confirms") the result. You remain a lame duck.", date: date, severity: 3)
                if parts.first == "court", let i = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) {
                    gs.countries[i].stability = max(1, gs.countries[i].stability - 8)
                }
            }
        case "house": c.houseLobby += num(1)
        case "midterm": c.midtermEffort += num(1)
        case "congress":
            if let i = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) {
                gs.countries[i].congressionalSupport = max(5, min(95, gs.countries[i].congressionalSupport + Int(num(1))))
            }
        default: break
        }
        gs.shadow.campaign = c
    }
}
