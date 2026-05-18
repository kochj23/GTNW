//
//  WidgetSync.swift
//  Global Thermal Nuclear War
//
//  Syncs game state to the widget via App Group shared container
//  Created by Jordan Koch
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// App Group identifier for shared container
private let appGroupIdentifier = "group.com.jkoch.gtnw"
private let widgetDataKey = "GTNWWidgetData"

// MARK: - Widget Data Model (Shared with Widget Extension)

/// Simplified game data for widget display
/// This is a copy of the model in the widget for the main app to use
struct WidgetGameData: Codable {
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
}

// MARK: - GameState Widget Sync Extension

extension GameState {
    /// Sync current game state to the widget
    /// Call this after significant game state changes:
    /// - Turn advances
    /// - DEFCON level changes
    /// - War starts/ends
    /// - Game over
    func syncToWidget(presidentName: String = "Unknown", administrationName: String = "Unknown") {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("[WidgetSync] Error: Could not access App Group container")
            return
        }

        let widgetData = WidgetGameData(
            defconLevel: defconLevel.rawValue,
            turn: turn,
            presidentName: presidentName,
            administrationName: administrationName,
            isAtWar: !activeWars.isEmpty,
            activeWarsCount: activeWars.count,
            totalCasualties: totalCasualties,
            globalRadiation: globalRadiation,
            gameOver: gameOver,
            gameOverReason: gameOverReason,
            lastUpdated: Date()
        )

        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(widgetData)
            defaults.set(encoded, forKey: widgetDataKey)
            defaults.synchronize()

            // Reload widget timelines
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif

            print("[WidgetSync] Synced: Turn \(turn), DEFCON \(defconLevel.rawValue), Wars \(activeWars.count)")
        } catch {
            print("[WidgetSync] Error encoding widget data: \(error)")
        }
    }

    /// Clear widget data when game ends or resets
    func clearWidgetData() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.removeObject(forKey: widgetDataKey)
        defaults.synchronize()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        print("[WidgetSync] Cleared widget data")
    }
}

// MARK: - Convenience Functions

/// Global function to sync game state to widget
/// Can be called from anywhere in the app
func syncGameToWidget(gameState: GameState, presidentName: String, administrationName: String) {
    gameState.syncToWidget(presidentName: presidentName, administrationName: administrationName)
}
