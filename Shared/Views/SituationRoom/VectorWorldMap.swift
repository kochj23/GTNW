//
//  VectorWorldMap.swift
//  Global Thermal Nuclear War
//
//  A bordered world map drawn from Natural Earth country outlines (public domain, bundled as
//  Resources/world_countries.json). Hover and click countries, zoom World / Region / Country, and colour the map by
//  ~20 thematic filters. Hit-testing uses path containment in map coordinates. Countries that no longer exist on the
//  modern map (USSR, Yugoslavia, Czechoslovakia…) claim their successor states' outlines.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

// MARK: - Map data

struct MapCountryShape {
    let id: String
    let name: String
    /// Outline in map units (x = longitude, y = -latitude).
    let path: Path
    let bounds: CGRect
}

final class WorldMapData {
    static let shared = WorldMapData()
    let shapes: [MapCountryShape]

    private struct File: Decodable {
        struct C: Decodable { let id: String; let name: String; let rings: [[Double]] }
        let countries: [C]
    }

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "world_countries", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { shapes = []; return }
        func shape(_ id: String, _ name: String, _ rings: [[Double]]) -> MapCountryShape {
            var p = Path()
            for ring in rings where ring.count >= 6 {
                p.move(to: CGPoint(x: ring[0], y: -ring[1]))
                var i = 2
                while i + 1 < ring.count { p.addLine(to: CGPoint(x: ring[i], y: -ring[i + 1])); i += 2 }
                p.closeSubpath()
            }
            return MapCountryShape(id: id, name: name, path: p, bounds: p.boundingRect)
        }
        var out: [MapCountryShape] = []
        for c in file.countries {   // Antarctica included since 3.10.0
            if c.id == "USA" {
                // 3.13.0: Alaska is its own outline, so Russian America can be drawn before 1867.
                let isAlaska = { (r: [Double]) in stride(from: 0, to: r.count - 1, by: 2).allSatisfy { r[$0] < -129 && r[$0 + 1] > 50 } }
                out.append(shape("USA", c.name, c.rings.filter { !isAlaska($0) }))
                out.append(shape(PreStateModel.alaska, "Alaska", c.rings.filter(isAlaska)))
            } else {
                out.append(shape(c.id, c.name, c.rings))
            }
        }
        shapes = out
    }

    /// Successor-state outlines claimed by historical countries when the modern state isn't in the game.
    static let historicalOwners: [String: [String]] = [
        "RUS": ["UKR", "BLR", "MDA", "EST", "LVA", "LTU", "GEO", "ARM", "AZE", "KAZ", "UZB", "TKM", "KGZ", "TJK"],
        "YUG": ["SRB", "HRV", "BIH", "SVN", "MKD", "MNE", "KOS"],
        "CSK": ["CZE", "SVK"],
        "XKX": ["KOS"],
        "DNK": ["GRL"],
        "USA": [PreStateModel.alaska],
    ]

    /// 3.14.0: who held small dependencies and not-yet-independent lands, by year (first row whose `until` is later
    /// than the year and whose owner is in the game). Lands with no row and no country are colonies (PreStateModel)
    /// or unclaimed land.
    static let dependencies: [String: [(until: Int, owner: String)]] = {
        let gbr = [(9999, "GBR")], fra = [(9999, "FRA")], nld = [(9999, "NLD")]
        let pacificUS = [(1899, "ESP"), (1914, "DEU"), (1945, "JPN"), (9999, "USA")]
        return [
            "PRI": [(1898, "ESP"), (9999, "USA")], "GUM": [(1898, "ESP"), (9999, "USA")], "MNP": pacificUS,
            "FSM": pacificUS, "PLW": pacificUS, "MHL": [(1885, "ESP"), (1914, "DEU"), (1945, "JPN"), (9999, "USA")],
            "ASM": [(1900, "GBR"), (9999, "USA")], "VIR": [(1917, "DNK"), (9999, "USA")],
            "FLK": [(1833, "ESP"), (9999, "GBR")], "SGS": gbr, "BMU": gbr, "CYM": gbr, "TCA": gbr, "VGB": gbr, "AIA": gbr,
            "MSR": gbr, "PCN": gbr, "SHN": gbr, "JEY": gbr, "GGY": gbr, "IMN": gbr, "IOT": [(1814, "FRA"), (9999, "GBR")],
            "ABW": nld, "CUW": nld, "SXM": nld, "SUR": nld, "MAF": fra, "BLM": fra, "SPM": fra, "NCL": fra, "PYF": fra,
            "WLF": fra, "ATF": fra, "FRO": [(9999, "DNK")], "ALA": [(1809, "SWE"), (1917, "RUS"), (9999, "FIN")],
            "NIU": [(1901, "GBR"), (9999, "NZL"), (9999, "GBR")], "COK": [(1901, "GBR"), (9999, "NZL"), (9999, "GBR")],
            "NFK": [(1914, "GBR"), (9999, "AUS")], "HMD": [(1947, "GBR"), (9999, "AUS")], "IOA": [(1955, "GBR"), (9999, "AUS")],
            "NRU": [(1914, "DEU"), (9999, "AUS")], "WSM": [(1914, "DEU"), (9999, "NZL")],
            "FJI": [(9999, "GBR")], "SLB": gbr, "VUT": gbr, "KIR": gbr, "TUV": gbr, "MLT": gbr, "MDV": gbr,
            "ESH": [(1976, "ESP"), (9999, "MAR")], "CYN": [(1878, "TUR"), (1960, "GBR"), (9999, "CYP")],
            "SOL": [(1960, "GBR"), (9999, "SOM")], "MAC": [(1999, "PRT"), (9999, "CHN")], "KAS": [(1947, "IND"), (9999, "IND")],
            "HKG": [(1841, "CHN"), (9999, "GBR")], "TWN": [(1895, "CHN"), (1945, "JPN"), (9999, "CHN")],
            "CYP": [(1878, "TUR"), (9999, "GBR")], "PSE": [(1917, "TUR"), (1948, "GBR"), (9999, "JOR")],
            "LKA": [(1796, "NLD"), (9999, "GBR")], "DZA": [(1830, "TUR"), (9999, "FRA")], "MRT": [(9999, "FRA")],
            "GNQ": [(9999, "ESP")], "TLS": [(1975, "PRT"), (9999, "IDN")], "PRK": [(1910, "KOR"), (1945, "JPN"), (9999, "KOR")],
            "SRB": [(1918, "TUR")], "MNE": [(1918, "TUR")], "MKD": [(1913, "TUR"), (1918, "SRB")], "KOS": [(1913, "TUR"), (1918, "SRB")],
            "HRV": [(1918, "AUT")], "SVN": [(1918, "AUT")], "BIH": [(1878, "TUR"), (1918, "AUT")],
            "CZE": [(1918, "AUT")], "SVK": [(1918, "AUT")],
        ]
    }()

    /// 3.14.0: what clicking an outline selects in this game: the pre-state land, the owning country, or the
    /// unclaimed land (nil = nothing, which the map sweep test forbids).
    static func selection(for shapeID: String, in gs: GameState, present: Set<String>, unclaimed: Set<String>) -> String? {
        if gs.preState(shapeID) != nil { return shapeID }
        if let o = owner(of: shapeID, in: present, year: gs.currentYear) { return o }
        return unclaimed.contains(shapeID) ? shapeID : nil
    }

    /// Which game country owns a map outline in this game (nil = not a player in this era).
    static func owner(of shapeID: String, in present: Set<String>, year: Int = 2025) -> String? {
        if present.contains(shapeID) { return shapeID }
        for (owner, parts) in historicalOwners where parts.contains(shapeID) && present.contains(owner) { return owner }
        if let rows = dependencies[shapeID], let row = rows.first(where: { year < $0.until && present.contains($0.owner) }) { return row.owner }
        return nil
    }
}

