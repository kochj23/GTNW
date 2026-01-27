//
//  PropagandaEngine.swift
//  GTNW
//
//  AI-Generated Propaganda System
//  Real-time poster generation based on game state
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class PropagandaEngine: ObservableObject {
    static let shared = PropagandaEngine()

    @Published var isGenerating = false
    @Published var propagandaGallery: [PropagandaPoster] = []
    @Published var lastError: String?

    private let imageGen = ImageGenerationUnified.shared
    private let llm = AIBackendManager.shared

    private init() {
        loadGallery()
    }

    // MARK: - Generate Propaganda

    func generateWarPropaganda(
        war: War,
        perspective: Country,
        style: PropagandaStyle
    ) async throws -> PropagandaPoster {
        isGenerating = true
        defer { isGenerating = false }

        // 1. Generate propaganda prompt using AI
        let promptEnhancement = """
        Create propaganda poster description for \(perspective.name) in war against \(war.opponent(of: perspective)?.name ?? "enemy").

        Style: \(style.rawValue)
        Era: \(war.startYear ?? 2025)
        Perspective: \(perspective.governmentType.rawValue) nation

        Include:
        - Patriotic slogan (bold text)
        - Visual elements (flag, soldier, symbols)
        - Color scheme (national colors)
        - Emotional tone (heroic, defensive, vengeful)

        Return only the visual description for image generation.
        """

        let enhancedPrompt = try await llm.generate(prompt: promptEnhancement)

        // 2. Generate image using SwarmUI/DALL-E
        let imageData = try await imageGen.generateImage(
            prompt: enhancedPrompt,
            backend: .swarmui,
            size: .portrait512x768,
            style: .artistic
        )

        // 3. Create poster object
        let poster = PropagandaPoster(
            id: UUID(),
            type: .war,
            country: perspective,
            title: generatePosterTitle(war: war, perspective: perspective),
            imageData: imageData,
            prompt: enhancedPrompt,
            style: style,
            timestamp: Date(),
            event: "War: \(war.description)"
        )

        // 4. Save to gallery
        propagandaGallery.append(poster)
        savePoster(poster)

        return poster
    }

    func generateVictoryPropaganda(
        winner: Country,
        victoryType: VictoryType
    ) async throws -> PropagandaPoster {
        isGenerating = true
        defer { isGenerating = false }

        let prompt = """
        Victory celebration poster, \(winner.name) triumphant,
        \(victoryType.rawValue) victory, heroic imagery,
        national colors, bold celebratory text "VICTORY",
        jubilant crowd, flags waving, 1940s propaganda style
        """

        let imageData = try await imageGen.generateImage(
            prompt: prompt,
            backend: .swarmui,
            size: .portrait512x768,
            style: .artistic
        )

        let poster = PropagandaPoster(
            id: UUID(),
            type: .victory,
            country: winner,
            title: "\(victoryType.rawValue.uppercased()) VICTORY!",
            imageData: imageData,
            prompt: prompt,
            style: .vintage,
            timestamp: Date(),
            event: "Victory: \(victoryType.rawValue)"
        )

        propagandaGallery.append(poster)
        savePoster(poster)

        return poster
    }

    func generateNuclearStrikeMemorial(
        target: Country,
        warheadCount: Int,
        casualties: Int
    ) async throws -> PropagandaPoster {
        isGenerating = true
        defer { isGenerating = false }

        let prompt = """
        Somber memorial poster for nuclear attack on \(target.name),
        \(warheadCount) warheads, \(casualties) casualties,
        mushroom cloud in background, dark tones,
        text "NEVER FORGET", memorial aesthetic,
        respectful and haunting, black and white
        """

        let imageData = try await imageGen.generateImage(
            prompt: prompt,
            backend: .swarmui,
            size: .portrait512x768,
            style: .realistic
        )

        let poster = PropagandaPoster(
            id: UUID(),
            type: .memorial,
            country: target,
            title: "In Memory: \(target.name)",
            imageData: imageData,
            prompt: prompt,
            style: .somber,
            timestamp: Date(),
            event: "Nuclear Strike: \(warheadCount) warheads"
        )

        propagandaGallery.append(poster)
        savePoster(poster)

        return poster
    }

    func generateRecruitmentPoster(
        country: Country,
        urgency: RecruitmentUrgency
    ) async throws -> PropagandaPoster {
        isGenerating = true
        defer { isGenerating = false }

        let prompt = """
        \(urgency.rawValue) military recruitment poster for \(country.name),
        "YOUR COUNTRY NEEDS YOU" bold text,
        heroic soldier pointing at viewer,
        \(country.name) flag colors,
        vintage WW2 propaganda style,
        patriotic and stirring
        """

        let imageData = try await imageGen.generateImage(
            prompt: prompt,
            backend: .swarmui,
            size: .portrait512x768,
            style: .artistic
        )

        let poster = PropagandaPoster(
            id: UUID(),
            type: .recruitment,
            country: country,
            title: "\(country.name.uppercased()) NEEDS YOU!",
            imageData: imageData,
            prompt: prompt,
            style: .vintage,
            timestamp: Date(),
            event: "Recruitment: \(urgency.rawValue)"
        )

        propagandaGallery.append(poster)
        savePoster(poster)

        return poster
    }

    // MARK: - Gallery Management

    private func loadGallery() {
        // Load from persistent storage
        let galleryPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("GTNW/Propaganda")

        // Load saved posters (simplified)
        propagandaGallery = []
    }

    private func savePoster(_ poster: PropagandaPoster) {
        // Save to disk
        let galleryPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("GTNW/Propaganda")

        try? FileManager.default.createDirectory(
            at: galleryPath,
            withIntermediateDirectories: true
        )

        let posterPath = galleryPath.appendingPathComponent("\(poster.id.uuidString).jpg")
        try? poster.imageData.write(to: posterPath)
    }

    // MARK: - Helpers

    private func generatePosterTitle(war: War, perspective: Country) -> String {
        let opponent = war.opponent(of: perspective)?.name ?? "Enemy"
        let templates = [
            "DEFEND \(perspective.name.uppercased())!",
            "VICTORY OVER \(opponent.uppercased())",
            "\(perspective.name.uppercased()) STANDS STRONG",
            "FREEDOM CALLS - ANSWER TODAY",
            "UNITE AGAINST \(opponent.uppercased())"
        ]
        return templates.randomElement() ?? templates[0]
    }
}

