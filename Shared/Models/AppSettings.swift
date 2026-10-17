//
//  AppSettings.swift
//  Global Thermal Nuclear War
//
//  Color scheme and UI settings inspired by WOPR from WarGames
//

import SwiftUI

struct AppSettings {
    // WOPR-inspired color scheme
    static var terminalGreen: Color { Theme.isRetro ? EGA.lightGreen : Color(red: 0.0, green: 1.0, blue: 0.0) }
    static var terminalAmber: Color { Theme.isRetro ? EGA.yellow : Color(red: 1.0, green: 0.75, blue: 0.0) }
    static var terminalRed: Color { Theme.isRetro ? EGA.lightRed : Color(red: 1.0, green: 0.0, blue: 0.0) }
    static var terminalBackground: Color { Theme.isRetro ? EGA.black : Color(red: 0.05, green: 0.05, blue: 0.05) }
    static var panelBackground: Color { Theme.isRetro ? EGA.blue : Color(red: 0.1, green: 0.1, blue: 0.1) }

    // Game colors
    static var defcon5: Color { Theme.isRetro ? EGA.lightBlue : Color.blue }
    static var defcon4: Color { Theme.isRetro ? EGA.lightGreen : Color.green }
    static var defcon3: Color { Theme.isRetro ? EGA.yellow : Color.yellow }
    static var defcon2: Color { Theme.isRetro ? EGA.brown : Color.orange }
    static var defcon1: Color { Theme.isRetro ? EGA.lightRed : Color.red }

    // UI settings
    static let cornerRadius: CGFloat = 8
    static let padding: CGFloat = 16
    static let monospaceFont = "Menlo"

    /// Get color for DEFCON level
    static func color(for defcon: DefconLevel) -> Color {
        switch defcon {
        case .defcon5: return defcon5
        case .defcon4: return defcon4
        case .defcon3: return defcon3
        case .defcon2: return defcon2
        case .defcon1: return defcon1
        }
    }
}

// MARK: - Shared Sentiment Types
// Defined here (Shared layer) so they're visible when compiling both Shared and app-level files

struct SentimentResult {
    let overallSentiment: Sentiment
    let score: Double
    let emotions: [String: Double]

    init(overallSentiment: Sentiment = .neutral, score: Double = 0.0, emotions: [String: Double] = [:]) {
        self.overallSentiment = overallSentiment
        self.score = score
        self.emotions = emotions
    }
}

enum Sentiment: String, Codable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    case mixed = "mixed"

    var description: String {
        switch self {
        case .positive: return "Friendly"
        case .negative: return "Hostile"
        case .neutral: return "Neutral"
        case .mixed: return "Mixed"
        }
    }
}
