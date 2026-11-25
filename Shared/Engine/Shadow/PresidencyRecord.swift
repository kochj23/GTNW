//
//  PresidencyRecord.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the record of his presidency.
//    • "I TOLD YOU SO": every warning the President overrules is kept verbatim with its date (the cabinet's advice
//      on an order, a recommendation he rejected, a danger warning he clicked past). An adviser overruled twice
//      leaks the warning to the press (approval −1.5, once per adviser); one who resigns over it quotes it in a
//      one-line statement; and when Congress moves to impeach, the overruled come back to testify, the news quoting
//      the warning and the date it was given. All of it from the record; nothing random.
//    • AWARDS: achievements for how he actually plays (removed in under five minutes, impeached on Easy, a war lost
//      to a much smaller power, the alphabet as a colonial naming scheme, nuking friends and the surrendered,
//      Antarctica every game…). Unlocked at game over from the end state, kept across games (`PresidencyCareer`,
//      local defaults like the Hall of Infamy; in GTNWCore, memory), logged as `achievement_unlocked` play events.
//    • EPILOGUE: the history books' one-paragraph verdict (a template from the record; a local AI may polish it
//      through the existing NovaAIKit path and must keep every number and name), the presidential library's name,
//      and "fifty years later": what the lands he renamed are called (his names survive where the land stayed held
//      and stable; elsewhere the old name comes back).
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - The record (saved with the game)

/// One warning the President overruled, verbatim.
struct OverruledWarning: Codable, Equatable, Identifiable {
    var id: Int
    var advisorID: String?
    /// "Pete Hegseth"; empty for a body that speaks as one (the Joint Chiefs).
    var name: String
    /// "Secretary of Defense", "the Joint Chiefs".
    var title: String
    /// Exactly what was said.
    var text: String
    var date: Date
    /// "Ground Invasion → Denmark".
    var order: String
    var testified = false

    init(id: Int, advisorID: String?, name: String, title: String, text: String, date: Date, order: String) {
        self.id = id; self.advisorID = advisorID; self.name = name; self.title = title
        self.text = text; self.date = date; self.order = order
    }

    enum CodingKeys: String, CodingKey { case id, advisorID, name, title, text, date, order, testified }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(Int.self, forKey: .id)) ?? 0
        advisorID = try? c.decodeIfPresent(String.self, forKey: .advisorID)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        text = (try? c.decodeIfPresent(String.self, forKey: .text)) ?? ""
        date = (try? c.decodeIfPresent(Date.self, forKey: .date)) ?? GameCalendar.inauguration(year: 2025)
        order = (try? c.decodeIfPresent(String.self, forKey: .order)) ?? ""
        testified = (try? c.decodeIfPresent(Bool.self, forKey: .testified)) ?? false
    }

    /// "Secretary of Defense Pete Hegseth" / "the Joint Chiefs".
    var speaker: String { name.isEmpty ? title : "\(title) \(name)" }
}

/// What this presidency did that the awards and the epilogue read. Arrays (never sets) so a save encodes the same
/// bytes every time.
struct PresidencyRecord: Codable, Equatable {
    var warnings: [OverruledWarning] = []
    var nextWarningID = 0
    /// Posts he overruled at least once (role key, or the speaker for the Joint Chiefs and the Vice President).
    var overruledPosts: [String] = []
    /// Times he took the room's advice (an approving adviser, an accepted recommendation, backing down).
    var followed = 0
    /// Presidential orders given (the advised-order path every front end uses).
    var orders = 0
    /// Advisers whose warning has reached the press.
    var leaked: [String] = []
    /// The highest impeachment stage the overruled have testified at (reset when Congress drops it).
    var testifiedStage = 0
    var friendsAttacked: [String] = []
    var friendsNuked: [String] = []
    var surrenderedNuked: [String] = []
    var microstatesNuked: [String] = []
    /// Nations that surrendered to anyone this game.
    var surrendered: [String] = []
    /// Nations that beat us in a war, and those of them much smaller than us.
    var lostTo: [String] = []
    var lostToSmaller: [String] = []
    /// Awards earned this game (set at game over).
    var awards: [String] = []
    /// Of `awards`, the ones earned for the first time.
    var firstAwards: [String] = []
    /// "72 wars, 2 wins" — the career line at game over.
    var careerLine: String?
    /// The history books' verdict as a local AI polished it (nil: the template stands).
    var verdict: String?
    var closed = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case warnings, nextWarningID, overruledPosts, followed, orders, leaked, testifiedStage, friendsAttacked
        case friendsNuked, surrenderedNuked, microstatesNuked, surrendered, lostTo, lostToSmaller, awards, firstAwards
        case careerLine, verdict, closed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func list(_ k: CodingKeys) -> [String] { (try? c.decodeIfPresent([String].self, forKey: k)) ?? [] }
        warnings = (try? c.decodeIfPresent([OverruledWarning].self, forKey: .warnings)) ?? []
        nextWarningID = (try? c.decodeIfPresent(Int.self, forKey: .nextWarningID)) ?? warnings.count
        overruledPosts = list(.overruledPosts)
        followed = (try? c.decodeIfPresent(Int.self, forKey: .followed)) ?? 0
        orders = (try? c.decodeIfPresent(Int.self, forKey: .orders)) ?? 0
        leaked = list(.leaked)
        testifiedStage = (try? c.decodeIfPresent(Int.self, forKey: .testifiedStage)) ?? 0
        friendsAttacked = list(.friendsAttacked)
        friendsNuked = list(.friendsNuked)
        surrenderedNuked = list(.surrenderedNuked)
        microstatesNuked = list(.microstatesNuked)
        surrendered = list(.surrendered)
        lostTo = list(.lostTo)
        lostToSmaller = list(.lostToSmaller)
        awards = list(.awards)
        firstAwards = list(.firstAwards)
        careerLine = try? c.decodeIfPresent(String.self, forKey: .careerLine)
        verdict = try? c.decodeIfPresent(String.self, forKey: .verdict)
        closed = (try? c.decodeIfPresent(Bool.self, forKey: .closed)) ?? false
    }

    static let maxWarnings = 80

    /// Append `id` to a list once.
    static func add(_ id: String, to list: inout [String]) { if !list.contains(id) { list.append(id) } }
}