// MARK: - Zoom & filters

enum MapZoom: String, CaseIterable, Identifiable {
    case world = "World", region = "Region", country = "Country"
    var id: String { rawValue }
}

enum MapFilter: String, CaseIterable, Identifiable {
    case alignment = "Alliances"
    case relations = "Relations with U.S."
    case ideology = "Ideology"
    case power = "World Powers"
    case economy = "Economy Size"
    case wealth = "Average Earnings"
    case qualityOfLife = "Quality of Life"
    case ethic = "Ethic"
    case ambition = "Ambition"
    case leadership = "Leadership"
    case unrest = "Unrest"
    case war = "Peace / War"
    case military = "Military Strength"
    case nuclear = "Nuclear Level"
    case nuclearAnxiety = "Nuclear Worry"
    case militaryAnxiety = "Military Worry"
    case politicalAnxiety = "Political Worry"
    case economicAnxiety = "Economic Worry"
    case socialAnxiety = "Social Worry"
    case aidNeed = "Aid Needed"
    case strategic = "Strategic Value"
    case population = "Population"
    case radiation = "Radiation"

    var id: String { rawValue }

    /// 0…1 for ramp filters (higher = "hotter"), nil for categorical ones.
    func value(_ c: Country, player: Country?) -> Double? {
        let p = c.profile
        switch self {
        case .alignment, .ideology: return nil
        case .relations: return Double(100 - (player?.diplomaticRelations[c.id] ?? 0)) / 200
        case .power: return Double(c.powerScore) / 100
        case .economy: return min(1, log10(max(c.gdp, 0.001) * 1000 + 1) / 4.5)
        case .wealth: return min(1, (c.gdp * 1000 / Double(max(1, c.population))) / 80)
        case .qualityOfLife: return p.qualityOfLife / 100
        case .ethic: return Double(6 - p.ethic) / 5
        case .ambition: return Double(p.ambition - 1) / 5
        case .leadership: return p.leadership / 100
        case .unrest: return p.outcry / 100
        case .war: return c.atWarWith.isEmpty ? 0 : min(1, 0.5 + Double(c.atWarWith.count) * 0.2)
        case .military: return Double(c.militaryStrength) / 100
        case .nuclear: return c.nuclearWarheads == 0 ? 0 : min(1, log10(Double(c.nuclearWarheads) + 1) / 4)
        case .nuclearAnxiety: return p.anxieties.nuclear / 100
        case .militaryAnxiety: return p.anxieties.military / 100
        case .politicalAnxiety: return p.anxieties.political / 100
        case .economicAnxiety: return p.anxieties.economic / 100
        case .socialAnxiety: return p.anxieties.social / 100
        case .aidNeed: return min(1, p.aidNeed.total / 15)
        case .strategic: return p.strategicValue / 100
        case .population: return min(1, log10(Double(max(1, c.population))) / 3.2)
        case .radiation: return Double(c.radiationLevel) / 100
        }
    }

