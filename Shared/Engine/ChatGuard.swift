//
//  ChatGuard.swift
//  Global Thermal Nuclear War
//
//  3.35.0: the chief of staff's guards, all pure and deterministic:
//
//  - `ChatGrounding`: every number and every proper name in a reply must appear in what the model was given this
//    conversation (tool results, the President's words, the briefing). A token-level check after Nova's own
//    nova_speaks guard: it stops invented figures and names, not a subtly changed claim. The agent re-asks once with
//    the offending tokens, then drops the sentences that still carry them.
//  - `ChatSafety`: the content rules at DEFCON 1. A reply (or a message) with a slur, sexual content, a sweeping
//    claim about a people or a faith, mockery of religion, or a weapons-method or drug term is replaced, whole, by a
//    neutral line (fail-closed). Host names, addresses and URLs are scrubbed from anything shown.
//  - `ChatRequestScreen`: the orders the conversation will not take at all (chemical and biological weapons,
//    assassination, terror, drugs; the same off-list prohibitions as the 3.34 command box), prompt-injection
//    phrasing, and the length cap.
//
//  The blocked-word list is kept as FNV-1a hashes so the words themselves are not in the sources.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - Words

enum ChatWords {
    /// Lowercase words (letters, digits, apostrophes), with possessives dropped.
    static func words(_ s: String) -> [String] {
        var out: [String] = []
        var cur = ""
        func flush() {
            guard !cur.isEmpty else { return }
            var w = cur.lowercased()
            if w.hasSuffix("'s") || w.hasSuffix("’s") { w.removeLast(2) }
            w = w.trimmingCharacters(in: CharacterSet(charactersIn: "'’"))
            if !w.isEmpty { out.append(w) }
            cur = ""
        }
        for ch in s {
            if ch.isLetter || ch.isNumber || ch == "'" || ch == "’" { cur.append(ch) } else { flush() }
        }
        flush()
        return out
    }

    /// Fold accents and common look-alike digits/symbols ("h4te" → "hate"), for the content check only.
    static func folded(_ w: String) -> String {
        let map: [Character: Character] = ["0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s", "!": "i"]
        var t = w.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        t = String(t.map { map[$0] ?? $0 })
        return t.filter { $0.isLetter }
    }

    static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01b3 }
        return h
    }
}

// MARK: - Grounding

enum ChatGrounding {
    /// Capitalized words that need no source: titles, the game's own words, calendar words, and common sentence
    /// openers.
    static let free: Set<String> = [
        "mr", "mrs", "madam", "sir", "president", "prime", "minister", "chancellor", "premier", "general", "secretary", "chief",
        "staff", "your", "excellency", "majesty", "highness", "the", "a", "an", "we", "i", "you", "our", "their", "they", "it", "its",
        "he", "she", "his", "her", "this", "that", "these", "those", "there", "here", "if", "then", "but", "and", "or", "so", "yes",
        "no", "not", "nothing", "none", "all", "both", "either", "neither", "one", "two", "three", "four", "five", "six", "seven",
        "eight", "nine", "ten", "first", "second", "third", "next", "last", "step", "steps", "plan", "order", "orders", "execute",
        "edit", "cancel", "confirm", "confirmation", "nuclear", "release", "defcon", "alert", "card", "warning", "warnings", "note",
        "understood", "noted", "done", "very", "well", "good", "certainly", "of", "course", "right", "now", "currently", "today",
        "recommend", "recommendation", "suggest", "advise", "advice", "consider", "option", "options", "however", "also", "still",
        "already", "with", "without", "against", "for", "from", "to", "in", "on", "at", "by", "as", "after", "before", "while",
        "when", "where", "what", "which", "who", "whom", "why", "how", "is", "are", "was", "were", "be", "been", "will", "would",
        "can", "could", "should", "shall", "may", "might", "must", "do", "does", "did", "have", "has", "had", "let", "let's",
        "please", "thank", "thanks", "sorry", "unfortunately", "fortunately", "alternatively", "meanwhile", "overall", "given",
        "based", "according", "per", "about", "any", "some", "every", "each", "more", "most", "less", "few", "many", "much",
        "only", "just", "even", "again", "too", "either", "other", "another", "such", "same", "different", "since", "until",
        "because", "though", "although", "unless", "whether", "otherwise", "instead", "rather", "perhaps", "likely", "unlikely",
        "ready", "standing", "by", "check", "checking", "reports", "report", "intelligence", "estimate", "estimates", "cabinet",
        "situation", "room", "war", "peace", "troops", "army", "navy", "air", "force", "forces", "fleet", "ground", "naval",
        "economy", "budget", "approval", "popularity", "election", "polls", "relations", "allies", "alliance", "treaty",
        "january", "february", "march", "april", "june", "july", "august", "september", "october", "november", "december",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "ok", "okay", "attack", "strike",
        "sanctions", "sanction", "blockade", "invasion", "ceasefire", "aid", "summary", "status", "risk", "risks", "odds",
        "warheads", "actions", "action", "turn", "month", "year", "week", "day", "committed", "held", "back", "refused",
        "joint", "chiefs", "pentagon", "congress", "senate", "house", "white", "state", "department", "defense", "treasury",
        "national", "security", "council", "adviser", "advisor", "advisers", "advisors", "ambassador", "embassy", "envoy",
        "intelligence", "agency", "ministry", "foreign", "office", "admiralty", "parliament", "crown", "king", "queen",
        "emperor", "tsar", "czar", "kaiser", "sultan", "shah", "communist", "party", "politburo", "kremlin", "cold",
        "world", "great", "powers", "allied", "axis", "central", "entente", "un", "united", "nations",
    ]