// MARK: - "I told you so"

enum ToldYouSo {
    /// The stock first sentences of an adviser's read; the quote is what comes after.
    static let openers = ["Mr. President, I advise against it.", "I can live with this, but go in with your eyes open.",
                          "I recommend we go ahead."]
    /// A leak costs this much approval, once per adviser.
    static let leakCost = 1.5
    /// A resignation statement that quotes the warning costs this much more.
    static let resignationCost = 1.0

    /// The words worth quoting from a warning: past the stock opener, whole sentences up to about 200 characters.
    /// Always a contiguous run of the recorded text, so the quote is verbatim.
    static func quote(_ text: String) -> String {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for o in openers where body.hasPrefix(o) {
            let rest = body.dropFirst(o.count).trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { body = rest }
        }
        let chars = Array(body)
        var cut: Int?
        for i in chars.indices where ".!?".contains(chars[i]) && (i + 1 == chars.count || chars[i + 1] == " ") {
            if i + 1 > 200 { break }
            cut = i + 1
            if i + 1 >= 60 { break }
        }
        if let cut { return String(chars[0..<cut]) }
        return chars.count <= 240 ? body : String(chars[0..<200]).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// The post a warning belongs to.
    static func post(advisor: Advisor?, title: String) -> String { advisor?.roleKey ?? title }

    /// Keep an overruled warning.
    static func record(_ gs: GameState, advisor: Advisor?, name: String? = nil, title: String? = nil, text: String, order: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var r = gs.shadow.presidency
        let title = title ?? advisor?.title ?? "an adviser"
        r.warnings.append(OverruledWarning(id: r.nextWarningID, advisorID: advisor?.id, name: name ?? advisor?.name ?? "",
                                           title: title, text: String(t.prefix(600)), date: gs.currentDate, order: order))
        r.nextWarningID += 1
        if r.warnings.count > PresidencyRecord.maxWarnings { r.warnings.removeFirst(r.warnings.count - PresidencyRecord.maxWarnings) }
        PresidencyRecord.add(post(advisor: advisor, title: title), to: &r.overruledPosts)
        gs.shadow.presidency = r
    }

    /// The danger warnings (level 2) he clicked past on a major order. The Secretary of State and the Vice President
    /// are people in the cabinet; the Joint Chiefs speak as one.
    static func recordDangers(_ gs: GameState, warnings: [AdvisorWarning], order: String) {
        // 3.37.0: the warnings arrive in the regime's words ("Foreign Minister", "Deputy Prime Minister").
        let state = gs.say("Secretary of State"), deputy = gs.say("Vice President")
        for w in warnings where w.level >= 2 {
            if w.who.hasPrefix(state) {
                let a = AdviceEngine.advisor(for: "state", in: gs.advisors)
                record(gs, advisor: a, name: a?.name ?? "", title: state, text: w.text, order: order)
            } else if w.who == deputy {
                let a = gs.playerCountryID == "USA" ? gs.advisors.first { $0.isActive && $0.title.contains("Vice President") }
                    : AdviceEngine.advisor(for: "whc", in: gs.advisors)
                record(gs, advisor: a, name: a?.name ?? "", title: deputy, text: w.text, order: order)
            } else {
                record(gs, advisor: nil, name: "", title: "the \(w.who)", text: w.text, order: order)
            }
        }
    }

    /// The first warning an adviser gave and was overruled on.
    static func first(_ gs: GameState, advisorID: String) -> OverruledWarning? {
        gs.shadow.presidency.warnings.first { $0.advisorID == advisorID }
    }

    /// The resignation line: the adviser's own words back at him, when there are any on the record.
    static func resignation(_ gs: GameState, advisor a: Advisor) -> String {
        guard let w = first(gs, advisorID: a.id) else {
            return "\(a.name) has resigned as \(a.title), citing \"fundamental disagreements over policy.\""
        }
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - resignationCost)
        return "\(a.name) has resigned as \(a.title). Statement: \"On \(GameCalendar.format(w.date)) I told the President, '\(quote(w.text))' I was overruled. I will not be overruled again.\""
    }

    /// The leak: a senior official tells the press what the President was told.
    static func leakText(_ w: OverruledWarning) -> String {
        "Leak: a senior official tells the press the President was warned on \(GameCalendar.format(w.date)) by the \(w.title): \"\(quote(w.text))\""
    }

