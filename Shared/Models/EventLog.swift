//
//  EventLog.swift
//  Global Thermal Nuclear War
//
//  The terminal's event log (moved out of MLXIntegration.swift in 3.24 when the MLX client was replaced by
//  NovaAIKit).
//  Created by Jordan Koch on 2025-12-03.
//

import Foundation
import SwiftUI

/// Event logger for tracking all country actions
class EventLogger: ObservableObject {
    @Published var events: [GameEvent] = []
    private let maxEvents = 500

    func log(_ event: GameEvent) {
        events.insert(event, at: 0)

        // Trim old events
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
    }

    func log(_ message: String, type: GameEvent.EventType, country: String? = nil, turn: Int) {
        let event = GameEvent(
            message: message,
            type: type,
            country: country,
            turn: turn,
            timestamp: Date()
        )
        log(event)
    }

    func clear() {
        events.removeAll()
    }

    func getEventsForTurn(_ turn: Int) -> [GameEvent] {
        return events.filter { $0.turn == turn }
    }
}

struct GameEvent: Identifiable, Codable {
    var id = UUID()
    var message: String
    var type: EventType
    var country: String?
    var turn: Int
    var timestamp: Date

    enum EventType: String, Codable {
        case nuclear = "☢️"
        case war = "⚔️"
        case diplomacy = "🤝"
        case economic = "💰"
        case cyber = "💻"
        case intel = "🔍"
        case system = "⚙️"
    }

    var color: Color {
        switch type {
        case .nuclear: return GTNWColors.terminalRed
        case .war: return .orange
        case .diplomacy: return GTNWColors.terminalGreen
        case .economic: return GTNWColors.neonCyan
        case .cyber: return GTNWColors.neonPurple
        case .intel: return GTNWColors.neonBlue
        case .system: return GTNWColors.terminalAmber
        }
    }
}
