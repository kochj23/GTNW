//
//  DiplomaticMessagesView.swift
//  GTNW
//
//  View for reading diplomatic messages from AI countries
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// Diplomatic message inbox view
struct DiplomaticMessagesView: View {
    @ObservedObject var diplomacyService: SafeDiplomacyService
    @ObservedObject var gameEngine: GameEngine
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var unreadCount: Int {
        diplomacyService.messages.filter { !$0.read }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.title)
                    .foregroundColor(GTNWColors.neonCyan)

                Text("DIPLOMATIC MESSAGES")
                    .font(GTNWFonts.title())
                    .foregroundColor(GTNWColors.terminalGreen)

                if unreadCount > 0 {
                    Text("(\(unreadCount) unread)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(GTNWColors.terminalRed)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(GTNWColors.terminalRed)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.9))

            Divider().background(GTNWColors.terminalGreen)

            if diplomacyService.messages.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "tray")
                        .font(.system(size: 64))
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.5))

                    Text("No Diplomatic Messages")
                        .font(GTNWFonts.title())
                        .foregroundColor(GTNWColors.terminalAmber)

                    Text("AI countries will send diplomatic communications as the game progresses")
                        .font(GTNWFonts.body())
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .frame(maxHeight: .infinity)
            } else {
                // Message list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(diplomacyService.messages) { message in
                            MessageCard(message: message, gameEngine: gameEngine, gameState: gameState)
                                .onAppear {
                                    markAsRead(message)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 700, height: 600)
        .background(Color.black)
        .border(GTNWColors.neonCyan, width: 2)
    }

    private func markAsRead(_ message: SafeDiplomaticMessage) {
        Task { @MainActor in
            if !message.read {
                if let index = diplomacyService.messages.firstIndex(where: { $0.id == message.id }) {
                    diplomacyService.messages[index].read = true
                }
            }
        }
    }
}

/// Individual message card
struct MessageCard: View {
    let message: SafeDiplomaticMessage
    @ObservedObject var gameEngine: GameEngine
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var fromCountry: Country? {
        gameState.countries.first { $0.id == message.from }
    }

    var messageType: MessageType {
        let content = message.content.lowercased()
        if content.contains("request") || content.contains("aid") {
            return .request
        } else if content.contains("propose") || content.contains("pact") {
            return .proposal
        } else if content.contains("demand") || content.contains("cease") {
            return .demand
        }
        return .statement
    }

    enum MessageType {
        case request, proposal, demand, statement
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Country flag/icon
                Text(fromCountry?.flag ?? "🏳️")
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("From: \(fromCountry?.name ?? message.from)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(GTNWColors.terminalGreen)

                        if !message.read {
                            Circle()
                                .fill(GTNWColors.terminalRed)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text("Turn \(message.turn)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                }

                Spacer()

                // Relations indicator
                if let country = fromCountry,
                   let playerID = gameState.getPlayerCountry()?.id,
                   let relations = country.diplomaticRelations[playerID] {
                    VStack(spacing: 4) {
                        Text("Relations")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                        Text("\(relations)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(relationColor(relations))
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                }
            }

            Divider().background(GTNWColors.terminalAmber.opacity(0.3))

            // Message content
            Text(message.content)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(GTNWColors.terminalAmber)
                .lineSpacing(4)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)

            // Action buttons
            HStack(spacing: 12) {
                // Accept button - context-sensitive
                ActionButton(
                    title: acceptButtonTitle,
                    icon: "checkmark.circle.fill",
                    color: GTNWColors.terminalGreen
                ) {
                    acceptMessage()
                }

                // Decline button
                ActionButton(
                    title: "Decline",
                    icon: "xmark.circle.fill",
                    color: GTNWColors.terminalRed
                ) {
                    declineMessage()
                }

                Spacer()
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(message.read ? GTNWColors.terminalAmber.opacity(0.3) : GTNWColors.neonCyan, lineWidth: message.read ? 1 : 2)
                )
        )
    }

    private var acceptButtonTitle: String {
        switch messageType {
        case .request:
            return "Accept & Send Aid ($5B)"
        case .proposal:
            return "Accept Proposal"
        case .demand:
            return "Comply with Demand"
        case .statement:
            return "Acknowledge"
        }
    }

    private func acceptMessage() {
        guard let playerCountry = gameState.getPlayerCountry(),
              let fromCountry = fromCountry else { return }

        switch messageType {
        case .request:
            // Send economic aid
            if playerCountry.gdp >= 5 {
                // Deduct $5B from player GDP
                gameEngine.modifyDiplomaticRelation(from: playerCountry.id, to: fromCountry.id, by: 30)
                gameEngine.modifyDiplomaticRelation(from: fromCountry.id, to: playerCountry.id, by: 30)
                gameEngine.addLog("✓ Sent $5B aid to \(fromCountry.name). Relations improved (+30).", type: .info)
            }

        case .proposal:
            // Form alliance or treaty
            gameEngine.formAlliance(country1: playerCountry.id, country2: fromCountry.id)
            gameEngine.addLog("✓ Accepted proposal from \(fromCountry.name). Alliance formed.", type: .info)

        case .demand:
            // Comply - improve relations but show weakness
            gameEngine.modifyDiplomaticRelation(from: fromCountry.id, to: playerCountry.id, by: 20)
            gameEngine.addLog("✓ Complied with \(fromCountry.name)'s demands. Relations improved (+20).", type: .info)

        case .statement:
            // Just improve relations slightly
            gameEngine.modifyDiplomaticRelation(from: fromCountry.id, to: playerCountry.id, by: 10)
            gameEngine.addLog("✓ Acknowledged message from \(fromCountry.name). Relations +10.", type: .info)
        }

        // Auto-end turn
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            gameEngine.endTurn()
        }

        dismiss()
    }

    private func declineMessage() {
        guard let playerCountry = gameState.getPlayerCountry(),
              let fromCountry = fromCountry else { return }

        // Decline worsens relations
        let relationChange = messageType == .demand ? -20 : -10
        gameEngine.modifyDiplomaticRelation(from: fromCountry.id, to: playerCountry.id, by: relationChange)
        gameEngine.addLog("✗ Declined message from \(fromCountry.name). Relations \(relationChange).", type: .warning)

        // Auto-end turn
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            gameEngine.endTurn()
        }

        dismiss()
    }

    private func relationColor(_ value: Int) -> Color {
        if value >= 50 { return GTNWColors.terminalGreen }
        if value >= 0 { return GTNWColors.terminalAmber }
        if value >= -50 { return GTNWColors.terminalAmber }
        return GTNWColors.terminalRed
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(6)
            .shadow(color: color.opacity(0.5), radius: 4)
        }
        .buttonStyle(.plain)
    }
}