    /// The testimony when Congress moves (or the inquiry, where there is no Congress).
    static func testimonyText(_ w: OverruledWarning, gs: GameState) -> String {
        let lead = gs.playerCountryID == "USA" ? "Impeachment hearings" : (gs.shadow.regime?.removal.inquiryLead ?? "The inquiry into the leader's conduct")
        let date = GameCalendar.format(w.date)
        if w.name.isEmpty {
            return "\(lead): the warning \(w.title) gave on \(date) is read into the record: \"\(quote(w.text))\""
        }
        let former = w.advisorID.flatMap { id in gs.advisors.first { $0.id == id } }.map { !$0.isActive } ?? false
        return "\(lead): \(former ? "former " : "")\(w.speaker) testifies that on \(date) the President was told: \"\(quote(w.text))\""
    }

    /// Who testifies next: those who have left first, then the earliest warning.
    static func nextWitness(_ gs: GameState) -> OverruledWarning? {
        let open = gs.shadow.presidency.warnings.filter { !$0.testified }
        func gone(_ w: OverruledWarning) -> Bool {
            w.advisorID.flatMap { id in gs.advisors.first { $0.id == id } }.map { !$0.isActive } ?? false
        }
        return open.first(where: gone) ?? open.first
    }
}

// MARK: - Awards

struct PresidencyAward: Identifiable, Equatable {
    var id: String
    var name: String
    var description: String
    var icon: String
    /// "Common" … "Legendary" (AchievementRarity raw values).
    var rarity: String
}

/// Kept across games (local defaults on the Mac, memory in GTNWCore), like the Hall of Infamy.
struct PresidencyCareer: Codable, Equatable {
    var games = 0
    var antarcticaGames = 0
    var warsStarted = 0
    var warsWon = 0
    var awards: [String] = []

    init() {}
    enum CodingKeys: String, CodingKey { case games, antarcticaGames, warsStarted, warsWon, awards }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        games = (try? c.decodeIfPresent(Int.self, forKey: .games)) ?? 0
        antarcticaGames = (try? c.decodeIfPresent(Int.self, forKey: .antarcticaGames)) ?? 0
        warsStarted = (try? c.decodeIfPresent(Int.self, forKey: .warsStarted)) ?? 0
        warsWon = (try? c.decodeIfPresent(Int.self, forKey: .warsWon)) ?? 0
        awards = (try? c.decodeIfPresent([String].self, forKey: .awards)) ?? []
    }

    /// "72 wars, 2 wins".
    var line: String { "\(warsStarted) war\(warsStarted == 1 ? "" : "s"), \(warsWon) win\(warsWon == 1 ? "" : "s")" }

    static let defaultsKey = "GTNW.presidencyCareer"
    /// Under XCTest the career lives in a throwaway suite, never the real defaults.
    static var defaults: UserDefaults = AudioGate.underXCTest
        ? UserDefaults(suiteName: "GTNW.tests.career.\(UUID().uuidString)")! : .standard

    static func load(_ d: UserDefaults = defaults) -> PresidencyCareer {
        guard let data = d.data(forKey: defaultsKey), let c = try? JSONDecoder().decode(PresidencyCareer.self, from: data) else { return PresidencyCareer() }
        return c
    }

    static func save(_ c: PresidencyCareer, _ d: UserDefaults = defaults) {
        if let data = try? JSONEncoder().encode(c) { d.set(data, forKey: defaultsKey) }
    }
}

enum PresidencyAwards {
    static let all: [PresidencyAward] = [
        PresidencyAward(id: "removed_under_5_minutes", name: "Removed in Under Five Minutes",
                        description: "Removed from office less than five real minutes after taking it", icon: "stopwatch", rarity: "Epic"),
        PresidencyAward(id: "impeached_on_easy", name: "Impeached on Easy",
                        description: "Removed by Congress on the easiest difficulty", icon: "tortoise", rarity: "Uncommon"),
        PresidencyAward(id: "fired_by_afghanistan", name: "Fired by Afghanistan",
                        description: "Lost a war to a much smaller power", icon: "mountain.2", rarity: "Rare"),
        PresidencyAward(id: "colonized_the_alphabet", name: "Colonized the Alphabet",
                        description: "Renamed five or more lands with a single letter", icon: "textformat.abc", rarity: "Rare"),
        PresidencyAward(id: "nuked_a_friend", name: "Nuked a Friend",
                        description: "A nuclear strike on a nation whose relations with you were above 40", icon: "heart.slash", rarity: "Rare"),
        PresidencyAward(id: "nuked_the_surrendered", name: "Nuked the Surrendered",
                        description: "A nuclear strike on a nation that had already surrendered", icon: "flag.slash", rarity: "Epic"),
        PresidencyAward(id: "antarctica_again", name: "Antarctica, Again",
                        description: "Claimed Antarctica in five different games", icon: "snowflake", rarity: "Rare"),
        PresidencyAward(id: "keyboard_smash_cartographer", name: "Keyboard Smash Cartographer",
                        description: "Renamed a land with something like \"Asdfjkl\"", icon: "keyboard", rarity: "Uncommon"),
        PresidencyAward(id: "served_the_full_term", name: "Served the Full Term",
                        description: "Stayed until the term limit or chose not to run, and handed over the keys", icon: "key", rarity: "Rare"),
        PresidencyAward(id: "many_wars_few_wins", name: "Many Wars, Few Wins",
                        description: "Ten or more wars started across your games, and no more than one won in ten", icon: "chart.line.downtrend.xyaxis", rarity: "Uncommon"),
        PresidencyAward(id: "zero_orders_removed", name: "Gave Zero Orders and Still Got Removed",
                        description: "Removed from office without giving a single order", icon: "hand.raised.slash", rarity: "Epic"),
        PresidencyAward(id: "ignored_whole_cabinet", name: "Ignored the Whole Cabinet",
                        description: "Overruled four or more posts in one game and never once took their advice", icon: "person.3", rarity: "Rare"),
        // The same spirit, from Nova's game reports.
        PresidencyAward(id: "friendly_fire", name: "With Friends Like These",
                        description: "Attacked a nation whose relations with you were above 40", icon: "person.2.slash", rarity: "Uncommon"),
        PresidencyAward(id: "overkill", name: "Overkill",
                        description: "A nuclear strike on a nation of under a million people", icon: "scope", rarity: "Rare"),
        PresidencyAward(id: "museum_docent", name: "Ran It Like a Museum",
                        description: "Served the full term without giving a single order", icon: "building.columns", rarity: "Epic"),
        PresidencyAward(id: "cartographer_general", name: "Cartographer General",
                        description: "Renamed ten or more lands in one game", icon: "map", rarity: "Uncommon"),
    ]

