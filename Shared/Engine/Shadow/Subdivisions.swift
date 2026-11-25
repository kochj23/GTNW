//
//  Subdivisions.swift
//  Global Thermal Nuclear War
//
//  3.36.0: states and provinces. The first-level subdivisions of the United States and of the larger powers
//  (Natural Earth admin-1, public domain; `SubdivisionData.swift`) exist in the eras they roughly apply to: the U.S.
//  states by their real admission dates with the territories before them (`USStatesHistory`), everyone else's
//  modern provinces from about the time they took their modern shape (after 1945 for most). Before that the nation is
//  shown undivided rather than inventing history.
//
//  What the game remembers about them is the `ProvinceLedger` on the Shadow state: the President's names, provinces
//  that changed hands (a peace that annexed them, a state that seceded and became a nation of its own), provinces an
//  army holds, and each province's unrest. Everything else follows from the date, so a save from before 3.36 loads
//  with the subdivisions of its year.
//
//  Each turn (`processSubdivisions`): unrest drifts toward a level set by the nation's stability and outcry and by
//  what has happened there (an army in the streets, a foreign flag, a name nobody chose, radiation, a lost election);
//  a province that boils over in a nation near collapse, with a reason to go (a war, nuclear fire, a civil war at
//  home), may declare independence and becomes a nation on the map. A won ground war records the provinces the
//  victor's army holds, and the peace can annex those provinces instead of the whole country (`annexOccupied`).
//  Randomness only from the game's seeded RNG, and only when a province is already on the edge.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// One state or province, as the data has it (its name and holder in a game come from the ledger).
struct Subdivision: Hashable, Sendable {
    let id: String
    /// The nation whose subdivision it is on the modern map ("USA", "RUS"…).
    let nation: String
    let name: String
    /// "State", "Province", "Oblast"…
    let kind: String
    let lat: Double
    let lon: Double
    /// Share of the nation's people, per mille (rough; the U.S. uses its apportionment by year instead).
    let weight: Double
}

/// What happened to states and provinces in this game (3.36.0). Saved with the game; every field defaults.
struct ProvinceLedger: Codable, Hashable {
    /// The President's names, by province.
    var names: [String: String] = [:]
    /// Provinces that changed hands: the new holder (a victor's annexation, or the nation a seceded state became).
    var owners: [String: String] = [:]
    /// Provinces an army holds that have not been ceded: the occupier.
    var occupied: [String: String] = [:]
    /// Unrest, 0…100, for provinces that have any.
    var unrest: [String: Double] = [:]
    /// When a province declared independence.
    var seceded: [String: Date] = [:]
    /// The last presidential election, state by state: the President's ticket's share of the two-party vote.
    var lastElection: [String: Double] = [:]
    var lastElectionYear: Int?
    /// States that went to a third candidate in it.
    var thirdCarried: Set<String> = []
    /// The civil war at home has been told state by state.
    var civilWarTold = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case names, owners, occupied, unrest, seceded, lastElection, lastElectionYear, thirdCarried, civilWarTold
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        names = (try? c.decodeIfPresent([String: String].self, forKey: .names)) ?? [:]
        owners = (try? c.decodeIfPresent([String: String].self, forKey: .owners)) ?? [:]
        occupied = (try? c.decodeIfPresent([String: String].self, forKey: .occupied)) ?? [:]
        unrest = (try? c.decodeIfPresent([String: Double].self, forKey: .unrest)) ?? [:]
        seceded = (try? c.decodeIfPresent([String: Date].self, forKey: .seceded)) ?? [:]
        lastElection = (try? c.decodeIfPresent([String: Double].self, forKey: .lastElection)) ?? [:]
        lastElectionYear = try? c.decodeIfPresent(Int.self, forKey: .lastElectionYear)
        thirdCarried = (try? c.decodeIfPresent(Set<String>.self, forKey: .thirdCarried)) ?? []
        civilWarTold = (try? c.decodeIfPresent(Bool.self, forKey: .civilWarTold)) ?? false
    }
}

