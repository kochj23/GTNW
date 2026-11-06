//
//  ElectionHistory.swift
//  Global Thermal Nuclear War
//
//  3.21.0: the facts behind every U.S. presidential election, 1789–2024, and the rules that changed between them —
//  who could nominate, when the country voted, how many electors there were, when the winner took the oath, and
//  whether the President could run again. Sources: the U.S. Constitution (12th, 20th, 22nd, 23rd Amendments), the
//  1792 and 1845 Acts of Congress, the Electoral Count Acts of 1887 and 2022, and the official electoral returns.
//  Created by Jordan Koch.
//

import Foundation

/// Party codes used by the election tables.
enum PartyCode: String, Codable, CaseIterable {
    case none = "N", federalist = "F", democraticRepublican = "DR", nationalRepublican = "NR"
    case democratic = "D", whig = "W", republican = "R"

    var name: String {
        switch self {
        case .none: return "Independent"
        case .federalist: return "Federalist"
        case .democraticRepublican: return "Democratic-Republican"
        case .nationalRepublican: return "National Republican"
        case .democratic: return "Democratic"
        case .whig: return "Whig"
        case .republican: return "Republican"
        }
    }

    /// Map an administration's party label ("Democratic", "Whig (expelled)", "None (Federalist-leaning)") to a code.
    static func from(label: String) -> PartyCode {
        let l = label.lowercased()
        if l.hasPrefix("none") { return .none }
        if l.contains("democratic-republican") { return .democraticRepublican }
        if l.contains("national republican") { return .nationalRepublican }
        if l.contains("federalist") { return .federalist }
        if l.contains("whig") { return .whig }
        if l.contains("republican") { return .republican }
        if l.contains("democratic") { return .democratic }
        return .none
    }

    /// The other major party of `year`, as seen from this one.
    func opposition(in year: Int) -> PartyCode {
        switch year {
        case ..<1828: return self == .federalist ? .democraticRepublican : .federalist
        case 1828...1832: return self == .democratic ? .nationalRepublican : .democratic
        case 1833...1852: return self == .democratic ? .whig : .democratic
        default: return self == .democratic ? .republican : .democratic
        }
    }
}

/// How a party chose its nominee in a given year.
enum NominationMethod: String, Codable {
    case acclamation          // 1789, 1792: no parties, no nomination
    case congressionalCaucus  // 1796–1824: "King Caucus"
    case stateLegislatures    // 1828: legislatures and mass meetings
    case convention           // 1832–1908: national conventions, delegates chosen by party bosses
    case conventionAndPrimaries // 1912–1968: a few binding primaries, conventions still decide
    case primaries            // 1972–: McGovern–Fraser reforms; binding primaries and caucuses

    static func forYear(_ y: Int) -> NominationMethod {
        switch y {
        case ..<1796: return .acclamation
        case 1796...1824: return .congressionalCaucus
        case 1825...1831: return .stateLegislatures
        case 1832...1911: return .convention
        case 1912...1971: return .conventionAndPrimaries
        default: return .primaries
        }
    }
}

/// One historical general election: the two leading candidates, by party.
struct HistoricalElection {
    let year: Int
    let totalEV: Int
    let nominees: [PartyCode: String]
    /// A notable third candidate who drew a real share: (name, party label, popular %).
    let third: (name: String, party: String, popular: Double)?
}

enum ElectionHistory {

    /// Electors allotted in each election (the denominator for a majority). Before 1804 each elector cast two votes.
    static let totalEV: [Int: Int] = [
        1789: 69, 1792: 132, 1796: 138, 1800: 138, 1804: 176, 1808: 176, 1812: 217, 1816: 221, 1820: 235, 1824: 261,
        1828: 261, 1832: 288, 1836: 294, 1840: 294, 1844: 275, 1848: 290, 1852: 296, 1856: 296, 1860: 303, 1864: 234,
        1868: 294, 1872: 366, 1876: 369, 1880: 369, 1884: 401, 1888: 401, 1892: 444, 1896: 447, 1900: 447, 1904: 476,
        1908: 483, 1912: 531, 1916: 531, 1920: 531, 1924: 531, 1928: 531, 1932: 531, 1936: 531, 1940: 531, 1944: 531,
        1948: 531, 1952: 531, 1956: 531, 1960: 537,
    ]