    static func award(_ id: String) -> PresidencyAward? { all.first { $0.id == id } }

    /// Ways out of office that count as being removed.
    static let removals: Set<DomesticEnding> = [.impeached, .noConfidence, .coup, .revolution, .partyCongress, .juntaDecision, .royalDismissal,
                                                .removedByCouncil, .resigned, .abdicated]

    static func isSingleLetter(_ name: String) -> Bool {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return t.count == 1 && (t.first?.isLetter ?? false)
    }

    /// "Asdfgh", "Qwerty", "Fjdksl", "Xkcdq": a run of five along a keyboard row, five consonants in a row, or no
    /// vowels at all in five letters or more. Real names ("Strength", "Rhythm", "Kyrgyzstan") are not smashes.
    static func isKeyboardSmash(_ name: String) -> Bool {
        let letters = name.lowercased().filter { $0.isASCII && $0.isLetter }
        guard letters.count >= 4 else { return false }
        let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        for row in rows {
            let r = Array(row)
            for i in 0...(r.count - 5) {
                let run = String(r[i..<(i + 5)])
                if letters.contains(run) || letters.contains(String(run.reversed())) { return true }
            }
        }
        let vowels = Set("aeiouy")
        if letters.count >= 5 && !letters.contains(where: vowels.contains) { return true }
        var run = 0
        for ch in letters {
            run = vowels.contains(ch) ? 0 : run + 1
            if run >= 5 { return true }
        }
        return false
    }

    /// The awards this game earned, given the career as it stands after this game is added to it. `realSeconds`
    /// is the wall-clock length of a game played start to finish in one sitting (nil otherwise).
    static func earned(_ gs: GameState, career: PresidencyCareer, realSeconds: Double?) -> [String] {
        let r = gs.shadow.presidency
        let ending = gs.shadow.domesticEnding
        let removed = ending.map(removals.contains) ?? false
        let servedOut = ending?.servedOut ?? false
        let me = gs.playerCountryID
        let nukes = gs.nuclearStrikes.contains { $0.attacker == me }
        let renamed = Set(gs.shadow.renames.map(\.land))
        let noOrders = r.orders == 0 && gs.shadow.renames.isEmpty && gs.shadow.claimDates.isEmpty
            && gs.shadow.playerWarsStarted == 0 && !nukes
        var out: [String] = []
        func give(_ id: String, _ ok: Bool) { if ok { out.append(id) } }
        give("removed_under_5_minutes", removed && (realSeconds.map { $0 < 300 } ?? false))
        give("impeached_on_easy", ending == .impeached && gs.difficultyLevel == .easy)
        give("fired_by_afghanistan", !r.lostToSmaller.isEmpty)
        give("colonized_the_alphabet", Set(gs.shadow.renames.filter { isSingleLetter($0.to) }.map(\.land)).count >= 5)
        give("nuked_a_friend", !r.friendsNuked.isEmpty)
        give("nuked_the_surrendered", !r.surrenderedNuked.isEmpty)
        give("antarctica_again", career.antarcticaGames >= 5)
        give("keyboard_smash_cartographer", gs.shadow.renames.contains { isKeyboardSmash($0.to) })
        give("served_the_full_term", servedOut)
        give("many_wars_few_wins", career.warsStarted >= 10 && career.warsWon * 10 <= career.warsStarted)
        give("zero_orders_removed", removed && noOrders)
        give("ignored_whole_cabinet", r.overruledPosts.count >= 4 && r.followed == 0)
        give("friendly_fire", !r.friendsAttacked.isEmpty)
        give("overkill", !r.microstatesNuked.isEmpty)
        give("museum_docent", servedOut && noOrders)
        give("cartographer_general", renamed.count >= 10)
        return out
    }

    /// Did this game claim Antarctica?
    static func claimedAntarctica(_ gs: GameState) -> Bool {
        gs.shadow.claimDates[Antarctica.id] != nil || gs.getCountry(id: Antarctica.id)?.territoryOf == gs.playerCountryID
    }

