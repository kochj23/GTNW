//
//  SubdivisionMap.swift
//  Global Thermal Nuclear War
//
//  3.36.0: states and provinces on the Situation Room map (app only; GTNWCore keeps the data in
//  Shared/Engine/Shadow/Subdivisions.swift and never loads this geometry, so the WebAssembly build is unchanged).
//  Resources/subdivisions.json (Natural Earth admin-1, public domain, simplified by tools/natural_earth_admin1_to_gtnw.py)
//  holds each subdivision's outer rings, for hit-testing and fills, and the borders two subdivisions share, drawn
//  faintly inside a nation. A province held by someone other than its nation (a seceded state, an annexed province,
//  a Confederate state) is filled in its holder's color; one an army occupies is hatched in the occupier's.
//  Repository: https://github.com/kochj23/GTNW
//

#if !GTNW_CORE
import SwiftUI

/// The map setting (Situation Room map controls): draw states and provinces.
enum SubdivisionMapSetting {
    static let key = "gtnw.map.subdivisions"
}

final class SubdivisionGeometry {
    static let shared = SubdivisionGeometry()

    struct Outline { let id: String; let path: Path; let bounds: CGRect }
    struct Border { let a: String; let b: String; let path: Path; let bounds: CGRect }

    let outlines: [String: Outline]
    /// Smallest first, so a city-state inside a province (Berlin in Brandenburg, Moscow in its oblast) wins a click.
    let bySize: [Outline]
    let borders: [Border]

    private struct File: Decodable {
        struct S: Decodable { let id: String; let rings: [[Double]] }
        struct B: Decodable { let a: String; let b: String; let lines: [[Double]] }
        let subdivisions: [S]
        let borders: [B]
    }

    init(data: Data? = GameResources.data("subdivisions")) {
        guard let data, let file = try? JSONDecoder().decode(File.self, from: data) else {
            outlines = [:]; bySize = []; borders = []
            return
        }
        func path(_ rings: [[Double]], closed: Bool) -> Path {
            var p = Path()
            for r in rings where r.count >= 4 {
                p.move(to: CGPoint(x: r[0], y: -r[1]))
                var i = 2
                while i + 1 < r.count { p.addLine(to: CGPoint(x: r[i], y: -r[i + 1])); i += 2 }
                if closed { p.closeSubpath() }
            }
            return p
        }
        var o: [String: Outline] = [:]
        for s in file.subdivisions {
            let p = path(s.rings, closed: true)
            o[s.id] = Outline(id: s.id, path: p, bounds: p.boundingRect)
        }
        outlines = o
        bySize = o.values.sorted { ($0.bounds.width * $0.bounds.height, $0.id) < ($1.bounds.width * $1.bounds.height, $1.id) }
        borders = file.borders.map { b in
            let p = path(b.lines, closed: false)
            return Border(a: b.a, b: b.b, path: p, bounds: p.boundingRect)
        }
    }

    /// The subdivision under a point in map units (x = longitude, y = -latitude), among those that exist.
    func hit(_ p: CGPoint, live: Set<String>) -> String? {
        bySize.first { live.contains($0.id) && $0.bounds.contains(p) && $0.path.contains(p) }?.id
    }
}

/// What the map shows about states and provinces this redraw.
struct SubdivisionLayer {
    let gs: GameState
    let live: Set<String>
    /// Provinces held by someone other than their nation, and their holder.
    let held: [String: String]
    let occupied: [String: String]
    /// The map setting: inner borders, labels and hover (fills for land that changed hands are always drawn).
    let borders: Bool

    init(_ gs: GameState, borders: Bool = true) {
        self.gs = gs
        self.borders = borders
        let holders = gs.provinceHolders()
        let live = Set(gs.subdivisions().map(\.id))
        self.live = live
        held = holders.owner.filter { holders.home[$0.key] != $0.value }
        occupied = gs.shadow.provinces.occupied.filter { live.contains($0.key) }
    }

    static var borderInk: Color { Theme.isRetro ? EGA.darkGray : Color.white.opacity(0.22) }

    /// Fills for provinces that changed hands or are occupied, then the faint inner borders.
    func draw(_ ctx: inout GraphicsContext, transform t: CGAffineTransform, size: CGSize, zoom: MapZoom,
              color: (Country) -> Color) {
        let geo = SubdivisionGeometry.shared
        let screen = CGRect(origin: .zero, size: size)
        for (id, owner) in held.sorted(by: { $0.key < $1.key }) {
            guard let o = geo.outlines[id], let c = gs.getCountry(id: owner) else { continue }
            let path = o.path.applying(t)
            guard path.boundingRect.intersects(screen) else { continue }
            ctx.fill(path, with: .color(c.isDestroyed ? .black : color(c)))
            if owner != id { VectorWorldMap.hatch(&ctx, path, spacing: 6) }   // annexed (a seceded nation is solid)
        }
        for (id, occupier) in occupied.sorted(by: { $0.key < $1.key }) {
            guard let o = geo.outlines[id], let c = gs.getCountry(id: occupier) else { continue }
            let path = o.path.applying(t)
            guard path.boundingRect.intersects(screen) else { continue }
            var layer = ctx
            layer.clip(to: path)
            let r = path.boundingRect
            var stripes = Path()
            var x = r.minX - r.height
            while x < r.maxX {
                stripes.move(to: CGPoint(x: x, y: r.maxY))
                stripes.addLine(to: CGPoint(x: x + r.height, y: r.minY))
                x += 4
            }
            layer.stroke(stripes, with: .color(color(c)), lineWidth: 1.4)
        }
        guard borders else { return }
        let width: CGFloat = zoom == .world ? 0.35 : (zoom == .region ? 0.6 : 0.9)
        let ink = Self.borderInk
        for b in geo.borders where live.contains(b.a) || live.contains(b.b) {
            let r = b.bounds.applying(t)
            guard r.intersects(screen), max(r.width, r.height) > 1.5 else { continue }
            ctx.stroke(b.path.applying(t), with: .color(ink), style: StrokeStyle(lineWidth: width, dash: Theme.isRetro ? [2, 2] : []))
        }
    }

