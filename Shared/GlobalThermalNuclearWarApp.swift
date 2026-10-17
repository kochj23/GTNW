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

    init() {
        NovaAPIServer.shared.start()
    }

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

            CommandMenu("Retro") {
                Toggle("Shadow President Art", isOn: Binding(get: { ShadowPack.shared.useRetroArt },
                                                             set: { ShadowPack.shared.useRetroArt = $0 }))
                Toggle("Sound Effects", isOn: Binding(get: { ShadowPack.shared.soundEnabled },
                                                      set: { ShadowPack.shared.soundEnabled = $0 }))
                Button("Reload Shadow Pack") { ShadowPack.shared.reload() }
            }
        }
        #endif

        #if os(macOS)
        Settings {
            TabView {
                AIBackendSettingsView().tabItem { Label("AI", systemImage: "cpu") }
                ShadowPackSettingsView().tabItem { Label("Shadow Pack", systemImage: "eye") }
            }
        }
        #endif
    }
}
