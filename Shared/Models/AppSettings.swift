//
//  AppSettings.swift
//  Global Thermal Nuclear War
//
//  Color scheme and UI settings inspired by WOPR from WarGames
//

import SwiftUI

struct AppSettings {
    // WOPR-inspired color scheme
    static let terminalGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
    static let terminalAmber = Color(red: 1.0, green: 0.75, blue: 0.0)
    static let terminalRed = Color(red: 1.0, green: 0.0, blue: 0.0)
    static let terminalBackground = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let panelBackground = Color(red: 0.1, green: 0.1, blue: 0.1)

    // Game colors
    static let defcon5 = Color.blue
    static let defcon4 = Color.green
    static let defcon3 = Color.yellow
    static let defcon2 = Color.orange
    static let defcon1 = Color.red

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
