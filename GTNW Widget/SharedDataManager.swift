//
//  SharedDataManager.swift
//  GTNW Widget
//
//  App Group data sharing between main app and widget
//  Created by Jordan Koch
//

import Foundation
import WidgetKit

/// Manages shared data between the main GTNW app and widget
class SharedDataManager {
    static let shared = SharedDataManager()

    /// App Group identifier for shared container
    static let appGroupIdentifier = "group.com.jkoch.gtnw"

    /// Key for storing widget data in shared container
    private let widgetDataKey = "GTNWWidgetData"

    /// Shared UserDefaults for App Group
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    private init() {}

    // MARK: - Save Data (Called from main app)

    /// Save current game state to shared container
    /// Call this whenever game state changes significantly
    func saveWidgetData(_ data: GTNWWidgetData) {
        guard let defaults = sharedDefaults else {
            print("[Widget] Error: Could not access shared UserDefaults")
            return
        }

        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(data)
            defaults.set(encoded, forKey: widgetDataKey)
            defaults.synchronize()

            // Reload widget timelines
            WidgetCenter.shared.reloadAllTimelines()

            print("[Widget] Saved game state: Turn \(data.turn), DEFCON \(data.defconLevel)")
        } catch {
            print("[Widget] Error encoding widget data: \(error)")
        }
    }

    /// Convenience method to save from GameState
    func saveFromGameState(
        defconLevel: Int,
        turn: Int,
        presidentName: String,
        administrationName: String,
        isAtWar: Bool,
        activeWarsCount: Int,
        totalCasualties: Int,
        globalRadiation: Int,
        gameOver: Bool,
        gameOverReason: String
    ) {
        let data = GTNWWidgetData(
            defconLevel: defconLevel,
            turn: turn,
            presidentName: presidentName,
            administrationName: administrationName,
            isAtWar: isAtWar,
            activeWarsCount: activeWarsCount,
            totalCasualties: totalCasualties,
            globalRadiation: globalRadiation,
            gameOver: gameOver,
            gameOverReason: gameOverReason,
            lastUpdated: Date()
        )
        saveWidgetData(data)
    }

    // MARK: - Load Data (Called from widget)

    /// Load current widget data from shared container
    func loadWidgetData() -> GTNWWidgetData {
        guard let defaults = sharedDefaults else {
            print("[Widget] Error: Could not access shared UserDefaults")
            return .placeholder
        }

        guard let data = defaults.data(forKey: widgetDataKey) else {
            print("[Widget] No saved widget data found")
            return .placeholder
        }

        do {
            let decoder = JSONDecoder()
            let widgetData = try decoder.decode(GTNWWidgetData.self, from: data)

            // Check if data is stale (more than 24 hours old)
            let timeSinceUpdate = Date().timeIntervalSince(widgetData.lastUpdated)
            if timeSinceUpdate > 86400 { // 24 hours
                print("[Widget] Widget data is stale, returning placeholder")
                return .placeholder
            }

            return widgetData
        } catch {
            print("[Widget] Error decoding widget data: \(error)")
            return .placeholder
        }
    }

    // MARK: - Clear Data

    /// Clear widget data (call when game ends or is reset)
    func clearWidgetData() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: widgetDataKey)
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        print("[Widget] Cleared widget data")
    }
}

// MARK: - Extension for Main App Integration

extension SharedDataManager {
    /// Quick update for DEFCON level changes
    func updateDefconLevel(_ level: Int) {
        var data = loadWidgetData()
        data = GTNWWidgetData(
            defconLevel: level,
            turn: data.turn,
            presidentName: data.presidentName,
            administrationName: data.administrationName,
            isAtWar: data.isAtWar,
            activeWarsCount: data.activeWarsCount,
            totalCasualties: data.totalCasualties,
            globalRadiation: data.globalRadiation,
            gameOver: data.gameOver,
            gameOverReason: data.gameOverReason,
            lastUpdated: Date()
        )
        saveWidgetData(data)
    }

    /// Quick update for turn advancement
    func updateTurn(_ turn: Int, casualties: Int, radiation: Int) {
        var data = loadWidgetData()
        data = GTNWWidgetData(
            defconLevel: data.defconLevel,
            turn: turn,
            presidentName: data.presidentName,
            administrationName: data.administrationName,
            isAtWar: data.isAtWar,
            activeWarsCount: data.activeWarsCount,
            totalCasualties: casualties,
            globalRadiation: radiation,
            gameOver: data.gameOver,
            gameOverReason: data.gameOverReason,
            lastUpdated: Date()
        )
        saveWidgetData(data)
    }
}
