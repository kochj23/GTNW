//
//  GameStoreRecords.swift
//  Global Thermal Nuclear War
//
//  Conversions between game types (GameState, GameScore, LeaderboardEntry) and store records.
//

import Foundation
import CryptoKit

extension UUID {
    /// Deterministic UUID from a string (SHA-256, version/variant bits set), so re-importing the same legacy
    /// entry always produces the same id and the DB's `ON CONFLICT (id) DO NOTHING` keeps it idempotent.
    static func stable(_ key: String) -> UUID {
        var b = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50
        b[8] = (b[8] & 0x3F) | 0x80
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}

extension LeaderboardRecord {
    init(entry e: LeaderboardEntry) {
        self.init(id: e.id,
                  playerName: StoreValidation.clean(e.playerName, max: StoreValidation.maxNameLength),
                  finalScore: min(max(0, e.score.finalScore), StoreValidation.maxScore),
                  baseScore: e.score.baseScore,
                  turnsPlayed: min(max(0, e.score.turnsPlayed), StoreValidation.maxTurn),
                  nuclearVirgin: e.score.nuclearVirgin,
                  difficultyMultiplier: e.score.difficultyMultiplier.isFinite ? min(max(0, e.score.difficultyMultiplier), 100) : 1,
                  victoryType: e.score.victoryType?.rawValue,
                  playerCountry: String(e.score.playerCountry.prefix(8)),
                  achievedAt: e.score.dateAchieved)
    }
}

extension LeaderboardEntry {
    init(record r: LeaderboardRecord) {
        var score = GameScore()
        score.victoryType = r.victoryType.flatMap(VictoryType.init(rawValue:))
        score.baseScore = r.baseScore
        score.turnsPlayed = r.turnsPlayed
        score.nuclearVirgin = r.nuclearVirgin
        score.difficultyMultiplier = r.difficultyMultiplier
        score.finalScore = r.finalScore
        score.playerCountry = r.playerCountry
        score.dateAchieved = r.achievedAt
        self.init(id: r.id, playerName: r.playerName, score: score)
    }
}

extension GameResultRecord {
    static func make(from gs: GameState, score: GameScore, victory: VictoryType?, id: UUID = UUID(), endedAt: Date = Date()) -> GameResultRecord {
        let scenario = gs.shadow.scenarioID.flatMap { StoreValidation.isIdentifier($0) ? $0 : nil } ?? "sandbox"
        return GameResultRecord(id: id, scenarioID: scenario,
                                playerCountry: String(gs.playerCountryID.prefix(8)),
                                won: victory != nil,
                                victoryType: victory?.rawValue,
                                reason: StoreValidation.clean(gs.gameOverReason, max: StoreValidation.maxReasonLength),
                                finalScore: min(max(0, score.finalScore), StoreValidation.maxScore),
                                turns: min(max(0, gs.turn), StoreValidation.maxTurn),
                                gameDate: StoreValidation.clean(gs.currentDateLabel, max: 64),
                                casualties: Int64(max(0, gs.totalCasualties)),
                                nuclearStrikes: gs.nuclearStrikes.count,
                                endedAt: endedAt)
    }
}
