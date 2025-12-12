//
//  OllamaService.swift
//  Global Thermal Nuclear War
//
//  Clean HTTP-based LLM integration using Ollama
//  No subprocess management, no MainActor issues, pure Swift
//  Created by Jordan Koch on 2025-12-12.
//

import Foundation
import SwiftUI

/// Ollama HTTP API service for LLM-powered gameplay
@MainActor
class OllamaService: ObservableObject {
    static let shared = OllamaService()

    @Published var isConnected = false
    @Published var availableModels: [OllamaModel] = []
    @Published var currentModel = "qwen3-vl:4b"  // Fast 3.3GB model
    @Published var lastResponse: String = ""
    @Published var isGenerating = false
    @Published var totalTokens: Int = 0
    @Published var tokensPerSecond: Double = 0.0

    private let baseURL = "http://localhost:11434"

    private init() {}

    /// Check if Ollama is running and list available models
    func initialize() async {
        print("[Ollama] Checking connection...")

        guard let url = URL(string: "\(baseURL)/api/tags") else {
            isConnected = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                availableModels = models.compactMap { dict in
                    guard let name = dict["name"] as? String else { return nil }
                    let size = dict["size"] as? Int64 ?? 0
                    return OllamaModel(name: name, size: size)
                }
                isConnected = true
                print("[Ollama] ✅ Connected! Found \(availableModels.count) models")

                // Pick best model
                if availableModels.contains(where: { $0.name.contains("qwen3-vl:4b") }) {
                    currentModel = "qwen3-vl:4b"
                } else if availableModels.contains(where: { $0.name.contains("deepseek-r1:8b") }) {
                    currentModel = "deepseek-r1:8b"
                } else if let first = availableModels.first {
                    currentModel = first.name
                }
                print("[Ollama] Using model: \(currentModel)")
            }
        } catch {
            isConnected = false
            print("[Ollama] ❌ Not running: \(error)")
            print("[Ollama] Start with: ollama serve")
        }
    }

    /// Generate AI response using Ollama
    func generate(prompt: String, maxTokens: Int = 100) async -> String? {
        guard isConnected else {
            print("[Ollama] Not connected, skipping generation")
            return nil
        }

        guard let url = URL(string: "\(baseURL)/api/generate") else { return nil }

        isGenerating = true
        let startTime = Date()
        defer {
            isGenerating = false
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0 {
                tokensPerSecond = Double(totalTokens) / elapsed
            }
        }

        let requestBody: [String: Any] = [
            "model": currentModel,
            "prompt": prompt,
            "stream": false,  // For now, no streaming (simpler)
            "options": [
                "num_predict": maxTokens,
                "temperature": 0.7,
                "top_p": 0.9
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        print("[Ollama] Generating with \(currentModel)...")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[Ollama] Bad response: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseText = json["response"] as? String else {
                print("[Ollama] Failed to parse response")
                return nil
            }

            // Count tokens for metrics
            let tokens = responseText.split(separator: " ").count
            totalTokens += tokens

            lastResponse = responseText
            print("[Ollama] Generated \(tokens) tokens, total: \(totalTokens)")

            return responseText.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch {
            print("[Ollama] Error: \(error)")
            return nil
        }
    }

    /// Generate with streaming (real-time token updates)
    func generateStreaming(prompt: String, maxTokens: Int = 100) async -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard let url = URL(string: "\(baseURL)/api/generate") else {
                    continuation.finish(throwing: NSError(domain: "Ollama", code: -1))
                    return
                }

                let requestBody: [String: Any] = [
                    "model": currentModel,
                    "prompt": prompt,
                    "stream": true,  // Enable streaming
                    "options": [
                        "num_predict": maxTokens,
                        "temperature": 0.7
                    ]
                ]

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                do {
                    let (bytes, _) = try await URLSession.shared.bytes(for: request)

                    for try await line in bytes.lines {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let response = json["response"] as? String {

                            await MainActor.run {
                                totalTokens += 1
                            }

                            continuation.yield(response)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Check if specific model is available
    func hasModel(_ name: String) -> Bool {
        return availableModels.contains { $0.name.contains(name) }
    }

    /// Download/pull a model
    func pullModel(_ name: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/pull") else { return false }

        let requestBody: [String: Any] = [
            "name": name,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300  // 5 minutes for download

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("[Ollama] Pull failed: \(error)")
            return false
        }
    }
}

// MARK: - Data Models

struct OllamaModel: Identifiable {
    let id = UUID()
    let name: String
    let size: Int64

    var sizeFormatted: String {
        let gb = Double(size) / 1_000_000_000
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Prompt Templates

extension OllamaService {
    /// Generate country AI decision
    func generateCountryDecision(country: Country, gameState: GameState) async -> String? {
        let wars = Array(country.atWarWith).joined(separator: ", ")
        let allies = Array(country.alliances).joined(separator: ", ")
        let otherCountries = gameState.countries
            .filter { !$0.isPlayerControlled && !$0.isDestroyed && $0.id != country.id }
            .prefix(8)
            .map { $0.name }
            .joined(separator: ", ")

        let prompt = """
        You are \(country.name)'s strategic AI in a Cold War simulation.

        YOUR STATUS:
        - Alignment: \(country.alignment.rawValue)
        - Military: \(formatNumber(country.militaryStrength))
        - Nukes: \(country.nuclearWarheads)
        - At War: \(wars.isEmpty ? "None" : wars)
        - Allies: \(allies.isEmpty ? "None" : allies)
        - Aggression: \(country.aggressionLevel)/10

        WORLD:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Turn: \(gameState.turn)
        - Wars: \(gameState.activeWars.count)
        - Other nations: \(otherCountries)

        Choose ONE action (respond ONLY in this exact format):
        ACTION: [WAIT / BUILD_MILITARY / BUILD_NUKES / ATTACK [country] / NUKE [country] / ALLY [country]] | REASON: [brief reason]

        Decision:
        """

        return await generate(prompt: prompt, maxTokens: 50)
    }

    /// Generate diplomatic message
    func generateDiplomaticMessage(from: Country, to: Country, purpose: String, gameState: GameState) async -> String? {
        let prompt = """
        You are \(from.name)'s Foreign Minister writing to \(to.name).

        Situation:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Your military: \(formatNumber(from.militaryStrength))
        - Their military: \(formatNumber(to.militaryStrength))
        - Purpose: \(purpose)

        Write a 3-sentence diplomatic message.
        Professional diplomatic language.

        Message:
        """

        return await generate(prompt: prompt, maxTokens: 80)
    }

    /// Generate intelligence report
    func generateIntelReport(about country: Country, gameState: GameState) async -> String? {
        let prompt = """
        Generate CIA intel report on \(country.name):

        Known: Military \(formatNumber(country.militaryStrength)), \(country.nuclearWarheads) nukes, DEFCON \(gameState.defconLevel.rawValue)

        Write 2 sentences covering threats and capabilities.
        CIA briefing style.

        Report:
        """

        return await generate(prompt: prompt, maxTokens: 60)
    }

    /// Parse natural language command
    func parseCommand(_ input: String, gameState: GameState) async -> String? {
        let countries = gameState.countries
            .filter { !$0.isDestroyed && !$0.isPlayerControlled }
            .prefix(10)
            .map { $0.name }
            .joined(separator: ", ")

        let prompt = """
        Parse this command: "\(input)"

        Available countries: \(countries)

        Extract: ACTION: [ATTACK/NUKE/ALLY/BUILD_MILITARY/BUILD_NUKES/SPY] [target] | REASON: [why]

        Parse:
        """

        return await generate(prompt: prompt, maxTokens: 40)
    }

    /// Generate random scenario
    func generateScenario(theme: String = "random") async -> String? {
        let prompt = """
        Generate a unique geopolitical crisis scenario.

        Theme: \(theme)

        Format:
        TITLE: [name]
        YEAR: [year]
        DESCRIPTION: [2 sentences]
        DEFCON: [1-5]
        ALLIANCES: [bloc1] | [bloc2]
        OBJECTIVE: [goal]

        Generate:
        """

        return await generate(prompt: prompt, maxTokens: 150)
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000.0)
        } else if number >= 1_000 {
            return String(format: "%.0fK", Double(number) / 1_000.0)
        }
        return "\(number)"
    }
}
