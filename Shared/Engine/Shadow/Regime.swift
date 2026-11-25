//
//  Regime.swift
//  Global Thermal Nuclear War
//
//  3.37.0: the player's own government. The domestic model was written for Washington (Congress, the Senate, the
//  Vice President, impeachment), and every other nation the player led was run as an American presidency with a
//  different flag. A `Regime` is the player nation's form of government, from its GovernmentType and the bundled
//  cabinet research (NationModel), corrected by a small table where the two disagree with how the country is run
//  (parliamentary republics, ruling monarchies, Vatican City). It gives:
//    • the words: the leader's title, the legislature, the deputy, the military chiefs, the seat of government.
//      `localize` rewrites the American terms in any player-facing line (the ticker, the log, crisis cards, the
//      cabinet's warnings, the game-over headline, the epilogue). The United States is never touched: a U.S. game
//      reads exactly as before.
//    • the way out of office: the same approval / outrage track, ending in impeachment, a no-confidence vote, the
//      party, the army, the Assembly of Experts, abdication or (Vatican City) a resignation under pressure.
//    • what the country can do: a nation with no meaningful military asks its nearest capable friend to act, and
//      that ally decides; a chemical or biological program is restarted only where one existed, otherwise started.
//  Content rules: the faith, the papacy and the clergy are written about with respect, in the game's neutral
//  wording; satire is aimed only at the player's own decisions. No real religious figure is named or quoted.
//  Deterministic: nothing here draws from the RNG.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// How the player's nation is governed.
enum RegimeKind: String, Codable, CaseIterable {
    case presidential, parliamentary, communist, authoritarian, military, monarchy, theocracy, papacy
}

/// The player nation's government (saved on `ShadowState.regime`; nil for the United States and older saves).
struct Regime: Codable, Equatable {
    var kind: RegimeKind
    var country: String
    var countryName: String
    var capital: String
    var removal: RemovalMechanism

    var isUS: Bool { country == "USA" }
}

// MARK: - Which government

extension Regime {
    /// Where the game's government type (and the research's generic default) misdescribes how a country is run.
    /// Only nations without a research period need listing: the 33 researched nations carry their own form.
    static let kindOverrides: [String: RegimeKind] = {
        var t: [String: RegimeKind] = ["VAT": .papacy]
        // Republics governed by a prime minister answerable to parliament.
        for id in ["IRL", "GRC", "CZE", "HUN", "SVK", "BGR", "EST", "LVA", "MLT", "ISL", "FIN", "PRT", "SVN", "HRV", "SRB",
                   "MNE", "MKD", "ALB", "XKX", "MDA", "ARM", "GEO", "NPL", "BGD", "SGP", "MUS", "TTO", "DMA", "VUT", "FJI",
                   "ETH", "IRQ", "LBN", "AND"] { t[id] = .parliamentary }
        // Monarchies where the monarch governs.
        for id in ["SAU", "ARE", "OMN", "QAT", "KWT", "BHR", "BRN", "SWZ", "MCO", "LIE", "JOR", "MAR"] { t[id] = .monarchy }
        return t
    }()

    /// The leader's title where it differs from the form of government's usual one.
    static let titleOverrides: [String: String] = [
        "DEU": "Chancellor", "AUT": "Chancellor", "SAU": "King", "JOR": "King", "MAR": "King", "SWZ": "King", "BHR": "King",
        "QAT": "Emir", "KWT": "Emir", "ARE": "Emir", "OMN": "Sultan", "BRN": "Sultan", "MCO": "Prince", "LIE": "Prince",
    ]

    /// The legislature by its own name, where the generic one would be wrong.
    static let legislatureOverrides: [String: String] = [
        "MEX": "Congress", "BRA": "Congress", "ARG": "Congress", "CHL": "Congress", "COL": "Congress", "PER": "Congress",
        "PHL": "Congress", "GTM": "Congress", "HND": "Congress", "PRY": "Congress", "FRA": "Parliament", "GBR": "Parliament",
        "DEU": "the Bundestag", "JPN": "the Diet", "ISR": "the Knesset", "IRN": "the Majlis", "RUS": "the Duma",
        "MCO": "the National Council", "LIE": "the Landtag", "SAU": "the Consultative Assembly",
    ]

