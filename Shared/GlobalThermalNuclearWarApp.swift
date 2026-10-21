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
    @StateObject private var fontScale = FontScaleManager.shared
    @State private var showingAISettings = false

    init() {
        #if os(macOS)
        // Under XCTest the app never activates and keeps its windows out of sight (and AudioGate mutes it).
        AudioGate.hideUnderTest()
        if StoreMigrationCLI.isRequested { StoreMigrationCLI.runAndExit() }
        if LaunchSmoke.isRequested {
            // Frame smoke test: boot the full app hidden (never activates, never takes
            // focus, no API server), then quit cleanly. See tools/launch_smoke.sh.
            LaunchSmoke.arm()
            return
        }
        #endif
        NovaAPIServer.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(gameEngine)
                .environmentObject(themes)
                // Default font for any Text without an explicit .font, scaled like everything else.
                .font(.scaled(.body))
                #if os(macOS)
                // Native controls (segmented pickers, popups) ignore .font; grow them with the text.
                .controlSize(FontScale.factor >= 1.5 ? .large : .regular)
                // Minimum window that fits the scaled content (capped to the display).
                .frame(minWidth: FontScale.w(1400), minHeight: FontScale.h(900))
                #endif
                // Rebuild every screen when the skin or text size changes so all theme/font tokens are re-read.
                .id("\(themes.theme.rawValue)-\(fontScale.factor)")
                .preferredColorScheme(.dark)
                .onAppear {
                    let store = GameStoreService.shared
                    gameEngine.autosaveManager = store.local.saves
                    gameEngine.store = store
                    store.start()
                    #if os(macOS)
                    LaunchHooks.apply(to: gameEngine)
                    #endif
                }
                #if os(macOS)
                // Best effort: close the open play session as "quit" (queued; it reaches the DB on the next sync).
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    gameEngine.endPlaySession(outcome: "quit")
                }
                #endif
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
                GameStoreSettingsView().tabItem { Label("Saves & DB", systemImage: "externaldrive.connected.to.line.below") }
            }
            .font(.scaled(.body))
            .controlSize(FontScale.factor >= 1.5 ? .large : .regular)
            .id("\(themes.theme.rawValue)-\(fontScale.factor)")
        }
        #endif
    }
}

#if os(macOS)
import AppKit

/// `--migrate-store [--backup-dir PATH] [--setup-credentials]`: headless one-time import of legacy saves /
/// leaderboard into the Games DB (backup first), print a JSON report, exit 0 when verified (or when no DB is
/// configured). `--setup-credentials` first runs the SSH credential hand-off if the keychain has no password.
enum StoreMigrationCLI {
    static let flag = "--migrate-store"
    static var isRequested: Bool { CommandLine.arguments.contains(flag) }

    static func runAndExit() -> Never {
        let args = CommandLine.arguments
        let backupRoot = args.firstIndex(of: "--backup-dir").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
            .map { URL(fileURLWithPath: $0, isDirectory: true) } ?? LegacyStoreImport.defaultBackupRoot
        if args.contains("--setup-credentials"),
           KeychainGameStoreCredentials().password(account: GameStoreConfig.load().user) == nil {
            do { print("credentials stored: \(try GameStoreSetup.fetchFromCore3())") }
            catch { print("credential setup failed: \(error)") }
        }
        let service = GameStoreService.makeDefault()
        let done = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var report = LegacyImportReport() }
        let box = Box()
        Task.detached {
            box.report = await LegacyStoreImport.run(service: service, defaults: .standard, domain: Bundle.main.bundleIdentifier,
                                                     backupRoot: backupRoot, alwaysBackup: true)
            done.signal()
        }
        done.wait()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: (try? enc.encode(box.report)) ?? Data(), as: UTF8.self))
        // (service.status is published on the main actor, which this blocked thread never yields to; report from the run.)
        print(service.remote == nil ? "status: no Games DB configured (local only)"
              : box.report.synced ? "status: Games DB reachable, synced" : "status: Games DB unreachable, writes pending")
        exit(box.report.verified || service.remote == nil ? 0 : 1)
    }
}

/// Screenshot / QA launch options (skin and text size need no hook: pass `-GTNW.theme retro -GTNW.fontScale 2`,
/// which the UserDefaults argument domain applies without changing saved preferences):
///   `--start-scenario`  start the 1990 world scenario straight into the Situation Room
///   `--open-settings`   open the Settings window after launch
enum LaunchHooks {
    static func apply(to engine: GameEngine) {
        let args = CommandLine.arguments
        if args.contains("--start-scenario"), engine.gameState == nil {
            engine.startScenario(.world1990, turnLength: .month)
        }
        if args.contains("--open-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // The app menu's "Settings…" (⌘,) item, the same path the user takes.
                guard let appMenu = NSApp.mainMenu?.items.first?.submenu,
                      let index = appMenu.items.firstIndex(where: { $0.keyEquivalent == "," }) else { return }
                appMenu.performActionForItem(at: index)
            }
        }
    }
}

/// `--launch-smoke`: start up, reach the run loop, then terminate with exit code 0.
enum LaunchSmoke {
    static let flag = "--launch-smoke"
    static var isRequested: Bool { CommandLine.arguments.contains(flag) }

    static func arm(after seconds: TimeInterval = 2.5) {
        NSApplication.shared.setActivationPolicy(.prohibited)
        // Keep any window the WindowGroup creates off-screen: never steal focus.
        for delay in stride(from: 0.0, through: seconds, by: 0.1) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSApplication.shared.windows.forEach { $0.orderOut(nil) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            print("[LaunchSmoke] reached main run loop; exiting cleanly")
            exit(0)
        }
    }
}
#endif
