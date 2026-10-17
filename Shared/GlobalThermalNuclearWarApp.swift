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
    @StateObject private var themes = ThemeManager.shared
    @State private var showingAISettings = false

    init() {
        NovaAPIServer.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(gameEngine)
                .environmentObject(themes)
                // Rebuild every screen when the skin changes so all theme tokens are re-read.
                .id(themes.theme)
                .preferredColorScheme(.dark)
                .onAppear { gameEngine.autosaveManager = SaveManager() }
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
                Picker("Skin", selection: $themes.theme) {
                    ForEach(GameTheme.allCases) { Text($0.displayName).tag($0) }
                }
                Button(themes.isRetro ? "Switch to Modern Skin" : "Switch to Retro Skin") { themes.toggle() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
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
                ThemeSettingsView().tabItem { Label("Game", systemImage: "gamecontroller") }
                AIBackendSettingsView().tabItem { Label("AI", systemImage: "cpu") }
                ShadowPackSettingsView().tabItem { Label("Shadow Pack", systemImage: "eye") }
            }
        }
        #endif
    }
}
