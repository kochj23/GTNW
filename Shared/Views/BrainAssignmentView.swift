//
//  BrainAssignmentView.swift
//  Global Thermal Nuclear War
//
//  "Who plays each country?" — assign a brain to any nation:
//  Human · This Session (live PvP) · Gateway-Claude · local models · frontier models.
//
//  Created by Jordan Koch on 2026.
//

import SwiftUI

struct BrainAssignmentView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) var dismiss

    @State private var localModels: [ModelInfo] = []
    @State private var loadingModels = false
    @State private var searchText = ""

    /// A small curated set of frontier models reachable via OpenRouter.
    private let frontierModels: [(label: String, id: String)] = [
        ("Claude Opus (OpenRouter)", "anthropic/claude-opus-4.1"),
        ("Claude Sonnet (OpenRouter)", "anthropic/claude-sonnet-4.5"),
        ("GPT (OpenRouter)", "openai/gpt-5"),
        ("Gemini (OpenRouter)", "google/gemini-2.5-pro"),
        ("Llama (OpenRouter)", "meta-llama/llama-3.3-70b-instruct")
    ]
    private let openRouterEndpoint = "https://openrouter.ai/api/v1/chat/completions"

    var body: some View {
        VStack(spacing: 0) {
            header

            if let gameState = gameEngine.gameState {
                List {
                    Section {
                        Text("Every unassigned country uses the fast Rule-Based AI. Set a country to \"This Session\" for true PvP against a live Claude Code session, \"Gateway-Claude\" for an always-on opponent, or any local / frontier model.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    ForEach(filteredCountries(gameState), id: \.id) { country in
                        row(for: country)
                    }
                }
            } else {
                Spacer()
                Text("Start a game to assign brains.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(minWidth: 520, minHeight: 560)
        .onAppear(perform: loadModels)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("🧠 WHO PLAYS EACH COUNTRY?")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalGreen)
                Text("Brain per country · PvP + PvE")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.8))
            }
            Spacer()
            Button(action: loadModels) {
                Label(loadingModels ? "…" : "Refresh Models", systemImage: "arrow.clockwise")
            }
            .disabled(loadingModels)
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }

    private func filteredCountries(_ gameState: GameState) -> [Country] {
        let living = gameState.countries.filter { !$0.isDestroyed }
        guard !searchText.isEmpty else { return living }
        let needle = searchText.lowercased()
        return living.filter { $0.name.lowercased().contains(needle) || $0.id.lowercased().contains(needle) }
    }

    private func row(for country: Country) -> some View {
        let current = gameEngine.brain(for: country.id)
        let isPlayer = gameEngine.gameState?.playerCountryID == country.id
        return HStack(spacing: 12) {
            Text(country.flag).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(country.name)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                Text("☢️ \(country.nuclearWarheads) · mil \(country.militaryStrength)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isPlayer {
                Text("YOU")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(GTNWColors.neonCyan)
            }
            brainMenu(for: country.id, current: current)
        }
        .padding(.vertical, 4)
    }

    private func brainMenu(for countryID: String, current: AIBrain) -> some View {
        Menu {
            Button("Human") { gameEngine.setBrain(.human, for: countryID) }
            Button("Rule-Based AI") { gameEngine.setBrain(.ruleBased, for: countryID) }
            Button("This Session (live PvP)") { gameEngine.setBrain(.liveSession, for: countryID) }
            Button("Gateway-Claude (always-on)") { gameEngine.setBrain(.gatewayClaude, for: countryID) }

            if !localModels.isEmpty {
                Menu("Local Models (Ollama)") {
                    ForEach(localModels) { model in
                        Button(model.name.isEmpty ? model.id : "\(model.name)  \(model.sizeLabel)") {
                            gameEngine.setBrain(
                                .model(id: model.name,
                                       endpoint: "\(ModelRegistry.ollamaHost)/v1/chat/completions",
                                       backend: .ollama),
                                for: countryID)
                        }
                    }
                }
            }

            Menu("Frontier Models (OpenRouter)") {
                ForEach(frontierModels, id: \.id) { fm in
                    Button(fm.label) {
                        gameEngine.setBrain(
                            .model(id: fm.id, endpoint: openRouterEndpoint, backend: .openRouter),
                            for: countryID)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon(for: current))
                Text(current.displayName)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(color(for: current))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color(for: current).opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color(for: current).opacity(0.5), lineWidth: 1))
            .cornerRadius(6)
        }
        .frame(width: 220)
    }

    private func icon(for brain: AIBrain) -> String {
        switch brain {
        case .human: return "person.fill"
        case .ruleBased: return "cpu"
        case .liveSession: return "bolt.horizontal.circle.fill"
        case .gatewayClaude: return "brain.head.profile"
        case .model: return "server.rack"
        }
    }

    private func color(for brain: AIBrain) -> Color {
        switch brain {
        case .human: return GTNWColors.neonCyan
        case .ruleBased: return GTNWColors.terminalGreen
        case .liveSession: return GTNWColors.neonPurple
        case .gatewayClaude: return GTNWColors.terminalAmber
        case .model: return GTNWColors.terminalRed
        }
    }

    private func loadModels() {
        loadingModels = true
        Task {
            let models = await ModelRegistry.fetchLocalModels()
            await MainActor.run {
                self.localModels = models
                self.loadingModels = false
            }
        }
    }
}

#Preview {
    BrainAssignmentView().environmentObject(GameEngine())
}