    /// Electors for `year`: the historical count, or 538 from 1964 (the 23rd Amendment gave D.C. three).
    static func electors(_ year: Int) -> Int {
        if let n = totalEV[year] { return n }
        if year >= 1964 { return 538 }
        return totalEV.filter { $0.key <= year }.max { $0.key < $1.key }?.value ?? 69
    }

    /// Votes needed to win: a majority of electors.
    static func majority(_ year: Int) -> Int { electors(year) / 2 + 1 }

    /// The major-party nominees of every election, so a historical President faces the opponent history gave them.
    static let nominees: [Int: [PartyCode: String]] = [
        1792: [.federalist: "John Adams", .democraticRepublican: "George Clinton"],
        1796: [.federalist: "John Adams", .democraticRepublican: "Thomas Jefferson"],
        1800: [.democraticRepublican: "Thomas Jefferson", .federalist: "John Adams"],
        1804: [.democraticRepublican: "Thomas Jefferson", .federalist: "Charles Cotesworth Pinckney"],
        1808: [.democraticRepublican: "James Madison", .federalist: "Charles Cotesworth Pinckney"],
        1812: [.democraticRepublican: "James Madison", .federalist: "DeWitt Clinton"],
        1816: [.democraticRepublican: "James Monroe", .federalist: "Rufus King"],
        1820: [.democraticRepublican: "James Monroe"],
        1824: [.democraticRepublican: "William H. Crawford", .federalist: "Andrew Jackson"],   // all four ran as Democratic-Republicans
        1828: [.democratic: "Andrew Jackson", .nationalRepublican: "John Quincy Adams"],
        1832: [.democratic: "Andrew Jackson", .nationalRepublican: "Henry Clay"],
        1836: [.democratic: "Martin Van Buren", .whig: "William Henry Harrison"],
        1840: [.whig: "William Henry Harrison", .democratic: "Martin Van Buren"],
        1844: [.democratic: "James K. Polk", .whig: "Henry Clay"],
        1848: [.whig: "Zachary Taylor", .democratic: "Lewis Cass"],
        1852: [.democratic: "Franklin Pierce", .whig: "Winfield Scott"],
        1856: [.democratic: "James Buchanan", .republican: "John C. Frémont"],
        1860: [.republican: "Abraham Lincoln", .democratic: "Stephen A. Douglas"],
        1864: [.republican: "Abraham Lincoln", .democratic: "George B. McClellan"],
        1868: [.republican: "Ulysses S. Grant", .democratic: "Horatio Seymour"],
        1872: [.republican: "Ulysses S. Grant", .democratic: "Horace Greeley"],
        1876: [.republican: "Rutherford B. Hayes", .democratic: "Samuel J. Tilden"],
        1880: [.republican: "James A. Garfield", .democratic: "Winfield Scott Hancock"],
        1884: [.democratic: "Grover Cleveland", .republican: "James G. Blaine"],
        1888: [.republican: "Benjamin Harrison", .democratic: "Grover Cleveland"],
        1892: [.democratic: "Grover Cleveland", .republican: "Benjamin Harrison"],
        1896: [.republican: "William McKinley", .democratic: "William Jennings Bryan"],
        1900: [.republican: "William McKinley", .democratic: "William Jennings Bryan"],
        1904: [.republican: "Theodore Roosevelt", .democratic: "Alton B. Parker"],
        1908: [.republican: "William Howard Taft", .democratic: "William Jennings Bryan"],
        1912: [.democratic: "Woodrow Wilson", .republican: "William Howard Taft"],
        1916: [.democratic: "Woodrow Wilson", .republican: "Charles Evans Hughes"],
        1920: [.republican: "Warren G. Harding", .democratic: "James M. Cox"],
        1924: [.republican: "Calvin Coolidge", .democratic: "John W. Davis"],
        1928: [.republican: "Herbert Hoover", .democratic: "Al Smith"],
        1932: [.democratic: "Franklin D. Roosevelt", .republican: "Herbert Hoover"],
        1936: [.democratic: "Franklin D. Roosevelt", .republican: "Alf Landon"],
        1940: [.democratic: "Franklin D. Roosevelt", .republican: "Wendell Willkie"],
        1944: [.democratic: "Franklin D. Roosevelt", .republican: "Thomas E. Dewey"],
        1948: [.democratic: "Harry S. Truman", .republican: "Thomas E. Dewey"],
        1952: [.republican: "Dwight D. Eisenhower", .democratic: "Adlai Stevenson"],
        1956: [.republican: "Dwight D. Eisenhower", .democratic: "Adlai Stevenson"],
        1960: [.democratic: "John F. Kennedy", .republican: "Richard Nixon"],
        1964: [.democratic: "Lyndon B. Johnson", .republican: "Barry Goldwater"],
        1968: [.republican: "Richard Nixon", .democratic: "Hubert Humphrey"],
        1972: [.republican: "Richard Nixon", .democratic: "George McGovern"],
        1976: [.democratic: "Jimmy Carter", .republican: "Gerald Ford"],
        1980: [.republican: "Ronald Reagan", .democratic: "Jimmy Carter"],
        1984: [.republican: "Ronald Reagan", .democratic: "Walter Mondale"],
        1988: [.republican: "George H.W. Bush", .democratic: "Michael Dukakis"],
        1992: [.democratic: "Bill Clinton", .republican: "George H.W. Bush"],
        1996: [.democratic: "Bill Clinton", .republican: "Bob Dole"],
        2000: [.republican: "George W. Bush", .democratic: "Al Gore"],
        2004: [.republican: "George W. Bush", .democratic: "John Kerry"],
        2008: [.democratic: "Barack Obama", .republican: "John McCain"],
        2012: [.democratic: "Barack Obama", .republican: "Mitt Romney"],
        2016: [.republican: "Donald Trump", .democratic: "Hillary Clinton"],
        2020: [.democratic: "Joe Biden", .republican: "Donald Trump"],
        2024: [.republican: "Donald Trump", .democratic: "Kamala Harris"],
    ]