enum Subdivisions {
    /// Every subdivision in the data, in id order.
    static let all: [Subdivision] = SubdivisionData.rows.split(separator: "\n").compactMap { line in
        let f = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard f.count == 7, let lat = Double(f[4]), let lon = Double(f[5]), let w = Double(f[6]) else { return nil }
        return Subdivision(id: f[0], nation: f[1], name: f[2], kind: f[3], lat: lat, lon: lon, weight: w)
    }

    static let byID: [String: Subdivision] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    static let byNation: [String: [Subdivision]] = Dictionary(grouping: all, by: \.nation)

    /// The first year a nation's modern subdivisions roughly apply; before it the nation is drawn undivided. The U.S.
    /// goes state by state (`USStatesHistory`).
    static let since: [String: Int] = [
        "CAN": 1949, "MEX": 1945, "BRA": 1945, "RUS": 1945, "CHN": 1949, "IND": 1950, "AUS": 1945, "DEU": 1990, "JPN": 1945,
        "UKR": 1992, "ARG": 1945, "ZAF": 1994, "KOR": 1948, "IDN": 1950, "PAK": 1971, "FRA": 1945, "ITA": 1948, "ESP": 1979,
        "GBR": 1922,
    ]

    /// Capital districts never secede (their nation would not survive it as itself).
    static func isCapitalDistrict(_ s: Subdivision) -> Bool {
        ["Federal District", "Federal City", "Capital Territory", "Municipality", "Union Territory"].contains(s.kind)
            || s.name.hasSuffix("Capital Territory") || s.id == "US-DC" || s.id == "GB-ENG"
    }

    static func dayKey(_ y: Int, _ m: Int, _ d: Int) -> Int { y * 10000 + m * 100 + d }
    static func dayKey(_ date: Date) -> Int {
        let c = GameCalendar.calendar.dateComponents([.year, .month, .day], from: date)
        return dayKey(c.year ?? 0, c.month ?? 1, c.day ?? 1)
    }

    /// Does this subdivision exist on a day? The U.S.: an original state, an admitted one, a territory organized by
    /// then, the District from 1791. Everyone else: from the nation's `since` year.
    static func exists(_ s: Subdivision, on date: Date) -> Bool {
        exists(s, day: dayKey(date), year: GameCalendar.year(of: date))
    }

    static func exists(_ s: Subdivision, day: Int, year: Int) -> Bool {
        guard s.nation == "USA" else { return year >= (since[s.nation] ?? 9999) }
        if USStatesHistory.original.contains(s.id) { return true }
        if s.id == "US-DC" { return year >= USStatesHistory.districtFrom }
        if let a = USStatesHistory.admitted[s.id], day >= dayKey(a.0, a.1, a.2) { return true }
        return (USStatesHistory.territories[s.id]?.first?.from ?? 9999) <= year
    }

    /// Is it a state of the Union on that day (rather than a territory or the District)?
    static func isUSState(_ id: String, on date: Date) -> Bool {
        if USStatesHistory.original.contains(id) { return true }
        guard let a = USStatesHistory.admitted[id] else { return false }
        return dayKey(date) >= dayKey(a.0, a.1, a.2)
    }

    /// Its kind and historical name on a day ("Dakota Territory", "Territory"; "Ohio", "State").
    static func historical(_ s: Subdivision, on date: Date) -> (name: String, kind: String) {
        guard s.nation == "USA", s.id != "US-DC", !isUSState(s.id, on: date) else { return (s.name, s.kind) }
        let year = GameCalendar.year(of: date)
        if let t = USStatesHistory.territories[s.id]?.last(where: { $0.from <= year }) { return (t.name, "Territory") }
        return (s.name, s.kind)
    }

