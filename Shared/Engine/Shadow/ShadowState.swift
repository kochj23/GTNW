//
//  ShadowState.swift
//  Global Thermal Nuclear War
//
//  Persistent state for the Shadow-President-style systems (popularity, elections, budget, foreign aid, War Room
//  fronts, scripted scenario events, the news ticker). Lives on GameState as one Codable value so saves stay simple
//  and older saves (which lack it) load with defaults.
//  Mechanics are re-implemented in GTNW's own code and words; no original game text or data lives here.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// How a presidency ended at home (as opposed to on the battlefield).
enum DomesticEnding: String, Codable, CaseIterable {
    case lostElection
    case impeached
    case assassinated
    case civilWar

    var headline: String {
        switch self {
        case .lostElection: return "The voters have spoken. You lost the election."
        case .impeached: return "Congress has removed you from office."
        case .assassinated: return "The President has been assassinated."
        case .civilWar: return "The country has collapsed into civil war."
        }
    }
}

/// One opinion poll.
struct PollRecord: Codable, Hashable {
    var date: Date
    var popularity: Double
}

/// The result of an election night.
struct ElectionResult: Codable, Hashable {
    var date: Date
    var playerShare: Double
    var opponentShare: Double
    var won: Bool
    var opponentName: String
}

/// A line in the bottom news ticker.
struct TickerItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var text: String
    var severity: Int        // 0 routine, 1 notable, 2 urgent, 3 flash
}

/// Snapshot of the world used for the Presidency Summary (start vs end).
struct PresidencySnapshot: Codable, Hashable {
    var date: Date
    var popularity: Double
    var usQualityOfLife: Double
    var worldQualityOfLife: Double
    var worldPeace: Double
    var leadership: Double
    var influenceShare: Double
}

/// Everything the Shadow systems keep between turns.
struct ShadowState: Codable {
    // Domestic politics
    var popularity: Double = 50
    var polls: [PollRecord] = []
    var electionsEnabled: Bool = true
    var lastElection: ElectionResult?
    var termsWon: Int = 0
    /// 0 = none, 1 = Congress investigating, 2 = articles of impeachment, 3 = trial in the Senate
    var impeachmentStage: Int = 0
    /// Accumulated public outrage from ruthless acts (nukes, assassinations, unprovoked wars). Decays over time.
    var ruthlessness: Double = 0
    var domesticEnding: DomesticEnding?

    // Money
    var budget = FederalBudget()
    /// Foreign aid still unspent this fiscal year, in billions of dollars.
    var aidRemaining: Double = 0
    /// Aid sent this fiscal year per country.
    var aidSent: [String: AidVector] = [:]
    /// True when the year-end budget has been processed and the player should review the new one.
    var budgetReviewPending: Bool = false
    var lastBudgetYear: Int?

    // War Room
    var fronts: [WarFront] = []
    var warLog: [String] = []
    /// Surrenders to the U.S. waiting for the President's choice: annex, or pick the new government (3.2.0).
    /// Unanswered ones fall back to the victor's-model government at the next turn.
    var pendingSettlements: [PostWarSettlement] = []
    /// Aircraft shot down in the President's air strikes (3.4.0); they come out of the air arm for the rest of the game.
    var aircraftLost: Int = 0
    /// U.S. troops (thousands) holding each territory, by country id (3.4.0); not free for other offensives.
    var garrisons: [String: Double] = [:]
    /// Fleets the President has sent out (3.5.0): under way or on station until recalled.
    var fleetDeployments: [FleetDeployment] = []
    /// Restarted chemical / biological programs by kind (3.6.0).
    var wmdPrograms: [String: WMDProgram] = [:]
    /// Expansion (3.7.0): dates lands were taken (claimed or annexed), when each territory was taken, territories
    /// already announced as producing, resource income earned ($B), and whether the impeachment warning is out.
    var expansionLog: [Date] = []
    var claimDates: [String: Date] = [:]
    var producing: Set<String> = []
    var resourceEarnings: Double = 0
    var impeachmentWarned = false

    // Scenario
    var scenarioID: String?
    var eventQueue: [ScheduledEvent] = []

    // Presentation
    var ticker: [TickerItem] = []
    var startSnapshot: PresidencySnapshot?

    // Advisors
    /// Advisor id -> how many times the player has gone against their advice recently (drives resignations).
    var advisorGrievances: [String: Int] = [:]

    // Play history (schema `play` in the Games DB)
    /// The play session this game is in. A new game or scenario starts one; loading a save starts a fresh one.
    /// The finished game's `game_history` row uses the same id, so the two join.
    var playSessionID: UUID?
    /// Wall-clock time the current play session started.
    var playSessionStartedAt: Date?

