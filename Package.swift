// swift-tools-version: 6.0
//
//  Package.swift
//  GTNW
//
//  GTNWCore: the game engine as a SwiftPM library — pure Swift + Foundation, no SwiftUI/AppKit/UIKit/Combine/os/
//  NovaAIKit/Dispatch — built from the same files the Xcode app compiles (no copies, no moves). Every app-only piece
//  in those files sits behind `#if !GTNW_CORE`, which this package defines. Documentation/WASM-PORT.md has the
//  boundary, the platform services and the phase-2 plan.
//
//  Targets:
//  - GTNWCore      the engine (the `coreSources` below; everything else in Shared/ is excluded) and, in
//                  Shared/CoreSupport, the JSON bridge (newGame / act / endTurn / snapshot / save / load)
//  - GTNWWasm      the WebAssembly reactor: C-ABI exports around the bridge (Swift SDK for WebAssembly)
//  - gtnw-golden   a CLI that plays the golden games through the bridge (native, or under WASI) for the parity check
//  - CGTNWExecutor the Swift concurrency hooks the bridge uses to run the engine's tasks on one thread, to completion
//
//  The Xcode project (GTNW.xcodeproj) does not use this package; it compiles the same files directly.
//
//  Native:  swift build --product gtnw-golden && swift test
//  Wasm:    Wasm/build.sh (Swift SDK for WebAssembly, toolchain and SDK under /Volumes/Data)
//

import Foundation
import PackageDescription

/// Engine files and folders (relative to Shared/) that make up the core. Everything else in Shared/ is app-only.
let coreSources: [String] = [
    "CoreSupport",
    "Engine",
    "Models",
    "Events/EmergencyCatalog.swift",
    "Events/WorldWatch.swift",
    "AI/AIOutputSanitizer.swift",
    "Design/Accessibility.swift",   // A11y's spoken descriptions (the command box answers with them)
    "Storage/GameStore.swift",
    "Storage/GameStoreRecords.swift",
    "Storage/InMemoryGameStore.swift",
    "Storage/PlayHistory.swift",
    // The map's data half (outline ids, owners by year); its drawing half is `#if !GTNW_CORE`.
    "Views/SituationRoom/VectorWorldMap.swift",
]

/// Files inside the core folders that are not core: dead code no Xcode target compiles, and app-only models.
let notCore: [String] = [
    "Models/AIPersonalityEngine.swift", "Models/AIWarRoom.swift", "Models/NarrativeEngine.swift",
    "Models/NuclearClubProgression.swift", "Models/WhatIfSimulator.swift", "Models/WorldCountriesDatabase_Complete.swift",
    "Models/AppSettings.swift", "Models/KeyBindings.swift", "Models/ModernDesignSystem.swift", "Models/WidgetSync.swift",
]

/// Everything under Shared/ that is not a core source, so SwiftPM neither compiles it nor warns about it. Computed
/// from the tree, so a new view or asset never needs listing here.
func appOnlyPaths() -> [String] {
    let shared = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Shared")
    func walk(_ rel: String) -> [String] {
        let dir = rel.isEmpty ? shared : shared.appendingPathComponent(rel)
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { !$0.hasPrefix(".") }
        return names.sorted().flatMap { name -> [String] in
            let path = rel.isEmpty ? name : rel + "/" + name
            if coreSources.contains(path) { return [] }
            if coreSources.contains(where: { $0.hasPrefix(path + "/") }) { return walk(path) }
            return [path]
        }
    }
    return walk("") + notCore
}

/// WebAssembly links FoundationEssentials, not Foundation: Foundation brings ICU, whose data was 35 MB of the 49 MB
/// module. There `import Foundation` means FoundationEssentials (a module alias), and the few APIs that need ICU or
/// the rest of Foundation (String(format:), .formatted(), .capitalized, regular expressions, JSONSerialization,
/// UserDefaults, NSLock) come from Shared/CoreSupport/Essentials.swift. `GTNW_ESSENTIALS` marks that build.
let core: [SwiftSetting] = [
    .define("GTNW_CORE"), .swiftLanguageMode(.v5),
    .define("GTNW_ESSENTIALS", .when(platforms: [.wasi])),
    .unsafeFlags(["-module-alias", "Foundation=FoundationEssentials"], .when(platforms: [.wasi])),
]

let package = Package(
    name: "GTNW",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GTNWCore", targets: ["GTNWCore"]),
        .executable(name: "gtnw-golden", targets: ["gtnw-golden"]),
        .executable(name: "GTNWWasm", targets: ["GTNWWasm"]),
    ],
    targets: [
        .target(name: "CGTNWExecutor", path: "Wasm/Sources/CGTNWExecutor"),
        .target(name: "GTNWCore", dependencies: ["CGTNWExecutor"], path: "Shared", exclude: appOnlyPaths(), sources: coreSources,
                swiftSettings: core),
        .executableTarget(name: "gtnw-golden", dependencies: ["GTNWCore"], path: "Wasm/Sources/gtnw-golden", swiftSettings: core),
        .executableTarget(name: "GTNWWasm", dependencies: ["GTNWCore"], path: "Wasm/Sources/GTNWWasm", swiftSettings: core),
        .testTarget(name: "GTNWCoreTests", dependencies: ["GTNWCore"], path: "Wasm/Tests/GTNWCoreTests", swiftSettings: core),
    ]
)