    /// Tokens in `reply` that appear in none of `sources`: numbers (any not in the sources, small counts up to ten
    /// excepted) and capitalized names. `aliases` maps a lowercase word ("french") to a name it stands for ("France"):
    /// the word passes when that name is in the sources. `knownNames` holds the game's own proper-noun words (nations,
    /// capitals, leaders): one of those opening a sentence is checked like any other name.
    static func unsupported(_ reply: String, sources: [String], aliases: [String: String] = [:], knownNames: Set<String> = []) -> [String] {
        let joined = sources.joined(separator: "\n")
        let srcWords = Set(ChatWords.words(joined).flatMap { w -> [String] in
            var out = [w]
            if w.hasSuffix("s") { out.append(String(w.dropLast())) }
            out += w.split(separator: "-").map(String.init)
            return out
        })
        let srcNumbers = numbers(in: joined)
        var bad: [String] = []
        // Numbers.
        for (text, value) in numberTokens(in: reply) where !(value <= 10 && value == value.rounded()) {
            let decimals = text.split(separator: ".").dropFirst().first?.count ?? 0
            let candidates = [value, value / 1000, value * 1000, value / 1_000_000, value / 1_000_000_000]
            let found = srcNumbers.contains { v in candidates.contains { c in abs(rounded(v, decimals) - c) < 1e-9 || abs(v - c) < 1e-9 } }
            if !found { bad.append(text) }
        }
        // Names: capitalized words. A sentence's first word passes when it is a word the sources or the free list use.
        var sentenceStart = true
        for raw in tokens(reply) {
            let t = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”()[]*_`"))
            defer { sentenceStart = raw.hasSuffix(".") || raw.hasSuffix("!") || raw.hasSuffix("?") || raw.hasSuffix(":") || raw.hasSuffix("\n") }
            guard let first = t.first, first.isUppercase else { continue }
            for part in t.split(whereSeparator: { $0 == "-" || $0 == "/" || $0 == "–" }) {
                for w in ChatWords.words(String(part)) where w.first?.isLetter == true {
                    if free.contains(w) || srcWords.contains(w) || srcWords.contains(w + "s") { continue }
                    if w.hasSuffix("s"), srcWords.contains(String(w.dropLast())) { continue }
                    if let name = aliases[w], srcWords.isSuperset(of: ChatWords.words(name)) { continue }
                    // A sentence's first word is only a name when the game knows it as one ("Bolivia would…"); otherwise
                    // it is an ordinary word with a capital ("Steady as she goes.").
                    if sentenceStart, !knownNames.contains(w), part.dropFirst().allSatisfy({ !$0.isUppercase }) { continue }
                    bad.append(String(part))
                }
            }
        }
        var seen = Set<String>()
        return bad.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Phrases that mark the model talking about its own work instead of to the President ("Okay, let's see. The tool
    /// says…"); their sentences are dropped from a reply.
    static let metaMarkers = ["let's see", "let me see", "let me check", "i need to", "i should", "the tool", "tool result",
                              "tool response", "tool's", "fact check", "fact-check", "the user", "system prompt", "wait,",
                              "okay, so", "hmm", "not in the reports", "look it up with", "rewrite your message",
                              "propose_orders", "rule 1", "rule 2", "rule 3", "rule 4", "rule 5", "rule 6", "rule 7",
                              "rule 8"]
    /// Whole words that only the model's own workings use.
    static let metaWords: Set<String> = ["tool", "tools", "function", "json", "prompt"]

    static func stripMeta(_ reply: String) -> String {
        func meta(_ text: String) -> Bool {
            let l = text.lowercased()
            return metaMarkers.contains { l.contains($0) } || !metaWords.isDisjoint(with: ChatWords.words(l))
        }
        // A line imitating the conversation's own markers ("[Plan card shown: …]") would look like a card that isn't there.
        let reply = reply.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { l in !["[plan card", "[game record"].contains { l.lowercased().contains($0) } }.joined(separator: "\n")
        guard meta(reply) else { return reply.trimmingCharacters(in: .whitespacesAndNewlines) }
        return sentences(reply).filter { !meta($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Drop every sentence that carries an unsupported token. Empty when nothing is left.
    static func strip(_ reply: String, unsupported: [String]) -> String {
        guard !unsupported.isEmpty else { return reply }
        let low = Set(unsupported.map { $0.lowercased() })
        var kept: [String] = []
        for s in sentences(reply) {
            let toks = Set(tokens(s).map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() })
                .union(ChatWords.words(s)).union(numberTokens(in: s).map { $0.0.lowercased() })
            if toks.isDisjoint(with: low) { kept.append(s) }
        }
        return kept.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The reply's sentences, each with the spacing after it, so joining them gives the text back. A sentence ends at
    /// ".", "!" or "?" followed by a space (not inside "2.6" or "U.S.") or at a line break (list items).
    static func sentences(_ s: String) -> [String] {
        var out: [String] = []
        var cur = ""
        let chars = Array(s)
        for (i, ch) in chars.enumerated() {
            cur.append(ch)
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            if ch == "\n" || (".!?".contains(ch) && next.isWhitespace) {
                out.append(cur); cur = ""
            }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    private static func tokens(_ s: String) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in s {
            if ch == " " || ch == "\t" { if !cur.isEmpty { out.append(cur); cur = "" } }
            else if ch == "\n" { cur.append(ch); out.append(cur); cur = "" }
            else { cur.append(ch) }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    /// Numeric tokens ("1,200", "45.5", "50") with their values; digits inside words ("F-16", "B-52") count too.
    static func numberTokens(in s: String) -> [(String, Double)] {
        var out: [(String, Double)] = []
        var cur = ""
        let chars = Array(s)
        func flush() {
            var t = cur
            while t.last == "." || t.last == "," { t.removeLast() }
            if !t.isEmpty, let v = Double(t.replacingOccurrences(of: ",", with: "")) { out.append((t, v)) }
            cur = ""
        }
        for (i, ch) in chars.enumerated() {
            if ch.isASCII && ch.isNumber { cur.append(ch) }
            else if (ch == "," || ch == "."), !cur.isEmpty, i + 1 < chars.count, chars[i + 1].isASCII, chars[i + 1].isNumber { cur.append(ch) }
            else { flush() }
        }
        flush()
        return out
    }

    static func numbers(in s: String) -> [Double] { numberTokens(in: s).map(\.1) }

    private static func rounded(_ v: Double, _ decimals: Int) -> Double {
        let p = GameMath.pow(10.0, Double(min(decimals, 6)))
        return (v * p).rounded() / p
    }
}

// MARK: - Content safety (DEFCON 1)

enum ChatSafety {
    /// What a reply that breaks the content rules is replaced with.
    static let fallback = "Let's keep to the business of state. What would you like to do next?"

    /// FNV-1a hashes of blocked words: slurs (racial, ethnic, antisemitic, homophobic, misogynistic) and explicit
    /// sexual terms, lowercased and accent-folded. Stored as hashes so the words never appear in the source; to add one,
    /// hash it with `ChatWords.fnv1a` and add the value here (and a case to `ChatSecurityTests`).
    static let blockedHashes: Set<UInt64> = [
        0x00ef32288a1656c5, 0x03632e0deb843dce, 0x062fbbbfe27253af, 0x07afd2f43d94700c, 0x09e8a888ee8c53d4,
        0x0a8100cc5f8db011, 0x0bb8f591194ef325, 0x0bc610911959ab62, 0x1a1bd29fe49297fe, 0x1ce4f7117af7cf57,
        0x1dbc6599c45e4e07, 0x1e359bef2e850857, 0x20ae424676455c0f, 0x22b44c8aa04b6cf2, 0x2d5df218d441759a,
        0x2d6501ec0d775cf9, 0x3059a47b3d25a29b, 0x3565c6ced4072262, 0x3a3c9b8e01277b22, 0x3da81967075841be,
        0x3e2f2e830073902e, 0x45846a193a78282c, 0x45c4fea731b4e827, 0x4c6d7290acc036bf, 0x4f88a5414b3add1d,
        0x538bfc80db10d1b7, 0x553753f23ec470d6, 0x582afab29d0a0d80, 0x5b39378e135dade3, 0x5c61a44c47e93a33,
        0x5eb4f3194882e691, 0x600024f2d4f9dd79, 0x600e3bf2d50641ea, 0x622a45762504d12e, 0x62aa07ad587224c5,
        0x62fac28da9d5a4ee, 0x66e4bd465dc2b686, 0x67ea3cbd93f2f225, 0x6acf1218f748a0db, 0x6d97c944092ff7c8,
        0x6d9ef21fd1da4113, 0x6f0b9ec3c2bac013, 0x6f59918485a380d8, 0x705ff5f6366e5206, 0x73639e3a6fbda42a,
        0x823b93195ce22287, 0x82f811e1df6207a8, 0x841114b2ba768c5b, 0x858e576730cea704, 0x85f78c2265d1c822,
        0x86585b78dafe862a, 0x883442217fbc98d0, 0x8b45548adbb248fb, 0x8b99ab19095527ea, 0x8c2cf10da8936508,
        0x8cdfd7808d9d200c, 0x8e949f60aa6011c1, 0x90a51c87d079bf3b, 0x917449a0a7cb685f, 0x93cbdebdaed73208,
        0x9828a7de5a2c996d, 0x9abe5f38c3da93ea, 0x9ce4d5720e9c8f65, 0x9e3077d58a9d1ca4, 0xa33b8bfd0330cd2d,
        0xad615bab371474a4, 0xb0a1180d886de88f, 0xb568711979a4ad59, 0xb8210ef9b628a07a, 0xb8c1d375c591328d,
        0xbcdc5e7ab13b0979, 0xbf85fb57ef268f35, 0xbfdc150cec0b359f, 0xc3c3013572754e05, 0xc67c686c3068fd78,
        0xcc0f6674cc68ccfb, 0xcd7719baf7dc26b4, 0xce46e919876944b3, 0xcfea364bdf3e433b, 0xd0f08d4e4f41761d,
        0xd2a564c0e72fc107, 0xd989dac7034c5516, 0xdcb97d18fee001bd, 0xddb881846844b355, 0xe095b59b0d068099,
        0xe0f0c58862cd1066, 0xe5255849b2d23e5e, 0xec61db67d03053ae, 0xed3e2b793050e868, 0xef315f7916a3110a,
        0xef8b99d72158c429, 0xfd7bae70a1fe37cd, 0xfe3cfb7b497e3183,
    ]

    /// Peoples and faiths a sweeping claim must never be made about (nations are not here: "the French are
    /// mobilizing" is a report, not a slur).
    static let groups: Set<String> = [
        "jews", "jew", "jewish", "muslims", "muslim", "christians", "christian", "hindus", "hindu", "buddhists", "sikhs", "catholics",
        "protestants", "mormons", "atheists", "blacks", "whites", "asians", "arabs", "africans", "hispanics", "latinos", "gypsies",
        "roma", "women", "woman", "girls", "gays", "lesbians", "immigrants", "refugees", "natives", "indians",
    ]
    static let sweeping: Set<String> = [
        "inferior", "subhuman", "animals", "vermin", "savages", "savage", "barbarians", "parasites", "filthy", "dirty", "lazy",
        "greedy", "stupid", "dumb", "evil", "criminals", "terrorists", "cockroaches", "rats", "dogs", "pigs", "apes", "monkeys",
        "hysterical", "emotional", "weak", "control", "controls", "belong", "shouldn't", "can't", "cannot", "breed", "infest",
    ]
    static let faith: Set<String> = [
        "god", "gods", "allah", "jesus", "christ", "muhammad", "mohammed", "prophet", "buddha", "bible", "quran", "koran", "torah",
        "gospel", "church", "mosque", "synagogue", "temple", "religion", "religions", "faith", "faiths", "pope", "rabbi", "imam",
        "priest", "priests", "monks", "scripture", "prayer", "prayers", "worship",
    ]
    static let mockery: Set<String> = [
        "stupid", "idiot", "idiots", "idiotic", "fake", "fairy", "fairytale", "ridiculous", "moron", "morons", "moronic", "pathetic",
        "joke", "delusional", "primitive", "superstitious", "superstition", "lunatic", "lunatics", "crazy", "nonsense", "absurd",
        "worthless", "silly", "dumb", "laughable", "imaginary", "brainwashed", "cult", "mumbo", "jumbo",
    ]
    /// The 3.31 content rules: no substance, organism or method names.
    static let methods: Set<String> = [
        "lsd", "mescaline", "psilocybin", "amphetamine", "amphetamines", "barbiturate", "barbiturates", "sarin", "tabun", "soman",
        "anthrax", "smallpox", "ricin", "botulinum", "dose", "doses", "milligram", "milligrams", "synthesize", "synthesis",
        "aerosolize", "aerosolized", "cocaine", "heroin", "fentanyl", "methamphetamine",
    ]

    /// Does the text break the content rules?
    static func violates(_ text: String) -> Bool {
        let words = ChatWords.words(text)
        let folded = words.map(ChatWords.folded)
        for (w, f) in zip(words, folded) {
            if blockedHashes.contains(ChatWords.fnv1a(w)) || blockedHashes.contains(ChatWords.fnv1a(f)) { return true }
            if methods.contains(w) { return true }
        }
        // A sweeping claim: a people or faith within four words of a sweeping word ("all X are Y", "X control the …").
        for (i, w) in folded.enumerated() where groups.contains(w) {
            let window = folded[(i + 1)..<min(folded.count, i + 5)]
            if window.contains(where: { sweeping.contains($0) }) { return true }
        }
        // Mocking a faith: a faith word within four words of a mocking word, either side.
        for (i, w) in folded.enumerated() where faith.contains(w) || groups.contains(w) {
            let lo = max(0, i - 4), hi = min(folded.count, i + 5)
            if folded[lo..<hi].contains(where: { mockery.contains($0) }) { return true }
        }
        return false
    }

    /// The reply as it may be shown: scrubbed of hosts and addresses, or the neutral line if it breaks the rules.
    static func clean(_ text: String) -> String {
        let scrubbed = scrubHosts(text)
        return violates(scrubbed) ? fallback : scrubbed
    }

    /// Remove URLs, host names with a port, IPv4 addresses and "localhost" from text for the screen.
    static func scrubHosts(_ text: String) -> String {
        var out: [String] = []
        for line in text.components(separatedBy: "\n") {
            let toks = line.split(separator: " ", omittingEmptySubsequences: false).map { tok -> String in
                let t = String(tok)
                let core = t.trimmingCharacters(in: .punctuationCharacters).lowercased()
                if core.contains("://") || core.hasPrefix("www.") || core.contains("localhost") || isIPv4(core)
                    || core.range(of: ":") != nil && core.split(separator: ":").last.map({ $0.allSatisfy(\.isNumber) && !$0.isEmpty }) == true
                    && core.split(separator: ":").first.map({ $0.contains(".") || $0 == "localhost" }) == true {
                    return "[removed]"
                }
                return t
            }
            out.append(toks.joined(separator: " "))
        }
        return out.joined(separator: "\n")
    }

    static func isIPv4(_ s: String) -> Bool {
        let host = s.split(separator: ":").first.map(String.init) ?? s
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { p in !p.isEmpty && p.count <= 3 && p.allSatisfy(\.isNumber) && (Int(p) ?? 999) <= 255 }
    }
}

// MARK: - What the conversation will not take

enum ChatRequestScreen {
    /// Characters of one message (the prompt-injection and memory bound; the 3.34 box took 200).
    static let maxInput = 600

    static let refusal = "That is not an order I can put in front of you. Chemical and biological weapons, assassination, terror and drug operations stay on the escalation ladder, where the cabinet and the legal status are in view."

    /// Trim, drop control characters, cap the length.
    static func sanitize(_ raw: String) -> String {
        let kept = raw.unicodeScalars.filter { $0 == "\n" || (!CharacterSet.controlCharacters.contains($0) && !CharacterSet.illegalCharacters.contains($0)) }
        return String(String(String.UnicodeScalarView(kept)).trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxInput))
    }

    /// Phrases that ask for an off-list order (the same prohibitions as the command box's whitelist).
    static let prohibited: [[String]] = [
        ["chemical", "weapon"], ["chemical", "attack"], ["chemical", "weapons"], ["nerve", "gas"], ["mustard", "gas"], ["poison", "gas"],
        ["gas", "attack"], ["bioweapon"], ["bioweapons"], ["biological", "weapon"], ["biological", "weapons"], ["biological", "attack"],
        ["germ", "warfare"], ["engineered", "pathogen"], ["release", "a", "virus"], ["release", "the", "virus"],
        ["assassinate"], ["assassination"], ["assassinated"], ["poison"], ["poisoned"], ["poisoning"],
        ["terror", "attack"], ["terrorist"], ["terrorists"], ["terrorism"], ["fund", "terror"], ["support", "terror"],
        ["drug", "trafficking"], ["drug", "smuggling"], ["drug", "operation"], ["drug", "operations"], ["narcotics"], ["cocaine"],
        ["heroin"], ["opium", "trade"], ["sarin"], ["anthrax"], ["smallpox"], ["ricin"],
    ]

    /// Does the message ask for something off the list?
    static func isProhibited(_ text: String) -> Bool {
        let w = ChatWords.words(text)
        for phrase in prohibited where phrase.count <= w.count {
            for i in 0...(w.count - phrase.count) where Array(w[i..<(i + phrase.count)]) == phrase { return true }
        }
        return false
    }

    static let injectionMarkers: [[String]] = [
        ["ignore", "your"], ["ignore", "all"], ["ignore", "previous"], ["ignore", "the", "rules"], ["system", "prompt"],
        ["you", "are", "now"], ["developer", "mode"], ["jailbreak"], ["without", "confirmation"], ["skip", "the", "confirmation"],
        ["skip", "confirmation"], ["without", "asking"], ["new", "instructions"], ["disregard"], ["pretend", "you"],
        ["execute", "it", "yourself"], ["execute", "immediately"], ["bypass"],
    ]

    /// Does the message try to rewrite the rules? (It changes nothing either way: the tools are the whitelist and
    /// nothing runs without EXECUTE. The agent adds a reminder to the model.)
    static func looksLikeInjection(_ text: String) -> Bool {
        let w = ChatWords.words(text)
        for m in injectionMarkers where m.count <= w.count {
            for i in 0...(w.count - m.count) where Array(w[i..<(i + m.count)]) == m { return true }
        }
        return false
    }
}
