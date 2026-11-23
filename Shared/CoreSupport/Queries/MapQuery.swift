//
//  MapQuery.swift
//  GTNWCore
//
//  `{"q":"map"}`: who holds every outline on the world map this year, the app's VectorWorldMap rules exactly:
//  successor states drawn in their era owner's color (USSR, Yugoslavia…), dependencies by year, territories
//  (hatched), colonies (owner's color, hatched, dashed border), pre-state indigenous land and unclaimed land
//  (parchment), the dots for nations with no outline and for small islands, fleets at sea, and the map flashes (who
//  just did what to whom). Outline ids are the ones in world_countries.json, plus `USA_AK` (Alaska's rings of the
//  U.S. outline, drawn on its own so Russian America shows before 1867).
//

#if GTNW_CORE
import Foundation

enum MapQuery: BridgeQuery {
    static let name = "map"

    struct Land: Encodable {
        /// nation, territory, colony, indigenous, unclaimed, none (no government in this era and not claimable)
        var kind: String
        /// The game country whose color the land takes (the owner of a territory or colony, too).
        var owner: String?
        /// What clicking the outline selects (a country id or the land's own id), nil = nothing.
        var selects: String?
        var label: String?
    }

    struct Dot: Encodable {
        var id: String
        var lat: Double
        var lon: Double
        /// nation (no outline of its own), colony, indigenous (an island nobody in the game holds)
        var kind: String
        var owner: String?
        var label: String
    }

    struct Fleet: Encodable {
        var fromLat: Double
        var fromLon: Double
        var lat: Double
        var lon: Double
    }

    struct Flash: Encodable {
        var ids: [String]
        /// hostile, friendly, disaster
        var tone: String
        var text: String
        var seconds: Double
    }

    struct Result: Encodable {
        var year: Int
        var player: String
        var lands: [String: Land]
        var dots: [Dot]
        var fleets: [Fleet]
        var flashes: [Flash]
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let year = gs.currentYear
        let present = Set(gs.countries.map(\.id))
        let byID = Dictionary(gs.countries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let unclaimed = gs.unclaimedLandIDs
        let shapes = WorldMapData.shared.shapes
        let shapeIDs = Set(shapes.map(\.id))

        var lands: [String: Land] = [:]
        for s in shapes {
            let selects = WorldMapData.selection(for: s.id, in: gs, present: present, unclaimed: unclaimed)
            if let st = gs.preState(s.id) {
                let colony = st.era.kind == .colony && byID[st.era.owner] != nil
                lands[s.id] = Land(kind: colony ? "colony" : "indigenous", owner: colony ? st.era.owner : nil, selects: selects, label: st.label)
            } else if let o = WorldMapData.owner(of: s.id, in: present, year: year), let c = byID[o] {
                if let holder = c.territoryOf, !c.isDestroyed {
                    lands[s.id] = Land(kind: "territory", owner: holder, selects: selects, label: c.name)
                } else {
                    lands[s.id] = Land(kind: "nation", owner: o, selects: selects, label: c.name)
                }
            } else if unclaimed.contains(s.id) {
                lands[s.id] = Land(kind: "unclaimed", owner: nil, selects: selects, label: s.name)
            } else {
                lands[s.id] = Land(kind: "none", owner: nil, selects: selects, label: s.name)
            }
        }

        var dots: [Dot] = gs.countries.filter { !shapeIDs.contains($0.id) && !$0.isDestroyed }.sorted { $0.id < $1.id }.map {
            Dot(id: $0.id, lat: $0.coordinates.lat, lon: $0.coordinates.lon, kind: "nation", owner: $0.territoryOf ?? $0.id, label: $0.name)
        }
        for i in Islands.dots {
            guard let st = gs.preState(i.id) else { continue }
            let colony = st.era.kind == .colony && byID[st.era.owner] != nil
            dots.append(Dot(id: i.id, lat: i.lat, lon: i.lon, kind: colony ? "colony" : "indigenous",
                            owner: colony ? st.era.owner : nil, label: st.label))
        }

        let fleets = gs.shadow.fleetDeployments.map { d -> Fleet in
            let now = d.position(at: gs.currentDate)
            return Fleet(fromLat: d.fromLat, fromLon: d.fromLon, lat: now.lat, lon: now.lon)
        }

        let clock = Date()
        let flashes = gs.mapFlashes.filter { $0.until > clock }.map { f -> Flash in
            let tone: String
            switch f.tone {
            case .hostile: tone = "hostile"
            case .friendly: tone = "friendly"
            case .disaster: tone = "disaster"
            }
            return Flash(ids: f.ids.sorted(), tone: tone, text: f.text, seconds: QueryText.round2(f.until.timeIntervalSince(clock)))
        }
        return Result(year: year, player: gs.playerCountryID, lands: lands, dots: dots, fleets: fleets, flashes: flashes)
    }
}
#endif