    /// For ramp filters: does a high value mean "good" (drawn green) rather than "bad" (red)?
    var highIsGood: Bool {
        switch self {
        case .power, .economy, .wealth, .qualityOfLife, .leadership, .military, .strategic, .population: return true
        default: return false
        }
    }

    func color(_ c: Country, player: Country?) -> Color {
        if self == .alignment {
            if Theme.isRetro {
                switch c.alignment {
                case .western: return EGA.lightBlue
                case .eastern: return EGA.red
                case .nonAligned: return EGA.green
                case .independent: return EGA.brown
                }
            }
            return c.color.opacity(0.75)
        }
        if self == .ideology {
            let all = LeaderIdeology.allCases
            let i = all.firstIndex(of: c.profile.ideology) ?? 0
            let palette: [Color] = Theme.isRetro ? Array(EGA.all.dropFirst()) :
                [.blue, .cyan, .teal, .mint, .green, .red, .orange, .brown, .gray, .purple, .pink, .yellow, .indigo]
            return palette[i % palette.count].opacity(Theme.isRetro ? 1 : 0.8)
        }
        let v = max(0, min(1, value(c, player: player) ?? 0))
        let band = min(6, Int(v * 7))
        return MapFilter.rampColor(band: highIsGood ? 6 - band : band)
    }

    /// 7 bands, 0 = calm/good … 6 = crisis/bad.
    static func rampColor(band: Int) -> Color {
        if Theme.isRetro { return EGA.ramp[max(0, min(6, band))] }
        let colors: [Color] = [Color(red: 0.1, green: 0.35, blue: 0.75), Color(red: 0.1, green: 0.55, blue: 0.7),
                               Color(red: 0.2, green: 0.65, blue: 0.4), Color(red: 0.55, green: 0.75, blue: 0.25),
                               Color(red: 0.9, green: 0.75, blue: 0.2), Color(red: 0.95, green: 0.5, blue: 0.15),
                               Color(red: 0.9, green: 0.2, blue: 0.2)]
        return colors[max(0, min(6, band))]
    }
}