    /// The form of government from the research's government string (NationModel.governmentType).
    static func kind(forGovernment gov: String) -> RegimeKind {
        if gov.contains("communist") { return .communist }
        if gov == "military_junta" { return .military }
        if gov.contains("theocratic") { return .theocracy }
        if gov == "absolute_monarchy" || gov == "constitutional_monarchy_executive" || gov == "empire_napoleonic" { return .monarchy }
        if gov.contains("parliamentary") || gov == "dominion" { return .parliamentary }
        if gov.contains("presidential") { return .presidential }
        return .authoritarian   // personalist dictatorship, one-party state, revolutionary or occupation government
    }

    static func kind(for government: GovernmentType) -> RegimeKind {
        switch government {
        case .democracy, .republic: return .presidential
        case .monarchy: return .parliamentary   // "Constitutional Monarchy": a prime minister governs
        case .communist: return .communist
        case .authoritarian: return .authoritarian
        case .military: return .military
        case .theocracy: return .theocracy
        }
    }

    /// The player nation's regime on a date; nil for the United States (whose words never change).
    static func resolve(_ c: Country, on date: Date) -> Regime? {
        guard c.id != "USA" else { return nil }
        let kind: RegimeKind
        if c.id == "VAT" { kind = .papacy }
        else if let p = NationModel.period(c.id, on: date) { kind = Self.kind(forGovernment: p.gov) }
        else { kind = kindOverrides[c.id] ?? Self.kind(for: c.government) }
        let removal: RemovalMechanism
        switch kind {
        case .papacy: removal = .resignationPressure
        case .theocracy: removal = .council
        case .monarchy: removal = .abdication   // the monarch is the one in office; nobody above to dismiss him
        default:
            if NationModel.period(c.id, on: date) != nil { removal = NationModel.removal(c, on: date) }
            else {
                switch kind {
                case .parliamentary: removal = .noConfidence
                case .communist: removal = .partyCongress
                case .authoritarian, .military: removal = .coup
                default: removal = .impeachment
                }
            }
        }
        return Regime(kind: kind, country: c.id, countryName: c.name, capital: c.capital, removal: removal)
    }

    static func resolve(_ gs: GameState) -> Regime? {
        gs.getPlayerCountry().flatMap { resolve($0, on: gs.currentDate) }
    }
}

// MARK: - The words

/// The player government's names for the things the American text calls Congress, the Vice President and so on.
struct RegimeTerms: Equatable {
    /// "Prime Minister", "Pope".
    var title: String
    /// With its article where it takes one: "Parliament", "the Politburo", "the College of Cardinals".
    var legislature: String
    var lowerHouse: String
    var upperHouse: String
    /// "the legislature's", as an adjective for "House committees" / "Senate votes".
    var legislatureAdj: String
    var deputy: String
    /// The body that answers for the armed forces ("General Staff", "Swiss Guard"); a speaker label.
    var chiefs: String
    /// With its article: "the presidential palace", "the Apostolic Palace".
    var seat: String
    var tenure: String
    var tenurePlural: String
    var tenureAdj: String
    var address: String
    var foreignMinister: String
    var defenseMinister: String
    var spyChief: String
    var spyService: String
    var spokesman: String
    var securityAdviser: String
    var chiefOfStaff: String
    var hasElections: Bool
}