// MARK: - Models

struct PropagandaPoster: Identifiable, Codable {
    let id: UUID
    let type: PropagandaType
    let country: Country
    let title: String
    let imageData: Data
    let prompt: String
    let style: PropagandaStyle
    let timestamp: Date
    let event: String
}

enum PropagandaType: String, Codable {
    case war = "War Poster"
    case victory = "Victory"
    case memorial = "Memorial"
    case recruitment = "Recruitment"
    case alliance = "Alliance"
    case enemy = "Enemy Propaganda"
}

enum PropagandaStyle: String, Codable {
    case vintage = "1940s Vintage"
    case modern = "Modern"
    case somber = "Somber Memorial"
    case heroic = "Heroic"
    case threatening = "Threatening"
}

enum RecruitmentUrgency: String {
    case urgent = "URGENT"
    case immediate = "IMMEDIATE"
    case critical = "CRITICAL"
}

// MARK: - War Extension

extension War {
    func opponent(of country: Country) -> Country? {
        // Return the other country in the war
        if aggressor.id == country.id {
            return defender
        } else if defender.id == country.id {
            return aggressor
        }
        return nil
    }
}

// MARK: - Propaganda Gallery View

struct PropagandaGalleryView: View {
    @StateObject private var propaganda = PropagandaEngine.shared

    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300))
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(propaganda.propagandaGallery.reversed()) { poster in
                        PosterCardView(poster: poster)
                    }
                }
                .padding()
            }
            .navigationTitle("🎨 Propaganda Gallery")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Text("\(propaganda.propagandaGallery.count) posters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct PosterCardView: View {
    let poster: PropagandaPoster

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster image
            if let nsImage = NSImage(data: poster.imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
            }

            // Poster info
            VStack(alignment: .leading, spacing: 4) {
                Text(poster.title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(poster.country.name)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Text(poster.event)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(8)
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