    /// A 64-bit FNV-1a hash (deterministic in every process, unlike `Hasher`), as -1…1.
    static func unit(_ key: String) -> Double {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01B3 }
        return Double(h % 20_001) / 10_000 - 1
    }

    /// Find a subdivision by a typed name (its real or historical name, or the President's name for it), among the
    /// ones that exist in the game. Exact matches only (normalized), so "Georgia" the nation is never shadowed by a
    /// prefix; an exact tie goes to the U.S. state.
    static func find(_ raw: String, in gs: GameState) -> Subdivision? {
        let n = CommandParser.normalizedName(raw)
        guard !n.isEmpty, n.count <= 60 else { return nil }
        let live = gs.subdivisions()
        let hits = live.filter { s in
            CommandParser.normalizedName(s.name) == n || CommandParser.normalizedName(gs.provinceName(s.id)) == n
                || CommandParser.normalizedName(historical(s, on: gs.currentDate).name) == n
        }
        return hits.first { $0.nation == "USA" } ?? hits.first
    }
}

// MARK: - The game's view

extension GameState {
    /// Subdivisions that exist on the game's date, of every nation (or one nation's), in id order.
    func subdivisions(of nation: String? = nil) -> [Subdivision] {
        let date = currentDate
        let day = Subdivisions.dayKey(date), year = GameCalendar.year(of: date)
        let pool = nation.map { Subdivisions.byNation[$0] ?? [] } ?? Subdivisions.all
        return pool.filter { Subdivisions.exists($0, day: day, year: year) }
    }

    /// Who holds every province that exists, and the nation each belongs to, worked out once (the map and the turn
    /// ask about hundreds of provinces at a time).
    func provinceHolders() -> (owner: [String: String], home: [String: String]) {
        let date = currentDate
        let day = Subdivisions.dayKey(date), year = GameCalendar.year(of: date)
        let present = Set(countries.filter { !$0.isDestroyed }.map(\.id))
        var homeOf: [String: String?] = [:]
        var owner: [String: String] = [:], home: [String: String] = [:]
        for s in Subdivisions.all where Subdivisions.exists(s, day: day, year: year) {
            if homeOf[s.nation] == nil { homeOf[s.nation] = .some(WorldMapData.owner(of: s.nation, in: present, year: year)) }
            if let h = homeOf[s.nation] ?? nil { home[s.id] = h }
            if let o = holder(s, day: day, year: year, home: homeOf[s.nation] ?? nil) { owner[s.id] = o }
        }
        return (owner, home)
    }

    /// The holder of an existing province: a recorded transfer, the Confederate States for a seceded state while that
    /// government stands, Ukraine for Crimea 1992–2013, else its nation.
    private func holder(_ s: Subdivision, day: Int, year: Int, home: String?) -> String? {
        if let o = shadow.provinces.owners[s.id], let c = getCountry(id: o), !c.isDestroyed { return o }
        if let d = USStatesHistory.seceded[s.id], day >= Subdivisions.dayKey(d.0, d.1, d.2),
           let csa = getCountry(id: "CSA"), !csa.isDestroyed, csa.territoryOf == nil {
            return "CSA"
        }
        // Natural Earth draws Crimea with Russia, as the game's map does; from 1992 to 2013 it was Ukraine's.
        if s.id == "UA-40" || s.id == "UA-43", (1992...2013).contains(year), let ukr = getCountry(id: "UKR"), !ukr.isDestroyed {
            return "UKR"
        }
        return home
    }

    /// The name it goes by: the President's name for it, else its name in the year.
    func provinceName(_ id: String) -> String {
        if let n = shadow.provinces.names[id] { return n }
        guard let s = Subdivisions.byID[id] else { return id }
        return Subdivisions.historical(s, on: currentDate).name
    }

    /// Who holds it now (nil when it doesn't exist this year, or its nation isn't in the game): a recorded transfer,
    /// the Confederate States for a seceded state while that government stands, else whoever holds its nation's
    /// outline this year (the Soviet Union for Ukraine's oblasts…).
    func provinceOwner(_ id: String) -> String? {
        let date = currentDate
        let day = Subdivisions.dayKey(date), year = GameCalendar.year(of: date)
        guard let s = Subdivisions.byID[id], Subdivisions.exists(s, day: day, year: year) else { return nil }
        return holder(s, day: day, year: year, home: provinceHomeNation(id))
    }

