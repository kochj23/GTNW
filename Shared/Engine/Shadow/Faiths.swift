//
//  Faiths.swift
//  Global Thermal Nuclear War
//
//  Theocracies of any faith (3.29.0). Before this every new theocracy was Islamic. Now, when clerics take power (a
//  government the President installs, a revolution, history's own era transitions), the state's faith is drawn from
//  a wide pool: the world religions, new religious movements, neopagan and folk revivals, African and diaspora
//  traditions, the gods of the ancient and indigenous worlds, and East Asian traditions. Any nation in any era can
//  draw any faith that exists by then (each has a founding year), with a mild weight toward its own dominant religion
//  (CIA World Factbook). The faith is stored on the country and shows in its name, its dossier and the news.
//  The wording is neutral and respectful: names, gods and titles of office, never mockery.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum Faith: String, Codable, CaseIterable, Identifiable {
    // World religions
    case christian, catholic, orthodox, sunni, shia, hindu, buddhist, sikh, jewish, zoroastrian, bahai
    // East Asian
    case shinto, taoist, confucian, chineseFolk, muism
    // New religious movements
    case latterDaySaint, jehovahsWitness, adventist, christianScience, scientology, rastafari, caoDai, tenrikyo, falunGong,
         unitarian, eckankar
    // Neopagan and folk revivals
    case wicca, druidry, asatru, rodnovery, romuva, kemetism
    // African and diaspora
    case vodou, santeria, candomble, umbanda, ifa, akan
    // Ancient, indigenous and historic
    case hellenic, roman, norse, egyptian, aztec, maya, inca, mesopotamian, canaanite, celtic, slavic, manichaean, mithraic,
         tengri, shamanic, rapaNui, hawaiian, maori

    var id: String { rawValue }

    /// How the state styles itself.
    enum Form { case theocracy, islamicRepublic, republic }

    /// adjective, founding year (negative = BCE), patron god(s) or title (nil: none named), who governs, state form.
    private var info: (adjective: String, from: Int, patron: String?, clergy: String, form: Form) {
        switch self {
        case .christian: return ("Christian", 30, nil, "church elders", .theocracy)
        case .catholic: return ("Catholic", 30, nil, "bishops", .theocracy)
        case .orthodox: return ("Orthodox", 1054, nil, "patriarchs", .theocracy)
        case .sunni: return ("Sunni Islamic", 632, nil, "ulema", .islamicRepublic)
        case .shia: return ("Shia Islamic", 680, nil, "ayatollahs", .islamicRepublic)
        case .hindu: return ("Hindu", -1500, nil, "priests and gurus", .theocracy)
        case .buddhist: return ("Buddhist", -500, nil, "monastic council", .theocracy)
        case .sikh: return ("Sikh", 1469, nil, "Khalsa council", .theocracy)
        case .jewish: return ("Jewish", -1000, nil, "rabbinical council", .theocracy)
        case .zoroastrian: return ("Zoroastrian", -1000, "Ahura Mazda", "mobeds", .theocracy)
        case .bahai: return ("Baháʼí", 1863, nil, "spiritual assembly", .theocracy)
        case .shinto: return ("Shinto", 700, "Amaterasu", "shrine priests", .theocracy)
        case .taoist: return ("Taoist", -400, "the Jade Emperor", "Taoist masters", .theocracy)
        case .confucian: return ("Confucian", -500, "Heaven", "ritual scholars", .theocracy)
        case .chineseFolk: return ("Chinese Folk", 0, "the Jade Emperor and the ancestors", "temple elders", .theocracy)
        case .muism: return ("Muist", -1000, "Haneullim", "mudang", .theocracy)
        case .latterDaySaint: return ("Latter-day Saint", 1830, nil, "First Presidency", .theocracy)
        case .jehovahsWitness: return ("Jehovah's Witness", 1879, "Jehovah", "Governing Body", .theocracy)
        case .adventist: return ("Seventh-day Adventist", 1863, nil, "General Conference", .theocracy)
        case .christianScience: return ("Christian Science", 1879, nil, "Mother Church board", .theocracy)
        case .scientology: return ("Scientologist", 1954, nil, "church leadership", .theocracy)
        case .rastafari: return ("Rastafari", 1930, "Jah", "elders", .theocracy)
        case .caoDai: return ("Cao Đài", 1926, "the Supreme Being", "Holy See of Tây Ninh", .theocracy)
        case .tenrikyo: return ("Tenrikyo", 1838, "God the Parent", "Shinbashira", .theocracy)
        case .falunGong: return ("Falun Gong", 1992, nil, "practitioners' council", .theocracy)
        case .unitarian: return ("Unitarian Universalist", 1961, nil, "congregational assembly", .theocracy)
        case .eckankar: return ("Eckankar", 1965, "Sugmad", "Living ECK Master", .theocracy)
        case .wicca: return ("Wiccan", 1954, "the Goddess and the Horned God", "coven elders", .theocracy)
        case .druidry: return ("Druidic", 1781, "the Awen", "arch-druids", .theocracy)
        case .asatru: return ("Ásatrú", 1972, "Odin and Thor", "goðar", .theocracy)
        case .rodnovery: return ("Rodnover", 1980, "Rod", "volkhvs", .theocracy)
        case .romuva: return ("Romuva", 1967, "Perkūnas", "krivis", .theocracy)
        case .kemetism: return ("Kemetic", 1988, "Netjer", "temple priests", .theocracy)
        case .vodou: return ("Vodou", 1700, "Bondye and the lwa", "houngans and mambos", .republic)
        case .santeria: return ("Santería", 1800, "the orishas", "santeros", .theocracy)
        case .candomble: return ("Candomblé", 1830, "the orixás", "mães and pais de santo", .theocracy)
        case .umbanda: return ("Umbanda", 1908, "Olorum and the orixás", "spiritual guides", .theocracy)
        case .ifa: return ("Ifá", 1000, "Olódùmarè", "babaláwo", .theocracy)
        case .akan: return ("Akan", 1000, "Nyame", "akomfo priests", .theocracy)
        case .hellenic: return ("Hellenic", -800, "Zeus", "high priests", .theocracy)
        case .roman: return ("Roman", -700, "Jupiter", "pontifices", .theocracy)
        case .norse: return ("Norse", 700, "Odin", "goðar", .theocracy)
        case .egyptian: return ("Egyptian", -3000, "Ra", "high priests", .theocracy)
        case .aztec: return ("Aztec", 1300, "Huitzilopochtli and Quetzalcoatl", "temple priests", .theocracy)
        case .maya: return ("Maya", -1000, "Itzamna", "daykeepers", .theocracy)
        case .inca: return ("Inca", 1200, "Inti", "Willaq Umu", .theocracy)
        case .mesopotamian: return ("Mesopotamian", -3000, "Marduk", "high priests", .theocracy)
        case .canaanite: return ("Canaanite", -2000, "Baal", "high priests", .theocracy)
        case .celtic: return ("Celtic", -500, "Lugh", "druids", .theocracy)
        case .slavic: return ("Slavic", 500, "Perun", "volkhvs", .theocracy)
        case .manichaean: return ("Manichaean", 240, "the Father of Greatness", "the Elect", .theocracy)
        case .mithraic: return ("Mithraic", 100, "Mithras", "Pater", .theocracy)
        case .tengri: return ("Tengrist", -500, "Tengri", "kams", .theocracy)
        case .shamanic: return ("Shamanic", -5000, "the spirits", "shamans", .theocracy)
        case .rapaNui: return ("Tangata Manu", 1000, "Makemake", "Makemake's priests", .theocracy)
        case .hawaiian: return ("Hawaiian Kapu", 1000, "Kū and Lono", "kahuna", .theocracy)
        case .maori: return ("Māori", 1300, "Rangi and Papa", "tohunga", .theocracy)
        }
    }

    var adjective: String { info.adjective }
    /// The year the faith exists from (negative = BCE): it can't be drawn earlier.
    var from: Int { info.from }
    var patron: String? { info.patron }
    var clergy: String { info.clergy }
    var form: Form { info.form }
    var isIslamic: Bool { form == .islamicRepublic }

    /// "Latter-day Saint Theocracy of Cuba", "Vodou Republic of Haiti", "Islamic Republic of Iran".
    func stateName(_ land: String) -> String {
        switch form {
        case .islamicRepublic: return "Islamic Republic of \(land)"
        case .republic: return "\(adjective) Republic of \(land)"
        case .theocracy: return "\(adjective) Theocracy of \(land)"
        }
    }

    /// One neutral line for the ticker when a theocracy is proclaimed.
    func proclamation(of land: String) -> String {
        if let god = patron { return "the \(stateName(land)) is proclaimed, honouring \(god); its \(clergy) will guide the government." }
        return "the \(stateName(land)) is proclaimed; its \(clergy) will guide the government."
    }

    /// The faith a country's dominant religion (Factbook) maps to, if any.
    static func from(_ r: Religion) -> Faith? {
        switch r {
        case .sunniIslam: return .sunni
        case .shiaIslam: return .shia
        case .catholic: return .catholic
        case .protestant: return .christian
        case .orthodox: return .orthodox
        case .hindu: return .hindu
        case .buddhist: return .buddhist
        case .confucian: return .confucian
        case .jewish: return .jewish
        case .animist: return .shamanic
        case .secular, .mixed: return nil
        }
    }

    /// Faiths that exist in a year.
    static func available(year: Int) -> [Faith] { allCases.filter { $0.from <= year } }

    /// Draw weights (design choice): every faith that exists by `year` 1, the country's own dominant religion +6
    /// (a mild lean: about one draw in eight in the modern era).
    static func weights(for countryID: String, year: Int) -> [(Faith, Double)] {
        let own = from(WorldFactbookDatabase.record(for: countryID).dominantReligion)
        return available(year: year).map { f in (f, 1 + (f == own ? 6 : 0)) }
    }

    /// Pick a faith for a new theocracy. `roll` in 0..<1.
    static func pick(for countryID: String, year: Int, roll: Double) -> Faith {
        let w = weights(for: countryID, year: year)
        var r = min(max(roll, 0), 0.999_999) * w.reduce(0) { $0 + $1.1 }
        for (f, x) in w {
            r -= x
            if r < 0 { return f }
        }
        return w.last?.0 ?? .christian
    }

    /// The faith of a theocracy the game started with (Iran, the Holy See…): its own religion, else Christian.
    static func historical(for countryID: String) -> Faith {
        from(WorldFactbookDatabase.record(for: countryID).dominantReligion) ?? .christian
    }
}