    /// Third candidates who carried real support: (name, party, popular %).
    static let thirdParties: [Int: (name: String, party: String, popular: Double)] = [
        1832: ("William Wirt", "Anti-Masonic", 7.8),
        1848: ("Martin Van Buren", "Free Soil", 10.1),
        1856: ("Millard Fillmore", "American (Know-Nothing)", 21.5),
        1860: ("John C. Breckinridge", "Southern Democratic", 18.1),
        1892: ("James B. Weaver", "Populist", 8.5),
        1912: ("Theodore Roosevelt", "Progressive (Bull Moose)", 27.4),
        1924: ("Robert La Follette", "Progressive", 16.6),
        1948: ("Strom Thurmond", "States' Rights (Dixiecrat)", 2.4),
        1968: ("George Wallace", "American Independent", 13.5),
        1980: ("John Anderson", "Independent", 6.6),
        1992: ("Ross Perot", "Independent", 18.9),
        1996: ("Ross Perot", "Reform", 8.4),
    ]

    /// Sitting presidents who faced a serious fight for their own party's nomination: year|party → challenger.
    static let nominationChallengers: [String: (name: String, strength: Double)] = [
        "1852|W": ("Gen. Winfield Scott", 0.75),
        "1856|D": ("James Buchanan", 0.75),
        "1868|D": ("Horatio Seymour", 0.8),
        "1880|R": ("James A. Garfield", 0.6),
        "1884|R": ("James G. Blaine", 0.7),
        "1912|R": ("Theodore Roosevelt", 0.6),
        "1948|D": ("the \"Draft Eisenhower\" movement", 0.35),
        "1952|D": ("Sen. Estes Kefauver", 0.6),
        "1968|D": ("Sen. Eugene McCarthy", 0.6),
        "1976|R": ("Ronald Reagan", 0.55),
        "1980|D": ("Sen. Ted Kennedy", 0.5),
        "1992|R": ("Pat Buchanan", 0.4),
    ]

    /// Presidents who rose from the vice presidency mid-term. Under the 22nd Amendment a President who served more
    /// than two years of someone else's term may be elected only once.
    static let successors: Set<String> = ["John Tyler", "Millard Fillmore", "Andrew Johnson", "Chester A. Arthur",
                                          "Theodore Roosevelt", "Calvin Coolidge", "Harry S. Truman",
                                          "Lyndon B. Johnson", "Gerald Ford"]

