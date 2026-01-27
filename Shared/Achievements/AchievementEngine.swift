//
//  AchievementEngine.swift
//  GTNW
//
//  Achievement System with AI-Generated Commemorative Posters
//  50+ achievements tracking presidential accomplishments
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class AchievementEngine: ObservableObject {
    static let shared = AchievementEngine()

    @Published var unlockedAchievements: Set<String> = []
    @Published var achievementProgress: [String: Double] = [:]
    @Published var recentUnlock: Achievement?
    @Published var showUnlockAnimation = false

    private let imageGen = ImageGenerationUnified.shared
    private let storage = UserDefaults.standard

    private init() {
        loadUnlocked()
    }

    // MARK: - Achievement Definitions

    func allAchievements() -> [Achievement] {
        return [
            // Founding Era
            Achievement(
                id: "founding_father",
                name: "Founding Father",
                description: "Play as all 6 founding presidents",
                category: .historical,
                requirement: 6,
                icon: "building.columns",
                rarity: .legendary
            ),
            Achievement(
                id: "washington_complete",
                name: "Father of the Nation",
                description: "Complete Washington administration",
                category: .historical,
                requirement: 1,
                icon: "flag",
                rarity: .common
            ),
            Achievement(
                id: "louisiana_purchase",
                name: "Continental Vision",
                description: "Execute Louisiana Purchase as Jefferson",
                category: .historical,
                requirement: 1,
                icon: "map",
                rarity: .uncommon
            ),

            // Civil War Era
            Achievement(
                id: "preserve_union",
                name: "Preserver of the Union",
                description: "Win Civil War as Lincoln",
                category: .historical,
                requirement: 1,
                icon: "shield",
                rarity: .rare
            ),
            Achievement(
                id: "emancipation",
                name: "Great Emancipator",
                description: "Issue Emancipation Proclamation",
                category: .historical,
                requirement: 1,
                icon: "hand.raised",
                rarity: .rare
            ),

            // Peace Achievements
            Achievement(
                id: "peace_maker",
                name: "Peace Maker",
                description: "Complete 20 turns without declaring war",
                category: .diplomatic,
                requirement: 20,
                icon: "dove",
                rarity: .rare
            ),
            Achievement(
                id: "master_diplomat",
                name: "Master Diplomat",
                description: "Achieve 80%+ allied nations",
                category: .diplomatic,
                requirement: 80,
                icon: "hand.wave",
                rarity: .epic
            ),
            Achievement(
                id: "mediator",
                name: "The Mediator",
                description: "Successfully mediate 10 conflicts",
                category: .diplomatic,
                requirement: 10,
                icon: "scale.3d",
                rarity: .uncommon
            ),

            // War Achievements
            Achievement(
                id: "warlord",
                name: "Warlord",
                description: "Win 10 wars",
                category: .military,
                requirement: 10,
                icon: "shield.lefthalf.filled",
                rarity: .rare
            ),
            Achievement(
                id: "nuclear_supremacy",
                name: "Nuclear Supremacy",
                description: "Be the only nuclear power remaining",
                category: .military,
                requirement: 1,
                icon: "bolt.circle",
                rarity: .legendary
            ),
            Achievement(
                id: "dr_strangelove",
                name: "Dr. Strangelove",
                description: "Launch 100+ nuclear warheads across games",
                category: .military,
                requirement: 100,
                icon: "atom",
                rarity: .legendary
            ),
            Achievement(
                id: "first_strike",
                name: "First Strike",
                description: "Launch your first nuclear weapon",
                category: .military,
                requirement: 1,
                icon: "bolt",
                rarity: .common
            ),

            // Covert Achievements
            Achievement(
                id: "shadow_operator",
                name: "Shadow Operator",
                description: "50 successful covert operations",
                category: .covert,
                requirement: 50,
                icon: "eye.slash",
                rarity: .epic
            ),
            Achievement(
                id: "spymaster",
                name: "Spymaster",
                description: "Establish spy networks in 20 countries",
                category: .covert,
                requirement: 20,
                icon: "binoculars",
                rarity: .rare
            ),
            Achievement(
                id: "regime_change",
                name: "Regime Change",
                description: "Successfully orchestrate 5 coups",
                category: .covert,
                requirement: 5,
                icon: "arrow.triangle.2.circlepath",
                rarity: .rare
            ),

            // Economic Achievements
            Achievement(
                id: "economic_powerhouse",
                name: "Economic Powerhouse",
                description: "Achieve highest GDP among all nations",
                category: .economic,
                requirement: 1,
                icon: "dollarsign.circle",
                rarity: .rare
            ),
            Achievement(
                id: "sanctions_master",
                name: "Economic Warrior",
                description: "Successfully sanction 15 countries",
                category: .economic,
                requirement: 15,
                icon: "xmark.circle",
                rarity: .uncommon
            ),

            // Crisis Management
            Achievement(
                id: "crisis_veteran",
                name: "Crisis Veteran",
                description: "Successfully resolve 50 historical crises",
                category: .strategic,
                requirement: 50,
                icon: "exclamationmark.triangle",
                rarity: .epic
            ),
            Achievement(
                id: "cuban_missile_survivor",
                name: "Brink of Annihilation",
                description: "Survive Cuban Missile Crisis",
                category: .strategic,
                requirement: 1,
                icon: "flame",
                rarity: .rare
            ),

            // Survival Achievements
            Achievement(
                id: "nuclear_winter_survivor",
                name: "Sole Survivor",
                description: "Win after surviving nuclear winter",
                category: .survival,
                requirement: 1,
                icon: "snowflake",
                rarity: .legendary
            ),
            Achievement(
                id: "defcon_1_escape",
                name: "Edge of Oblivion",
                description: "Reach DEFCON 1 and de-escalate to peace",
                category: .survival,
                requirement: 1,
                icon: "arrow.down.circle",
                rarity: .epic
            ),

            // Collection Achievements
            Achievement(
                id: "time_traveler",
                name: "Time Traveler",
                description: "Play all 47 presidents",
                category: .collection,
                requirement: 47,
                icon: "clock.arrow.circlepath",
                rarity: .legendary
            ),
            Achievement(
                id: "cold_warrior",
                name: "Cold Warrior",
                description: "Complete all Cold War presidents (Truman-Bush Sr.)",
                category: .collection,
                requirement: 9,
                icon: "snowflake.circle",
                rarity: .epic
            ),
            Achievement(
                id: "modern_president",
                name: "Modern President",
                description: "Play all post-Cold War presidents",
                category: .collection,
                requirement: 6,
                icon: "laptopcomputer",
                rarity: .rare
            ),

            // Special Achievements
            Achievement(
                id: "wopr_choice",
                name: "WOPR's Choice",
                description: "Discover the secret ending",
                category: .special,
                requirement: 1,
                icon: "brain",
                rarity: .legendary
            ),
            Achievement(
                id: "provocateur",
                name: "The Provocateur",
                description: "Start World War 3",
                category: .special,
                requirement: 1,
                icon: "flame.circle",
                rarity: .uncommon
            ),
            Achievement(
                id: "betrayer",
                name: "Betrayer of Trust",
                description: "Break 10 alliances",
                category: .special,
                requirement: 10,
                icon: "hand.thumbsdown",
                rarity: .rare
            ),
            Achievement(
                id: "pacifist",
                name: "Pacifist",
                description: "Win game without military action",
                category: .special,
                requirement: 1,
                icon: "heart",
                rarity: .epic
            )
        ]
    }

    // MARK: - Check Achievements

    func checkAchievements(gameState: GameState) {
        for achievement in allAchievements() {
            guard !isUnlocked(achievement.id) else { continue }

            if shouldUnlock(achievement, gameState: gameState) {
                Task {
                    await unlockAchievement(achievement)
                }
            }
        }
    }

    private func shouldUnlock(_ achievement: Achievement, gameState: GameState) -> Bool {
        switch achievement.id {
        case "peace_maker":
            return gameState.turnNumber >= 20 && gameState.warsStarted == 0

        case "nuclear_supremacy":
            let nuclearPowers = gameState.countries.filter { $0.hasNuclearWeapons }
            return nuclearPowers.count == 1 && nuclearPowers.first?.isPlayer == true

        case "dr_strangelove":
            return gameState.totalWarheadsLaunched >= 100

        case "time_traveler":
            return gameState.presidentsPlayed.count >= 47

        // Add more checks for each achievement
        default:
            return false
        }
    }

    // MARK: - Unlock Achievement

    func unlockAchievement(_ achievement: Achievement) async {
        guard !isUnlocked(achievement.id) else { return }

        // Mark as unlocked
        unlockedAchievements.insert(achievement.id)
        saveUnlocked()

        // Generate commemorative poster
        if let poster = try? await generateAchievementPoster(achievement) {
            achievement.commemorativePoster = poster
        }

        // Show unlock animation
        recentUnlock = achievement
        showUnlockAnimation = true

        // Hide after 5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            showUnlockAnimation = false
        }
    }

    private func generateAchievementPoster(_ achievement: Achievement) async throws -> Data {
        let prompt = """
        Achievement badge for "\(achievement.name)",
        description: \(achievement.description),
        rarity: \(achievement.rarity.rawValue),
        category: \(achievement.category.rawValue),
        golden trophy, presidential seal,
        elegant design, commemorative style,
        bold text "\(achievement.name.uppercased())",
        achievement unlocked aesthetic
        """

        return try await imageGen.generateImage(
            prompt: prompt,
            backend: .dalle,
            size: .square512,
            style: .artistic
        )
    }

    // MARK: - Persistence

    private func loadUnlocked() {
        if let saved = storage.array(forKey: "gtnw_achievements") as? [String] {
            unlockedAchievements = Set(saved)
        }
    }

    private func saveUnlocked() {
        storage.set(Array(unlockedAchievements), forKey: "gtnw_achievements")
    }

    func isUnlocked(_ id: String) -> Bool {
        return unlockedAchievements.contains(id)
    }

    func completionPercentage() -> Double {
        let total = allAchievements().count
        let unlocked = unlockedAchievements.count
        return Double(unlocked) / Double(total) * 100.0
    }
}

