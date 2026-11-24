//
//  USStatesHistory.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the U.S. states by date. The thirteen original states; every later state at its real admission date; the
//  organized territories before statehood (Dakota Territory, the Northwest Territory…); the states that seceded in
//  1860–61 (held by the Confederate States while that government stands in the game); and each state's electors in
//  every presidential election, 1788–2024 (the official electoral returns: a state that cast no vote, as the
//  Confederate states in 1864, has 0). The electors double as the states' population weights (two fewer: the House
//  seats). Encyclopedia-level facts only.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum USStatesHistory {
    /// The thirteen states that ratified the Constitution: states from the first day of any game.
    static let original: Set<String> = ["US-DE", "US-PA", "US-NJ", "US-GA", "US-CT", "US-MA", "US-MD", "US-SC", "US-NH",
                                        "US-VA", "US-NY", "US-NC", "US-RI"]

    /// Admission to the Union (year, month, day) for every later state.
    static let admitted: [String: (Int, Int, Int)] = [
        "US-VT": (1791, 3, 4), "US-KY": (1792, 6, 1), "US-TN": (1796, 6, 1), "US-OH": (1803, 3, 1), "US-LA": (1812, 4, 30),
        "US-IN": (1816, 12, 11), "US-MS": (1817, 12, 10), "US-IL": (1818, 12, 3), "US-AL": (1819, 12, 14), "US-ME": (1820, 3, 15),
        "US-MO": (1821, 8, 10), "US-AR": (1836, 6, 15), "US-MI": (1837, 1, 26), "US-FL": (1845, 3, 3), "US-TX": (1845, 12, 29),
        "US-IA": (1846, 12, 28), "US-WI": (1848, 5, 29), "US-CA": (1850, 9, 9), "US-MN": (1858, 5, 11), "US-OR": (1859, 2, 14),
        "US-KS": (1861, 1, 29), "US-WV": (1863, 6, 20), "US-NV": (1864, 10, 31), "US-NE": (1867, 3, 1), "US-CO": (1876, 8, 1),
        "US-ND": (1889, 11, 2), "US-SD": (1889, 11, 2), "US-MT": (1889, 11, 8), "US-WA": (1889, 11, 11), "US-ID": (1890, 7, 3),
        "US-WY": (1890, 7, 10), "US-UT": (1896, 1, 4), "US-OK": (1907, 11, 16), "US-NM": (1912, 1, 6), "US-AZ": (1912, 2, 14),
        "US-AK": (1959, 1, 3), "US-HI": (1959, 8, 21),
    ]

    /// What the land was before statehood: (first year, name), oldest first. A state with no entry (Kentucky, Vermont,
    /// Maine, West Virginia, Texas, California) was part of another state or not U.S. land until it was admitted.
    static let territories: [String: [(from: Int, name: String)]] = [
        "US-OH": [(1789, "Northwest Territory")],
        "US-IN": [(1789, "Northwest Territory"), (1800, "Indiana Territory")],
        "US-IL": [(1789, "Northwest Territory"), (1800, "Indiana Territory"), (1809, "Illinois Territory")],
        "US-MI": [(1789, "Northwest Territory"), (1800, "Indiana Territory"), (1805, "Michigan Territory")],
        "US-WI": [(1789, "Northwest Territory"), (1800, "Indiana Territory"), (1809, "Illinois Territory"), (1818, "Michigan Territory"),
                  (1836, "Wisconsin Territory")],
        "US-TN": [(1790, "Southwest Territory")],
        "US-MS": [(1798, "Mississippi Territory")],
        "US-AL": [(1798, "Mississippi Territory"), (1817, "Alabama Territory")],
        "US-LA": [(1804, "Territory of Orleans")],
        "US-MO": [(1805, "Louisiana Territory"), (1812, "Missouri Territory")],
        "US-AR": [(1812, "Missouri Territory"), (1819, "Arkansas Territory")],
        "US-FL": [(1822, "Florida Territory")],
        "US-IA": [(1838, "Iowa Territory")],
        "US-MN": [(1849, "Minnesota Territory")],
        "US-OR": [(1848, "Oregon Territory")],
        "US-KS": [(1854, "Kansas Territory")],
        "US-NE": [(1854, "Nebraska Territory")],
        "US-WA": [(1853, "Washington Territory")],
        "US-UT": [(1850, "Utah Territory")],
        "US-NM": [(1850, "New Mexico Territory")],
        "US-AZ": [(1850, "New Mexico Territory"), (1863, "Arizona Territory")],
        "US-NV": [(1861, "Nevada Territory")],
        "US-CO": [(1861, "Colorado Territory")],
        "US-ND": [(1861, "Dakota Territory")],
        "US-SD": [(1861, "Dakota Territory")],
        "US-ID": [(1863, "Idaho Territory")],
        "US-MT": [(1864, "Montana Territory")],
        "US-WY": [(1868, "Wyoming Territory")],
        "US-OK": [(1834, "Indian Territory"), (1890, "Oklahoma Territory")],
        "US-AK": [(1867, "Department of Alaska"), (1884, "District of Alaska"), (1912, "Territory of Alaska")],
        "US-HI": [(1898, "Territory of Hawaii")],
    ]

    /// The federal district: the District of Columbia from 1791.
    static let districtFrom = 1791

    /// The states that seceded, 1860–61, with the date of each ordinance of secession.
    static let seceded: [String: (Int, Int, Int)] = [
        "US-SC": (1860, 12, 20), "US-MS": (1861, 1, 9), "US-FL": (1861, 1, 10), "US-AL": (1861, 1, 11), "US-GA": (1861, 1, 19),
        "US-LA": (1861, 1, 26), "US-TX": (1861, 2, 1), "US-VA": (1861, 4, 17), "US-AR": (1861, 5, 6), "US-NC": (1861, 5, 20),
        "US-TN": (1861, 6, 8),
    ]

    /// The first election of each apportionment (a column of `electorRows`).
    static let electionColumns = [1788, 1792, 1796, 1804, 1812, 1816, 1820, 1824, 1832, 1836, 1844, 1848, 1852, 1860, 1864, 1868,
                                  1872, 1876, 1884, 1892, 1896, 1904, 1908, 1912, 1932, 1944, 1952, 1960, 1964, 1972, 1984, 1992,
                                  2004, 2012, 2024]

    /// Electors by state and election ("-": no vote that year), in `electionColumns` order.
    static let electorRows = """
AK - - - - - - - - - - - - - - - - - - - - - - - - - - - 3 3 3 3 3 3 3 3
AL - - - - - - 3 5 7 7 9 9 9 9 0 8 10 10 10 11 11 11 11 12 11 11 11 11 10 9 9 9 9 9 9
AR - - - - - - - - - 3 3 3 4 4 0 5 6 6 7 8 8 9 9 9 9 9 8 8 6 6 6 6 6 6 6
AZ - - - - - - - - - - - - - - - - - - - - - - - 3 3 4 4 4 5 6 7 8 10 11 11
CA - - - - - - - - - - - - 4 4 5 5 6 6 8 9 9 10 10 13 22 25 32 32 40 45 47 54 55 55 54
CO - - - - - - - - - - - - - - - - - 3 3 4 4 5 5 6 6 6 6 6 6 7 8 8 9 9 10
CT 7 9 9 9 9 9 9 8 8 8 6 6 6 6 6 6 6 6 6 6 6 7 7 7 8 8 8 8 8 8 8 8 7 7 7
DC - - - - - - - - - - - - - - - - - - - - - - - - - - - - 3 3 3 3 3 3 3
DE 3 3 3 3 4 4 4 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3
FL - - - - - - - - - - - 3 3 3 0 3 4 4 4 4 4 5 5 6 7 8 10 10 14 17 21 25 27 29 30
GA 5 4 4 6 8 8 8 9 11 11 10 10 10 10 0 9 11 11 12 13 13 13 13 14 12 12 12 12 12 12 12 13 15 16 16
HI - - - - - - - - - - - - - - - - - - - - - - - - - - - 3 4 4 4 4 4 4 4
IA - - - - - - - - - - - 4 4 4 8 8 11 11 13 13 13 13 13 13 11 10 10 10 9 8 8 7 7 6 6
ID - - - - - - - - - - - - - - - - - - - 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4
IL - - - - - - 3 3 5 5 9 9 11 11 16 16 21 21 22 24 24 27 27 29 29 28 27 27 26 26 24 22 21 20 19
IN - - - - - 3 3 5 9 9 12 12 13 13 13 13 15 15 15 15 15 15 15 15 14 13 13 13 13 13 12 12 11 11 11
KS - - - - - - - - - - - - - - 3 3 5 5 9 10 10 10 10 10 9 8 8 8 7 7 7 6 6 6 6
KY - 4 4 8 12 12 12 14 15 15 12 12 12 12 11 11 12 12 13 13 13 13 13 13 11 11 10 10 9 9 9 8 8 8 8
LA - - - - 3 3 3 5 5 5 6 6 6 6 7 7 8 8 8 8 8 9 9 10 10 10 10 10 10 10 10 9 9 8 8
MA 10 16 16 19 22 22 15 15 14 14 12 12 13 13 12 12 13 13 14 15 15 16 16 18 17 16 16 16 14 14 13 12 12 11 11
MD 8 10 10 11 11 11 11 11 10 10 8 8 8 8 7 7 8 8 8 8 8 8 8 8 8 8 9 9 10 10 10 10 10 10 10
ME - - - - - - 9 9 10 10 9 9 8 8 7 7 7 7 6 6 6 6 6 6 5 5 5 5 4 4 4 4 4 4 4
MI - - - - - - - - - 3 5 5 6 6 8 8 11 11 13 14 14 14 14 15 19 19 20 20 21 21 20 18 17 16 15
MN - - - - - - - - - - - - - 4 4 4 5 5 7 9 9 11 11 12 11 11 11 11 10 10 10 10 10 10 10
MO - - - - - - 3 3 4 4 7 7 9 9 11 11 15 15 16 17 17 18 18 18 15 15 13 13 12 12 11 11 11 10 10
MS - - - - - - 3 3 4 4 6 6 7 7 0 0 8 8 9 9 9 10 10 10 9 9 8 8 7 7 7 7 6 6 6
MT - - - - - - - - - - - - - - - - - - - 3 3 3 3 4 4 4 4 4 4 4 4 3 3 3 4
NC - 12 12 14 15 15 15 15 15 15 11 11 10 10 0 9 10 10 11 11 11 12 12 12 13 14 14 14 13 13 13 14 15 15 16
ND - - - - - - - - - - - - - - - - - - - 3 3 4 4 5 4 4 4 4 4 3 3 3 3 3 3
NE - - - - - - - - - - - - - - - 3 3 3 5 8 8 8 8 8 7 6 6 6 5 5 5 5 5 5 5
NH 5 6 6 7 8 8 8 8 7 7 6 6 5 5 5 5 5 5 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4
NJ 6 7 7 8 8 8 8 8 8 8 7 7 7 7 7 7 9 9 9 10 10 12 12 14 16 16 16 16 17 17 16 15 15 14 14
NM - - - - - - - - - - - - - - - - - - - - - - - 3 3 4 4 4 4 4 5 5 5 5 5
NV - - - - - - - - - - - - - - 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 4 4 5 6 6
NY 8 12 12 19 29 29 29 36 42 42 36 36 35 35 33 33 35 35 36 36 36 39 39 45 47 47 45 45 43 41 36 33 31 29 28
OH - - - 3 8 8 8 16 21 21 23 23 23 23 21 21 22 22 23 23 23 23 23 24 26 25 25 25 26 25 23 21 20 18 17
OK - - - - - - - - - - - - - - - - - - - - - - 7 10 11 10 8 8 8 8 8 8 7 7 7
OR - - - - - - - - - - - - - 3 3 3 3 3 3 4 4 4 4 5 5 6 6 6 6 6 7 7 7 7 8
PA 10 15 15 20 25 25 25 28 30 30 26 26 27 27 26 26 29 29 30 32 32 34 34 38 36 35 32 32 29 27 25 23 21 20 19
RI - 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 5 4 4 4 4 4 4 4 4 4 4 4
SC 7 8 8 10 11 11 11 11 11 11 9 9 8 8 0 6 7 7 9 9 9 9 9 9 8 8 8 8 8 8 8 8 8 9 9
SD - - - - - - - - - - - - - - - - - - - 4 4 4 4 5 4 4 4 4 4 4 3 3 3 3 3
TN - - 3 5 8 8 8 11 15 15 13 13 12 12 10 10 12 12 12 12 12 12 12 12 11 12 11 11 11 10 11 11 11 11 11
TX - - - - - - - - - - - 4 4 4 0 0 8 8 13 15 15 18 18 20 23 23 24 24 25 26 29 32 34 38 40
UT - - - - - - - - - - - - - - - - - - - - 3 3 3 4 4 4 4 4 4 4 5 5 5 6 6
VA 12 21 21 24 25 25 25 24 23 23 17 17 15 15 0 0 11 11 12 12 12 12 12 12 11 11 12 12 12 12 12 13 13 13 13
VT - 4 4 6 8 8 8 7 7 7 6 6 5 5 5 5 5 5 4 4 4 4 4 4 3 3 3 3 3 3 3 3 3 3 3
WA - - - - - - - - - - - - - - - - - - - 4 4 5 5 7 8 8 9 9 9 9 10 11 11 12 12
WI - - - - - - - - - - - 4 5 5 8 8 10 10 11 12 12 13 13 13 12 12 12 12 12 11 11 11 10 10 10
WV - - - - - - - - - - - - - - 5 5 5 5 6 6 6 7 7 8 8 8 8 8 7 6 6 5 5 5 4
WY - - - - - - - - - - - - - - - - - - - 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3
"""

    /// Each state's electors by column, parsed once.
    static let electors: [String: [Int?]] = {
        var out: [String: [Int?]] = [:]
        for line in electorRows.split(separator: "\n") {
            let f = line.split(separator: " ")
            guard f.count == electionColumns.count + 1 else { continue }
            out["US-" + f[0]] = f.dropFirst().map { Int($0) }
        }
        return out
    }()

    /// The column for an election year (the latest apportionment at or before it).
    static func column(year: Int) -> Int {
        electionColumns.lastIndex { $0 <= year } ?? 0
    }

    /// A state's electors in an election year: nil if it had none (not yet a state, or did not take part).
    static func electors(_ id: String, year: Int) -> Int? {
        guard let row = electors[id] else { return nil }
        return row[column(year: year)]
    }

    /// Population weight in a year: its House seats (electors less two) at the latest apportionment it had, half a
    /// seat for a territory or a state before its first election, one for the District.
    static func weight(_ id: String, year: Int) -> Double {
        if id == "US-DC" { return 1 }
        guard let row = electors[id] else { return 0.5 }
        var k = column(year: year)
        while k >= 0 {
            if let e = row[k], e > 0 { return Double(max(1, e - 2)) }
            k -= 1
        }
        return 0.5   // a territory, or a state before its first election
    }
}
