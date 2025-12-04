//
//  GlobalThermalNuclearWarApp.swift
//  Global Thermal Nuclear War
//
//  Main application entry point for all platforms
//  Inspired by the 1983 film "WarGames"
//

import SwiftUI

@main
struct GlobalThermalNuclearWarApp: App {
    @StateObject private var gameEngine = GameEngine()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(gameEngine)
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Game") {
                    gameEngine.startNewGame()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        #endif
    }
}