    /// The nation a subdivision belongs to in the game this year (its owner by default, ignoring transfers).
    func provinceHomeNation(_ id: String) -> String? {
        guard let s = Subdivisions.byID[id] else { return nil }
        let present = Set(countries.filter { !$0.isDestroyed }.map(\.id))
        return WorldMapData.owner(of: s.nation, in: present, year: currentYear)
    }

    /// Subdivisions a country holds now: its own (less any lost) and any it gained.
    func provinces(heldBy owner: String) -> [Subdivision] {
        let held = provinceHolders().owner
        return Subdivisions.all.filter { held[$0.id] == owner }
    }

    /// Population weights of a nation's subdivisions this year (the U.S. by apportionment), summing to 1.
    func provinceShares(of nation: String) -> [String: Double] {
        let subs = subdivisions(of: nation)
        let year = currentYear
        let w = subs.map { nation == "USA" ? USStatesHistory.weight($0.id, year: year) : $0.weight }
        let total = max(0.000_001, w.reduce(0, +))
        return Dictionary(uniqueKeysWithValues: zip(subs.map(\.id), w.map { $0 / total }))
    }

    /// One province's share of its nation's people this year (0…1).
    func populationShare(_ id: String) -> Double {
        guard let s = Subdivisions.byID[id] else { return 0 }
        return provinceShares(of: s.nation)[id] ?? 0
    }

    /// Provinces the President may rename: those he holds, at home and abroad (3.36.0).
    var renamableProvinces: [Subdivision] {
        provinces(heldBy: playerCountryID).sorted { provinceName($0.id) < provinceName($1.id) }
    }

    /// "California (State, held by the Confederate States, unrest 40)": one line per province for the chief of staff.
    func provinceLine(_ s: Subdivision) -> String {
        let h = Subdivisions.historical(s, on: currentDate)
        var parts = [h.kind]
        if let o = provinceOwner(s.id), o != provinceHomeNation(s.id) { parts.append("held by \(getCountry(id: o)?.name ?? o)") }
        if let o = shadow.provinces.occupied[s.id] { parts.append("occupied by \(getCountry(id: o)?.name ?? o)") }
        let u = Int((shadow.provinces.unrest[s.id] ?? 0).rounded())
        if u >= 1 { parts.append("unrest \(u)") }
        let named = shadow.provinces.names[s.id].map { "\($0) (\(h.name))" } ?? h.name
        return "\(named): \(parts.joined(separator: ", "))"
    }
}

// MARK: - Unrest, secession, occupation

enum ProvinceModel {
    /// Where a province's unrest heads: the nation's mood, plus what happened there. 0…100.
    static func unrestTarget(_ s: Subdivision, nation: Country, owner: String?, in gs: GameState) -> Double {
        var t = nation.profile.outcry * 0.6 + Double(100 - nation.stability) * 0.4 - 20   // a settled nation: little
        t += 6 * Subdivisions.unit("lean:" + s.id)                       // some places are always more restless
        if gs.shadow.provinces.occupied[s.id] != nil { t += 25 }        // an army in the streets
        if let o = owner, o != nation.id { t += 20 }                    // a foreign flag over the town hall
        if gs.shadow.provinces.names[s.id] != nil { t += 8 }            // a name nobody there chose
        t += Double(nation.radiationLevel) * 0.3
        if nation.id == gs.playerCountryID, let share = gs.shadow.provinces.lastElection[s.id] {
            t += max(0, 45 - share) * 0.4                                // it voted against the President, hard
        }
        return min(100, max(0, t))
    }

    /// A reason to go, beyond unrest: a war, nuclear fire, collapse at home.
    static func trigger(_ nation: Country, in gs: GameState) -> String? {
        if gs.nuclearStrikes.contains(where: { $0.target == nation.id }) || nation.radiationLevel > 20 { return "after the nuclear strikes" }
        if !nation.atWarWith.isEmpty { return "in the middle of the war" }
        if nation.id == gs.playerCountryID, gs.shadow.domesticEnding == .civilWar { return "as the country falls into civil war" }
        if nation.profile.outcry > 85 { return "as the government loses control" }
        return nil
    }

    /// Unrest above which a province may go, and the national stability below which it can.
    static let breakingPoint = 85.0
    static let collapse = 15

