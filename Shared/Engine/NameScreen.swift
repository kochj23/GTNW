//
//  NameScreen.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the content check on every name the President gives a land or a nation (the Situation Room's rename
//  sheet, the command box, the chief of staff, a saved group). Pure and deterministic, part of GTNWCore.
//
//  - Shape: 1–40 characters on one line (the 3.3.0 rule).
//  - Content: slurs, hate terms, sexual terms, mockery of a faith and hostility toward a people are refused with one
//    neutral line. The chat's own screen (`ChatSafety`) runs first, so a name the chief of staff could not say is never
//    put on the map; on top of it, names are taken apart the way people build them: "RacismLand" → racism + land,
//    "Newxland" → new + x + land, and the letters with the spaces taken out ("N a z i").
//  - Crude jokes and gibberish stay allowed ("ShitGibbon", "asdfasdf"); `tone` sorts them for the people's reaction.
//
//  Slurs stay as hashes in `ChatSafety.blockedHashes`; the extra lists here hold no slurs.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// What the screen says about a proposed name.
enum NameVerdict: Equatable, Sendable {
    /// The name as it will be stored (trimmed).
    case ok(String)
    /// Wrong shape (empty, too long, more than one line).
    case invalid(String)
    /// Refused for its content; the reason is neutral and never repeats the name.
    case blocked(String)

    var name: String? { if case .ok(let n) = self { return n }; return nil }
    var reason: String? {
        switch self {
        case .ok: return nil
        case .invalid(let r), .blocked(let r): return r
        }
    }
}

/// How a name lands with the people who have to live under it.
enum NameTone: Int, Comparable, Sendable {
    case dignified, silly, mocking
    static func < (a: NameTone, b: NameTone) -> Bool { a.rawValue < b.rawValue }
    var label: String {
        switch self {
        case .dignified: return "dignified"
        case .silly: return "silly"
        case .mocking: return "mocking"
        }
    }
}

enum NameScreen {
    static let maxLength = 40
    static let shapeReason = "Use 1–\(maxLength) characters on one line."
    static let blockedReason = "That name can't go on the map. Choose another."

    // MARK: Check

