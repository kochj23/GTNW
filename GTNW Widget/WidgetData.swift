//
//  WidgetData.swift
//  GTNW Widget
//
//  Data models for widget display
//  Created by Jordan Koch
//

import Foundation
import WidgetKit
import SwiftUI

/// Simplified game data for widget display
struct GTNWWidgetData: Codable {
    let defconLevel: Int
    let turn: Int
    let presidentName: String
    let administrationName: String
    let isAtWar: Bool
    let activeWarsCount: Int
    let totalCasualties: Int
    let globalRadiation: Int
    let gameOver: Bool
    let gameOverReason: String
    let lastUpdated: Date

    /// Default placeholder data
    static var placeholder: GTNWWidgetData {
        GTNWWidgetData(
            defconLevel: 5,
            turn: 0,
            presidentName: "No Active Game",
            administrationName: "Start a new game",
            isAtWar: false,
            activeWarsCount: 0,
            totalCasualties: 0,
            globalRadiation: 0,
            gameOver: false,
            gameOverReason: "",
            lastUpdated: Date()
        )
    }

    /// Sample data for previews
    static var sample: GTNWWidgetData {
        GTNWWidgetData(
            defconLevel: 3,
            turn: 15,
            presidentName: "John F. Kennedy",
            administrationName: "Kennedy Administration",
            isAtWar: true,
            activeWarsCount: 1,
            totalCasualties: 125000,
            globalRadiation: 0,
            gameOver: false,
            gameOverReason: "",
            lastUpdated: Date()
        )
    }

    /// Critical state sample
    static var criticalSample: GTNWWidgetData {
        GTNWWidgetData(
            defconLevel: 2,
            turn: 42,
            presidentName: "Richard Nixon",
            administrationName: "Nixon Administration",
            isAtWar: true,
            activeWarsCount: 3,
            totalCasualties: 2500000,
            globalRadiation: 15,
            gameOver: false,
            gameOverReason: "",
            lastUpdated: Date()
        )
    }

    // MARK: - DEFCON Display Helpers

    var defconDescription: String {
        switch defconLevel {
        case 5: return "PEACETIME"
        case 4: return "ELEVATED"
        case 3: return "INCREASED"
        case 2: return "MAXIMUM"
        case 1: return "NUCLEAR WAR"
        default: return "UNKNOWN"
        }
    }

    var defconColor: Color {
        switch defconLevel {
        case 5: return .blue
        case 4: return .green
        case 3: return .yellow
        case 2: return .orange
        case 1: return .red
        default: return .gray
        }
    }

    var warStatusText: String {
        if gameOver {
            return "GAME OVER"
        } else if isAtWar {
            return activeWarsCount == 1 ? "AT WAR" : "\(activeWarsCount) WARS"
        } else {
            return "PEACE"
        }
    }

    var warStatusColor: Color {
        if gameOver { return .red }
        return isAtWar ? .orange : .green
    }

    var formattedCasualties: String {
        if totalCasualties == 0 { return "0" }
        if totalCasualties >= 1_000_000 {
            return String(format: "%.1fM", Double(totalCasualties) / 1_000_000)
        } else if totalCasualties >= 1_000 {
            return String(format: "%.0fK", Double(totalCasualties) / 1_000)
        }
        return "\(totalCasualties)"
    }

    var radiationLevel: String {
        if globalRadiation == 0 { return "NONE" }
        if globalRadiation < 25 { return "LOW" }
        if globalRadiation < 50 { return "MODERATE" }
        if globalRadiation < 75 { return "HIGH" }
        return "CRITICAL"
    }

    var radiationColor: Color {
        if globalRadiation == 0 { return .green }
        if globalRadiation < 25 { return .yellow }
        if globalRadiation < 50 { return .orange }
        return .red
    }
}

/// Timeline entry for the widget
struct GTNWWidgetEntry: TimelineEntry {
    let date: Date
    let data: GTNWWidgetData

    static var placeholder: GTNWWidgetEntry {
        GTNWWidgetEntry(date: Date(), data: .placeholder)
    }
}