// MARK: - The map view

struct VectorWorldMap: View {
    @ObservedObject var gameState: GameState
    @Binding var selectedCountryID: String?
    @Binding var zoom: MapZoom
    @Binding var filter: MapFilter
    @State private var hoverID: String?

    private let data = WorldMapData.shared
    private static let worldRect = CGRect(x: -180, y: -84, width: 360, height: 158)   // lat 84N … 74S (Antarctica's coast, 3.10.0)

    var body: some View {
        GeometryReader { geo in
            let rect = viewRect(aspect: geo.size.width / max(1, geo.size.height))
            let t = transform(rect: rect, size: geo.size)
            let present = Set(gameState.countries.map(\.id))
            let byID = Dictionary(gameState.countries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let player = gameState.getPlayerCountry()
            let unclaimed = gameState.unclaimedLandIDs
            // 3.13.0: pre-state land on every continent: colonies (owner's colour, hatched) and indigenous-held land.
            let pre = Dictionary(uniqueKeysWithValues: PreStateModel.lands.compactMap { id in gameState.preState(id).map { (id, $0) } })
            ZStack(alignment: .bottomLeading) {
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(oceanColor))
                    for s in data.shapes {
                        let path = s.path.applying(t)
                        guard path.boundingRect.intersects(CGRect(origin: .zero, size: size)) else { continue }
                        let ownerID = pre[s.id] == nil ? WorldMapData.owner(of: s.id, in: present, year: gameState.currentYear) : nil
                        var fill = unclaimedColor
                        var territory = false
                        var colonyOwner: Country?
                        if let st = pre[s.id] {
                            if st.era.kind == .colony, let own = byID[st.era.owner] {
                                colonyOwner = own
                                fill = filter.color(own, player: player)
                            } else {
                                fill = Self.claimableColor
                            }
                            if s.id == selectedCountryID { fill = Theme.isRetro ? EGA.lightMagenta : Color(red: 1.0, green: 0.85, blue: 0.25) }
                            else if s.id == hoverID { fill = Theme.isRetro ? EGA.lightRed : fill.opacity(0.55) }
                        }
                        // Land no government holds in this era (3.3.0): parchment under every filter, and selectable.
                        if ownerID == nil, unclaimed.contains(s.id) {
                            fill = s.id == selectedCountryID ? (Theme.isRetro ? EGA.lightMagenta : Color(red: 1.0, green: 0.85, blue: 0.25))
                                 : (s.id == hoverID ? (Theme.isRetro ? EGA.lightRed : Self.claimableColor.opacity(0.55)) : Self.claimableColor)
                        }
                        if let o = ownerID, let c = byID[o] {
                            fill = c.isDestroyed ? Color.black : filter.color(c, player: player)
                            // A territory takes its owner's colour on the Alliances map, and is hatched on every map.
                            if let ownerOf = c.territoryOf, !c.isDestroyed {
                                territory = true
                                if filter == .alignment, let own = byID[ownerOf] { fill = filter.color(own, player: player) }
                            }
                            if o == selectedCountryID { fill = Theme.isRetro ? EGA.lightMagenta : Color(red: 1.0, green: 0.85, blue: 0.25) }
                            else if o == hoverID { fill = Theme.isRetro ? EGA.lightRed : fill.opacity(0.55) }
                        }
                        ctx.fill(path, with: .color(fill))
                        if colonyOwner != nil {
                            Self.hatch(&ctx, path, spacing: 7)
                            ctx.stroke(path, with: .color(borderColor), style: StrokeStyle(lineWidth: zoom == .world ? 0.6 : 1.2, dash: [2, 2]))
                        } else if territory {
                            Self.hatch(&ctx, path)
                            ctx.stroke(path, with: .color(Self.territoryInk), style: StrokeStyle(lineWidth: zoom == .world ? 1 : 1.6, dash: [3, 2]))
                        } else {
                            ctx.stroke(path, with: .color(borderColor), lineWidth: zoom == .world ? 0.5 : 1)
                        }
                    }
                    // Fleets at sea (3.5.0): a dashed wake from home port to where the fleet is now.
                    for d in gameState.shadow.fleetDeployments {
                        let now = d.position(at: gameState.currentDate)
                        var wake = Path()
                        wake.move(to: CGPoint(x: d.fromLon, y: -d.fromLat).applying(t))
                        wake.addLine(to: CGPoint(x: now.lon, y: -now.lat).applying(t))
                        ctx.stroke(wake, with: .color(Self.fleetInk), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                    }
                    // Countries with no outline (micro-states, East Germany…) get a dot.
                    for c in gameState.countries where !hasShape(c.id) && !c.isDestroyed {
                        let pt = CGPoint(x: c.coordinates.lon, y: -c.coordinates.lat).applying(t)
                        let r: CGFloat = c.id == selectedCountryID ? 5 : 3
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                                 with: .color(c.id == selectedCountryID ? EGA.lightRed : filter.color(c, player: player)))
                    }
                }
                markers(transform: t, byID: byID, unclaimed: unclaimed)
                preStateTags(transform: t, pre: pre)
                hoverLabel(byID: byID, unclaimed: unclaimed, pre: pre)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                if let id = hit(v.location, transform: t, present: present, unclaimed: unclaimed, pre: Set(pre.keys)) {
                    selectedCountryID = id
                    if zoom == .world { ShadowPack.shared.play("sfx.boop", volume: 0.4) }
                }
            })
            .modifier(HoverTracker { loc in hoverID = loc.flatMap { hit($0, transform: t, present: present, unclaimed: unclaimed, pre: Set(pre.keys)) } })
            .clipped()
        }
    }

    // MARK: Drawing helpers

    private var oceanColor: Color { Theme.isRetro ? EGA.blue : Color(red: 0.02, green: 0.06, blue: 0.14) }
    private var borderColor: Color { Theme.isRetro ? EGA.yellow : Color.cyan.opacity(0.45) }
    private var unclaimedColor: Color { Theme.isRetro ? EGA.darkGray : Color.gray.opacity(0.25) }

    /// Unclaimed land (3.3.0): parchment on the modern map, light gray on the EGA map (unplayable land stays dark gray).
    static var claimableColor: Color { Theme.isRetro ? EGA.lightGray : Color(red: 0.80, green: 0.72, blue: 0.52).opacity(0.6) }

    /// "New Spain (Spain)": the selected or hovered colony / people at world zoom, every roomy one zoomed in (3.13.0).
    @ViewBuilder
    private func preStateTags(transform t: CGAffineTransform, pre: [String: PreStateStatus]) -> some View {
        let pinned = Set([selectedCountryID, hoverID].compactMap { $0 }).intersection(pre.keys)
        let roomy = zoom == .world ? Set<String>() : Set(pre.keys.filter { id in
            (data.shapes.first { $0.id == id }?.bounds.applying(t).width ?? 0) > FontScale.w(90)
        })
        ForEach(Array(pinned.union(roomy)).sorted(), id: \.self) { id in
            if let st = pre[id], let tpl = PreStateModel.template(id) {
                Text(verbatim: st.label)
                    .font(ThemeFont.mono(zoom == .world ? 7 : 9, .bold))
                    .foregroundColor(Theme.isRetro ? EGA.black : .black)
                    .padding(.horizontal, 2)
                    .background(st.era.kind == .colony ? (Theme.isRetro ? EGA.lightCyan : Color(white: 0.9)) : (Theme.isRetro ? EGA.yellow : Color(red: 0.93, green: 0.87, blue: 0.70)))
                    .position(CGPoint(x: tpl.lon, y: -tpl.lat).applying(t))
                    .allowsHitTesting(false)
            }
        }
    }

    /// Fleets at sea and their wakes (3.5.0).
    static var fleetInk: Color { Theme.isRetro ? EGA.lightCyan : Color(red: 0.4, green: 0.9, blue: 1.0) }

    /// Ink for territory hatching and borders.
    static var territoryInk: Color { Theme.isRetro ? EGA.white : Color.white.opacity(0.7) }

    /// Diagonal stripes clipped to a path: how the map marks a territory under any filter.
    static func hatch(_ ctx: inout GraphicsContext, _ path: Path, spacing: CGFloat = 5) {
        var layer = ctx
        layer.clip(to: path)
        let r = path.boundingRect
        var stripes = Path()
        var x = r.minX - r.height
        while x < r.maxX {
            stripes.move(to: CGPoint(x: x, y: r.maxY))
            stripes.addLine(to: CGPoint(x: x + r.height, y: r.minY))
            x += spacing
        }
        layer.stroke(stripes, with: .color(territoryInk), lineWidth: 0.8)
    }

    private func hasShape(_ id: String) -> Bool {
        data.shapes.contains { $0.id == id } || WorldMapData.historicalOwners[id] != nil
    }

    @ViewBuilder
    private func markers(transform t: CGAffineTransform, byID: [String: Country], unclaimed: Set<String>) -> some View {
        let struck = Set(gameState.nuclearStrikes.map(\.target))
        let warring = Set(gameState.shadow.fronts.filter { $0.status == .fighting }.map(\.defender))
        // UNCLAIMED tags: the land selected or under the pointer, plus (zoomed in) every land wide enough to hold one.
        let pinned = unclaimed.intersection([selectedCountryID, hoverID].compactMap { $0 })
        let roomy = zoom == .world ? [] : unclaimed.filter { id in
            (data.shapes.first { $0.id == id }?.bounds.applying(t).width ?? 0) > FontScale.w(70)
        }
        let tagged = pinned.union(roomy)
        ForEach(gameState.shadow.fleetDeployments) { d in
            let p = d.position(at: gameState.currentDate)
            Text(verbatim: "⚓ \((NavalModel.fleet(id: d.fleetID)?.name ?? d.fleetID).uppercased())")
                .font(ThemeFont.mono(zoom == .world ? 7 : 9, .bold))
                .foregroundColor(Theme.isRetro ? EGA.black : .black)
                .padding(.horizontal, 2)
                .background(Self.fleetInk)
                .position(CGPoint(x: p.lon, y: -p.lat).applying(t))
                .allowsHitTesting(false)
        }
        ForEach(tagged.sorted().compactMap { WorldCountriesDatabase.template(id: $0) }, id: \.id) { land in
            Text("UNCLAIMED")
                .font(ThemeFont.mono(zoom == .world ? 7 : 9, .bold))
                .foregroundColor(Theme.isRetro ? EGA.black : .black)
                .padding(.horizontal, 2)
                .background(Theme.isRetro ? EGA.yellow : Color(red: 0.93, green: 0.87, blue: 0.70))
                .position(CGPoint(x: land.lon, y: -land.lat).applying(t))
                .allowsHitTesting(false)
        }
        ForEach(gameState.countries.filter { $0.isTerritory && !$0.isDestroyed }, id: \.id) { c in
            Text(gameState.territoryLabel(c))
                .font(ThemeFont.mono(zoom == .world ? 7 : 9, .bold))
                .foregroundColor(Theme.isRetro ? EGA.white : .white)
                .padding(.horizontal, 2)
                .background(Theme.isRetro ? EGA.blue : Color.blue.opacity(0.7))
                .position(CGPoint(x: c.coordinates.lon, y: -c.coordinates.lat).applying(t))
                .offset(y: 12)
                .allowsHitTesting(false)
        }
        ForEach(Array(struck.union(warring)).sorted(), id: \.self) { id in
            if let c = byID[id] {
                let pt = CGPoint(x: c.coordinates.lon, y: -c.coordinates.lat).applying(t)
                Group {
                    if struck.contains(id) {
                        PackImage("map.nuke_marker1") {
                            Text("☢").font(.scaled(size: 16)).foregroundColor(Theme.isRetro ? EGA.yellow : .yellow)
                        }
                        .frame(width: FontScale.w(22), height: FontScale.h(20))
                    } else {
                        Text("⚔").font(.scaled(size: 13, weight: .bold)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                            .shadow(color: .black, radius: 1)
                    }
                }
                .position(pt)
                .allowsHitTesting(false)
            }
        }
    }

    private func hoverLabel(byID: [String: Country], unclaimed: Set<String>, pre: [String: PreStateStatus]) -> some View {
        let id = hoverID ?? selectedCountryID
        let text: String = {
            if let id, let st = pre[id] {
                return st.era.kind == .colony ? "\(st.label.uppercased()) — COLONY" : "\(st.label.uppercased()) — PEOPLES NOT MODELLED AS A STATE"
            }
            if let id, unclaimed.contains(id) {
                return "UNCLAIMED LAND — \(WorldCountriesDatabase.template(id: id)?.name ?? id)"
            }
            guard let id, let c = byID[id] else { return "Click a country" }
            if let o = c.territoryOf {
                let owner = byID[o]
                return "\(owner?.flag ?? "") \(gameState.territoryLabel(c)) — \(c.name)"
            }
            return "\(c.flag) \(c.name) / \(c.region.rawValue)"
        }()
        return Text(verbatim: text)
            .font(ThemeFont.mono(12, .bold))
            .foregroundColor(Theme.isRetro ? EGA.white : .white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.isRetro ? EGA.black : Color.black.opacity(0.6))
            .padding(6)
            .allowsHitTesting(false)
    }

    // MARK: Geometry

    private func viewRect(aspect: CGFloat) -> CGRect {
        var r = Self.worldRect
        let selected = selectedCountryID.flatMap { gameState.getCountry(id: $0) }
        // An unclaimed land frames like a country, from its template.
        let land = selected == nil ? selectedCountryID.flatMap { WorldCountriesDatabase.template(id: $0) } : nil
        let unclaimed = gameState.unclaimedLandIDs
        switch zoom {
        case .world: break
        case .region:
            // 3.18.x: a curated box per region. The old code unioned raw shape bounds, but regions crossing the
            // ±180° antimeridian (North America's Aleutians, Asia's Russia, Oceania's Pacific islands) made a
            // ~300°-wide box that tripped bounds()'s "width > 200 -> whole world" guard, so Region never zoomed.
            if let region = selected?.region ?? land?.region { r = Self.regionRect(region) }
        case .country:
            if let id = selected?.id ?? land?.id { r = bounds(for: [id])?.insetBy(dx: -4, dy: -4) ?? r }
        }
        // Keep the aspect ratio of the view so outlines aren't stretched.
        let minW: CGFloat = 12
        if r.width < minW { r = r.insetBy(dx: -(minW - r.width) / 2, dy: 0) }
        let want = r.width / max(0.01, r.height)
        if want < aspect { let w = r.height * aspect; r = r.insetBy(dx: -(w - r.width) / 2, dy: 0) }
        else { let h = r.width / aspect; r = r.insetBy(dx: 0, dy: -(h - r.height) / 2) }
        return r
    }

    /// A framing box (lon, −lat) per world region, antimeridian-safe (far-Pacific tails are intentionally
    /// cropped so the box stays tight and never trips the whole-world fallback).
    /// ponytail: hand-tuned rects; nudge the framing here if a region sits awkwardly.
    static func regionRect(_ region: WorldRegion) -> CGRect {
        switch region {
        case .northAmerica: return CGRect(x: -170, y: -72, width: 122, height: 65)   // Alaska → Panama (Aleutians cropped)
        case .southAmerica: return CGRect(x: -82,  y: -13, width: 48,  height: 69)
        case .europe:       return CGRect(x: -25,  y: -71, width: 70,  height: 37)
        case .asia:         return CGRect(x: 40,   y: -76, width: 110, height: 72)    // Russia's far-east tail cropped
        case .middleEast:   return CGRect(x: 25,   y: -42, width: 40,  height: 31)
        case .africa:       return CGRect(x: -20,  y: -38, width: 72,  height: 74)
        case .oceania:      return CGRect(x: 110,  y: 8,   width: 70,  height: 42)    // Australia + NZ (far Pacific cropped)
        }
    }

    private func bounds(for ids: Set<String>) -> CGRect? {
        let present = Set(gameState.countries.map(\.id))
        var out: CGRect?
        for s in data.shapes {
            let o = WorldMapData.owner(of: s.id, in: present, year: gameState.currentYear) ?? s.id   // unowned outlines: unclaimed land (3.3.0)
            guard ids.contains(o) else { continue }
            // Ignore far-flung overseas territories when framing (e.g. French Guiana for France).
            out = out.map { $0.union(s.bounds) } ?? s.bounds
        }
        if out == nil, let c = ids.first.flatMap({ gameState.getCountry(id: $0) }) {
            out = CGRect(x: c.coordinates.lon - 5, y: -c.coordinates.lat - 4, width: 10, height: 8)
        }
        if let r = out, r.width > 200 { return Self.worldRect }
        return out?.insetBy(dx: -2, dy: -2)
    }

    private func transform(rect: CGRect, size: CGSize) -> CGAffineTransform {
        let sx = size.width / rect.width, sy = size.height / rect.height
        return CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: -rect.minX * sx, ty: -rect.minY * sy)
    }

    private func hit(_ location: CGPoint, transform t: CGAffineTransform, present: Set<String>, unclaimed: Set<String>, pre: Set<String> = []) -> String? {
        let p = location.applying(t.inverted())
        for s in data.shapes where s.bounds.contains(p) && s.path.contains(p) {
            if let id = WorldMapData.selection(for: s.id, in: gameState, present: present, unclaimed: unclaimed) { return id }
        }
        // Dots for shapeless countries.
        let near = gameState.countries.filter { !hasShape($0.id) }.min {
            hypot($0.coordinates.lon - p.x, -$0.coordinates.lat - p.y) < hypot($1.coordinates.lon - p.x, -$1.coordinates.lat - p.y)
        }
        if let n = near, hypot(n.coordinates.lon - p.x, -n.coordinates.lat - p.y) < 1.5 { return n.id }
        return nil
    }
}