    static func check(_ raw: String) -> NameVerdict {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= maxLength,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0) })
        else { return .invalid(shapeReason) }
        return isBlocked(name) ? .blocked(blockedReason) : .ok(name)
    }

    /// The name as it may be shown: itself, or `fallback` (the land's real name) when it breaks the rules (an old save).
    static func shown(_ name: String, fallback: String) -> String { isBlocked(name) ? fallback : name }

    /// Does the name break the content rules? A real place name (a country or island on the modern map) never does.
    static func isBlocked(_ name: String) -> Bool {
        if CommandTargets.modernNames[CommandParser.normalize(name)] != nil { return false }
        if ChatSafety.scrubHosts(name) != name { return true }   // no addresses on the map
        let parts = pieces(name)
        if ChatSafety.violates(name) || ChatSafety.violates(parts.joined(separator: " ")) { return true }
        let run = parts.joined()
        let words = parts.count > 1 ? parts + [run] : parts   // "N a z i" is read as one word too
        let stems = words.flatMap(stemsOf)
        let all = Set(words + stems.map(\.stem))
        // A blocked word, a hate term or a sexual term, as a word or the stem of one ("racismland").
        for w in all where blocked(w) { return true }
        // Inside the letters run together ("xxracistyy"): long, unambiguous stems only.
        if longStems.contains(where: { run.contains($0) }) { return true }
        if hashedSubstring(run) { return true }
        // Mocking a faith, or hostility toward a people.
        let crude = crudeWords.union(ChatSafety.mockery)
        let hostile = crude.union(ChatSafety.sweeping).union(negation)
        let faithHit = all.contains { faithWords.contains($0) } || faithStems.contains { run.contains($0) }
        if faithHit && (all.contains { crude.contains($0) || sexualWords.contains($0) } || crudeStems.contains { run.contains($0) }) { return true }
        let groupHit = all.contains { groupWords.contains($0) }
        if groupHit && (all.contains { hostile.contains($0) } || stems.contains { groupWords.contains($0.stem) && negation.contains($0.affix) }) {
            return true
        }
        return false
    }

    /// Dignified, silly (gibberish, shouting, symbols) or mocking (crude words, insults).
    static func tone(_ name: String) -> NameTone {
        let parts = pieces(name)
        let all = Set(parts + parts.flatMap(stemsOf).map(\.stem))
        let run = parts.joined()
        if all.contains(where: { crudeWords.contains($0) || ChatSafety.mockery.contains($0) }) || crudeStems.contains(where: { run.contains($0) }) {
            return .mocking
        }
        let letters = name.filter(\.isLetter)
        if letters.count < max(1, name.filter { !$0.isWhitespace }.count / 2) { return .silly }   // mostly symbols or digits
        if parts.contains(where: gibberish) { return .silly }
        if letters.count >= 6, letters.allSatisfy({ $0.isUppercase }), name.contains(where: \.isLetter) { return .silly }
        return .dignified
    }

    // MARK: Pieces

    /// Folded lowercase words, camel case split ("ShitGibbon" → shit, gibbon; "USAland" → usa, land).
    static func pieces(_ name: String) -> [String] {
        var out: [String] = []
        var cur = ""
        var prev: Character?
        func flush() {
            let f = ChatWords.folded(cur.lowercased())
            if !f.isEmpty { out.append(f) }
            cur = ""
        }
        let chars = Array(name)
        for (i, ch) in chars.enumerated() {
            guard ch.isLetter || ch.isNumber else { flush(); prev = nil; continue }
            if let p = prev, ch.isUppercase, p.isLowercase { flush() }
            // "USAland": an upper run followed by upper+lower splits before the last upper ("USA", "Land").
            if let p = prev, p.isUppercase, ch.isUppercase, i + 1 < chars.count, chars[i + 1].isLowercase, cur.count > 1 { flush() }
            cur.append(ch)
            prev = ch
        }
        flush()
        return out
    }

    struct Stem: Equatable { var stem: String; var affix: String }

    /// What is left of a word once place-name endings and beginnings are taken off ("racismland" → racism,
    /// "newjapstan" → jap; "jewfree" → jew with the affix "free").
    static func stemsOf(_ w: String) -> [Stem] {
        var out: [Stem] = []
        var starts = [(w, "")]
        for p in prefixes where w.hasPrefix(p) && w.count >= p.count + 3 { starts.append((String(w.dropFirst(p.count)), p)) }
        for (s, p) in starts {
            if !p.isEmpty { out.append(Stem(stem: s, affix: p)) }
            for x in suffixes where s.hasSuffix(x) && s.count >= x.count + 3 {
                out.append(Stem(stem: String(s.dropLast(x.count)), affix: x))
            }
        }
        return out
    }

    private static func blocked(_ w: String) -> Bool {
        ChatSafety.blockedHashes.contains(ChatWords.fnv1a(w)) || hateWords.contains(w) || sexualWords.contains(w) || ChatSafety.methods.contains(w)
    }

    /// A blocked word of six letters or more anywhere in the run of letters (shorter ones are too often inside an
    /// innocent name: they are matched as words and stems only).
    private static func hashedSubstring(_ run: String) -> Bool {
        let a = Array(run)
        guard a.count >= 6 else { return false }
        for i in 0..<(a.count - 5) {
            for len in 6...min(14, a.count - i) where ChatSafety.blockedHashes.contains(ChatWords.fnv1a(String(a[i..<(i + len)]))) { return true }
        }
        return false
    }

    /// Gibberish: a long word with no vowel, a run of five consonants, a keyboard row, one letter four times running.
    static func gibberish(_ w: String) -> Bool {
        guard w.count >= 4 else { return false }
        let vowels = Set("aeiouy")
        if !w.contains(where: { vowels.contains($0) }) { return true }
        if ["asdf", "sdfg", "qwer", "wert", "zxcv", "hjkl", "jkl", "uiop", "fdsa", "rewq"].contains(where: { w.contains($0) }) { return true }
        var run = 0, same = 1
        var last: Character?
        for ch in w {
            run = vowels.contains(ch) || ch.isNumber ? 0 : run + 1
            same = ch == last ? same + 1 : 1
            last = ch
            if run >= 5 || same >= 4 { return true }
        }
        return false
    }

    // MARK: Lists

    static let prefixes = ["new", "north", "south", "east", "west", "great", "greater", "little", "upper", "lower", "fort", "port",
                           "san", "saint", "st", "nova", "neo", "anti", "united", "republicof", "kingdomof"]
    static let suffixes = ["land", "lands", "stan", "istan", "ia", "ania", "ville", "town", "burg", "berg", "topia", "opolis",
                           "polis", "city", "ton", "island", "islands", "isle", "shire", "dom", "free", "less", "haters",
                           "hater", "killer", "killers", "ers", "er", "s"]
    static let hateWords: Set<String> = [
        "racism", "racist", "racists", "nazi", "nazis", "neonazi", "hitler", "hitlers", "kkk", "klan", "klux", "aryan", "aryans",
        "holocaust", "genocide", "genocidal", "apartheid", "supremacist", "supremacists", "whitepower", "infidel", "infidels",
        "heathen", "heathens", "lynching", "pogrom", "reich", "gestapo", "ss", "jihadi", "jihadis",
    ]
    static let longStems = ["racis", "neonazi", "hitler", "holocaust", "genocid", "whitepower", "kukluxklan", "supremacis",
                            "ethniccleans", "thirdreich", "fourthreich", "heilhitler", "siegheil", "gaschamber", "porno", "blowjob",
                            "handjob", "dildo", "orgasm", "hentai", "masturb", "ejacul", "genital", "testicl", "scrotum", "vagina",
                            "nipple", "erotic", "titties", "boobies", "naziland", "nazistan"]
    static let sexualWords: Set<String> = [
        "sex", "sexy", "sexx", "porn", "porno", "xxx", "nude", "nudes", "naked", "nsfw", "anal", "cum", "boob", "boobs", "tits",
        "titty", "penis", "vagina", "dildo", "orgy", "orgies", "orgasm", "horny", "erection", "boner", "milf", "hentai", "nipple",
        "nipples", "genitals", "testicles", "scrotum", "clit", "labia", "brothel", "hooker", "hookers", "stripper", "strippers",
        "kinky", "fetish", "bdsm", "incest",
    ]
    static let crudeWords: Set<String> = [
        "shit", "shitty", "crap", "crappy", "poop", "poo", "fart", "farts", "butt", "butts", "turd", "turds", "piss", "pee", "puke",
        "vomit", "toilet", "booger", "boogers", "garbage", "trash", "loser", "losers", "suck", "sucks", "stink", "stinky", "smelly",
        "lol", "lmao", "rofl", "clown", "clowns", "dung", "sewer", "landfill", "dump", "bum", "ugly", "hell", "damn", "dumpster",
        "manure", "diarrhea", "barf", "snot", "doodoo", "fake", "joke",
    ]
    static let crudeStems = ["shit", "crap", "poop", "fart", "turd", "piss", "puke", "vomit", "toilet", "booger", "garbage", "stupid",
                             "idiot", "moron", "loser", "diarrh", "dumpster"]
    static let faithWords: Set<String> = ChatSafety.faith.union([
        "allahs", "jesuses", "christs", "buddhas", "mohammad", "muhammed", "hindu", "hindus", "sikh", "sikhs", "jew", "jews",
        "jewish", "muslim", "muslims", "islam", "islamic", "christian", "christians", "catholic", "catholics", "mormon", "mormons",
        "buddhist", "buddhists", "judaism", "hinduism", "christianity", "vatican", "mecca", "nun", "nuns", "rabbis", "imams", "popes",
    ])
    static let faithStems = ["allah", "jesus", "christ", "muhammad", "mohammed", "mohammad", "buddha", "bible", "quran", "koran", "torah",
                             "mosque", "synagog", "rabbi", "prophet", "gospel", "muslim", "islam", "jewish", "hindu"]
    static let groupWords: Set<String> = ChatSafety.groups.union([
        "jew", "jews", "black", "blacks", "white", "whites", "asian", "asians", "arab", "arabs", "african", "africans", "mexican",
        "mexicans", "chinese", "gay", "gays", "lesbian", "lesbians", "trans", "migrant", "migrants", "immigrant", "immigrants",
        "muslim", "muslims", "hindu", "hindus", "sikh", "sikhs", "gypsy", "gypsies", "roma", "romani", "women", "woman", "girls",
        "native", "natives", "indian", "indians", "latino", "latinos", "hispanic", "hispanics", "refugee", "refugees", "catholic",
        "catholics", "christian", "christians", "atheist", "atheists", "mormon", "mormons",
    ])
    static let negation: Set<String> = [
        "no", "not", "free", "less", "ban", "banned", "anti", "kill", "killer", "killers", "die", "dead", "out", "hate", "haters",
        "hater", "begone", "exterminate", "purge", "cleanse", "cleansed", "allowed", "only", "pure", "gas", "deport",
        "deported", "hunt", "hunting",
    ]
}
