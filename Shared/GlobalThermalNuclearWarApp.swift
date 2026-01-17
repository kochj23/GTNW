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
    @State private var showingAISettings = false

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

            CommandMenu("AI") {
                Button("AI Backend Settings...") {
                    showingAISettings = true
                }
                .keyboardShortcut("a", modifiers: [.command, .option])

                Divider()

                Text("Active: \(AIBackendManager.shared.activeBackend?.rawValue ?? "None")")
                    .disabled(true)
            }
        }
        #endif

        #if os(macOS)
        Settings {
            AIBackendSettingsView()
        }
        #endif
    }
}
