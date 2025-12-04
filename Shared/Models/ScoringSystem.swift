//
//  ScoringSystem.swift
//  Global Thermal Nuclear War
//
//  Victory paths, scoring, and leaderboards
//  Created by Jordan Koch & Claude Code on 2025-12-03.
//

import Foundation

/// Types of victory conditions
enum VictoryType: String, Codable, CaseIterable {
    case peaceMaker = "Peace Maker"                  // 1500 pts
    case secretEnding = "WOPR's Choice"              // 2000 pts
    case diplomaticVictory = "Master Diplomat"       // 1200 pts
    case economicVictory = "Economic Tycoon"         // 1000 pts
    case supremacy = "Nuclear Supremacy"             // 800 pts
    case survival = "Sole Survivor"                  // 600 pts
    case pyrrhicVictory = "Pyrrhic Victory"          // 200 pts

    var baseScore: Int {
        switch self {
        case .secretEnding: return 2000
        case .peaceMaker: return 1500
        case .diplomaticVictory: return 1200
        case .economicVictory: return 1000
        case .supremacy: return 800
        case .survival: return 600
        case .pyrrhicVictory: return 200
        }
    }

    var description: String {
        switch self {
        case .peaceMaker:
            return "Ended all wars without launching nuclear weapons"
        case .secretEnding:
            return "Discovered WOPR's backdoor - the only winning move is not to play"
        case .diplomaticVictory:
            return "Formed alliances with 80%+ of world nations"
        case .economicVictory:
            return "Achieved economic dominance without warfare"
        case .supremacy:
            return "Last remaining nuclear power standing"
        case .survival:
            return "Survived nuclear winter and rebuilt civilization"
        case .pyrrhicVictory:
            return "Won the war but at catastrophic cost"
        }
    }
}

/// Game score calculation and tracking
struct GameScore: Codable {
    var victoryType: VictoryType?
    var baseScore: Int = 0
    var turnsPlayed: Int = 0
    var nuclearVirgin: Bool = true    // Never launched nukes
    var casualtyPenalty: Int = 0
    var allianceBonus: Int = 0
    var treatyBonus: Int = 0
    var economicBonus: Int = 0
    var difficultyMultiplier: Double = 1.0
    var finalScore: Int = 0
    var playerCountry: String = ""
    var dateAchieved: Date = Date()

    /// Calculate score from game state
    static func calculate(from gameState: GameState, victoryType: VictoryType?) -> GameScore {
        var score = GameScore()
        score.victoryType = victoryType
        score.baseScore = victoryType?.baseScore ?? 0
        score.turnsPlayed = gameState.turn
        score.playerCountry = gameState.playerCountryID

        // Nuclear virgin bonus
        score.nuclearVirgin = gameState.nuclearStrikes.filter {
            $0.attacker == gameState.playerCountryID
        }.isEmpty

        // Casualty penalty (-1 per 1000 casualties)
        score.casualtyPenalty = -(gameState.totalCasualties / 1000)

        // Alliance bonus (+20 per treaty)
        score.allianceBonus = gameState.treaties.count * 20
        score.treatyBonus = gameState.treaties.filter {
            $0.signatories.contains(gameState.playerCountryID)
        }.count * 15

        // Economic bonus (if player country still exists)
        if let player = gameState.getPlayerCountry() {
            score.economicBonus = Int(player.gdp / 1_000_000)  // Trillions to points
        }

        // Difficulty multiplier
        switch gameState.difficultyLevel {
        case .easy: score.difficultyMultiplier = 1.0
        case .normal: score.difficultyMultiplier = 1.5
        case .hard: score.difficultyMultiplier = 2.0
        case .nightmare: score.difficultyMultiplier = 2.5
        }

        // Calculate final score
        var total = score.baseScore
        total += score.turnsPlayed * 5
        total += score.nuclearVirgin ? 500 : 0
        total += score.casualtyPenalty
        total += score.allianceBonus
        total += score.treatyBonus
        total += score.economicBonus
        total = Int(Double(total) * score.difficultyMultiplier)
        score.finalScore = max(0, total)

        return score
    }
}

/// Leaderboard entry
struct LeaderboardEntry: Identifiable, Codable {
    let id = UUID()
    var playerName: String
    var score: GameScore
    var rank: Int = 0

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: score.dateAchieved)
    }
}