extension Regime {
    var terms: RegimeTerms {
        let title = Self.titleOverrides[country]
        let leg = Self.legislatureOverrides[country]
        var t: RegimeTerms
        switch kind {
        case .presidential:
            let congress = leg == "Congress"
            t = RegimeTerms(title: title ?? "President", legislature: leg ?? "the legislature",
                            lowerHouse: congress ? "the Chamber of Deputies" : "the lower house",
                            upperHouse: congress ? "the Senate" : "the upper house", legislatureAdj: "legislative",
                            deputy: country == "FRA" ? "Prime Minister" : "Vice President", chiefs: "General Staff",
                            seat: "the presidential palace", tenure: "presidency", tenurePlural: "presidencies",
                            tenureAdj: "presidential", address: "Mr. President", foreignMinister: "Foreign Minister",
                            defenseMinister: "Defense Minister", spyChief: "intelligence chief", spyService: "the intelligence service",
                            spokesman: "Government Spokesman", securityAdviser: "National Security Adviser", chiefOfStaff: "Chief of Staff",
                            hasElections: true)
        case .parliamentary:
            let chancellor = (title ?? "") == "Chancellor"
            t = RegimeTerms(title: title ?? "Prime Minister", legislature: leg ?? "Parliament",
                            lowerHouse: country == "GBR" ? "the Commons" : "the lower house",
                            upperHouse: country == "GBR" ? "the Lords" : "the upper house", legislatureAdj: "parliamentary",
                            deputy: chancellor ? "Vice-Chancellor" : "Deputy Prime Minister", chiefs: "General Staff",
                            seat: chancellor ? "the Chancellery" : (country == "GBR" ? "Downing Street" : "the Prime Minister's office"),
                            tenure: chancellor ? "chancellorship" : "premiership", tenurePlural: chancellor ? "chancellorships" : "premierships",
                            tenureAdj: "government", address: chancellor ? "Chancellor" : "Prime Minister",
                            foreignMinister: "Foreign Minister", defenseMinister: "Defense Minister", spyChief: "intelligence chief",
                            spyService: "the intelligence service", spokesman: "Government Spokesman",
                            securityAdviser: "National Security Adviser", chiefOfStaff: "Chief of Staff", hasElections: true)
        case .communist:
            t = RegimeTerms(title: title ?? "General Secretary", legislature: leg ?? "the Politburo", lowerHouse: "the Central Committee",
                            upperHouse: "the Politburo", legislatureAdj: "party", deputy: "Premier", chiefs: "General Staff",
                            seat: "party headquarters", tenure: "leadership", tenurePlural: "leaderships", tenureAdj: "leadership",
                            address: "Comrade General Secretary", foreignMinister: "Foreign Minister", defenseMinister: "Defense Minister",
                            spyChief: "Chairman of State Security", spyService: "State Security", spokesman: "Party Spokesman",
                            securityAdviser: "Chief of the General Staff", chiefOfStaff: "Head of the General Office", hasElections: false)
        case .authoritarian:
            t = RegimeTerms(title: title ?? "President", legislature: leg ?? "the legislature", lowerHouse: leg ?? "the legislature",
                            upperHouse: leg ?? "the legislature", legislatureAdj: "legislative", deputy: "Prime Minister",
                            chiefs: "General Staff", seat: "the presidential palace", tenure: "rule", tenurePlural: "regimes",
                            tenureAdj: "presidential", address: "Mr. President", foreignMinister: "Foreign Minister",
                            defenseMinister: "Defense Minister", spyChief: "security chief", spyService: "the security service",
                            spokesman: "Government Spokesman", securityAdviser: "Security Adviser", chiefOfStaff: "Chief of Staff",
                            hasElections: false)
        case .military:
            t = RegimeTerms(title: title ?? "Chairman of the Junta", legislature: "the junta", lowerHouse: "the junta",
                            upperHouse: "the junta", legislatureAdj: "junta", deputy: "Deputy Chairman", chiefs: "Service Commanders",
                            seat: "the junta's headquarters", tenure: "rule", tenurePlural: "juntas", tenureAdj: "junta",
                            address: "Mr. Chairman", foreignMinister: "Foreign Minister", defenseMinister: "Defense Minister",
                            spyChief: "Director of Military Intelligence", spyService: "military intelligence",
                            spokesman: "Junta Spokesman", securityAdviser: "Chief of the General Staff", chiefOfStaff: "Chief of Staff",
                            hasElections: false)
        case .monarchy:
            let majesty = ["SAU", "JOR", "MAR", "SWZ", "BHR"].contains(country)
            let address = majesty ? "Your Majesty" : (["MCO", "LIE"].contains(country) ? "Your Serene Highness" : "Your Highness")
            t = RegimeTerms(title: title ?? "Monarch", legislature: leg ?? "the royal council", lowerHouse: leg ?? "the royal council",
                            upperHouse: leg ?? "the royal council", legislatureAdj: "council", deputy: country == "MCO" ? "Minister of State" : "Prime Minister",
                            chiefs: "General Staff", seat: "the palace", tenure: "reign", tenurePlural: "reigns", tenureAdj: "royal",
                            address: address, foreignMinister: "Foreign Minister", defenseMinister: "Defense Minister",
                            spyChief: "intelligence chief", spyService: "the intelligence service", spokesman: "Palace Spokesman",
                            securityAdviser: "Security Adviser", chiefOfStaff: "Head of the Royal Court", hasElections: false)
        case .theocracy:
            t = RegimeTerms(title: title ?? "Supreme Leader", legislature: leg ?? "the national assembly",
                            lowerHouse: leg ?? "the national assembly", upperHouse: "the Guardian Council", legislatureAdj: "assembly",
                            deputy: "President of the Republic", chiefs: "General Staff", seat: "the Leader's office", tenure: "tenure",
                            tenurePlural: "tenures", tenureAdj: "leadership", address: "Supreme Leader", foreignMinister: "Foreign Minister",
                            defenseMinister: "Defense Minister", spyChief: "Intelligence Minister", spyService: "the intelligence ministry",
                            spokesman: "Government Spokesman", securityAdviser: "Chief of the General Staff",
                            chiefOfStaff: "Head of the Leader's Office", hasElections: false)
        case .papacy:
            // The Holy See's own offices (Secretariat of State, the Swiss Guard, the Gendarmerie Corps, the Press Office).
            t = RegimeTerms(title: "Pope", legislature: "the College of Cardinals", lowerHouse: "the College of Cardinals",
                            upperHouse: "the College of Cardinals", legislatureAdj: "curial", deputy: "Substitute for General Affairs",
                            chiefs: "Swiss Guard", seat: "the Apostolic Palace", tenure: "pontificate", tenurePlural: "pontificates",
                            tenureAdj: "papal", address: "Holy Father", foreignMinister: "Secretary of State",
                            defenseMinister: "Commander of the Swiss Guard", spyChief: "Commander of the Gendarmerie Corps",
                            spyService: "the Gendarmerie", spokesman: "Director of the Holy See Press Office",
                            securityAdviser: "Commander of the Swiss Guard", chiefOfStaff: "Prefect of the Papal Household", hasElections: false)
        }
        return t
    }

