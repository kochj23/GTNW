//
//  Advisor.swift
//  Global Thermal Nuclear War
//
//  Presidential advisors system inspired by Shadow President (1993)
//  Updated with Trump administration 2025 cabinet positions
//

import Foundation
import SwiftUI

/// Represents a presidential advisor (cabinet member, military leader, or staff)
struct Advisor: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let title: String
    let department: String
    let bio: String

    // Stats
    var expertise: Int // 0-100, knowledge in their field
    var loyalty: Int // 0-100, loyalty to president
    var influence: Int // 0-100, political influence
    var publicSupport: Int // 0-100, public approval

    // Personality traits
    var hawkishness: Int // 0-100 (dove to hawk)
    var interventionism: Int // 0-100 (isolationist to interventionist)
    var fiscalConservatism: Int // 0-100

    // Advice specialties
    var adviceAreas: [AdviceArea]

    // Current state
    var currentAdvice: String?
    var adviceType: AdviceType?
    var lastAdviceGiven: String? // Timestamp

    // Portrait (for now, color-coded placeholder)
    var portraitColor: String // Hex color for placeholder

    /// Initialize a new advisor
    init(
        id: String,
        name: String,
        title: String,
        department: String,
        bio: String,
        expertise: Int,
        loyalty: Int,
        influence: Int,
        publicSupport: Int,
        hawkishness: Int,
        interventionism: Int,
        fiscalConservatism: Int,
        adviceAreas: [AdviceArea],
        currentAdvice: String? = nil,
        adviceType: AdviceType? = nil,
        portraitColor: String
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.department = department
        self.bio = bio
        self.expertise = expertise
        self.loyalty = loyalty
        self.influence = influence
        self.publicSupport = publicSupport
        self.hawkishness = hawkishness
        self.interventionism = interventionism
        self.fiscalConservatism = fiscalConservatism
        self.adviceAreas = adviceAreas
        self.currentAdvice = currentAdvice
        self.adviceType = adviceType
        self.portraitColor = portraitColor
    }

    /// Get color for portrait placeholder
    var colorValue: Color {
        Color(hex: portraitColor) ?? .gray
    }

    /// Get advisor's initials for placeholder
    var initials: String {
        name.components(separatedBy: " ")
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
    }

    /// Generate advice based on current game state
    mutating func generateAdvice(for situation: GameSituation) {
        switch situation {
        case .nuclearThreat:
            if hawkishness > 70 {
                currentAdvice = "Mr. President, we must respond with overwhelming force. Show them we mean business."
                adviceType = .military
            } else if interventionism < 40 {
                currentAdvice = "Sir, I advise restraint. Let's pursue diplomatic channels first."
                adviceType = .diplomatic
            } else {
                currentAdvice = "We should prepare our forces but exhaust all options before escalating."
                adviceType = .military
            }

        case .diplomaticCrisis:
            if interventionism > 60 {
                currentAdvice = "This requires decisive action. We cannot show weakness."
                adviceType = .diplomatic
            } else {
                currentAdvice = "I recommend a measured diplomatic response."
                adviceType = .diplomatic
            }

        case .economicSanctions:
            currentAdvice = "Economic pressure can be effective, but we must consider the impact on our own economy."
            adviceType = .economic

        case .covertOperation:
            if expertise > 70 && loyalty > 80 {
                currentAdvice = "We have covert options that would provide plausible deniability."
                adviceType = .intelligence
            } else {
                currentAdvice = "Covert operations carry significant risks, sir."
                adviceType = .intelligence
            }

        case .domesticCrisis:
            currentAdvice = "This requires immediate attention, Mr. President. Your approval ratings are at stake."
            adviceType = .domestic
        }
    }
}

/// Areas of expertise for advisors
enum AdviceArea: String, Codable, CaseIterable {
    case militaryStrike = "Military Strike"
    case nuclearWeapons = "Nuclear Weapons"
    case diplomacy = "Diplomacy"
    case covertOps = "Covert Operations"
    case economicSanctions = "Economic Sanctions"
    case domesticPolicy = "Domestic Policy"
    case intelligence = "Intelligence"
    case cybersecurity = "Cybersecurity"
    case borderSecurity = "Border Security"
    case energy = "Energy & Nuclear"
    case legal = "Legal Matters"
    case media = "Media & Communications"
}

/// Types of advice
enum AdviceType: String, Codable {
    case military = "Military"
    case diplomatic = "Diplomatic"
    case economic = "Economic"
    case intelligence = "Intelligence"
    case domestic = "Domestic"
    case legal = "Legal"
}

/// Game situations that trigger advisor advice
enum GameSituation {
    case nuclearThreat(country: String)
    case diplomaticCrisis(country: String)
    case economicSanctions
    case covertOperation
    case domesticCrisis
}