/// Manages leaderboard persistence
class LeaderboardManager: ObservableObject {
    @Published var entries: [LeaderboardEntry] = []

    private let saveKey = "GTNW_Leaderboard"
    private let maxEntries = 100

    init() {
        loadLeaderboard()
    }

    /// Add new entry to leaderboard
    func addEntry(playerName: String, score: GameScore) {
        let entry = LeaderboardEntry(playerName: playerName, score: score)

        // Add to list
        entries.append(entry)

        // Sort by score
        entries.sort { $0.score.finalScore > $1.score.finalScore }

        // Assign ranks
        for (index, _) in entries.enumerated() {
            entries[index].rank = index + 1
        }

        // Keep only top entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveLeaderboard()
    }

    /// Load leaderboard from persistent storage
    func loadLeaderboard() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([LeaderboardEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }

    /// Save leaderboard to persistent storage
    func saveLeaderboard() {
        guard let encoded = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(encoded, forKey: saveKey)
    }

    /// Get top N entries
    func getTopEntries(count: Int = 10) -> [LeaderboardEntry] {
        return Array(entries.prefix(count))
    }

    /// Get player's best score
    func getBestScore(playerName: String) -> LeaderboardEntry? {
        return entries.filter { $0.playerName == playerName }.first
    }

    /// Get rank for score
    func getRank(for score: Int) -> Int {
        return entries.filter { $0.score.finalScore > score }.count + 1
    }
}

/// Check victory conditions
class VictoryChecker {
    /// Check if player has achieved victory
    static func checkVictory(gameState: GameState) -> VictoryType? {
        guard let player = gameState.getPlayerCountry(), !player.isDestroyed else {
            return nil
        }

        // Secret ending: survived 50+ turns without war or nukes
        if gameState.turn >= 50 &&
           gameState.activeWars.isEmpty &&
           gameState.nuclearStrikes.isEmpty {
            return .secretEnding
        }

        // Peace Maker: ended all wars, no nukes
        let playerLaunchedNukes = gameState.nuclearStrikes.contains {
            $0.attacker == gameState.playerCountryID
        }
        if !playerLaunchedNukes &&
           gameState.activeWars.isEmpty &&
           gameState.turn >= 20 {
            return .peaceMaker
        }

        // Diplomatic Victory: 80%+ alliances
        let totalCountries = gameState.countries.filter { !$0.isDestroyed }.count
        let allianceCount = gameState.treaties.filter {
            $0.type == .alliance && $0.signatories.contains(gameState.playerCountryID)
        }.count
        if Double(allianceCount) / Double(totalCountries) >= 0.8 {
            return .diplomaticVictory
        }

        // Economic Victory: GDP > all others combined
        let playerGDP = player.gdp
        let othersGDP = gameState.countries.filter {
            !$0.isPlayerControlled && !$0.isDestroyed
        }.reduce(0) { $0 + $1.gdp }
        if playerGDP > othersGDP {
            return .economicVictory
        }

        // Nuclear Supremacy: last nuclear power
        let nuclearPowers = gameState.countries.filter {
            !$0.isDestroyed && $0.nuclearWarheads > 0
        }
        if nuclearPowers.count == 1 && nuclearPowers.first?.id == player.id {
            return .supremacy
        }

        // Survival: survived nuclear winter
        if gameState.systems.environ.stage.rawValue >= 3 &&
           !player.isDestroyed &&
           gameState.turn >= 100 {
            return .survival
        }

        return nil
    }

    /// Check if player has lost
    static func checkDefeat(gameState: GameState) -> (defeated: Bool, reason: String) {
        guard let player = gameState.getPlayerCountry() else {
            return (true, "Your nation has been destroyed")
        }

        // Player country destroyed
        if player.isDestroyed {
            return (true, "Your nation has been destroyed in nuclear fire")
        }

        // Global radiation too high
        if gameState.globalRadiation > 500 {
            return (true, "Earth is uninhabitable. Humanity extinct.")
        }

        // Too many casualties
        if gameState.totalCasualties > 1_000_000_000 {
            return (true, "Over 1 billion dead. Civilization has collapsed.")
        }

        // Nuclear winter extinction
        if gameState.systems.environ.stage == .extinction {
            return (true, "Nuclear winter has caused human extinction")
        }

        return (false, "")
    }
}