    /// The leader as the history books name him when no name is on record ("The Prime Minister", "The Pope").
    var leaderFallback: String { "The " + terms.title }

    /// Cabinet titles for the research's role keys where the generic form of government would be wrong (only the
    /// Holy See, whose offices the generic theocratic table does not describe).
    func cabinetTitle(role: String) -> String? {
        guard kind == .papacy else { return nil }
        switch role {
        case "head_of_state": return "Pope"
        case "head_of_government": return "Secretary of State"
        case "foreign": return "Secretary for Relations with States"
        case "defense": return "Head of the Governorate"
        case "finance": return "Prefect of the Secretariat for the Economy"
        case "intelligence": return "Commander of the Gendarmerie Corps"
        case "military_chief": return "Commander of the Swiss Guard"
        case "interior": return "Director of the Holy See Press Office"
        default: return nil
        }
    }
}

// MARK: - Rewriting American text

extension Regime {
    /// Whole sentences the domestic model writes about impeachment and the American calendar, in this government's
    /// terms. Applied before the word table, so a sentence is replaced whole.
    var phrases: [(String, String)] {
        let t = terms
        let m = removal
        var p: [(String, String)] = []
        if m != .impeachment {
            p += [(PopularityModel.impeachmentText(stage: 1), m.stageText(1)),
                  (PopularityModel.impeachmentText(stage: 2), m.stageText(2)),
                  (PopularityModel.impeachmentText(stage: 3), m.stageText(3)),
                  ("Within days the House impeaches and the Senate convicts. You are removed from office.", m.ending.headline),
                  ("Articles of impeachment are drafted anyway.", m.stageText(2)),
                  ("Articles of impeachment are drafted.", m.stageText(2)),
                  ("Congress drafts articles of impeachment.", m.stageText(2)),
                  ("Congress drops its investigation of the White House.", m.dropText),
                  ("Congress will move to impeach at the next poll.", m.imminentText),
                  ("Impeachment talk is rising on the Hill.", m.risingText),
                  (DomesticEnding.impeached.headline, m.ending.headline),
                  ("Impeachment hearings", m.inquiryLead)]
        }
        switch kind {
        case .papacy:
            p += [("You take the oath of office.", "Your pontificate begins."),
                  ("State of the Union: the President addresses a joint session of Congress.",
                   "The Pope gives the annual address to the diplomatic corps accredited to the Holy See."),
                  ("The inquiry into the leader's conduct", "Before the College of Cardinals")]
        case .monarchy:
            p += [("You take the oath of office.", "You take up the duties of the crown."),
                  ("State of the Union: the President addresses a joint session of Congress.", "The \(t.title) gives the annual address to the nation.")]
        case .parliamentary:
            p += [("State of the Union: the President addresses a joint session of Congress.",
                   "The \(t.title) sets out the government's program to \(t.legislature).")]
        case .communist:
            p += [("You take the oath of office.", "You take up the leadership of the party."),
                  ("State of the Union: the President addresses a joint session of Congress.",
                   "The \(t.title) delivers the annual report to the Central Committee.")]
        case .military:
            p += [("You take the oath of office.", "You take charge of the junta."),
                  ("State of the Union: the President addresses a joint session of Congress.", "The \(t.title) addresses the nation.")]
        case .presidential, .authoritarian, .theocracy:
            p += [("State of the Union: the President addresses a joint session of Congress.",
                   "The \(t.title) gives the annual address to \(t.legislature).")]
        }
        return p
    }

