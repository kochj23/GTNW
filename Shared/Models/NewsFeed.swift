//
//  NewsFeed.swift
//  Global Thermal Nuclear War
//
//  Dynamic news feed system
//  Created by Jordan Koch on 2025-12-03.
//

import Foundation
import SwiftUI

enum NewsSource: String, Codable {
    case cnn, foxNews, bbc, rt, alJazeera, xinhua, ap, reuters

    var displayName: String {
        switch self {
        case .cnn: return "CNN"
        case .foxNews: return "FOX NEWS"
        case .bbc: return "BBC"
        case .rt: return "RT"
        case .alJazeera: return "AL JAZEERA"
        case .xinhua: return "XINHUA"
        case .ap: return "AP"
        case .reuters: return "REUTERS"
        }
    }

    var credibility: Int {
        switch self {
        case .ap, .reuters, .bbc: return 95
        case .cnn: return 85
        case .foxNews: return 80
        case .alJazeera: return 75
        case .xinhua: return 60
        case .rt: return 50
        }
    }
}

enum NewsSeverity: String, Codable {
    case breaking, developing, routine

    var color: Color {
        switch self {
        case .breaking: return Color.red
        case .developing: return Color.orange
        case .routine: return AppSettings.terminalGreen
        }
    }

    var prefix: String {
        switch self {
        case .breaking: return "🔴 BREAKING"
        case .developing: return "🟡 DEVELOPING"
        case .routine: return "🟢 REPORT"
        }
    }
}

struct NewsEvent: Identifiable, Codable {
    let id = UUID()
    var headline: String
    var source: NewsSource
    var severity: NewsSeverity
    var turn: Int
    var timestamp: Date = Date()
}

class NewsManager: ObservableObject {
    @Published var headlines: [NewsEvent] = []
    private let maxHeadlines = 50
    private var useMLX: Bool = true  // Toggle MLX-powered news generation

    func generateNews(from gameState: GameState) {
        // Use MLX for dynamic news generation if available
        Task { @MainActor in
            let isMLXAvailable = await checkMLXAvailability()
            if useMLX && isMLXAvailable {
                await generateMLXNews(from: gameState)
            } else {
                generateStaticNews(from: gameState)
            }
        }
    }

    @MainActor
    private func checkMLXAvailability() async -> Bool {
        return EnhancedMLXService.shared.isConnected
    }

    /// Generate dynamic news using MLX
    private func generateMLXNews(from gameState: GameState) async {
        // Wars
        for war in gameState.activeWars {
            if let aggressor = gameState.getCountry(id: war.aggressor),
               let defender = gameState.getCountry(id: war.defender) {
                let context = "\(aggressor.name) declares war on \(defender.name)"
                if let headline = await EnhancedMLXService.shared.generateNewsArticle(headline: context, gameState: gameState) {
                    addHeadline(headline, source: .ap, severity: .breaking, turn: gameState.turn)
                } else {
                    addHeadline(context, source: .ap, severity: .breaking, turn: gameState.turn)
                }
            }
        }

        // Nuclear strikes
        if let lastStrike = gameState.nuclearStrikes.last {
            if let attacker = gameState.getCountry(id: lastStrike.attacker),
               let target = gameState.getCountry(id: lastStrike.target) {
                let context = "\(attacker.name) launches nuclear strike on \(target.name) - \(lastStrike.casualties.formatted()) casualties"
                if let headline = await EnhancedMLXService.shared.generateNewsArticle(headline: context, gameState: gameState) {
                    addHeadline(headline, source: .cnn, severity: .breaking, turn: gameState.turn)
                } else {
                    addHeadline(context, source: .cnn, severity: .breaking, turn: gameState.turn)
                }
            }
        }

        // Generate additional contextual news based on game state
        if gameState.defconLevel.rawValue <= 2 {
            if let headline = await EnhancedMLXService.shared.generateEvent(gameState: gameState, eventType: .nuclear) {
                addHeadline(headline, source: .reuters, severity: .breaking, turn: gameState.turn)
            }
        }
    }

    /// Generate static news (fallback when MLX unavailable)
    private func generateStaticNews(from gameState: GameState) {
        // Wars
        for war in gameState.activeWars {
            if let aggressor = gameState.getCountry(id: war.aggressor),
               let defender = gameState.getCountry(id: war.defender) {
                addHeadline(
                    "\(aggressor.name) declares war on \(defender.name)",
                    source: .ap,
                    severity: .breaking,
                    turn: gameState.turn
                )
            }
        }

        // Nuclear strikes
        if let lastStrike = gameState.nuclearStrikes.last {
            if let attacker = gameState.getCountry(id: lastStrike.attacker),
               let target = gameState.getCountry(id: lastStrike.target) {
                addHeadline(
                    "\(attacker.name) launches nuclear strike on \(target.name) - \(lastStrike.casualties.formatted()) casualties",
                    source: .cnn,
                    severity: .breaking,
                    turn: gameState.turn
                )
            }
        }

        // DEFCON changes
        if gameState.defconLevel.rawValue <= 2 {
            addHeadline(
                "World at \(gameState.defconLevel.description) - Nuclear war imminent",
                source: .bbc,
                severity: .breaking,
                turn: gameState.turn
            )
        }

        // Treaties
        if let lastTreaty = gameState.treaties.last {
            addHeadline(
                "\(lastTreaty.signatories.count) nations sign \(lastTreaty.type.rawValue)",
                source: .reuters,
                severity: .routine,
                turn: gameState.turn
            )
        }

        // Random diplomatic news
        if Int.random(in: 0...100) < 15 {
            generateRandomDiplomaticNews(from: gameState)
        }
    }

    private func generateRandomDiplomaticNews(from gameState: GameState) {
        let templates = [
            "Diplomatic tensions rise between {country1} and {country2}",
            "{country1} president makes controversial statement about {country2}",
            "Trade negotiations between {country1} and {country2} break down",
            "{country1} expels {country2} diplomats",
            "Summit scheduled between {country1} and {country2} leaders"
        ]

        guard let c1 = gameState.countries.randomElement(),
              let c2 = gameState.countries.filter({ $0.id != c1.id }).randomElement() else { return }

        let template = templates.randomElement()!
        let headline = template
            .replacingOccurrences(of: "{country1}", with: c1.name)
            .replacingOccurrences(of: "{country2}", with: c2.name)

        addHeadline(headline, source: .ap, severity: .routine, turn: gameState.turn)
    }

    func addHeadline(_ headline: String, source: NewsSource, severity: NewsSeverity, turn: Int) {
        let event = NewsEvent(headline: headline, source: source, severity: severity, turn: turn)
        headlines.insert(event, at: 0)

        // Trim old headlines
        if headlines.count > maxHeadlines {
            headlines = Array(headlines.prefix(maxHeadlines))
        }
    }

    func addBreakingNews(_ headline: String) {
        addHeadline(headline, source: .ap, severity: .breaking, turn: 0)
    }
}