    /// The new nation a seceding province becomes.
    static func breakaway(_ s: Subdivision, name: String, from parent: Country, share: Double) -> Country {
        let t = CountryTemplate(s.id, name, flag: "🏳️", capital: name, lat: s.lat, lon: s.lon, region: parent.region,
                                gov: .republic, align: parent.alignment == .independent ? .nonAligned : parent.alignment,
                                gdp: max(0.5, parent.gdp * 1000 * share), pop: max(0.05, Double(parent.population) * share),
                                mil: max(3, parent.militaryStrength / 5), aggr: 25, stab: 35)
        var c = t.toCountry()
        c.diplomaticRelations[parent.id] = -60
        return c
    }
}

extension GameEngine {
    /// Each turn: unrest drifts, a province on the edge of a nation in collapse may secede, the civil war at home is
    /// told state by state, and the provinces a won war's army holds are recorded for the peace.
    func processSubdivisions() {
        guard let gs = gameState else { return }
        let keep = GameMath.pow(0.7, gs.turnLength.yearFraction / 0.25)
        let holders = gs.provinceHolders()
        var home: [String: [Subdivision]] = [:]   // the nation in the game each province belongs to
        for s in Subdivisions.all { if let n = holders.home[s.id] { home[n, default: []].append(s) } }
        for nid in home.keys.sorted() {
            guard let nation = gs.getCountry(id: nid), !nation.isDestroyed, nation.territoryOf == nil, let subs = home[nid] else { continue }
            // One write per nation: `shadow` is published, so a write per province would copy and notify 500 times a turn.
            var unrest = gs.shadow.provinces.unrest
            for s in subs {
                let now = unrest[s.id] ?? 0
                let next = now * keep + ProvinceModel.unrestTarget(s, nation: nation, owner: holders.owner[s.id], in: gs) * (1 - keep)
                unrest[s.id] = next < 0.5 ? nil : (next * 10).rounded() / 10
            }
            gs.shadow.provinces.unrest = unrest
            // Secession: a nation near collapse, a reason, and a province past the breaking point (the most restless).
            guard nation.stability < ProvinceModel.collapse, let why = ProvinceModel.trigger(nation, in: gs) else { continue }
            let candidates = subs.filter { holders.owner[$0.id] == nid && !Subdivisions.isCapitalDistrict($0)
                && (gs.shadow.provinces.unrest[$0.id] ?? 0) > ProvinceModel.breakingPoint }
            guard let s = candidates.max(by: { (gs.shadow.provinces.unrest[$0.id] ?? 0, $1.id) < (gs.shadow.provinces.unrest[$1.id] ?? 0, $0.id) }),
                  candidates.count < subs.count / 2 + 1 || subs.count <= 2 else { continue }
            if Double.random(in: 0..<1, using: &gs.rng) < gs.scale.probability(annual: 0.35) {
                self.gameState = gs
                secede(s.id, reason: why)
            }
        }
        // The civil war at home, state by state (the presidency is over; this is how the news tells it).
        if gs.shadow.domesticEnding == .civilWar, !gs.shadow.provinces.civilWarTold {
            gs.shadow.provinces.civilWarTold = true
            let mine = gs.provinces(heldBy: gs.playerCountryID).filter { !Subdivisions.isCapitalDistrict($0) }
            let rising = mine.sorted { (gs.shadow.provinces.unrest[$0.id] ?? 0, $1.id) > (gs.shadow.provinces.unrest[$1.id] ?? 0, $0.id) }.prefix(3)
            if !rising.isEmpty {
                let names = rising.map { gs.provinceName($0.id) }
                let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + names.last! : names[0]
                gs.shadow.post("Civil war: \(list) refuse the federal government's authority.", date: gs.currentDate, severity: 3)
            }
        }
        recordOccupations()
        self.gameState = gs
    }