    /// Party labels that differ from the code in a given year (1824: every candidate was a Democratic-Republican).
    static func partyLabel(_ code: PartyCode, year: Int) -> String {
        if year == 1824 { return code == .federalist ? "Democratic-Republican (Jackson faction)" : "Democratic-Republican (Crawford faction)" }
        if year == 1864 && code == .republican { return "National Union" }
        return code.name
    }

    /// Successors who served more than two years of a predecessor's term, so the 22nd Amendment allows them only one
    /// election of their own. (Lyndon Johnson served 14 months of Kennedy's term and could have run twice; Ford
    /// served 29 months of Nixon's.)
    static let overTwoYearSuccessors: Set<String> = ["Gerald Ford"]

    static func historical(_ year: Int) -> HistoricalElection? {
        guard let n = nominees[year] else { return nil }
        return HistoricalElection(year: year, totalEV: electors(year), nominees: n, third: thirdParties[year])
    }
}

/// The calendar and law of one presidential election year.
struct ElectionRules {
    let year: Int

    var nomination: NominationMethod { .forYear(year) }
    var electors: Int { ElectionHistory.electors(year) }
    var majority: Int { ElectionHistory.majority(year) }
    /// Popular votes were not recorded nationally until 1824; most electors were chosen by state legislatures.
    var hasPopularVote: Bool { year >= 1824 }
    /// The 12th Amendment (1804) put President and Vice President on one ticket; before it the runner-up was VP.
    var hasTicket: Bool { year >= 1804 }
    /// Televised debates: Kennedy–Nixon 1960, then none until 1976.
    var hasDebates: Bool { year == 1960 || year >= 1976 }
    /// Vice-presidential debates: 1976, then every cycle from 1984.
    var hasVPDebate: Bool { year == 1976 || year >= 1984 }
    /// The 22nd Amendment (ratified 1951) first bound the 1952 election (and exempted the sitting President).
    var termLimited: Bool { year >= 1952 }
    var iowaFirst: Bool { year >= 1972 }
    var newHampshirePrimary: Bool { year >= 1920 }
    var superTuesday: Bool { year >= 1988 }
    /// Live coast-to-coast convention coverage from 1952; radio from 1924.
    var televised: Bool { year >= 1952 }
    /// Nominees did not appear at conventions until FDR flew to Chicago in 1932.
    var acceptsInPerson: Bool { year >= 1932 }

    /// Election day. From 1845 the Tuesday after the first Monday of November; before that states chose electors over
    /// a 34-day window ending on the first Wednesday of December, when the electors met.
    var electionDay: Date { GameCalendar.electionDay(year: year) }

    /// When the electors cast their ballots.
    var electorsMeet: Date {
        switch year {
        case ..<1887: return ElectionRules.firstWeekday(4, month: 12, year: year)       // first Wednesday of Dec
        case 1887...1933: return ElectionRules.nthWeekday(2, weekday: 2, month: 1, year: year + 1)   // second Monday of Jan
        default: return GameCalendar.date(year: year, month: 12, day: 15)
        }
    }

    /// Congress counts the electoral votes: the second Wednesday of February until 1934, January 6 since 1937.
    var countDay: Date {
        year >= 1936 ? GameCalendar.date(year: year + 1, month: 1, day: 6)
                     : ElectionRules.nthWeekday(2, weekday: 4, month: 2, year: year + 1)
    }

    /// Inauguration: March 4 through 1933; January 20 from 1937 (20th Amendment).
    var inauguration: Date {
        year >= 1936 ? GameCalendar.date(year: year + 1, month: 1, day: 20) : GameCalendar.date(year: year + 1, month: 3, day: 4)
    }

    static func firstWeekday(_ weekday: Int, month: Int, year: Int) -> Date { nthWeekday(1, weekday: weekday, month: month, year: year) }

    /// The `n`th `weekday` (1 = Sunday … 7 = Saturday) of a month.
    static func nthWeekday(_ n: Int, weekday: Int, month: Int, year: Int) -> Date {
        let first = GameCalendar.date(year: year, month: month, day: 1)
        let wd = GameCalendar.calendar.component(.weekday, from: first)
        let offset = (weekday - wd + 7) % 7 + (n - 1) * 7
        return GameCalendar.calendar.date(byAdding: .day, value: offset, to: first) ?? first
    }
}