extension Country {
    /// The state faith of a theocracy (nil for other governments).
    var stateFaith: Faith? { government == .theocracy ? (faith ?? Faith.historical(for: id)) : nil }

    /// "Theocratic · Hellenic (Zeus)" for the dossier's government line.
    var governmentLine: String {
        guard let f = stateFaith else { return government.rawValue }
        return "\(government.rawValue) · \(f.adjective)\(f.patron.map { " (\($0))" } ?? "")"
    }
}

enum FaithNames {
    /// A state name given in one faith's words, restyled for another ("Islamic Republic of Iran" under a Norse
    /// theocracy is the "Norse Theocracy of Iran"). Names without a religious style are kept.
    static func styled(_ name: String, faith: Faith) -> String {
        for prefix in ["Islamic Republic of ", "Islamic Emirate of "] where name.hasPrefix(prefix) {
            return faith.isIslamic ? name : faith.stateName(String(name.dropFirst(prefix.count)))
        }
        for f in Faith.allCases where !f.isIslamic {
            let prefix = f.stateName("")
            if name.hasPrefix(prefix) { return faith.stateName(String(name.dropFirst(prefix.count))) }
        }
        return name
    }
}

extension GameEngine {
    /// Make the country at `index` a theocracy of a newly drawn faith (3.29.0). Its ideology follows the faith, and a
    /// name history gave it in another faith's words ("Islamic Republic of…") is restyled. Returns the faith.
    @discardableResult
    func proclaimTheocracy(_ index: Int, roll: Double? = nil) -> Faith {
        guard let gs = gameState, gs.countries.indices.contains(index) else { return .christian }
        let id = gs.countries[index].id
        let faith = Faith.pick(for: id, year: gs.currentYear, roll: roll ?? Double.random(in: 0..<1, using: &gs.rng))
        gs.countries[index].government = .theocracy
        gs.countries[index].faith = faith
        gs.countries[index].profile.ideology = faith.isIslamic ? .islamicRepublic : .theocracy
        gs.countries[index].name = FaithNames.styled(gs.countries[index].name, faith: faith)
        logPlayEvent("theocracy_proclaimed", detail: ["country": id, "faith": faith.rawValue, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return faith
    }
}