    /// Add this game to the career and return the updated career.
    static func adding(_ gs: GameState, to c: PresidencyCareer) -> PresidencyCareer {
        var c = c
        c.games += 1
        if claimedAntarctica(gs) { c.antarcticaGames += 1 }
        c.warsStarted += gs.shadow.playerWarsStarted
        c.warsWon += gs.warsWon
        return c
    }
}

// MARK: - Epilogue

enum PresidencyEpilogue {
    /// The AI polish for the verdict (template → paragraph, nil on failure). The app wires it; tests inject fakes.
    static var polisher: ((String) async -> String?)?

    static let polishSystemPrompt = """
        You write one paragraph of a school history textbook about a fictional presidency in a strategy game. \
        Rewrite the facts you are given as ONE paragraph of at most 130 words in a measured historian's voice with a \
        dry edge. Keep every name, date and number exactly as given; add no new facts, names or numbers. No headings, \
        no lists, no emoji, no hashtags.
        """

    /// The leader's name: the president for the United States, the head of government elsewhere.
    static func leaderName(_ gs: GameState) -> String {
        if gs.playerCountryID == "USA", let p = PlaySummary.president(gs) { return p }
        // 3.37.0: a pope is never given a real name in this game; others fall back to their own title.
        if gs.shadow.regime?.kind == .papacy { return "The Pope" }
        if let n = gs.shadow.playerLeader, !n.isEmpty { return n }
        if let c = gs.getPlayerCountry() {
            let h = NationModel.leader(for: c, on: gs.startDate)
            if !h.generic { return h.name }
        }
        return gs.shadow.regime?.leaderFallback ?? "The President"
    }

    /// A name the President chose, if it may be shown (a name that breaks the content rules never is).
    static func shown(_ name: String) -> String? {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty || ChatSafety.violates(t) ? nil : t
    }

    static func endingClause(_ gs: GameState, victory: VictoryType?) -> String {
        if let e = gs.shadow.domesticEnding {
            switch e {
            case .impeached: return "and was removed from office by Congress"
            case .noConfidence: return "and fell to a vote of no confidence"
            case .coup: return "and was overthrown by the army"
            case .revolution: return "and was swept away by revolution"
            case .partyCongress: return "and was removed by the party"
            case .juntaDecision: return "and was replaced by the junta"
            case .royalDismissal: return "and was dismissed by the monarch"
            case .assassinated: return "and was assassinated in office"
            case .civilWar: return "and left the country in civil war"
            case .lostElection: return "and lost the election"
            case .termLimited, .retired: return "and served the full term"
            case .deniedRenomination: return "and was denied renomination by the party"
            case .ruleExtended: return "and stayed in power without an election"
            case .removedByCouncil: return "and was removed by the Assembly of Experts"
            case .resigned: return "and resigned the papacy under mounting pressure"
            case .abdicated: return "and abdicated when the government fell"
            }
        }
        if let v = victory { return "and left office in victory (\(v.rawValue.lowercased()))" }
        if gs.getPlayerCountry()?.isDestroyed ?? false { return "and presided over the nation's destruction" }
        return "until the end came"
    }

    /// The history books' paragraph, from the record alone.
    static func verdictTemplate(_ gs: GameState, victory: VictoryType?) -> String {
        let r = gs.shadow.presidency
        let me = gs.playerCountryID
        let name = { (id: String) in gs.getCountry(id: id)?.name ?? WorldCountriesDatabase.template(id: id)?.name ?? id }
        let country = gs.getPlayerCountry()?.name ?? me
        let start = GameCalendar.year(of: gs.startDate), end = gs.currentYear
        var s: [String] = []
        let years = start == end ? "in \(start)" : "from \(start) to \(end)"
        var opening = "\(leaderName(gs)) led \(country) \(years) \(endingClause(gs, victory: victory))"
        if gs.turn <= 3 && (gs.shadow.domesticEnding.map(PresidencyAwards.removals.contains) ?? false) {
            opening += " after \(gs.turn) turn\(gs.turn == 1 ? "" : "s"), one of the shortest tenures on record"
        }
        s.append(opening + ".")
        let wars = gs.shadow.playerWarsStarted
        if wars > 0 {
            s.append("\(governmentNoun(gs)) started \(wars) war\(wars == 1 ? "" : "s") and won \(gs.warsWon).")
        }
        if let v = r.lostToSmaller.first {
            s.append("It lost a war to \(name(v)), a far smaller power.")
        }
        let strikes = gs.nuclearStrikes.filter { $0.attacker == me }.count
        if strikes > 0 {
            var line = "It ordered \(strikes) nuclear strike\(strikes == 1 ? "" : "s")"
            if let f = r.friendsNuked.first { line += ", one of them on \(name(f)), then a friend" }
            if let x = r.surrenderedNuked.first { line += ", and one on \(name(x)), which had already surrendered" }
            s.append(line + ".")
        }
        if r.friendsNuked.isEmpty, let f = r.friendsAttacked.first {
            s.append("It turned its guns on \(name(f)), a friend at the time.")
        }
        let renamed = Set(gs.shadow.renames.map(\.land)).count
        if renamed > 0 {
            let letters = Set(gs.shadow.renames.filter { PresidencyAwards.isSingleLetter($0.to) }.map(\.land)).count
            s.append("It renamed \(renamed) land\(renamed == 1 ? "" : "s")\(letters >= 2 ? ", \(letters) of them with a single letter" : "").")
        }
        if PresidencyAwards.claimedAntarctica(gs) { s.append("It planted a flag on Antarctica.") }
        let overruled = r.warnings.count
        if overruled > 0 {
            let resigned = gs.advisors.filter { $0.status == .resigned }.count
            var line = "It overruled its own cabinet \(overruled) time\(overruled == 1 ? "" : "s")"
            if resigned > 0 { line += "; \(resigned) adviser\(resigned == 1 ? "" : "s") resigned" }
            if let w = r.warnings.first {
                line += ", and the warning \(w.speaker) gave on \(GameCalendar.format(w.date)), \"\(ToldYouSo.quote(w.text))\", is now quoted in every textbook"
            }
            s.append(line + ".")
        } else if r.orders == 0 && wars == 0 && strikes == 0 {
            s.append("It gave no orders at all.")
        }
        s.append("Approval stood at \(Int(gs.shadow.popularity.rounded()))% at the end.")
        s.append(closing(gs, victory: victory, strikes: strikes))
        return s.joined(separator: " ")
    }