    /// Labels for provinces wide enough on screen to carry one (zoomed in only), with the President's names.
    func labels(transform t: CGAffineTransform, zoom: MapZoom) -> [(id: String, text: String, at: CGPoint)] {
        guard zoom != .world else { return [] }
        let geo = SubdivisionGeometry.shared
        let minWidth = FontScale.w(zoom == .region ? 70 : 44)
        return live.sorted().compactMap { id in
            guard let o = geo.outlines[id], let s = Subdivisions.byID[id] else { return nil }
            guard o.bounds.applying(t).width > minWidth else { return nil }
            return (id, gs.provinceName(id), CGPoint(x: s.lon, y: -s.lat).applying(t))
        }
    }

    /// "CALIFORNIA — STATE · 12.1% OF THE PEOPLE · UNITED STATES": the hover / tap line.
    func describe(_ id: String) -> String {
        guard let s = Subdivisions.byID[id] else { return id }
        let h = Subdivisions.historical(s, on: gs.currentDate)
        var parts = ["\(gs.provinceName(id)) — \(h.kind)"]
        if gs.shadow.provinces.names[id] != nil { parts[0] += " (\(h.name))" }
        let share = gs.populationShare(id) * 100
        parts.append(share >= 0.1 ? String(format: "%.1f%% of the people", share) : "under 0.1% of the people")
        if let o = gs.provinceOwner(id) { parts.append(gs.getCountry(id: o)?.name ?? o) }
        if let occ = gs.shadow.provinces.occupied[id] { parts.append("occupied by \(gs.getCountry(id: occ)?.name ?? occ)") }
        if let u = gs.shadow.provinces.unrest[id], u >= 30 { parts.append("unrest \(Int(u.rounded()))") }
        return parts.joined(separator: " · ")
    }
}

/// The last presidential election state by state, as a small map (the end screen).
struct ElectionStateMap: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        let shares = gameState.shadow.provinces.lastElection
        let third = gameState.shadow.provinces.thirdCarried
        let geo = SubdivisionGeometry.shared
        let ids = shares.keys.filter { geo.outlines[$0] != nil }.sorted()
        let won = shares.filter { $0.value > 50 && !third.contains($0.key) }.count
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "ELECTION MAP \(gameState.shadow.provinces.lastElectionYear.map(String.init) ?? "")")
                .font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber)
            Canvas { ctx, size in
                // The lower 48 (Alaska and Hawaii would shrink it to nothing).
                let frame = CGRect(x: -125, y: -50, width: 59, height: 26)
                let s = min(size.width / frame.width, size.height / frame.height)
                let t = CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: -frame.minX * s, ty: -frame.minY * s)
                for id in ids {
                    guard let o = geo.outlines[id], let v = shares[id] else { continue }
                    let fill: Color = third.contains(id) ? (Theme.isRetro ? EGA.yellow : .yellow)
                        : (v > 50 ? (Theme.isRetro ? EGA.lightGreen : Color(red: 0.2, green: 0.75, blue: 0.35))
                                  : (Theme.isRetro ? EGA.lightRed : Color(red: 0.85, green: 0.25, blue: 0.25)))
                    let p = o.path.applying(t)
                    ctx.fill(p, with: .color(fill.opacity(Theme.isRetro ? 1 : 0.35 + min(0.6, abs(v - 50) / 20))))
                    ctx.stroke(p, with: .color(Theme.isRetro ? EGA.black : .black.opacity(0.6)), lineWidth: 0.5)
                }
            }
            .frame(height: FontScale.h(150))
            Text(verbatim: "\(won) states for you · \(shares.count - won - third.count) against\(third.isEmpty ? "" : " · \(third.count) third candidate")")
                .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Election map")
        .accessibilityValue("\(won) states for you, \(shares.count - won - third.count) against"
                            + (third.isEmpty ? "" : ", \(third.count) for the third candidate"))
    }
}
/// 3.36.0's peace term on the surrender sheet: annex only the provinces the army holds.
struct OccupiedProvincesOption: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var gameState: GameState
    let settlement: PostWarSettlement

    var body: some View {
        let held = gameEngine.occupiedProvinces(for: settlement.id)
        if !held.isEmpty {
            let names = held.map { gameState.provinceName($0.id) }
            let list = names.count <= 6 ? names.joined(separator: ", ") : names.prefix(6).joined(separator: ", ") + " and \(names.count - 6) more"
            let share = Int((held.reduce(0) { $0 + gameState.populationShare($1.id) } * 100).rounded())
            let loser = gameState.getCountry(id: settlement.loser)?.name ?? settlement.loser
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ANNEX THE OCCUPIED PROVINCES (\(held.count))").font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber)
                    Text(verbatim: "\(list): about \(share)% of \(loser)'s people. \(loser) keeps its government and the rest of its land, "
                         + "pays reparations and is capped like any loser; the world minds less than a whole nation swallowed.")
                        .font(ThemeFont.mono(10)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("ANNEX PROVINCES") { gameEngine.annexOccupied(settlement.id) }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalAmber, prominent: true))
                    .accessibilityLabel("Annex the occupied provinces: \(list)")
            }
            .padding(8)
            .themedPanel()
        }
    }
}
#endif
