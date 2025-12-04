//
//  HistoricalAdministrations.swift
//  Global Thermal Nuclear War
//
//  Historical US Presidents and Cabinet Members from Nuclear Age (1945-2025)
//  Data compiled from historical records and government sources
//

import Foundation
import SwiftUI

/// Historical administration period
struct Administration: Identifiable, Codable {
    let id: String
    let name: String
    let president: String
    let years: String
    let startYear: Int
    let endYear: Int
    let party: String
    let advisors: [Advisor]

    var description: String {
        "\(president) (\(years)) - \(party)"
    }
}

extension Advisor {
    /// Get all historical administrations since the nuclear age began (1945)
    static func allAdministrations() -> [Administration] {
        return [
            trumanAdministration(),
            eisenhowerAdministration(),
            kennedyAdministration(),
            johnsonAdministration(),
            nixonAdministration(),
            fordAdministration(),
            carterAdministration(),
            reaganAdministration(),
            bushSrAdministration(),
            clintonAdministration(),
            bushJrAdministration(),
            obamaAdministration(),
            trumpFirstAdministration(),
            bidenAdministration(),
            trumpSecondAdministration()
        ]
    }

    // MARK: - Truman Administration (1945-1953)

    static func trumanAdministration() -> Administration {
        Administration(
            id: "truman",
            name: "Truman Administration",
            president: "Harry S. Truman",
            years: "1945-1953",
            startYear: 1945,
            endYear: 1953,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "truman",
                    name: "Harry S. Truman",
                    title: "President",
                    department: "Executive Office",
                    bio: "33rd President, Made decision to use atomic bombs on Japan",
                    expertise: 70,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 50,
                    hawkishness: 75,
                    interventionism: 70,
                    fiscalConservatism: 60,
                    adviceAreas: [.militaryStrike, .nuclearWeapons, .diplomacy],
                    currentAdvice: "The buck stops here. We must make the hard decisions.",
                    adviceType: .military,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "acheson",
                    name: "Dean Acheson",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Architect of Cold War containment policy",
                    expertise: 90,
                    loyalty: 85,
                    influence: 90,
                    publicSupport: 55,
                    hawkishness: 70,
                    interventionism: 75,
                    fiscalConservatism: 65,
                    adviceAreas: [.diplomacy, .economicSanctions],
                    currentAdvice: "We must contain Soviet expansion through strength and alliances.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "marshall",
                    name: "George C. Marshall",
                    title: "Secretary of Defense",
                    department: "Defense",
                    bio: "Five-star General, Marshall Plan architect",
                    expertise: 100,
                    loyalty: 90,
                    influence: 95,
                    publicSupport: 85,
                    hawkishness: 60,
                    interventionism: 70,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike, .diplomacy],
                    currentAdvice: "Military strength must be balanced with diplomatic wisdom.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                )
            ]
        )
    }

    // MARK: - Eisenhower Administration (1953-1961)

    static func eisenhowerAdministration() -> Administration {
        Administration(
            id: "eisenhower",
            name: "Eisenhower Administration",
            president: "Dwight D. Eisenhower",
            years: "1953-1961",
            startYear: 1953,
            endYear: 1961,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "eisenhower",
                    name: "Dwight D. Eisenhower",
                    title: "President",
                    department: "Executive Office",
                    bio: "34th President, Supreme Allied Commander WWII, Warned of military-industrial complex",
                    expertise: 95,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 70,
                    hawkishness: 60,
                    interventionism: 65,
                    fiscalConservatism: 75,
                    adviceAreas: [.militaryStrike, .nuclearWeapons, .diplomacy],
                    currentAdvice: "Peace through strength. But we must beware the military-industrial complex.",
                    adviceType: .military,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "dulles_state",
                    name: "John Foster Dulles",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Cold warrior, Massive retaliation doctrine",
                    expertise: 85,
                    loyalty: 90,
                    influence: 90,
                    publicSupport: 60,
                    hawkishness: 85,
                    interventionism: 80,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy, .nuclearWeapons],
                    currentAdvice: "We must respond with massive retaliation to any Soviet aggression.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "dulles_cia",
                    name: "Allen Dulles",
                    title: "CIA Director",
                    department: "CIA",
                    bio: "Spymaster, Covert operations expert",
                    expertise: 95,
                    loyalty: 85,
                    influence: 85,
                    publicSupport: 50,
                    hawkishness: 80,
                    interventionism: 90,
                    fiscalConservatism: 65,
                    adviceAreas: [.covertOps, .intelligence],
                    currentAdvice: "We have assets in place for covert action, Mr. President.",
                    adviceType: .intelligence,
                    portraitColor: "#2F4F4F"
                )
            ]
        )
    }

    // MARK: - Kennedy Administration (1961-1963)

    static func kennedyAdministration() -> Administration {
        Administration(
            id: "kennedy",
            name: "Kennedy Administration",
            president: "John F. Kennedy",
            years: "1961-1963",
            startYear: 1961,
            endYear: 1963,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "kennedy",
                    name: "John F. Kennedy",
                    title: "President",
                    department: "Executive Office",
                    bio: "35th President, Cuban Missile Crisis, Youngest elected president",
                    expertise: 75,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 70,
                    hawkishness: 50,
                    interventionism: 60,
                    fiscalConservatism: 55,
                    adviceAreas: [.diplomacy, .militaryStrike, .nuclearWeapons],
                    currentAdvice: "We cannot let fear drive our decisions, but we must be prepared.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "mcnamara",
                    name: "Robert McNamara",
                    title: "Secretary of Defense",
                    department: "Defense",
                    bio: "Systems analyst, Vietnam War architect, Later regretted escalation",
                    expertise: 90,
                    loyalty: 85,
                    influence: 90,
                    publicSupport: 60,
                    hawkishness: 70,
                    interventionism: 75,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike, .nuclearWeapons],
                    currentAdvice: "The numbers suggest a surgical strike could succeed, but the risks are enormous.",
                    adviceType: .military,
                    portraitColor: "#8B0000"
                ),
                Advisor(
                    id: "rusk",
                    name: "Dean Rusk",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Cuban Missile Crisis negotiator",
                    expertise: 85,
                    loyalty: 90,
                    influence: 85,
                    publicSupport: 65,
                    hawkishness: 55,
                    interventionism: 65,
                    fiscalConservatism: 65,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "We must pursue backchannel negotiations while maintaining our quarantine.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "rfk",
                    name: "Robert F. Kennedy",
                    title: "Attorney General",
                    department: "Justice",
                    bio: "President's brother, Key advisor during Cuban Missile Crisis",
                    expertise: 75,
                    loyalty: 100,
                    influence: 90,
                    publicSupport: 70,
                    hawkishness: 40,
                    interventionism: 50,
                    fiscalConservatism: 55,
                    adviceAreas: [.diplomacy, .legal],
                    currentAdvice: "We must find a peaceful solution. A nuclear exchange would be catastrophic.",
                    adviceType: .diplomatic,
                    portraitColor: "#800080"
                )
            ]
        )
    }

    // MARK: - Johnson Administration (1963-1969)

    static func johnsonAdministration() -> Administration {
        Administration(
            id: "johnson",
            name: "Johnson Administration",
            president: "Lyndon B. Johnson",
            years: "1963-1969",
            startYear: 1963,
            endYear: 1969,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "johnson",
                    name: "Lyndon B. Johnson",
                    title: "President",
                    department: "Executive Office",
                    bio: "36th President, Vietnam War escalation, Great Society programs",
                    expertise: 80,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 50,
                    hawkishness: 70,
                    interventionism: 80,
                    fiscalConservatism: 40,
                    adviceAreas: [.militaryStrike, .domesticPolicy],
                    currentAdvice: "We will not lose to communism. Do what's necessary.",
                    adviceType: .military,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "mcnamara_lbj",
                    name: "Robert McNamara",
                    title: "Secretary of Defense",
                    department: "Defense",
                    bio: "Continued from Kennedy, Vietnam War expansion",
                    expertise: 90,
                    loyalty: 80,
                    influence: 85,
                    publicSupport: 45,
                    hawkishness: 75,
                    interventionism: 80,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike, .nuclearWeapons],
                    currentAdvice: "Escalation may be necessary to achieve our objectives.",
                    adviceType: .military,
                    portraitColor: "#8B0000"
                )
            ]
        )
    }

    // MARK: - Nixon Administration (1969-1974)

    static func nixonAdministration() -> Administration {
        Administration(
            id: "nixon",
            name: "Nixon Administration",
            president: "Richard Nixon",
            years: "1969-1974",
            startYear: 1969,
            endYear: 1974,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "nixon",
                    name: "Richard Nixon",
                    title: "President",
                    department: "Executive Office",
                    bio: "37th President, Détente with USSR, Opening to China, Watergate",
                    expertise: 85,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 40,
                    hawkishness: 70,
                    interventionism: 75,
                    fiscalConservatism: 65,
                    adviceAreas: [.diplomacy, .covertOps, .nuclearWeapons],
                    currentAdvice: "I am not a crook. But I will do what it takes to win.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "kissinger",
                    name: "Henry Kissinger",
                    title: "Secretary of State & National Security Advisor",
                    department: "State",
                    bio: "Architect of détente, Realpolitik master, Nobel Peace Prize",
                    expertise: 100,
                    loyalty: 80,
                    influence: 95,
                    publicSupport: 60,
                    hawkishness: 60,
                    interventionism: 85,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy, .covertOps, .militaryStrike],
                    currentAdvice: "Power is the ultimate aphrodisiac. We must use it strategically.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - Ford Administration (1974-1977)

    static func fordAdministration() -> Administration {
        Administration(
            id: "ford",
            name: "Ford Administration",
            president: "Gerald Ford",
            years: "1974-1977",
            startYear: 1974,
            endYear: 1977,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "ford",
                    name: "Gerald Ford",
                    title: "President",
                    department: "Executive Office",
                    bio: "38th President, Only unelected president, Pardoned Nixon",
                    expertise: 70,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 45,
                    hawkishness: 55,
                    interventionism: 60,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy, .domesticPolicy],
                    currentAdvice: "Our long national nightmare is over. Let's heal and move forward.",
                    adviceType: .domestic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "kissinger_ford",
                    name: "Henry Kissinger",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Continued from Nixon administration",
                    expertise: 100,
                    loyalty: 75,
                    influence: 90,
                    publicSupport: 55,
                    hawkishness: 60,
                    interventionism: 85,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy, .covertOps],
                    currentAdvice: "Détente remains our best path forward, Mr. President.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - Carter Administration (1977-1981)

    static func carterAdministration() -> Administration {
        Administration(
            id: "carter",
            name: "Carter Administration",
            president: "Jimmy Carter",
            years: "1977-1981",
            startYear: 1977,
            endYear: 1981,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "carter",
                    name: "Jimmy Carter",
                    title: "President",
                    department: "Executive Office",
                    bio: "39th President, Human rights advocate, Iran hostage crisis, Camp David Accords",
                    expertise: 70,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 45,
                    hawkishness: 30,
                    interventionism: 40,
                    fiscalConservatism: 55,
                    adviceAreas: [.diplomacy, .domesticPolicy],
                    currentAdvice: "We must pursue peace with the same vigor we prepare for war.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "vance",
                    name: "Cyrus Vance",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Diplomat, Resigned over Iran rescue attempt",
                    expertise: 85,
                    loyalty: 75,
                    influence: 80,
                    publicSupport: 50,
                    hawkishness: 25,
                    interventionism: 35,
                    fiscalConservatism: 60,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Diplomacy and negotiation must always come first, Mr. President.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "brzezinski",
                    name: "Zbigniew Brzezinski",
                    title: "National Security Advisor",
                    department: "NSC",
                    bio: "Hardline anti-Soviet strategist, Afghanistan policy architect",
                    expertise: 95,
                    loyalty: 90,
                    influence: 95,
                    publicSupport: 55,
                    hawkishness: 75,
                    interventionism: 80,
                    fiscalConservatism: 65,
                    adviceAreas: [.militaryStrike, .intelligence, .covertOps],
                    currentAdvice: "The Soviets only understand strength. We must be prepared to use force.",
                    adviceType: .military,
                    portraitColor: "#8B4513"
                )
            ]
        )
    }

    // MARK: - Reagan Administration (1981-1989)

    static func reaganAdministration() -> Administration {
        Administration(
            id: "reagan",
            name: "Reagan Administration",
            president: "Ronald Reagan",
            years: "1981-1989",
            startYear: 1981,
            endYear: 1989,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "reagan",
                    name: "Ronald Reagan",
                    title: "President",
                    department: "Executive Office",
                    bio: "40th President, 'Mr. Gorbachev, tear down this wall!', SDI Star Wars, Ended Cold War",
                    expertise: 70,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 65,
                    hawkishness: 80,
                    interventionism: 75,
                    fiscalConservatism: 80,
                    adviceAreas: [.militaryStrike, .nuclearWeapons, .economicSanctions],
                    currentAdvice: "We win, they lose. Peace through strength.",
                    adviceType: .military,
                    portraitColor: "#FFD700"
                ),
                Advisor(
                    id: "shultz",
                    name: "George Shultz",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Negotiated with Gorbachev, Arms control advocate",
                    expertise: 90,
                    loyalty: 85,
                    influence: 90,
                    publicSupport: 70,
                    hawkishness: 50,
                    interventionism: 65,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy, .economicSanctions],
                    currentAdvice: "Mr. President, we're making progress with Gorbachev. Let's keep negotiating.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "weinberger",
                    name: "Caspar Weinberger",
                    title: "Secretary of Defense",
                    department: "Defense",
                    bio: "Military buildup architect, 'Cap the Knife'",
                    expertise: 85,
                    loyalty: 95,
                    influence: 90,
                    publicSupport: 60,
                    hawkishness: 85,
                    interventionism: 70,
                    fiscalConservatism: 80,
                    adviceAreas: [.militaryStrike, .nuclearWeapons],
                    currentAdvice: "Our military buildup is working, sir. The Soviets can't keep up.",
                    adviceType: .military,
                    portraitColor: "#8B0000"
                ),
                Advisor(
                    id: "casey",
                    name: "William Casey",
                    title: "CIA Director",
                    department: "CIA",
                    bio: "Covert operations mastermind, Iran-Contra",
                    expertise: 90,
                    loyalty: 90,
                    influence: 85,
                    publicSupport: 50,
                    hawkishness: 85,
                    interventionism: 95,
                    fiscalConservatism: 75,
                    adviceAreas: [.covertOps, .intelligence],
                    currentAdvice: "We have assets worldwide ready for covert action, Mr. President.",
                    adviceType: .intelligence,
                    portraitColor: "#2F4F4F"
                )
            ]
        )
    }

    // MARK: - Bush Sr. Administration (1989-1993)

    static func bushSrAdministration() -> Administration {
        Administration(
            id: "bush_sr",
            name: "Bush Sr. Administration",
            president: "George H.W. Bush",
            years: "1989-1993",
            startYear: 1989,
            endYear: 1993,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "bush_sr",
                    name: "George H.W. Bush",
                    title: "President",
                    department: "Executive Office",
                    bio: "41st President, Former CIA Director, Gulf War, End of Cold War",
                    expertise: 90,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 60,
                    hawkishness: 65,
                    interventionism: 70,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy, .militaryStrike, .intelligence],
                    currentAdvice: "We must build a new world order based on cooperation.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "baker",
                    name: "James Baker",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Master negotiator, Managed German reunification",
                    expertise: 95,
                    loyalty: 90,
                    influence: 95,
                    publicSupport: 70,
                    hawkishness: 50,
                    interventionism: 65,
                    fiscalConservatism: 80,
                    adviceAreas: [.diplomacy, .economicSanctions],
                    currentAdvice: "We can negotiate from a position of strength, Mr. President.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "cheney",
                    name: "Dick Cheney",
                    title: "Secretary of Defense",
                    department: "Defense",
                    bio: "Gulf War architect, Later VP under Bush Jr.",
                    expertise: 90,
                    loyalty: 90,
                    influence: 90,
                    publicSupport: 60,
                    hawkishness: 90,
                    interventionism: 85,
                    fiscalConservatism: 75,
                    adviceAreas: [.militaryStrike, .nuclearWeapons],
                    currentAdvice: "Sir, we have overwhelming military superiority. We should use it.",
                    adviceType: .military,
                    portraitColor: "#8B0000"
                ),
                Advisor(
                    id: "powell",
                    name: "General Colin Powell",
                    title: "Chairman, Joint Chiefs",
                    department: "Defense",
                    bio: "Four-star General, Gulf War commander, Powell Doctrine",
                    expertise: 95,
                    loyalty: 85,
                    influence: 90,
                    publicSupport: 80,
                    hawkishness: 55,
                    interventionism: 50,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike],
                    currentAdvice: "Use overwhelming force if we go in, but exhaust diplomacy first.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                )
            ]
        )
    }

    // MARK: - Clinton Administration (1993-2001)

    static func clintonAdministration() -> Administration {
        Administration(
            id: "clinton",
            name: "Clinton Administration",
            president: "Bill Clinton",
            years: "1993-2001",
            startYear: 1993,
            endYear: 2001,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "clinton",
                    name: "Bill Clinton",
                    title: "President",
                    department: "Executive Office",
                    bio: "42nd President, Balanced budgets, Kosovo intervention, Lewinsky scandal",
                    expertise: 75,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 60,
                    hawkishness: 45,
                    interventionism: 60,
                    fiscalConservatism: 55,
                    adviceAreas: [.diplomacy, .economicSanctions, .domesticPolicy],
                    currentAdvice: "We need to focus on the economy. It's the economy, stupid.",
                    adviceType: .economic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "albright",
                    name: "Madeleine Albright",
                    title: "Secretary of State",
                    department: "State",
                    bio: "First female Secretary of State, Interventionist",
                    expertise: 85,
                    loyalty: 85,
                    influence: 85,
                    publicSupport: 65,
                    hawkishness: 65,
                    interventionism: 75,
                    fiscalConservatism: 55,
                    adviceAreas: [.diplomacy, .militaryStrike],
                    currentAdvice: "What's the point of having this superb military if we can't use it?",
                    adviceType: .diplomatic,
                    portraitColor: "#FF1493"
                )
            ]
        )
    }

    // MARK: - Bush Jr. Administration (2001-2009)

    static func bushJrAdministration() -> Administration {
        Administration(
            id: "bush_jr",
            name: "Bush Jr. Administration",
            president: "George W. Bush",
            years: "2001-2009",
            startYear: 2001,
            endYear: 2009,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "bush_jr",
                    name: "George W. Bush",
                    title: "President",
                    department: "Executive Office",
                    bio: "43rd President, 9/11, Iraq War, War on Terror",
                    expertise: 60,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 50,
                    hawkishness: 85,
                    interventionism: 90,
                    fiscalConservatism: 60,
                    adviceAreas: [.militaryStrike, .covertOps],
                    currentAdvice: "You're either with us or against us.",
                    adviceType: .military,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "cheney_vp",
                    name: "Dick Cheney",
                    title: "Vice President",
                    department: "Executive Office",
                    bio: "Most powerful VP in history, Iraq War architect",
                    expertise: 90,
                    loyalty: 95,
                    influence: 95,
                    publicSupport: 35,
                    hawkishness: 95,
                    interventionism: 95,
                    fiscalConservatism: 75,
                    adviceAreas: [.militaryStrike, .nuclearWeapons, .covertOps],
                    currentAdvice: "We have to work the dark side. The gloves come off.",
                    adviceType: .military,
                    portraitColor: "#8B0000"
                ),
                Advisor(
                    id: "powell_state",
                    name: "Colin Powell",
                    title: "Secretary of State",
                    department: "State",
                    bio: "First Black Secretary of State, Resigned over Iraq War",
                    expertise: 90,
                    loyalty: 70,
                    influence: 80,
                    publicSupport: 75,
                    hawkishness: 55,
                    interventionism: 55,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy, .militaryStrike],
                    currentAdvice: "Mr. President, we need more evidence before military action.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "rumsfeld",
                    name: "Donald Rumsfeld",
                    title: "Secretary of Defense",
                    department: "Defense",
                    bio: "Iraq War architect, 'Known unknowns' quote",
                    expertise: 85,
                    loyalty: 85,
                    influence: 90,
                    publicSupport: 40,
                    hawkishness: 90,
                    interventionism: 85,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike, .nuclearWeapons],
                    currentAdvice: "Shock and awe, Mr. President. We go in fast and hard.",
                    adviceType: .military,
                    portraitColor: "#8B0000"
                ),
                Advisor(
                    id: "rice",
                    name: "Condoleezza Rice",
                    title: "National Security Advisor",
                    department: "NSC",
                    bio: "Soviet expert, Later Secretary of State",
                    expertise: 90,
                    loyalty: 90,
                    influence: 85,
                    publicSupport: 65,
                    hawkishness: 75,
                    interventionism: 80,
                    fiscalConservatism: 70,
                    adviceAreas: [.intelligence, .diplomacy, .militaryStrike],
                    currentAdvice: "We don't want the smoking gun to be a mushroom cloud.",
                    adviceType: .intelligence,
                    portraitColor: "#FF8C00"
                )
            ]
        )
    }

    // MARK: - Obama Administration (2009-2017)

    static func obamaAdministration() -> Administration {
        Administration(
            id: "obama",
            name: "Obama Administration",
            president: "Barack Obama",
            years: "2009-2017",
            startYear: 2009,
            endYear: 2017,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "obama",
                    name: "Barack Obama",
                    title: "President",
                    department: "Executive Office",
                    bio: "44th President, First Black president, Iran nuclear deal, Osama bin Laden raid",
                    expertise: 80,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 55,
                    hawkishness: 45,
                    interventionism: 55,
                    fiscalConservatism: 50,
                    adviceAreas: [.diplomacy, .covertOps, .militaryStrike],
                    currentAdvice: "Let's be clear-eyed about our options. Every decision has consequences.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "clinton_hillary",
                    name: "Hillary Clinton",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Former First Lady, Senator, Libya intervention",
                    expertise: 85,
                    loyalty: 75,
                    influence: 85,
                    publicSupport: 50,
                    hawkishness: 70,
                    interventionism: 75,
                    fiscalConservatism: 55,
                    adviceAreas: [.diplomacy, .militaryStrike],
                    currentAdvice: "We came, we saw, he died. Sometimes force is necessary.",
                    adviceType: .diplomatic,
                    portraitColor: "#FF1493"
                ),
                Advisor(
                    id: "gates",
                    name: "Robert Gates",
                    title: "Secretary of Defense",
                    department: "Defense",
                    bio: "Continued from Bush, Pragmatic military leader",
                    expertise: 95,
                    loyalty: 80,
                    influence: 90,
                    publicSupport: 70,
                    hawkishness: 60,
                    interventionism: 65,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike, .intelligence],
                    currentAdvice: "Any future Secretary of Defense who advises a president to send a big American land army into Asia or the Middle East should have his head examined.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                ),
                Advisor(
                    id: "biden_vp",
                    name: "Joe Biden",
                    title: "Vice President",
                    department: "Executive Office",
                    bio: "Former Senator, Foreign Relations Committee Chairman",
                    expertise: 80,
                    loyalty: 90,
                    influence: 80,
                    publicSupport: 55,
                    hawkishness: 55,
                    interventionism: 65,
                    fiscalConservatism: 50,
                    adviceAreas: [.diplomacy, .domesticPolicy],
                    currentAdvice: "Look, here's the deal - we need to think this through.",
                    adviceType: .diplomatic,
                    portraitColor: "#4682B4"
                )
            ]
        )
    }

    // MARK: - Trump First Administration (2017-2021)

    static func trumpFirstAdministration() -> Administration {
        Administration(
            id: "trump_first",
            name: "Trump First Administration",
            president: "Donald Trump",
            years: "2017-2021",
            startYear: 2017,
            endYear: 2021,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "trump_first",
                    name: "Donald J. Trump",
                    title: "President",
                    department: "Executive Office",
                    bio: "45th President, 'Fire and fury', North Korea summit, America First",
                    expertise: 65,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 45,
                    hawkishness: 80,
                    interventionism: 55,
                    fiscalConservatism: 50,
                    adviceAreas: [.militaryStrike, .economicSanctions, .diplomacy],
                    currentAdvice: "Fire and fury like the world has never seen.",
                    adviceType: .military,
                    portraitColor: "#FFD700"
                ),
                Advisor(
                    id: "mattis",
                    name: "James Mattis",
                    title: "Secretary of Defense",
                    department: "Defense",
                    bio: "'Mad Dog', Marine General, Resigned over Syria withdrawal",
                    expertise: 95,
                    loyalty: 60,
                    influence: 85,
                    publicSupport: 75,
                    hawkishness: 75,
                    interventionism: 70,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike, .nuclearWeapons],
                    currentAdvice: "Be polite, be professional, but have a plan to kill everybody you meet.",
                    adviceType: .military,
                    portraitColor: "#8B0000"
                ),
                Advisor(
                    id: "tillerson",
                    name: "Rex Tillerson",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Former Exxon CEO, Fired by Trump",
                    expertise: 75,
                    loyalty: 50,
                    influence: 60,
                    publicSupport: 45,
                    hawkishness: 60,
                    interventionism: 65,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy, .economicSanctions],
                    currentAdvice: "We need to maintain our alliances and commitments, sir.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "pompeo",
                    name: "Mike Pompeo",
                    title: "CIA Director / Secretary of State",
                    department: "CIA / State",
                    bio: "Former Army officer, CIA Director, China hawk",
                    expertise: 85,
                    loyalty: 90,
                    influence: 85,
                    publicSupport: 50,
                    hawkishness: 85,
                    interventionism: 80,
                    fiscalConservatism: 70,
                    adviceAreas: [.intelligence, .diplomacy, .militaryStrike],
                    currentAdvice: "We lie, we cheat, we steal. That's the CIA way.",
                    adviceType: .intelligence,
                    portraitColor: "#2F4F4F"
                )
            ]
        )
    }

    // MARK: - Biden Administration (2021-2025)

    static func bidenAdministration() -> Administration {
        Administration(
            id: "biden",
            name: "Biden Administration",
            president: "Joe Biden",
            years: "2021-2025",
            startYear: 2021,
            endYear: 2025,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "biden_pres",
                    name: "Joe Biden",
                    title: "President",
                    department: "Executive Office",
                    bio: "46th President, Ukraine support, China competition, Oldest president",
                    expertise: 75,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 42,
                    hawkishness: 50,
                    interventionism: 60,
                    fiscalConservatism: 45,
                    adviceAreas: [.diplomacy, .militaryStrike],
                    currentAdvice: "C'mon man! We need to stand with our allies.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "blinken",
                    name: "Antony Blinken",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Deputy Secretary under Obama, Multilateralist",
                    expertise: 85,
                    loyalty: 90,
                    influence: 85,
                    publicSupport: 50,
                    hawkishness: 50,
                    interventionism: 70,
                    fiscalConservatism: 50,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "We must rebuild our alliances and lead through diplomacy.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "austin",
                    name: "Lloyd Austin",
                    title: "Secretary of Defense",
                    department: "Defense",
                    bio: "Retired four-star General, First Black Secretary of Defense",
                    expertise: 90,
                    loyalty: 85,
                    influence: 85,
                    publicSupport: 60,
                    hawkishness: 65,
                    interventionism: 70,
                    fiscalConservatism: 60,
                    adviceAreas: [.militaryStrike, .nuclearWeapons],
                    currentAdvice: "Our forces are ready, Mr. President. We maintain deterrence.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                ),
                Advisor(
                    id: "sullivan",
                    name: "Jake Sullivan",
                    title: "National Security Advisor",
                    department: "NSC",
                    bio: "Former Clinton advisor, Ukraine strategy",
                    expertise: 80,
                    loyalty: 90,
                    influence: 85,
                    publicSupport: 50,
                    hawkishness: 55,
                    interventionism: 65,
                    fiscalConservatism: 50,
                    adviceAreas: [.intelligence, .diplomacy],
                    currentAdvice: "We're threading the needle on Ukraine - support without escalation.",
                    adviceType: .intelligence,
                    portraitColor: "#8B4513"
                )
            ]
        )
    }

    // MARK: - Trump Second Administration (2025-present)

    static func trumpSecondAdministration() -> Administration {
        Administration(
            id: "trump_second",
            name: "Trump Second Administration",
            president: "Donald Trump",
            years: "2025-present",
            startYear: 2025,
            endYear: 2029,
            party: "Republican",
            advisors: trumpCabinet() // Use existing complete cabinet
        )
    }
}