    /// "The administration" (the United States), "The Holy See", or "The government".
    static func governmentNoun(_ gs: GameState) -> String {
        gs.playerCountryID == "USA" ? "The administration" : (gs.shadow.regime?.kind == .papacy ? "The Holy See" : "The government")
    }

    static func closing(_ gs: GameState, victory: VictoryType?, strikes: Int) -> String {
        let removed = gs.shadow.domesticEnding.map(PresidencyAwards.removals.contains) ?? false
        let pool: [String]
        if gs.shadow.regime?.kind == .papacy {
            // 3.37.0: measured about the office; the judgment is on the decisions.
            pool = strikes > 0 || removed || gs.shadow.presidency.friendsAttacked.count > 0
                ? ["Historians record it as a sharp break with the Holy See's long tradition of neutrality.",
                   "Historians treat it as a turbulent chapter, judged by its decisions."]
                : ["Historians give it a short, respectful chapter.", "Historians record it as a quiet pontificate."]
        } else if strikes > 0 || removed || gs.shadow.presidency.friendsAttacked.count > 0 {
            pool = ["Historians rank it near the bottom, just above the ones nobody remembers.",
                    "Historians still argue about it, mostly over which chapter it belongs in.",
                    "Historians are unanimous, which is rarely good news."]
        } else if victory != nil || (gs.shadow.domesticEnding?.servedOut ?? false) {
            pool = ["Historians rank it among the steadier presidencies of its age.",
                    "Historians call it uneventful, which in this line of work is a compliment.",
                    "Historians give it a respectable grade and a short chapter."]
        } else {
            pool = ["Historians give it a footnote and move on.", "Historians file it under \"could have been worse.\""]
        }
        return pool[NovaCommentary.stableHash("\(gs.rng.seed)\(gs.turn)") % pool.count]
    }

    /// The verdict shown: the polished one if a local AI gave one that kept to the facts, else the template.
    static func verdict(_ gs: GameState, victory: VictoryType?) -> String {
        gs.say(gs.shadow.presidency.verdict ?? verdictTemplate(gs, victory: victory))   // 3.37.0: the regime's words
    }

    /// A polished paragraph, or nil when it can't be trusted: a reasoning scratchpad, a link or markup, a content
    /// rule broken, or any number or name the template did not have.
    static func cleanPolish(_ reply: String, template: String) -> String? {
        guard let text = AIOutputSanitizer.clean(reply), !NovaCommentary.isReasoning(text) else { return nil }
        let t = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        guard (60...1200).contains(t.count), !t.contains("http"), !t.contains("@"), !t.contains("<"),
              !ChatSafety.violates(t), grounded(t, in: template) else { return nil }
        return t
    }

    /// Words a historian may open a sentence with that are not names.
    static let plainCapitals: Set<String> = ["The", "It", "Its", "In", "A", "An", "This", "That", "These", "Those", "After",
                                             "When", "During", "As", "By", "With", "Under", "Over", "Few", "Historians",
                                             "History", "Yet", "But", "And", "Still", "Even", "Approval", "Textbooks"]

    /// Every number in `text` is one of the template's, and every capitalized word is in the template (or a plain
    /// sentence opener): nothing invented.
    static func grounded(_ text: String, in template: String) -> Bool {
        let known = Set(ChatGrounding.numbers(in: template))
        guard ChatGrounding.numbers(in: text).allSatisfy(known.contains) else { return false }
        let words = Set(template.split { !$0.isLetter && $0 != "'" }.map(String.init))
        for w in text.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        where w.first?.isUppercase ?? false {
            if !words.contains(w) && !plainCapitals.contains(w) { return false }
        }
        return true
    }

    /// The presidential library: the leader's name, and where it stands — the newest land he renamed and still
    /// holds (by his name for it), or the capital.
    static func library(_ gs: GameState) -> String {
        let leader = leaderName(gs)
        let country = gs.getPlayerCountry()
        if gs.shadow.regime?.kind == .papacy {   // 3.37.0: the Holy See keeps its papers in its own archive
            return "The papers of the pontificate, in the Vatican Apostolic Archive"
        }
        let kind = gs.playerCountryID == "USA" ? "Presidential Library" : "State Library"
        let countryName = country?.name ?? gs.playerCountryID
        let held = gs.nameBook.first { gs.isHeldByPlayer($0.land) }
        if let n = held, let current = shown(n.current) {
            let original = shown(n.original) ?? "a land with an older name"
            let tie = gs.isPuppet(n.land) ? "whose government \(countryName) installed" : "a territory of \(countryName)"
            return "The \(leader) \(kind), \(current) (formerly \(original)), \(tie)"
        }
        return "The \(leader) \(kind), \(country?.capital ?? countryName), \(countryName)"
    }