/// Mouse hover on macOS 13+/iOS 16+; a no-op elsewhere.
private struct HoverTracker: ViewModifier {
    let onMove: (CGPoint?) -> Void
    func body(content: Content) -> some View {
        if #available(macOS 13.0, iOS 16.0, *) {
            content.onContinuousHover { phase in
                switch phase {
                case .active(let p): onMove(p)
                case .ended: onMove(nil)
                }
            }
        } else {
            content
        }
    }
}

/// Legend for the current filter.
struct MapLegend: View {
    let filter: MapFilter
    /// Adds an "Unclaimed" swatch (3.3.0) when the era has land nobody governs.
    var showUnclaimed = false

    var body: some View {
        HStack(spacing: 4) {
            switch filter {
            case .alignment:
                ForEach([("Western", PoliticalAlignment.western), ("Eastern", .eastern), ("Non-aligned", .nonAligned), ("Independent", .independent)], id: \.0) { item in
                    swatch(MapFilter.alignment.color(Country.legendStub(item.1), player: nil), item.0)
                }
                territorySwatch
            case .ideology:
                Text("Coloured by ideology — hover a country for details").font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            default:
                Text(filter.highIsGood ? "low" : "calm").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                ForEach(0..<7, id: \.self) { b in
                    Rectangle().fill(MapFilter.rampColor(band: filter.highIsGood ? 6 - b : b)).frame(width: FontScale.w(16), height: FontScale.h(9))
                }
                Text(filter.highIsGood ? "high" : "crisis").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
            }
            if showUnclaimed {
                swatch(VectorWorldMap.claimableColor, "Unclaimed / peoples")
                HStack(spacing: 3) {   // 3.13.0: colonies, in their owner's colour under a wider hatch
                    Canvas { ctx, size in
                        let r = Path(CGRect(origin: .zero, size: size))
                        ctx.fill(r, with: .color(Color.gray))
                        VectorWorldMap.hatch(&ctx, r, spacing: 4)
                    }
                    .frame(width: FontScale.w(12), height: FontScale.h(9))
                    Text("Colony").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                }
            }
        }
    }

    /// "Territory": the owner's colour under diagonal hatching, as drawn on the map.
    private var territorySwatch: some View {
        HStack(spacing: 3) {
            Canvas { ctx, size in
                let r = Path(CGRect(origin: .zero, size: size))
                ctx.fill(r, with: .color(MapFilter.alignment.color(Country.legendStub(.western), player: nil)))
                VectorWorldMap.hatch(&ctx, r, spacing: 3)
            }
            .frame(width: FontScale.w(12), height: FontScale.h(9))
            Text("Territory").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
        }
    }

    private func swatch(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            Rectangle().fill(c).frame(width: FontScale.w(12), height: FontScale.h(9))
            Text(label).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
        }
    }
}

private extension Country {
    /// A throwaway country used only to colour legend swatches.
    static func legendStub(_ alignment: PoliticalAlignment) -> Country {
        Country(id: "LEGEND", name: "", code: "", flag: "", capital: "", region: .europe, lat: 0, lon: 0,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0, bombers: 0,
                militaryStrength: 1, gdp: 1, population: 1, economicStrength: 1, government: .democracy,
                alignment: alignment, stability: 50)
    }
}