// MARK: - Achievement Model

struct Achievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: AchievementCategory
    let requirement: Int
    let icon: String
    let rarity: AchievementRarity
    var commemorativePoster: Data?
}

enum AchievementCategory: String {
    case historical = "Historical"
    case diplomatic = "Diplomatic"
    case military = "Military"
    case covert = "Covert Operations"
    case economic = "Economic"
    case strategic = "Strategic"
    case survival = "Survival"
    case collection = "Collection"
    case special = "Special"
}

enum AchievementRarity: String {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"

    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

// MARK: - Achievement Unlock View

struct AchievementUnlockView: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 16) {
            // Rarity indicator
            Text(achievement.rarity.rawValue.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(achievement.rarity.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(achievement.rarity.color.opacity(0.2))
                .cornerRadius(8)

            // Icon
            Image(systemName: achievement.icon)
                .font(.system(size: 60))
                .foregroundColor(achievement.rarity.color)

            // Achievement name
            Text("ACHIEVEMENT UNLOCKED")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            Text(achievement.name)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(achievement.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Commemorative poster
            if let posterData = achievement.commemorativePoster,
               let nsImage = NSImage(data: posterData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 300)
                    .cornerRadius(12)
            }
        }
        .padding(32)
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(achievement.rarity.color, lineWidth: 3)
                )
        )
        .shadow(color: achievement.rarity.color.opacity(0.5), radius: 20)
    }
}