    /// 3.37.0: the lands held abroad at the end, from the one definition (HeldLands.swift): "4 lands held abroad:
    /// 3 territories and 1 government installed (Cuba)." Nil when none.
    static func landsHeld(_ gs: GameState) -> String? {
        let held = gs.heldLands
        guard !held.isEmpty else { return nil }
        let puppets = held.filter { gs.isPuppet($0.id) }
        let territories = held.count - puppets.count
        var parts: [String] = []
        if territories > 0 { parts.append("\(territories) territor\(territories == 1 ? "y" : "ies")") }
        if !puppets.isEmpty {
            let names = puppets.prefix(4).map(\.name).joined(separator: ", ") + (puppets.count > 4 ? " and \(puppets.count - 4) more" : "")
            parts.append("\(puppets.count) government\(puppets.count == 1 ? "" : "s") installed (\(names))")
        }
        return "\(held.count) land\(held.count == 1 ? "" : "s") held abroad: " + parts.joined(separator: " and ") + "."
    }

    /// One land's name fifty years on.
    struct Afterlife: Identifiable, Equatable {
        var id: String { land }
        var land: String
        var hisName: String
        var original: String
        var survives: Bool
        var line: String
    }

    /// Fifty years later: his names survive where the land is still held and stable (stability 40 or more); elsewhere
    /// the original name comes back. A name that may not be shown never survives. Newest renames first, at most 12.
    static func fiftyYearsLater(_ gs: GameState) -> [Afterlife] {
        gs.nameBook.prefix(12).map { n in
            let c = gs.getCountry(id: n.land)
            let original = shown(n.original) ?? "its old name"
            let his = shown(n.current)
            let held = gs.isHeldByPlayer(n.land)
            let stable = (c?.stability ?? 0) >= 40
            let h = NovaCommentary.stableHash(n.land + n.current)
            if let his, held, stable {
                let tails = ["Schoolchildren no longer ask why.", "The maps never changed back.",
                             "The locals have made their peace with it.", "It is on the stamps."]
                return Afterlife(land: n.land, hisName: his, original: original, survives: true,
                                 line: "\(his) is still \(his). \(tails[h % tails.count])")
            }
            let why: String
            if c?.isDestroyed ?? false { why = "Nobody lives there to call it anything; the atlases say \(original)." }
            else if his == nil { why = "The name he gave it was struck from the record. It is \(original)." }
            else if !held { why = "It went back to being \(original) the week the flag came down." }
            else { why = "It is \(original) again; the unrest outlasted the signs." }
            return Afterlife(land: n.land, hisName: his ?? "(struck from the record)", original: original, survives: false, line: why)
        }
    }
}

// MARK: - Engine hooks

extension GameEngine {
    /// A presidential order given on the advised path: count it, and note a hostile order on a friend and a strike
    /// on a friend, the surrendered or a microstate. `relationBefore` is our relation with the target before the order.
    func notePresidentialOrder(_ action: PresidentialAction, targetID: String, relationBefore: Int) {
        guard let gs = gameState else { return }
        gs.shadow.presidency.orders += 1
        if action.isHostile && relationBefore > 40 { PresidencyRecord.add(targetID, to: &gs.shadow.presidency.friendsAttacked) }
        if action.rung == .nuclear && action.isHostile && action != .nuclearTest {
            notePlayerNuke(targetID: targetID, relation: relationBefore)
        }
    }

    /// A nuclear strike by the player, whichever screen ordered it.
    func notePlayerNuke(targetID: String, relation: Int) {
        guard let gs = gameState else { return }
        var r = gs.shadow.presidency
        if relation > 40 { PresidencyRecord.add(targetID, to: &r.friendsNuked) }
        let surrendered = r.surrendered.contains(targetID) || gs.shadow.pendingSettlements.contains { $0.loser == targetID }
            || gs.shadow.peaceTerms.contains { $0.loser == targetID }
        if surrendered { PresidencyRecord.add(targetID, to: &r.surrenderedNuked) }
        if let t = gs.getCountry(id: targetID), t.population < 1 { PresidencyRecord.add(targetID, to: &r.microstatesNuked) }
        gs.shadow.presidency = r
    }

