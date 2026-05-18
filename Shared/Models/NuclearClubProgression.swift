//
//  NuclearClubProgression.swift
//  GTNW
//
//  Historically accurate nuclear weapons proliferation timeline
//  Source: Federation of American Scientists, IAEA records
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// Nuclear club membership by year
struct NuclearClubProgression {

    /// Get list of nuclear-armed countries for a specific year
    static func nuclearPowersForYear(_ year: Int) -> [String] {
        var powers: [String] = []

        // USA - First nuclear power (1945, Trinity test)
        if year >= 1945 {
            powers.append("USA")
        }

        // USSR/Russia - 1949 (RDS-1 test)
        if year >= 1949 {
            powers.append(year < 1992 ? "USSR" : "Russia")
        }

        // United Kingdom - 1952 (Operation Hurricane)
        if year >= 1952 {
            powers.append("UK")
        }

        // France - 1960 (Gerboise Bleue test)
        if year >= 1960 {
            powers.append("France")
        }

        // China - 1964 (596 test)
        if year >= 1964 {
            powers.append("China")
        }

        // India - 1974 (Smiling Buddha test)
        if year >= 1974 {
            powers.append("India")
        }

        // Pakistan - 1998 (Chagai-I test)
        if year >= 1998 {
            powers.append("Pakistan")
        }

        // North Korea - 2006 (First test)
        if year >= 2006 {
            powers.append("North Korea")
        }

        // Israel - Undeclared but widely believed since ~1967
        // Add for realism in modern scenarios
        if year >= 1967 {
            powers.append("Israel")
        }

        return powers
    }

    /// Get year range for administration
    static func yearForAdministration(_ administrationID: String) -> Int {
        let adminYears: [String: Int] = [
            "truman": 1945,
            "eisenhower": 1953,
            "kennedy": 1961,
            "johnson": 1963,
            "nixon": 1969,
            "ford": 1974,
            "carter": 1977,
            "reagan": 1981,
            "bush_sr": 1989,
            "clinton": 1993,
            "bush_jr": 2001,
            "obama": 2009,
            "trump_first": 2017,
            "biden": 2021,
            "trump_second": 2025
        ]

        return adminYears[administrationID] ?? 2025
    }

    /// Check if country should have nuclear weapons in given year
    static func hasNuclearWeapons(country: String, year: Int) -> Bool {
        return nuclearPowersForYear(year).contains(country)
    }

    /// Get initial nuclear arsenal for country in given year
    static func initialNuclearArsenal(country: String, year: Int) -> Int {
        guard hasNuclearWeapons(country: country, year: year) else { return 0 }

        // Historical estimates (approximate)
        switch country {
        case "USA":
            if year < 1950 { return 200 }      // Early Cold War
            if year < 1960 { return 1000 }     // Massive buildup
            if year < 1970 { return 5000 }     // Peak buildup
            if year < 1990 { return 10000 }    // Cold War peak
            if year < 2000 { return 8000 }     // Post-Cold War reduction
            return 5500                         // Current (~5,550)

        case "USSR", "Russia":
            if year < 1955 { return 50 }       // Early development
            if year < 1965 { return 500 }      // Catching up
            if year < 1975 { return 2000 }     // Parity pursuit
            if year < 1990 { return 10000 }    // Cold War peak
            if year < 2000 { return 7000 }     // Reduction
            if year < 2010 { return 5000 }     // Further reduction
            return 5900                         // Current (~5,900)

        case "UK":
            if year < 1960 { return 10 }
            if year < 1970 { return 50 }
            if year < 1990 { return 200 }
            return 225                          // Current

        case "France":
            if year < 1970 { return 10 }
            if year < 1980 { return 100 }
            if year < 2000 { return 500 }
            return 290                          // Current

        case "China":
            if year < 1970 { return 20 }
            if year < 1980 { return 100 }
            if year < 1990 { return 200 }
            if year < 2010 { return 240 }
            return 410                          // Current (~410)

        case "India":
            if year < 1998 { return 10 }       // After 1974 test
            if year < 2010 { return 60 }
            return 170                          // Current estimate

        case "Pakistan":
            if year < 2005 { return 20 }
            if year < 2015 { return 100 }
            return 170                          // Current estimate

        case "North Korea":
            if year < 2010 { return 5 }
            if year < 2015 { return 10 }
            if year < 2020 { return 30 }
            return 50                           // Current estimate

        case "Israel":
            if year < 1970 { return 0 }        // Undeclared
            if year < 1980 { return 20 }
            if year < 2000 { return 100 }
            return 90                           // Current estimate (undeclared)

        default:
            return 0
        }
    }
}