/// Trump Administration 2025 Cabinet
extension Advisor {
    /// Get all Trump administration advisors
    static func trumpCabinet() -> [Advisor] {
        return [
            // President
            Advisor(
                id: "trump",
                name: "Donald J. Trump",
                title: "President",
                department: "Executive Office",
                bio: "45th and 47th President of the United States",
                expertise: 70,
                loyalty: 100,
                influence: 100,
                publicSupport: 45,
                hawkishness: 75,
                interventionism: 60,
                fiscalConservatism: 50,
                adviceAreas: [.militaryStrike, .nuclearWeapons, .diplomacy, .economicSanctions, .domesticPolicy],
                currentAdvice: "We need to project strength. No more weak responses.",
                adviceType: .military,
                portraitColor: "#FFD700" // Gold
            ),

            // Vice President
            Advisor(
                id: "vance",
                name: "JD Vance",
                title: "Vice President",
                department: "Executive Office",
                bio: "Senator from Ohio, Author of 'Hillbilly Elegy'",
                expertise: 65,
                loyalty: 90,
                influence: 75,
                publicSupport: 50,
                hawkishness: 60,
                interventionism: 50,
                fiscalConservatism: 70,
                adviceAreas: [.domesticPolicy, .economicSanctions],
                portraitColor: "#4169E1" // Royal Blue
            ),

            // Secretary of State
            Advisor(
                id: "rubio",
                name: "Marco Rubio",
                title: "Secretary of State",
                department: "Department of State",
                bio: "Senator from Florida, Foreign Relations Committee",
                expertise: 75,
                loyalty: 80,
                influence: 85,
                publicSupport: 55,
                hawkishness: 70,
                interventionism: 75,
                fiscalConservatism: 70,
                adviceAreas: [.diplomacy, .economicSanctions],
                currentAdvice: "Mr. President, we should pursue diplomatic channels first, but maintain military readiness as leverage.",
                adviceType: .diplomatic,
                portraitColor: "#1E90FF" // Dodger Blue
            ),

            // Secretary of Defense
            Advisor(
                id: "hegseth",
                name: "Pete Hegseth",
                title: "Secretary of Defense",
                department: "Department of Defense",
                bio: "U.S. Army National Guard veteran, Iraq & Afghanistan",
                expertise: 85,
                loyalty: 85,
                influence: 90,
                publicSupport: 60,
                hawkishness: 90,
                interventionism: 80,
                fiscalConservatism: 60,
                adviceAreas: [.militaryStrike, .nuclearWeapons],
                currentAdvice: "Sir, our military is ready to strike. I recommend immediate action. Hesitation shows weakness.",
                adviceType: .military,
                portraitColor: "#8B0000" // Dark Red
            ),

            // Secretary of Treasury
            Advisor(
                id: "bessent",
                name: "Scott Bessent",
                title: "Secretary of Treasury",
                department: "Department of Treasury",
                bio: "Hedge fund manager, Economic policy expert",
                expertise: 90,
                loyalty: 75,
                influence: 80,
                publicSupport: 55,
                hawkishness: 50,
                interventionism: 55,
                fiscalConservatism: 80,
                adviceAreas: [.economicSanctions, .domesticPolicy],
                currentAdvice: "Mr. President, economic sanctions can be our most powerful weapon without military escalation.",
                adviceType: .economic,
                portraitColor: "#228B22" // Forest Green
            ),

            // Attorney General
            Advisor(
                id: "bondi",
                name: "Pam Bondi",
                title: "Attorney General",
                department: "Department of Justice",
                bio: "Former Florida Attorney General, Trump loyalist",
                expertise: 80,
                loyalty: 95,
                influence: 70,
                publicSupport: 50,
                hawkishness: 65,
                interventionism: 60,
                fiscalConservatism: 65,
                adviceAreas: [.legal, .domesticPolicy],
                currentAdvice: "Sir, this action is within your legal authority as Commander-in-Chief.",
                adviceType: .legal,
                portraitColor: "#800080" // Purple
            ),

            // Secretary of Homeland Security
            Advisor(
                id: "noem",
                name: "Kristi Noem",
                title: "Secretary of Homeland Security",
                department: "Department of Homeland Security",
                bio: "Governor of South Dakota, Border security advocate",
                expertise: 70,
                loyalty: 90,
                influence: 75,
                publicSupport: 55,
                hawkishness: 75,
                interventionism: 65,
                fiscalConservatism: 70,
                adviceAreas: [.borderSecurity, .domesticPolicy, .cybersecurity],
                currentAdvice: "We need to secure our homeland first, Mr. President.",
                adviceType: .domestic,
                portraitColor: "#FF1493" // Deep Pink
            ),

            // Director of National Intelligence
            Advisor(
                id: "gabbard",
                name: "Tulsi Gabbard",
                title: "Director of National Intelligence",
                department: "ODNI",
                bio: "Former Congresswoman, Iraq War veteran, Non-interventionist",
                expertise: 70,
                loyalty: 75,
                influence: 70,
                publicSupport: 50,
                hawkishness: 30,
                interventionism: 20,
                fiscalConservatism: 60,
                adviceAreas: [.intelligence, .covertOps],
                currentAdvice: "Mr. President, I advise caution. Our intelligence suggests this could escalate unnecessarily.",
                adviceType: .intelligence,
                portraitColor: "#FF8C00" // Dark Orange
            ),

            // CIA Director
            Advisor(
                id: "ratcliffe",
                name: "John Ratcliffe",
                title: "CIA Director",
                department: "CIA",
                bio: "Former DNI, Texas Congressman, Intelligence expert",
                expertise: 75,
                loyalty: 90,
                influence: 80,
                publicSupport: 55,
                hawkishness: 80,
                interventionism: 75,
                fiscalConservatism: 65,
                adviceAreas: [.covertOps, .intelligence],
                currentAdvice: "We have covert options available that would give us plausible deniability, sir.",
                adviceType: .intelligence,
                portraitColor: "#2F4F4F" // Dark Slate Gray
            ),

            // National Security Advisor
            Advisor(
                id: "waltz",
                name: "Mike Waltz",
                title: "National Security Advisor",
                department: "National Security Council",
                bio: "Green Beret, Afghanistan veteran, China hawk",
                expertise: 85,
                loyalty: 85,
                influence: 90,
                publicSupport: 60,
                hawkishness: 85,
                interventionism: 75,
                fiscalConservatism: 65,
                adviceAreas: [.militaryStrike, .intelligence, .covertOps],
                currentAdvice: "This is a critical national security issue, Mr. President. We must act decisively.",
                adviceType: .military,
                portraitColor: "#8B4513" // Saddle Brown
            ),

            // Secretary of Energy
            Advisor(
                id: "wright",
                name: "Chris Wright",
                title: "Secretary of Energy",
                department: "Department of Energy",
                bio: "Fracking executive, Energy independence advocate",
                expertise: 80,
                loyalty: 80,
                influence: 65,
                publicSupport: 50,
                hawkishness: 60,
                interventionism: 55,
                fiscalConservatism: 75,
                adviceAreas: [.energy, .nuclearWeapons],
                currentAdvice: "Our nuclear arsenal is maintained and ready, Mr. President.",
                adviceType: .military,
                portraitColor: "#FFD700" // Gold
            ),

            // UN Ambassador
            Advisor(
                id: "stefanik",
                name: "Elise Stefanik",
                title: "UN Ambassador",
                department: "U.S. Mission to the UN",
                bio: "New York Congresswoman, Pro-Israel, Trump loyalist",
                expertise: 70,
                loyalty: 90,
                influence: 75,
                publicSupport: 55,
                hawkishness: 75,
                interventionism: 70,
                fiscalConservatism: 70,
                adviceAreas: [.diplomacy],
                currentAdvice: "The UN will condemn any action, but we can veto any resolution.",
                adviceType: .diplomatic,
                portraitColor: "#4682B4" // Steel Blue
            ),

            // Chairman of Joint Chiefs
            Advisor(
                id: "brown",
                name: "General Charles Q. Brown Jr.",
                title: "Chairman, Joint Chiefs",
                department: "Department of Defense",
                bio: "Air Force General, Professional military officer",
                expertise: 95,
                loyalty: 70,
                influence: 85,
                publicSupport: 70,
                hawkishness: 60,
                interventionism: 55,
                fiscalConservatism: 60,
                adviceAreas: [.militaryStrike, .nuclearWeapons],
                currentAdvice: "Sir, I can provide you with military options, but the final decision is yours.",
                adviceType: .military,
                portraitColor: "#556B2F" // Dark Olive Green
            ),

            // White House Chief of Staff
            Advisor(
                id: "wiles",
                name: "Susie Wiles",
                title: "Chief of Staff",
                department: "White House",
                bio: "Veteran political strategist, Trump campaign manager",
                expertise: 85,
                loyalty: 95,
                influence: 90,
                publicSupport: 55,
                hawkishness: 60,
                interventionism: 55,
                fiscalConservatism: 65,
                adviceAreas: [.domesticPolicy, .media],
                currentAdvice: "Consider how this will play with your base, Mr. President.",
                adviceType: .domestic,
                portraitColor: "#DC143C" // Crimson
            ),

            // Press Secretary
            Advisor(
                id: "leavitt",
                name: "Karoline Leavitt",
                title: "Press Secretary",
                department: "White House Communications",
                bio: "Youngest press secretary in history, Aggressive communicator",
                expertise: 75,
                loyalty: 95,
                influence: 70,
                publicSupport: 50,
                hawkishness: 65,
                interventionism: 60,
                fiscalConservatism: 70,
                adviceAreas: [.media, .domesticPolicy],
                currentAdvice: "I can spin this positively in the press, sir. We'll control the narrative.",
                adviceType: .domestic,
                portraitColor: "#FF69B4" // Hot Pink
            )
        ]
    }
}

// Helper extension for Color from hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
