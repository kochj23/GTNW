//
//  Reach.swift
//  Global Thermal Nuclear War
//
//  Attacks only where physically possible (3.29.0). A computer-run nation may start a war, strike or invade only
//  where it can get at the target: across a land border (neighbours computed once from the map outlines), by sea
//  (it has a coast and a navy that can cover the distance in its era), or by air and missile (long-range bombers from
//  1945, ballistic missiles from 1960). Territories and colonies count for their owner on both sides. A nation that
//  can't reach its enemy falls back to moves that need no contact: condemnation, covert action, arming rebels,
//  threats. Game-balance numbers, not a logistics model.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum Reach {
    /// How an attacker gets at a target.
    enum Mode: String, Codable { case land, sea, air, missile }

    // MARK: Map adjacency (computed once)

    /// Grid cell size (degrees) for the vertex hash; outlines whose vertices fall in the same or a touching cell are
    /// neighbours (tolerance ≈ 0.4°, so straits like Gibraltar count and open sea doesn't).
    static let cellDegrees = 0.2

    /// Map outline id → the outlines touching it. Built from the bundled Natural Earth outlines (Alaska split from the
    /// U.S. like `WorldMapData`).
    static let shapeNeighbors: [String: Set<String>] = neighbors(bundle: .main)

    static func neighbors(bundle: Bundle) -> [String: Set<String>] {
        struct File: Decodable {
            struct C: Decodable { let id: String; let rings: [[Double]] }
            let countries: [C]
        }
        guard let url = bundle.url(forResource: "world_countries", withExtension: "json"),
              let data = try? Data(contentsOf: url), let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }
        struct Cell: Hashable { let x: Int; let y: Int }
        var cells: [Cell: Set<String>] = [:]
        for c in file.countries {
            for ring in c.rings {
                let alaska = c.id == "USA" && stride(from: 0, to: ring.count - 1, by: 2).allSatisfy { ring[$0] < -129 && ring[$0 + 1] > 50 }
                let id = alaska ? PreStateModel.alaska : c.id
                var i = 0
                while i + 1 < ring.count {
                    cells[Cell(x: Int((ring[i] / cellDegrees).rounded(.down)), y: Int((ring[i + 1] / cellDegrees).rounded(.down))), default: []].insert(id)
                    i += 2
                }
            }
        }
        var out: [String: Set<String>] = [:]
        for (cell, ids) in cells {
            var near = Set<String>()
            for dx in -1...1 { for dy in -1...1 { near.formUnion(cells[Cell(x: cell.x + dx, y: cell.y + dy)] ?? []) } }
            for a in ids { out[a, default: []].formUnion(near.subtracting([a])) }
        }
        return out
    }

    // MARK: Who holds which outline (cached per world state)

    /// What reach needs about a game, built once per turn and territory change (3.29.0: checked for every AI move).
    struct Snapshot {
        /// Map outline → its holders, innermost first.
        var chains: [String: [String]] = [:]
        /// Nation → the nations sharing a land border with anything it holds.
        var neighbors: [String: Set<String>] = [:]
        /// Nation → the centres of everything it holds.
        var places: [String: [Coordinates]] = [:]
        /// Nations with a coast (themselves or a territory).
        var coastal: Set<String> = []
    }

    private static let lock = NSLock()
    private static var cacheKey: [Int] = []
    private static var cache = Snapshot()

    static func snapshot(_ gs: GameState) -> Snapshot {
        let key = [ObjectIdentifier(gs).hashValue, gs.turn, gs.currentYear, gs.countries.count,
                   gs.countries.reduce(0) { $0 &+ ($1.territoryOf?.hashValue ?? 0) &+ ($1.isDestroyed ? 7 : 0) }]
        lock.lock(); defer { lock.unlock() }
        if key == cacheKey { return cache }
        let present = Set(gs.countries.lazy.filter { !$0.isDestroyed }.map(\.id))
        let byID = Dictionary(gs.countries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var s = Snapshot()
        for shape in shapeNeighbors.keys {
            var holder = WorldMapData.owner(of: shape, in: present, year: gs.currentYear)
            if holder == nil, PreStateModel.lands.contains(shape), let st = gs.preState(shape), st.era.kind == .colony, st.ownerPresent {
                holder = st.era.owner
            }
            var chain: [String] = []
            while let h = holder, !chain.contains(h) {
                chain.append(h)
                holder = byID[h]?.territoryOf
            }
            if !chain.isEmpty { s.chains[shape] = chain }
        }
        for (shape, chain) in s.chains {
            var touching = Set<String>()
            for n in shapeNeighbors[shape] ?? [] { touching.formUnion(s.chains[n] ?? []) }
            for h in chain { s.neighbors[h, default: []].formUnion(touching) }
        }
        for h in Array(s.neighbors.keys) { s.neighbors[h]?.remove(h) }
        for c in gs.countries where !c.isDestroyed {
            let holder = c.territoryOf ?? c.id
            s.places[c.id, default: []].append(c.coordinates)
            if c.territoryOf != nil { s.places[holder, default: []].append(c.coordinates) }
            if !NavalModel.isLandlocked(c.id) { s.coastal.insert(c.id); s.coastal.insert(holder) }
        }
        cacheKey = key
        cache = s
        return s
    }

    /// Map outline → its holders, innermost first: the country itself (or a colony's owner), then whoever holds that
    /// country as a territory. An attack on any of them can go through the outline.
    static func chains(in gs: GameState) -> [String: [String]] { snapshot(gs).chains }

    /// The nations sharing a land border with `id` (or with any land `id` holds), in this game and year.
    static func landNeighbors(_ id: String, in gs: GameState) -> Set<String> { snapshot(gs).neighbors[id] ?? [] }

    /// True when some land held by `a` touches some land held by `b`.
    static func shareBorder(_ a: String, _ b: String, in gs: GameState) -> Bool { landNeighbors(a, in: gs).contains(b) }

    // MARK: Distance, coasts, ranges

    /// Great-circle distance, km.
    static func distanceKm(_ a: Coordinates, _ b: Coordinates) -> Double {
        let r = Double.pi / 180
        let dLat = (b.lat - a.lat) * r, dLon = (b.lon - a.lon) * r
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(a.lat * r) * cos(b.lat * r) * sin(dLon / 2) * sin(dLon / 2)
        return 6371 * 2 * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }

    /// Shortest distance between anything `a` holds and anything `b` holds (capitals / land centres), km.
    static func nearestKm(_ a: String, _ b: String, in gs: GameState) -> Double {
        let s = snapshot(gs)
        var best = Double.infinity
        for x in s.places[a] ?? [] { for y in s.places[b] ?? [] { best = min(best, distanceKm(x, y)) } }
        return best
    }

    /// Has a coast: the nation itself or one of its territories is not landlocked.
    static func isCoastal(_ id: String, in gs: GameState) -> Bool { snapshot(gs).coastal.contains(id) }

    /// Navies that crossed oceans from a year, beyond the colonial powers: the Great White Fleet era U.S. Navy, the
    /// Imperial Russian Navy, and China's blue-water navy.
    static let blueWater: [String: Int] = ["USA": 1898, "RUS": 1789, "CHN": 2010]

    /// How far its navy can carry an invasion or a blockade, km. Design choices: the era's blue-water powers reach
    /// anywhere; any other coastal state reaches navalForces × 30 km before 1850, × 45 to 1900, × 70 to 1945, × 100
    /// after, and at least 600 km (coastal raids). Landlocked: 0.
    static func seaRangeKm(_ c: Country, year: Int, coastal: Bool) -> Double {
        guard coastal else { return 0 }
        if WorldPolitics.reachesOverseas(c.id, year: year) || (blueWater[c.id].map { year >= $0 } ?? false) { return .infinity }
        let navy = Double(min(100, max(0, c.navalForces)))
        let perPoint: Double = year < 1850 ? 30 : (year < 1900 ? 45 : (year < 1945 ? 70 : 100))
        return max(600, navy * perPoint)
    }

    /// Air and missile reach, km, and the arm that has it. Ballistic missiles (land or sea launched) from 1960 reach
    /// anywhere; long-range bombers from 1945 (6,000 km, 12,000 from 1955); a strong tactical air force from 1940
    /// covers 1,500 km. Nothing before.
    static func airRange(_ c: Country, year: Int) -> (km: Double, mode: Mode) {
        if year >= 1960 && (c.icbmCount > 0 || c.submarineLaunchedMissiles > 0) { return (.infinity, .missile) }
        if year >= 1945 && c.bombers > 0 { return (year >= 1955 ? 12_000 : 6_000, .air) }
        if year >= 1940 && min(100, c.airForces) >= 40 { return (1_500, .air) }
        return (0, .air)
    }

    // MARK: The check

    /// How `attacker` can get at `target` now, or nil when it can't: land first, then sea, then air / missile.
    static func how(_ attacker: String, _ target: String, in gs: GameState) -> Mode? {
        guard attacker != target, let a = gs.getCountry(id: attacker), let t = gs.getCountry(id: target),
              !a.isDestroyed, !t.isDestroyed else { return nil }
        // A territory fights with its owner's reach.
        let actor = a.territoryOf.flatMap { gs.getCountry(id: $0) } ?? a
        if shareBorder(actor.id, target, in: gs) { return .land }
        let year = gs.currentYear
        let km = nearestKm(actor.id, target, in: gs)
        if isCoastal(target, in: gs), km <= seaRangeKm(actor, year: year, coastal: isCoastal(actor.id, in: gs)) { return .sea }
        let air = airRange(actor, year: year)
        if km <= air.km { return air.mode }
        return nil
    }

    static func canReach(_ attacker: String, _ target: String, in gs: GameState) -> Bool { how(attacker, target, in: gs) != nil }

    /// A blockade needs a coast and a navy that covers the distance, against a target with a coast to close.
    static func canBlockade(_ attacker: String, _ target: String, in gs: GameState) -> Bool {
        guard attacker != target, let a = gs.getCountry(id: attacker), gs.getCountry(id: target) != nil,
              isCoastal(attacker, in: gs), isCoastal(target, in: gs), min(100, max(0, a.navalForces)) >= 5 else { return false }
        return nearestKm(attacker, target, in: gs) <= seaRangeKm(a, year: gs.currentYear, coastal: true)
    }

    /// What a nation that can't reach its enemy does instead: no contact needed.
    static func fallback(for c: Country, against target: String) -> WorldMove {
        if c.nuclearWarheads > 0 { return .threaten(target) }
        switch CountryProfile.stableUnit(c.id + target) {
        case ..<0.4: return .condemn(target)
        case ..<0.7: return .covertAction(target)
        default: return .supportRebels(target)
        }
    }
}