    /// The player declared war: on a friend?
    func notePlayerWar(on defender: String) {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return }
        if (me.diplomaticRelations[defender] ?? 0) > 40 { PresidencyRecord.add(defender, to: &gs.shadow.presidency.friendsAttacked) }
    }

    /// A front ended: who surrendered, and whether we lost (and to how small a power).
    func noteFrontResolved(_ f: WarFront, verdict: FrontStatus) {
        guard let gs = gameState else { return }
        let me = gs.playerCountryID
        var r = gs.shadow.presidency
        if verdict == .attackerWon { PresidencyRecord.add(f.defender, to: &r.surrendered) }
        var victor: String?
        if verdict == .attackerWon && (f.defender == me || (f.usSide == f.defender && f.attacker != me)) { victor = f.attacker }
        if verdict == .defenderWon && (f.attacker == me || (f.usSide == f.attacker && f.defender != me)) { victor = f.defender }
        if let v = victor {
            PresidencyRecord.add(v, to: &r.lostTo)
            if let us = gs.getPlayerCountry(), let them = gs.getCountry(id: v), Self.muchSmaller(them, than: us) {
                PresidencyRecord.add(v, to: &r.lostToSmaller)
            }
        }
        gs.shadow.presidency = r
    }

    /// A fifth of our economy or less, and a weaker military.
    static func muchSmaller(_ a: Country, than b: Country) -> Bool {
        a.gdp * 5 <= b.gdp && a.militaryStrength < b.militaryStrength
    }

    /// Each turn: an adviser overruled twice leaks the warning to the press; when Congress moves a stage, the
    /// overruled testify. Deterministic: the record decides who and when.
    func processPresidencyRecord() {
        guard let gs = gameState else { return }
        // Leaks.
        for a in gs.advisors where (gs.shadow.advisorGrievances[a.id] ?? 0) >= 2 && !gs.shadow.presidency.leaked.contains(a.id) {
            guard let w = ToldYouSo.first(gs, advisorID: a.id) else { continue }
            gs.shadow.presidency.leaked.append(a.id)
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - ToldYouSo.leakCost)
            let text = ToldYouSo.leakText(w)
            gs.shadow.post(text, date: gs.currentDate, severity: 2)
            logPlayEvent("advisor_leak", detail: ["advisor": PlayHistory.text(w.speaker), "warning": PlayHistory.text(w.text),
                                                  "warned_on": PlayHistory.day(w.date), "game_date": PlayHistory.day(gs.currentDate)])
        }
        // Testimony.
        let removed = gs.shadow.domesticEnding == .impeached
        let stage = removed ? 4 : gs.shadow.impeachmentStage
        if stage == 0 { gs.shadow.presidency.testifiedStage = 0 }
        if stage > gs.shadow.presidency.testifiedStage {
            gs.shadow.presidency.testifiedStage = stage
            if let w = ToldYouSo.nextWitness(gs), let i = gs.shadow.presidency.warnings.firstIndex(where: { $0.id == w.id }) {
                gs.shadow.presidency.warnings[i].testified = true
                let text = ToldYouSo.testimonyText(w, gs: gs)
                gs.shadow.post(text, date: gs.currentDate, severity: 2)
                addLog("🏛️ \(text)", type: .warning)
                logPlayEvent("advisor_testified", detail: ["advisor": PlayHistory.text(w.speaker), "warning": PlayHistory.text(w.text),
                                                       "warned_on": PlayHistory.day(w.date), "order": PlayHistory.text(w.order),
                                                       "stage": stage, "game_date": PlayHistory.day(gs.currentDate)])
            }
        }
        self.gameState = gs
    }

    /// Game over: the awards, the career, the play events, and (when a local AI is wired) the polished verdict.
    /// Once per game; never for a watch game or multiplayer.
    func closePresidencyRecord(_ gs: GameState, victory: VictoryType?, now: Date = Date()) {
        guard !gs.shadow.presidency.closed, !spectating, !gs.isMultiplayer else { return }
        gs.shadow.presidency.closed = true
        var realSeconds: Double?
        #if !GTNW_CORE
        // Wall-clock only for a game played from its first turn in this sitting; GTNWCore never reads the clock here.
        if let t = playSession, t.game === gs, t.startTurn == 0, t.resumedFromTurn == nil { realSeconds = now.timeIntervalSince(t.startedAt) }
        #endif
        let before = PresidencyCareer.load()
        var career = PresidencyAwards.adding(gs, to: before)
        let earned = PresidencyAwards.earned(gs, career: career, realSeconds: realSeconds)
        let first = earned.filter { !before.awards.contains($0) }
        career.awards += first
        PresidencyCareer.save(career)
        gs.shadow.presidency.awards = earned
        gs.shadow.presidency.firstAwards = first
        gs.shadow.presidency.careerLine = career.line
        for id in earned {
            guard let a = PresidencyAwards.award(id) else { continue }
            logPlayEvent("achievement_unlocked", detail: ["id": id, "name": a.name, "description": PlayHistory.text(a.description),
                                                          "first_time": first.contains(id), "career": career.line,
                                                          "game_date": PlayHistory.day(gs.currentDate)])
            if first.contains(id) { addLog("🏅 Award: \(a.name) — \(a.description).", type: .info) }
        }
        let template = PresidencyEpilogue.verdictTemplate(gs, victory: victory)
        logPlayEvent("history_verdict", detail: ["text": PlayHistory.text(gs.say(template)), "library": PlayHistory.text(PresidencyEpilogue.library(gs))])
        #if !GTNW_CORE
        for id in first { store?.unlockAchievement(id) }
        if !first.isEmpty && !AudioGate.underXCTest { Task { @MainActor in AchievementEngine.shared.reload() } }
        #endif
        self.gameState = gs
        // 3.37.0: no AI-written text about a religious office; the template stands.
        guard let polish = PresidencyEpilogue.polisher, ![.papacy, .theocracy].contains(gs.shadow.regime?.kind) else { return }
        let prompt = "Facts (keep every one, add none):\n" + template
        Task { @MainActor in
            guard let reply = await polish(prompt), let text = PresidencyEpilogue.cleanPolish(reply, template: template),
                  let g = self.gameState, g === gs else { return }
            g.shadow.presidency.verdict = text
            self.gameState = g
        }
    }
}
