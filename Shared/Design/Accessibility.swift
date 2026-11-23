//
//  Accessibility.swift
//  Global Thermal Nuclear War
//
//  3.33.0: VoiceOver labels and values for the map and the Situation Room, and Reduce Motion. The words live here
//  (plain functions of the game state) so the views stay short and the tests can read them.
//

#if GTNW_CORE
import Foundation   // GTNWCore compiles `A11y` (the command box reads it); `Motion` is app-only
#else
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
#endif

enum A11y {

    /// One nation on the map as VoiceOver reads it.
    struct MapNation: Identifiable, Equatable {
        let id: String
        let label: String
        let value: String
    }

    static let mapLabel = "World map"

    /// "France, ally" / "Soviet Union, at war with you" / "Brazil, territory of Portugal" / "United States, your nation".
    static func countryLabel(_ c: Country, in gs: GameState) -> String {
        let player = gs.playerCountryID
        var parts = [c.name]
        if c.id == player { parts.append("your nation") }
        else if c.atWarWith.contains(player) { parts.append("at war with you") }
        else if c.alliances.contains(player) { parts.append("ally") }
        if let owner = c.territoryOf { parts.append("territory of \(gs.getCountry(id: owner)?.name ?? owner)") }
        if c.isDestroyed { parts.append("destroyed") }
        return parts.joined(separator: ", ")
    }

    /// Relations, strength, stability and arms, short enough to hear in one breath.
    static func countryValue(_ c: Country, in gs: GameState) -> String {
        var parts: [String] = []
        if c.id != gs.playerCountryID {
            let r = c.diplomaticRelations[gs.playerCountryID] ?? 0
            parts.append("relations \(r) (\(relationWord(r)))")
        }
        parts.append("military \(c.militaryStrength)")
        parts.append("stability \(c.stability)")
        if c.nuclearWarheads > 0 { parts.append("\(c.nuclearWarheads) warheads") }
        let wars = c.atWarWith.compactMap { gs.getCountry(id: $0)?.name }.sorted()
        if !wars.isEmpty { parts.append("at war with " + wars.joined(separator: " and ")) }
        return parts.joined(separator: ", ")
    }

    static func relationWord(_ r: Int) -> String {
        switch r {
        case ..<(-60): return "hostile"
        case ..<(-20): return "unfriendly"
        case ..<20: return "neutral"
        case ..<60: return "friendly"
        default: return "close"
        }
    }

    /// The map's own value: what is selected and how the world stands.
    static func mapValue(_ gs: GameState, selected: String?) -> String {
        let live = gs.liveCountries
        let wars = gs.activeWars.count
        var s = "\(live.count) nations, \(wars) war\(wars == 1 ? "" : "s"), \(gs.defconName) \(gs.defconLevel.rawValue)"
        if let id = selected {
            s = "Selected: \(gs.getCountry(id: id)?.name ?? WorldCountriesDatabase.template(id: id)?.name ?? id). " + s
        }
        return s
    }

    /// Every nation on the board, the player's first, then by name.
    static func mapNations(_ gs: GameState) -> [MapNation] {
        gs.countries.filter { !$0.isDestroyed }
            .sorted { ($0.id == gs.playerCountryID ? 0 : 1, $0.name) < ($1.id == gs.playerCountryID ? 0 : 1, $1.name) }
            .map { MapNation(id: $0.id, label: countryLabel($0, in: gs), value: countryValue($0, in: gs)) }
    }

    /// The top bar's numbers as one sentence.
    static func statusValue(_ gs: GameState) -> String {
        "\(gs.currentDateLabel), \(gs.actionsRemaining) of \(gs.actionsPerTurn) actions left, popularity "
            + "\(Int(gs.shadow.popularity.rounded())) percent, \(gs.defconName) \(gs.defconLevel.rawValue)"
    }
}

#if !GTNW_CORE
/// Reduce Motion: SwiftUI views read `\.accessibilityReduceMotion`; code outside a view asks `Motion`.
enum Motion {
    /// Tests set this; nil means ask the system.
    nonisolated(unsafe) static var override: Bool?

    static var reduced: Bool {
        if let override { return override }
        #if os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        return UIAccessibility.isReduceMotionEnabled
        #endif
    }

    /// The animation, or none when the player asked for less motion.
    static func allow(_ a: Animation?) -> Animation? { reduced ? nil : a }
}
#endif