    /// American terms → this government's. Single pass, longest first at each position, so a replacement is never
    /// rewritten again (the Iranian "President" is the Supreme Leader's deputy, not the leader).
    var words: [(String, String)] {
        let t = terms
        var w: [(String, String)] = [
            ("Vice President", t.deputy),
            ("Mr. President", t.address), ("Madam President", t.address),
            ("White House Chief of Staff", t.chiefOfStaff), ("Chief of Staff", t.chiefOfStaff),
            ("the White House", t.seat), ("White House", t.seat), ("the Oval Office", t.seat), ("Oval Office", t.seat),
            ("the Rose Garden", t.seat), ("Capitol Hill", t.legislature), ("on the Hill", "in " + t.legislature),
            ("Joint Chiefs of Staff", t.chiefs), ("Joint Chiefs", t.chiefs),
            ("House of Representatives", t.lowerHouse), ("the House", t.lowerHouse), ("The House", t.lowerHouse),
            ("the Senate", t.upperHouse), ("The Senate", t.upperHouse), ("House", t.legislatureAdj), ("Senate", t.legislatureAdj),
            ("joint session of Congress", t.legislature), ("Congressional", t.legislatureAdj), ("congressional", t.legislatureAdj),
            ("Congress", t.legislature),
            ("the President", "the " + t.title), ("The President", "The " + t.title), ("President", t.title),
            ("Presidential", Self.capitalized(t.tenureAdj)), ("presidential", t.tenureAdj),
            ("presidencies", t.tenurePlural), ("Presidency", Self.capitalized(t.tenure)), ("presidency", t.tenure),
            ("Secretary of State", t.foreignMinister), ("Secretary of Defense", t.defenseMinister),
            ("Secretary of Homeland Security", t.spyChief), ("Director of National Intelligence", t.spyChief),
            ("Director of Central Intelligence", t.spyChief), ("CIA Director", t.spyChief), ("the CIA", t.spyService), ("CIA", t.spyService),
            ("National Security Advisor", t.securityAdviser), ("Press Secretary", t.spokesman),
            ("the Pentagon", kind == .papacy ? "the Swiss Guard" : "the defense ministry"),
            ("the State Department", kind == .papacy ? "the Secretariat of State" : "the foreign ministry"),
            ("midterms", t.hasElections ? "elections" : "the next review"), ("midterm", t.hasElections ? "election" : "review"),
            ("impeachment", removal == .impeachment ? "impeachment" : "removal"),
            ("Impeachment", removal == .impeachment ? "Impeachment" : "Removal"),
            ("impeached", removal == .impeachment ? "impeached" : "removed"),
            ("impeach", removal == .impeachment ? "impeach" : "remove"),
        ]
        // The same words in capitals (banners, card titles): "CONGRESS", "THE PRESIDENT IS DEAD".
        w += w.compactMap { from, to in from.uppercased() == from ? nil : (from.uppercased(), to.uppercased()) }
        return w
    }

