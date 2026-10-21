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
    // How leaders of other nations fall (3.11.0).
    case noConfidence, coup, revolution, partyCongress, juntaDecision, royalDismissal

    var headline: String {
        switch self {
        case .lostElection: return "The voters have spoken. You lost the election."
        case .impeached: return "Congress has removed you from office."
        case .assassinated: return "The President has been assassinated."
        case .civilWar: return "The country has collapsed into civil war."
        case .noConfidence: return "The government loses a vote of no confidence. You are out."
        case .coup: return "The army has seized power. You are overthrown."
        case .revolution: return "Revolution sweeps the regime away."
        case .partyCongress: return "The party congress removes you from the leadership."
        case .juntaDecision: return "The junta votes to replace you."
        case .royalDismissal: return "The monarch dismisses you from office."
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
    /// Congress (3.8.0): every vote on a war request, and War Powers clocks by enemy.
    var authorizations: [WarAuthorization] = []
    var warPowersClocks: [String: WarPowersClock] = [:]
    /// Manpower and territories (3.9.0): drafts / mobilizations called, territory governance, states admitted.
    var mobilizations: [Mobilization] = []
    var territoryPolicies: [String: TerritoryPolicy] = [:]
    var statesAdmitted: [StatehoodRecord] = []
    /// Custom nation groups the President saved for group actions (3.10.0), by name.
    var savedGroups: [String: [String]] = [:]
    /// Coalitions the player has assembled, by target (3.12.0).
    var coalitions: [String: Coalition] = [:]
    /// Evolving cabinets (3.12.2): whether the player's government still follows history, the leader the player
    /// started as, the government each computer-run nation had when tracking began, nations whose story has
    /// diverged, and their historical leaders' names for the dossier.
    var cabinetFollowsHistory = true
    var playerLeader: String?
    var trackedGovernments: [String: String] = [:]
    var divergedNations: Set<String> = []
    var leaderNames: [String: String] = [:]
    /// Historical acquisitions accepted (3.13.0), their yearly value, and offers already announced.
    var acquired: Set<String> = []
    var acquisitionIncome: Double = 0
    var announcedOffers: Set<String> = []
    /// Territory money (3.13.1): extraction rate by territory, last levy dates, and the cash paid last turn ($B).
    var extraction: [String: String] = [:]
    var lastLevy: [String: Date] = [:]
    var lastTurnCash: Double = 0
    /// The living world (3.14.0): AI activity counters ("wars", "claims", "diplomacy"), the era wars already begun,
    /// treaties other nations have offered the player, and the last reaction to U.S. expansion.
    var worldStats: [String: Int] = [:]
    var firedRivalries: Set<String> = []
    var treatyOffers: [TreatyOffer] = []
    var lastReaction: Date?
    /// Nova's commentary this game (3.15.0), newest last, capped at 30.
    var novaLines: [TickerItem] = []
    /// Era transitions (3.15.0): the last game year synced, each nation's government as history left it, and the
    /// nations whose story has diverged (they no longer follow history).
    var eraSyncYear = 0
    var eraGovernment: [String: String] = [:]
    var eraDiverged: Set<String> = []
    /// Peace brokered between other nations (3.16.0).
    var nobelMoments = 0
    /// Wars the player declared (3.16.0; the peaceful endings need none).
    var playerWarsStarted = 0
    /// The player's share of world output when the game began (economic dominance is measured from it).
    var startOutputShare = 0.0

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
        case expansionLog, claimDates, producing, resourceEarnings, impeachmentWarned, authorizations, warPowersClocks
        case mobilizations, territoryPolicies, statesAdmitted, savedGroups, coalitions
        case cabinetFollowsHistory, playerLeader, trackedGovernments, divergedNations, leaderNames
        case acquired, acquisitionIncome, announcedOffers, extraction, lastLevy, lastTurnCash, worldStats, firedRivalries, treatyOffers, lastReaction, novaLines, eraSyncYear, eraGovernment, eraDiverged, nobelMoments, playerWarsStarted, startOutputShare
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
        authorizations = try c.decodeIfPresent([WarAuthorization].self, forKey: .authorizations) ?? []
        warPowersClocks = try c.decodeIfPresent([String: WarPowersClock].self, forKey: .warPowersClocks) ?? [:]
        mobilizations = try c.decodeIfPresent([Mobilization].self, forKey: .mobilizations) ?? []
        territoryPolicies = try c.decodeIfPresent([String: TerritoryPolicy].self, forKey: .territoryPolicies) ?? [:]
        statesAdmitted = try c.decodeIfPresent([StatehoodRecord].self, forKey: .statesAdmitted) ?? []
        savedGroups = try c.decodeIfPresent([String: [String]].self, forKey: .savedGroups) ?? [:]
        coalitions = try c.decodeIfPresent([String: Coalition].self, forKey: .coalitions) ?? [:]
        cabinetFollowsHistory = try c.decodeIfPresent(Bool.self, forKey: .cabinetFollowsHistory) ?? true
        playerLeader = try c.decodeIfPresent(String.self, forKey: .playerLeader)
        trackedGovernments = try c.decodeIfPresent([String: String].self, forKey: .trackedGovernments) ?? [:]
        divergedNations = try c.decodeIfPresent(Set<String>.self, forKey: .divergedNations) ?? []
        leaderNames = try c.decodeIfPresent([String: String].self, forKey: .leaderNames) ?? [:]
        acquired = try c.decodeIfPresent(Set<String>.self, forKey: .acquired) ?? []
        acquisitionIncome = try c.decodeIfPresent(Double.self, forKey: .acquisitionIncome) ?? 0
        announcedOffers = try c.decodeIfPresent(Set<String>.self, forKey: .announcedOffers) ?? []
        extraction = try c.decodeIfPresent([String: String].self, forKey: .extraction) ?? [:]
        lastLevy = try c.decodeIfPresent([String: Date].self, forKey: .lastLevy) ?? [:]
        lastTurnCash = try c.decodeIfPresent(Double.self, forKey: .lastTurnCash) ?? 0
        worldStats = try c.decodeIfPresent([String: Int].self, forKey: .worldStats) ?? [:]
        firedRivalries = try c.decodeIfPresent(Set<String>.self, forKey: .firedRivalries) ?? []
        treatyOffers = try c.decodeIfPresent([TreatyOffer].self, forKey: .treatyOffers) ?? []
        lastReaction = try c.decodeIfPresent(Date.self, forKey: .lastReaction)
        novaLines = try c.decodeIfPresent([TickerItem].self, forKey: .novaLines) ?? []
        eraSyncYear = try c.decodeIfPresent(Int.self, forKey: .eraSyncYear) ?? 0
        eraGovernment = try c.decodeIfPresent([String: String].self, forKey: .eraGovernment) ?? [:]
        eraDiverged = try c.decodeIfPresent(Set<String>.self, forKey: .eraDiverged) ?? []
        nobelMoments = try c.decodeIfPresent(Int.self, forKey: .nobelMoments) ?? 0
        playerWarsStarted = try c.decodeIfPresent(Int.self, forKey: .playerWarsStarted) ?? 0
        startOutputShare = try c.decodeIfPresent(Double.self, forKey: .startOutputShare) ?? 0
    }
}

extension ElectionResult: Identifiable {
    var id: Date { date }
}