// MARK: - Achievements View

struct AchievementsView: View {
    @StateObject private var achievements = AchievementEngine.shared

    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200))
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                // Progress summary
                VStack(spacing: 8) {
                    Text("Achievement Progress")
                        .font(.headline)
                        .foregroundColor(.white)

                    ProgressView(value: achievements.completionPercentage() / 100.0)
                        .progressViewStyle(.linear)
                        .tint(.blue)

                    Text("\(achievements.unlockedAchievements.count) / \(achievements.allAchievements().count) Unlocked")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .padding()

                // Achievement grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(achievements.allAchievements()) { achievement in
                        AchievementCardView(
                            achievement: achievement,
                            isUnlocked: achievements.isUnlocked(achievement.id)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("🏆 Achievements")
        }
    }
}

struct AchievementCardView: View {
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement.icon)
                .font(.largeTitle)
                .foregroundColor(isUnlocked ? achievement.rarity.color : .gray)

            Text(achievement.name)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if isUnlocked {
                Text("✅ UNLOCKED")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Text("🔒 Locked")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(width: 150, height: 150)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(isUnlocked ? 0.5 : 0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isUnlocked ? achievement.rarity.color : Color.gray.opacity(0.3),
                            lineWidth: 2
                        )
                )
        )
        .opacity(isUnlocked ? 1.0 : 0.5)
    }
}