    /// A province declares independence and becomes a nation on the map. Returns the new nation's id.
    @discardableResult
    func secede(_ id: String, reason: String) -> String? {
        guard let gs = gameState, let s = Subdivisions.byID[id], let ownerID = gs.provinceOwner(id),
              let pi = gs.countries.firstIndex(where: { $0.id == ownerID }), gs.getCountry(id: id) == nil else { return nil }
        let parent = gs.countries[pi]
        let name = gs.provinceName(id)
        let share = gs.populationShare(id)
        var free = ProvinceModel.breakaway(s, name: name, from: parent, share: share)
        let ids = Set(gs.countries.map(\.id))
        free.diplomaticRelations = free.diplomaticRelations.filter { ids.contains($0.key) }
        gs.countries.append(free)
        for i in gs.countries.indices where gs.countries[i].id != id {
            gs.countries[i].diplomaticRelations[id] = gs.countries[i].id == ownerID ? -60 : 0
        }
        gs.countries[pi].population = max(1, gs.countries[pi].population - free.population)
        gs.countries[pi].gdp = max(0.001, gs.countries[pi].gdp * (1 - share))
        gs.countries[pi].stability = max(0, gs.countries[pi].stability - 5)
        gs.shadow.provinces.owners[id] = id
        gs.shadow.provinces.seceded[id] = gs.currentDate
        gs.shadow.provinces.occupied.removeValue(forKey: id)
        gs.shadow.eraGovernment[id] = free.government.rawValue
        gs.shadow.eraDiverged.insert(id)
        if ownerID == gs.playerCountryID { gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 6) }
        gs.shadow.post("\(name) declares independence from \(parent.name) \(reason).", date: gs.currentDate, severity: 3)
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(name) secedes from \(parent.name).")
        addLog("🏳️ \(name) declares independence from \(parent.name).", type: .critical)
        logPlayEvent("province_seceded", detail: ["province": id, "name": PlayHistory.text(name), "from": ownerID,
                                                  "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return id
    }

    /// Provinces a won war's army holds, for the peace: nearest the victor's capital first, more of the country the
    /// more decisive the win (40% of its people for a bare win, all of it for a rout). Recorded once per surrender.
    func recordOccupations() {
        guard let gs = gameState else { return }
        for p in gs.shadow.pendingSettlements {
            let held = gs.provinces(heldBy: p.loser)
            guard let victor = gs.getCountry(id: p.victor), !held.isEmpty,
                  !held.contains(where: { gs.shadow.provinces.occupied[$0.id] == p.victor }) else { continue }
            let front = gs.shadow.fronts.last { $0.attacker == p.victor && $0.defender == p.loser }
            let m = max(0, min(1, front?.attackerMomentum ?? 0.5))
            let reach = 0.4 + 0.6 * m
            let shares = gs.provinceShares(of: held[0].nation)
            func dist(_ s: Subdivision) -> Double {
                let dx = s.lon - victor.coordinates.lon, dy = s.lat - victor.coordinates.lat
                return dx * dx + dy * dy
            }
            var taken = 0.0
            for s in held.sorted(by: { (dist($0), $0.id) < (dist($1), $1.id) }) {
                guard taken < reach else { break }
                gs.shadow.provinces.occupied[s.id] = p.victor
                taken += shares[s.id] ?? 0
            }
        }
        // An occupation ends when the province's holder is no longer at war with, or beaten by, the occupier.
        for (k, v) in gs.shadow.provinces.occupied.sorted(by: { $0.key < $1.key }) {
            let holder = gs.provinceOwner(k)
            let pending = gs.shadow.pendingSettlements.contains { $0.victor == v && $0.loser == holder }
            let atWar = holder.flatMap { gs.getCountry(id: $0)?.atWarWith.contains(v) } ?? false
            if holder == v || !(pending || atWar) { gs.shadow.provinces.occupied.removeValue(forKey: k) }
        }
        self.gameState = gs
    }

    /// The occupied provinces a pending settlement could annex.
    func occupiedProvinces(for settlementID: UUID) -> [Subdivision] {
        guard let gs = gameState, let s = gs.shadow.pendingSettlements.first(where: { $0.id == settlementID }) else { return [] }
        return gs.provinces(heldBy: s.loser).filter { gs.shadow.provinces.occupied[$0.id] == s.victor }
    }

    /// 3.36.0's peace term: annex only the provinces the army holds. The loser keeps its government and the rest of
    /// its land, pays and is capped as any loser is, and the provinces fly the victor's flag. False when no province
    /// is held (the settlement is left waiting).
    @discardableResult
    func annexOccupied(_ settlementID: UUID) -> Bool {
        let taken = occupiedProvinces(for: settlementID)
        guard let gs = gameState, !taken.isEmpty, let si = gs.shadow.pendingSettlements.firstIndex(where: { $0.id == settlementID }) else { return false }
        let s = gs.shadow.pendingSettlements.remove(at: si)
        guard let li = gs.countries.firstIndex(where: { $0.id == s.loser }), let vi = gs.countries.firstIndex(where: { $0.id == s.victor }) else {
            self.gameState = gs
            return false
        }
        self.gameState = gs
        writePeaceTerms(victor: s.victor, loser: s.loser, negotiated: false, territory: taken.map(\.id))
        let share = taken.reduce(0) { $0 + gs.populationShare($1.id) }
        let loserName = gs.countries[li].name
        for p in taken {
            gs.shadow.provinces.owners[p.id] = s.victor
            gs.shadow.provinces.occupied.removeValue(forKey: p.id)
        }
        let people = Int((Double(gs.countries[li].population) * share).rounded())
        gs.countries[li].population = max(1, gs.countries[li].population - people)
        gs.countries[vi].population += people
        let output = gs.countries[li].gdp * share
        gs.countries[li].gdp = max(0.001, gs.countries[li].gdp - output)
        gs.countries[vi].gdp += output * 0.5   // rebuilt, garrisoned and resented: half the output, for now
        gs.countries[li].stability = max(0, gs.countries[li].stability - 10)
        gs.countries[li].profile.outcry = min(100, gs.countries[li].profile.outcry + 15)
        gs.countries[li].diplomaticRelations[s.victor] = min(gs.countries[li].diplomaticRelations[s.victor] ?? 0, -50)
        // The world minds less than a whole nation swallowed, but it minds.
        for i in gs.countries.indices where !gs.countries[i].isDestroyed && !gs.countries[i].isTerritory && gs.countries[i].id != s.victor
            && gs.countries[i].id != s.loser {
            let hit = gs.countries[i].alliances.contains(s.victor) ? -1 : (gs.countries[i].alignment == .eastern ? -8 : -4)
            modifyDiplomaticRelation(from: gs.countries[i].id, to: s.victor, by: hit)
        }
        if s.victor == gs.playerCountryID { gs.shadow.ruthlessness += 6 }
        let names = taken.map { gs.provinceName($0.id) }
        let list = names.count <= 4 ? names.joined(separator: ", ") : names.prefix(4).joined(separator: ", ") + " and \(names.count - 4) more"
        let victorName = gs.countries[vi].name
        gs.shadow.post("\(loserName) cedes \(list) to \(victorName). Its government stays in \(gs.countries[li].capital).",
                       date: gs.currentDate, severity: 3)
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(loserName) cedes \(taken.count) province\(taken.count == 1 ? "" : "s") to \(victorName).")
        logPlayEvent("provinces_annexed", detail: ["loser": s.loser, "victor": s.victor, "provinces": taken.map(\.id).joined(separator: ","),
                                                   "share": PlayHistory.num(share), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return true
    }

    /// Store a name for a province the President holds, after the rename system's checks (`rename`). The record goes
    /// to the same name book as every other rename.
    @discardableResult
    func applyProvinceName(_ id: String, _ name: String) -> (old: String, new: String)? {
        guard let gs = gameState, gs.provinceOwner(id) == gs.playerCountryID else { return nil }
        let old = gs.provinceName(id)
        guard old != name else { return nil }
        if let s = Subdivisions.byID[id], Subdivisions.historical(s, on: gs.currentDate).name == name {
            gs.shadow.provinces.names.removeValue(forKey: id)   // its real name back
        } else {
            gs.shadow.provinces.names[id] = name
        }
        self.gameState = gs
        return (old, name)
    }
}
