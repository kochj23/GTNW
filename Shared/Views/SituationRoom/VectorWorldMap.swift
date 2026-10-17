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
        shapes = file.countries.filter { $0.id != "ATA" }.map { c in
            var p = Path()
            for ring in c.rings where ring.count >= 6 {
                p.move(to: CGPoint(x: ring[0], y: -ring[1]))
                var i = 2
                while i + 1 < ring.count { p.addLine(to: CGPoint(x: ring[i], y: -ring[i + 1])); i += 2 }
                p.closeSubpath()
            }
            return MapCountryShape(id: c.id, name: c.name, path: p, bounds: p.boundingRect)
        }
    }

    /// Successor-state outlines claimed by historical countries when the modern state isn't in the game.
    static let historicalOwners: [String: [String]] = [
        "RUS": ["UKR", "BLR", "MDA", "EST", "LVA", "LTU", "GEO", "ARM", "AZE", "KAZ", "UZB", "TKM", "KGZ", "TJK"],
        "YUG": ["SRB", "HRV", "BIH", "SVN", "MKD", "MNE", "KOS"],
        "CSK": ["CZE", "SVK"],
        "XKX": ["KOS"],
        "DNK": ["GRL"],
    ]

    /// Which game country owns a map outline in this game (nil = not a player in this era).
    static func owner(of shapeID: String, in present: Set<String>) -> String? {
        if present.contains(shapeID) { return shapeID }
        for (owner, parts) in historicalOwners where parts.contains(shapeID) && present.contains(owner) { return owner }
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
    private static let worldRect = CGRect(x: -180, y: -84, width: 360, height: 140)   // lat 84N … 56S

    var body: some View {
        GeometryReader { geo in
            let rect = viewRect(aspect: geo.size.width / max(1, geo.size.height))
            let t = transform(rect: rect, size: geo.size)
            let present = Set(gameState.countries.map(\.id))
            let byID = Dictionary(gameState.countries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let player = gameState.getPlayerCountry()
            ZStack(alignment: .bottomLeading) {
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(oceanColor))
                    for s in data.shapes {
                        let path = s.path.applying(t)
                        guard path.boundingRect.intersects(CGRect(origin: .zero, size: size)) else { continue }
                        let ownerID = WorldMapData.owner(of: s.id, in: present)
                        var fill = unclaimedColor
                        if let o = ownerID, let c = byID[o] {
                            fill = c.isDestroyed ? Color.black : filter.color(c, player: player)
                            if o == selectedCountryID { fill = Theme.isRetro ? EGA.lightMagenta : Color(red: 1.0, green: 0.85, blue: 0.25) }
                            else if o == hoverID { fill = Theme.isRetro ? EGA.lightRed : fill.opacity(0.55) }
                        }
                        ctx.fill(path, with: .color(fill))
                        ctx.stroke(path, with: .color(borderColor), lineWidth: zoom == .world ? 0.5 : 1)
                    }
                    // Countries with no outline (micro-states, East Germany…) get a dot.
                    for c in gameState.countries where !hasShape(c.id) && !c.isDestroyed {
                        let pt = CGPoint(x: c.coordinates.lon, y: -c.coordinates.lat).applying(t)
                        let r: CGFloat = c.id == selectedCountryID ? 5 : 3
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                                 with: .color(c.id == selectedCountryID ? EGA.lightRed : filter.color(c, player: player)))
                    }
                }
                markers(transform: t, byID: byID)
                hoverLabel(byID: byID)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                if let id = hit(v.location, transform: t, present: present) {
                    selectedCountryID = id
                    if zoom == .world { ShadowPack.shared.play("sfx.boop", volume: 0.4) }
                }
            })
            .modifier(HoverTracker { loc in hoverID = loc.flatMap { hit($0, transform: t, present: present) } })
            .clipped()
        }
    }

    // MARK: Drawing helpers

    private var oceanColor: Color { Theme.isRetro ? EGA.blue : Color(red: 0.02, green: 0.06, blue: 0.14) }
    private var borderColor: Color { Theme.isRetro ? EGA.yellow : Color.cyan.opacity(0.45) }
    private var unclaimedColor: Color { Theme.isRetro ? EGA.darkGray : Color.gray.opacity(0.25) }

    private func hasShape(_ id: String) -> Bool {
        data.shapes.contains { $0.id == id } || WorldMapData.historicalOwners[id] != nil
    }

    @ViewBuilder
    private func markers(transform t: CGAffineTransform, byID: [String: Country]) -> some View {
        let struck = Set(gameState.nuclearStrikes.map(\.target))
        let warring = Set(gameState.shadow.fronts.filter { $0.status == .fighting }.map(\.defender))
        ForEach(Array(struck.union(warring)).sorted(), id: \.self) { id in
            if let c = byID[id] {
                let pt = CGPoint(x: c.coordinates.lon, y: -c.coordinates.lat).applying(t)
                Group {
                    if struck.contains(id) {
                        PackImage("map.nuke_marker1") {
                            Text("☢").font(.system(size: 16)).foregroundColor(Theme.isRetro ? EGA.yellow : .yellow)
                        }
                        .frame(width: 22, height: 20)
                    } else {
                        Text("⚔").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                            .shadow(color: .black, radius: 1)
                    }
                }
                .position(pt)
                .allowsHitTesting(false)
            }
        }
    }

    private func hoverLabel(byID: [String: Country]) -> some View {
        let id = hoverID ?? selectedCountryID
        let text: String = {
            guard let id, let c = byID[id] else { return "Click a country" }
            return "\(c.flag) \(c.name) / \(c.region.rawValue)"
        }()
        return Text(text)
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
        switch zoom {
        case .world: break
        case .region:
            if let sel = selected {
                let ids = Set(gameState.countries.filter { $0.region == sel.region }.map(\.id))
                r = bounds(for: ids) ?? r
            }
        case .country:
            if let sel = selected { r = bounds(for: [sel.id])?.insetBy(dx: -4, dy: -4) ?? r }
        }
        // Keep the aspect ratio of the view so outlines aren't stretched.
        let minW: CGFloat = 12
        if r.width < minW { r = r.insetBy(dx: -(minW - r.width) / 2, dy: 0) }
        let want = r.width / max(0.01, r.height)
        if want < aspect { let w = r.height * aspect; r = r.insetBy(dx: -(w - r.width) / 2, dy: 0) }
        else { let h = r.width / aspect; r = r.insetBy(dx: 0, dy: -(h - r.height) / 2) }
        return r
    }

    private func bounds(for ids: Set<String>) -> CGRect? {
        let present = Set(gameState.countries.map(\.id))
        var out: CGRect?
        for s in data.shapes {
            guard let o = WorldMapData.owner(of: s.id, in: present), ids.contains(o) else { continue }
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

    private func hit(_ location: CGPoint, transform t: CGAffineTransform, present: Set<String>) -> String? {
        let p = location.applying(t.inverted())
        for s in data.shapes where s.bounds.contains(p) && s.path.contains(p) {
            if let o = WorldMapData.owner(of: s.id, in: present) { return o }
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

    var body: some View {
        HStack(spacing: 4) {
            switch filter {
            case .alignment:
                ForEach([("Western", PoliticalAlignment.western), ("Eastern", .eastern), ("Non-aligned", .nonAligned), ("Independent", .independent)], id: \.0) { item in
                    swatch(MapFilter.alignment.color(Country.legendStub(item.1), player: nil), item.0)
                }
            case .ideology:
                Text("Coloured by ideology — hover a country for details").font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            default:
                Text(filter.highIsGood ? "low" : "calm").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                ForEach(0..<7, id: \.self) { b in
                    Rectangle().fill(MapFilter.rampColor(band: filter.highIsGood ? 6 - b : b)).frame(width: 16, height: 9)
                }
                Text(filter.highIsGood ? "high" : "crisis").font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
            }
        }
    }

    private func swatch(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            Rectangle().fill(c).frame(width: 12, height: 9)
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