    mutating func post(_ text: String, date: Date, severity: Int = 0) {
        ticker.append(TickerItem(date: date, text: text, severity: severity))
        if ticker.count > 120 { ticker.removeFirst(ticker.count - 120) }
    }

    mutating func logWar(_ text: String) {
        warLog.append(text)
        if warLog.count > 200 { warLog.removeFirst(warLog.count - 200) }
    }

    enum CodingKeys: String, CodingKey {
        case popularity, polls, electionsEnabled, lastElection, termsWon, impeachmentStage, ruthlessness
        case domesticEnding, budget, aidRemaining, aidSent, budgetReviewPending, lastBudgetYear
        case fronts, warLog, scenarioID, eventQueue, ticker, startSnapshot, advisorGrievances
        case playSessionID, playSessionStartedAt, pendingSettlements, aircraftLost, garrisons, fleetDeployments, wmdPrograms
        case expansionLog, claimDates, producing, resourceEarnings, impeachmentWarned
    }

    init() {}

    /// Tolerant decoding: any missing field falls back to its default so saves survive future additions.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ShadowState()
        popularity = try c.decodeIfPresent(Double.self, forKey: .popularity) ?? d.popularity
        polls = try c.decodeIfPresent([PollRecord].self, forKey: .polls) ?? []
        electionsEnabled = try c.decodeIfPresent(Bool.self, forKey: .electionsEnabled) ?? true
        lastElection = try c.decodeIfPresent(ElectionResult.self, forKey: .lastElection)
        termsWon = try c.decodeIfPresent(Int.self, forKey: .termsWon) ?? 0
        impeachmentStage = try c.decodeIfPresent(Int.self, forKey: .impeachmentStage) ?? 0
        ruthlessness = try c.decodeIfPresent(Double.self, forKey: .ruthlessness) ?? 0
        domesticEnding = try c.decodeIfPresent(DomesticEnding.self, forKey: .domesticEnding)
        budget = try c.decodeIfPresent(FederalBudget.self, forKey: .budget) ?? FederalBudget()
        aidRemaining = try c.decodeIfPresent(Double.self, forKey: .aidRemaining) ?? 0
        aidSent = try c.decodeIfPresent([String: AidVector].self, forKey: .aidSent) ?? [:]
        budgetReviewPending = try c.decodeIfPresent(Bool.self, forKey: .budgetReviewPending) ?? false
        lastBudgetYear = try c.decodeIfPresent(Int.self, forKey: .lastBudgetYear)
        fronts = try c.decodeIfPresent([WarFront].self, forKey: .fronts) ?? []
        warLog = try c.decodeIfPresent([String].self, forKey: .warLog) ?? []
        scenarioID = try c.decodeIfPresent(String.self, forKey: .scenarioID)
        eventQueue = try c.decodeIfPresent([ScheduledEvent].self, forKey: .eventQueue) ?? []
        ticker = try c.decodeIfPresent([TickerItem].self, forKey: .ticker) ?? []
        startSnapshot = try c.decodeIfPresent(PresidencySnapshot.self, forKey: .startSnapshot)
        advisorGrievances = try c.decodeIfPresent([String: Int].self, forKey: .advisorGrievances) ?? [:]
        playSessionID = try c.decodeIfPresent(UUID.self, forKey: .playSessionID)
        playSessionStartedAt = try c.decodeIfPresent(Date.self, forKey: .playSessionStartedAt)
        pendingSettlements = try c.decodeIfPresent([PostWarSettlement].self, forKey: .pendingSettlements) ?? []
        aircraftLost = try c.decodeIfPresent(Int.self, forKey: .aircraftLost) ?? 0
        garrisons = try c.decodeIfPresent([String: Double].self, forKey: .garrisons) ?? [:]
        fleetDeployments = try c.decodeIfPresent([FleetDeployment].self, forKey: .fleetDeployments) ?? []
        wmdPrograms = try c.decodeIfPresent([String: WMDProgram].self, forKey: .wmdPrograms) ?? [:]
        expansionLog = try c.decodeIfPresent([Date].self, forKey: .expansionLog) ?? []
        claimDates = try c.decodeIfPresent([String: Date].self, forKey: .claimDates) ?? [:]
        producing = try c.decodeIfPresent(Set<String>.self, forKey: .producing) ?? []
        resourceEarnings = try c.decodeIfPresent(Double.self, forKey: .resourceEarnings) ?? 0
        impeachmentWarned = try c.decodeIfPresent(Bool.self, forKey: .impeachmentWarned) ?? false
    }
}

extension ElectionResult: Identifiable {
    var id: Date { date }
}