    static func capitalized(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    /// This government's version of an American line. Identity for the United States.
    func localize(_ text: String) -> String {
        guard !isUS, !text.isEmpty else { return text }
        var s = text
        for (from, to) in phrases where s.contains(from) { s = s.replacingOccurrences(of: from, with: to) }
        return Self.replaceWords(s, words)
    }

    /// One pass over `text`: at each position the longest pattern that matches as whole words is replaced. A
    /// replacement that opens a sentence gets a capital. "President" before a name ("President Lincoln") or before
    /// " of" ("the President of France") is someone else's title and stays.
    static func replaceWords(_ text: String, _ pairs: [(String, String)]) -> String {
        let sorted = pairs.map { (Array($0.0), $0.1) }.sorted { $0.0.count > $1.0.count }
        let chars = Array(text)
        func isWord(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }
        var out = ""
        var i = 0
        while i < chars.count {
            var matched = false
            if i == 0 || !isWord(chars[i - 1]) {
                for (from, to) in sorted where i + from.count <= chars.count && chars[i] == from[0] {
                    guard Array(chars[i..<(i + from.count)]) == from else { continue }
                    let end = i + from.count
                    if end < chars.count, isWord(chars[end]) { continue }
                    let rest = String(chars[end..<min(chars.count, end + 4)])
                    if String(from).hasSuffix("President") || String(from).hasSuffix("House") {
                        if rest.hasPrefix(" of") { continue }
                        if rest.count >= 2, rest.first == " ", rest.dropFirst().first?.isUppercase == true,
                           String(from) == "President" || String(from) == "House" { continue }
                    }
                    // Sentence start: nothing before but spaces, or a stop, a colon, a quote or a bracket.
                    var j = i - 1
                    while j >= 0, chars[j] == " " { j -= 1 }
                    let opens = j < 0 || ".!?:\"“(—\n".contains(chars[j])
                    out += opens && to.first?.isLowercase == true ? capitalized(to) : to
                    i = end
                    matched = true
                    break
                }
            }
            if !matched { out.append(chars[i]); i += 1 }
        }
        return out
    }
}

// MARK: - Removal

extension RemovalMechanism {
    /// The line when the pressure eases.
    var dropText: String {
        switch self {
        case .impeachment: return "Congress drops its investigation of the White House."
        case .resignationPressure: return "The calls for resignation fade."
        default: return "The threat to your leadership passes."
        }
    }

    /// The cabinet's warning that removal comes at the next poll.
    var imminentText: String {
        switch self {
        case .impeachment: return "Congress will move to impeach at the next poll."
        case .noConfidence: return "A confidence vote will follow at the next poll."
        case .coup: return "The army will move against you at the next poll."
        case .revolution: return "The streets will rise against you at the next poll."
        case .partyCongress: return "The party will move to replace you at the next poll."
        case .juntaDecision: return "The junta will vote to replace you at the next poll."
        case .royalDismissal: return "The monarch will dismiss you at the next poll."
        case .council: return "The Assembly of Experts will move to remove you at the next poll."
        case .resignationPressure: return "Calls for your resignation will come to a head at the next poll."
        case .abdication: return "The government will fall at the next poll."
        }
    }

    /// The cabinet's note that the pressure is building.
    var risingText: String {
        switch self {
        case .impeachment: return "Impeachment talk is rising on the Hill."
        case .noConfidence: return "Talk of a confidence vote is rising."
        case .coup, .juntaDecision: return "Discontent in the officer corps is rising."
        case .resignationPressure: return "Concern among the cardinals is rising."
        default: return "Pressure on your leadership is rising."
        }
    }

    /// Who reads the overruled warnings into the record when the pressure moves a stage.
    var inquiryLead: String {
        switch self {
        case .impeachment: return "Impeachment hearings"
        case .noConfidence: return "In the confidence debate"
        case .resignationPressure: return "Before the College of Cardinals"
        case .council: return "Before the Assembly of Experts"
        default: return "The inquiry into the leader's conduct"
        }
    }
}

// MARK: - The game's words for the player

extension GameState {
    /// The player's government (the United States when nothing is recorded).
    var regime: Regime { shadow.regime ?? Regime.resolve(self) ?? Regime.us }

    /// An American line in the player government's words (unchanged for the United States).
    /// The player's nation as world news names it: "the United States", or the nation's own name.
    var playerNation: String { playerCountryID == "USA" ? "the United States" : (getPlayerCountry()?.name ?? playerCountryID) }
    func say(_ text: String) -> String { shadow.regime.map { $0.localize(text) } ?? text }

    /// The game-over headline for a domestic ending.
    func endingHeadline(_ e: DomesticEnding) -> String { say(e.headline) }
}

extension Regime {
    static let us = Regime(kind: .presidential, country: "USA", countryName: "United States", capital: "Washington, D.C.",
                           removal: .impeachment)
}

extension GameEngine {
    /// Keep `shadow.regime` in step with the player's nation (a new game, a loaded save, an era's change of government).
    func refreshRegime() {
        guard let gs = gameState else { return }
        let r = Regime.resolve(gs)
        if gs.shadow.regime != r { gs.shadow.regime = r }
    }
}
