//
//  ShadowPack.swift
//  Global Thermal Nuclear War
//
//  Optional local art & sound pack harvested from the user's own copy of Shadow President (1993, D.C. True).
//  The pack is NOT part of this repository: tools/build_shadow_pack.py writes it to
//  ~/Library/Application Support/GTNW/ShadowPack (CATALOG.json + images, GIF animations and WAV sounds).
//  Every caller falls back to GTNW's own look when the pack — or a given asset — is missing.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation
import SwiftUI
import AVFoundation
import ImageIO

#if canImport(AppKit)
import AppKit
typealias PackPlatformImage = NSImage
#else
import UIKit
typealias PackPlatformImage = UIImage
#endif

/// One asset in the pack's CATALOG.json.
struct ShadowPackEntry: Codable, Hashable {
    let id: String
    let kind: String          // image | sprite | animation | sound | map | capture
    let path: String
    let depicts: String?
    let width: Int?
    let height: Int?
}

private struct ShadowPackCatalog: Codable {
    let version: Int?
    let entries: [ShadowPackEntry]
}

/// Decoded animation: frames plus per-frame delay (seconds).
struct ShadowPackAnimation {
    let frames: [CGImage]
    let delays: [Double]
    var duration: Double { delays.reduce(0, +) }
}

final class ShadowPack: ObservableObject {
    static let shared = ShadowPack()

    @Published private(set) var isInstalled = false
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "ShadowPack.soundEnabled") }
    }
    @Published var useRetroArt: Bool {
        didSet { UserDefaults.standard.set(useRetroArt, forKey: "ShadowPack.useRetroArt") }
    }

    let folder: URL
    private var entries: [String: ShadowPackEntry] = [:]
    private var imageCache: [String: PackPlatformImage] = [:]
    private var animationCache: [String: ShadowPackAnimation] = [:]
    private var players: [AVAudioPlayer] = []
    private let lock = NSLock()

    static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GTNW/ShadowPack", isDirectory: true)
    }

    init(folder: URL = ShadowPack.defaultFolder) {
        self.folder = folder
        let d = UserDefaults.standard
        soundEnabled = d.object(forKey: "ShadowPack.soundEnabled") as? Bool ?? true
        useRetroArt = d.object(forKey: "ShadowPack.useRetroArt") as? Bool ?? true
        reload()
    }

    /// Re-read CATALOG.json (after the user builds or updates the pack).
    func reload() {
        lock.lock(); defer { lock.unlock() }
        imageCache.removeAll(); animationCache.removeAll()
        let url = folder.appendingPathComponent("CATALOG.json")
        guard let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(ShadowPackCatalog.self, from: data) else {
            entries = [:]; isInstalled = false; return
        }
        entries = Dictionary(catalog.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        isInstalled = !entries.isEmpty
    }

    var count: Int { entries.count }

    func entry(_ id: String) -> ShadowPackEntry? { entries[id] }

    func url(_ id: String) -> URL? {
        guard let e = entries[id] else { return nil }
        let u = folder.appendingPathComponent(e.path)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    /// Ids starting with a prefix, e.g. ids(prefix: "sfx.").
    func ids(prefix: String) -> [String] { entries.keys.filter { $0.hasPrefix(prefix) }.sorted() }

    // MARK: Images

    func image(_ id: String) -> PackPlatformImage? {
        guard useRetroArt else { return nil }
        lock.lock(); defer { lock.unlock() }
        if let cached = imageCache[id] { return cached }
        guard let e = entries[id] else { return nil }
        let u = folder.appendingPathComponent(e.path)
        #if canImport(AppKit)
        let img = NSImage(contentsOf: u)
        #else
        let img = UIImage(contentsOfFile: u.path)
        #endif
        if let img { imageCache[id] = img }
        return img
    }

    /// First id in the list that the pack has (lets callers ask for "aspect-corrected, else original").
    func firstImage(_ ids: [String]) -> PackPlatformImage? {
        for id in ids { if let img = image(id) { return img } }
        return nil
    }

    // MARK: Animations (GIF)

    func animation(_ id: String) -> ShadowPackAnimation? {
        guard useRetroArt else { return nil }
        lock.lock(); defer { lock.unlock() }
        if let cached = animationCache[id] { return cached }
        guard let e = entries[id], let src = CGImageSourceCreateWithURL(folder.appendingPathComponent(e.path) as CFURL, nil)
        else { return nil }
        let n = CGImageSourceGetCount(src)
        guard n > 0 else { return nil }
        var frames: [CGImage] = [], delays: [Double] = []
        for i in 0..<n {
            guard let f = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            frames.append(f)
            delays.append(Self.gifDelay(src, i))
        }
        let anim = ShadowPackAnimation(frames: frames, delays: delays)
        animationCache[id] = anim
        return anim
    }

    static func gifDelay(_ src: CGImageSource, _ i: Int) -> Double {
        let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
        let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let d = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
        return d < 0.02 ? 0.1 : d
    }

    // MARK: Sounds

    /// Play a pack sound (e.g. "sfx.nuke_strike"). Returns false when sound is off or the pack lacks it.
    @discardableResult
    func play(_ id: String, volume: Float = 1) -> Bool {
        guard soundEnabled, let u = url(id), let p = try? AVAudioPlayer(contentsOf: u) else { return false }
        p.volume = volume
        p.play()
        lock.lock()
        players.removeAll { !$0.isPlaying }
        players.append(p)
        lock.unlock()
        return true
    }

    // MARK: Mapping GTNW concepts to pack ids

    /// Shadow President had seven advisors; map a GTNW cabinet title onto the matching portrait key.
    static func advisorKey(forTitle title: String) -> String? {
        let t = title.lowercased()
        if t.contains("national security") { return "nsa" }
        if t.contains("state") && !t.contains("homeland") { return "state" }
        if t.contains("defense") || t.contains("of war") || t.contains("joint chiefs") { return "defense" }
        if t.contains("treasury") || t.contains("economic") || t.contains("commerce") { return "economic" }
        if t.contains("cia") || t.contains("central intelligence") || t.contains("national intelligence") { return "cia" }
        if t.contains("chief of staff") { return "whc" }
        if t.contains("press") { return "press" }
        return nil
    }

    func advisorPortrait(title: String) -> PackPlatformImage? {
        guard let key = Self.advisorKey(forTitle: title) else { return nil }
        return image("advisor.\(key).portrait")
    }
}

// MARK: - SwiftUI helpers

extension Image {
    init(packImage: PackPlatformImage) {
        #if canImport(AppKit)
        self.init(nsImage: packImage)
        #else
        self.init(uiImage: packImage)
        #endif
    }
}

/// Shows a pack image, or `fallback` when the pack (or that asset) isn't installed. Pixel art stays crisp.
struct PackImage<Fallback: View>: View {
    @ObservedObject private var pack = ShadowPack.shared
    let ids: [String]
    let fallback: Fallback

    init(_ ids: String..., @ViewBuilder fallback: () -> Fallback) {
        self.ids = ids
        self.fallback = fallback()
    }

    var body: some View {
        if let img = pack.firstImage(ids) {
            Image(packImage: img).interpolation(.none).resizable().aspectRatio(contentMode: .fit)
        } else {
            fallback
        }
    }
}

/// Plays a pack GIF animation once (or looping); falls back when missing.
struct PackAnimationView<Fallback: View>: View {
    let id: String
    var loop = false
    let fallback: Fallback
    @State private var start = Date()

    init(_ id: String, loop: Bool = false, @ViewBuilder fallback: () -> Fallback) {
        self.id = id; self.loop = loop; self.fallback = fallback()
    }

    var body: some View {
        if let anim = ShadowPack.shared.animation(id), !anim.frames.isEmpty {
            TimelineView(.animation) { ctx in
                let frame = Self.frameIndex(anim, elapsed: ctx.date.timeIntervalSince(start), loop: loop)
                Image(decorative: anim.frames[frame], scale: 1).interpolation(.none).resizable().aspectRatio(contentMode: .fit)
            }
            .onAppear { start = Date() }
        } else {
            fallback
        }
    }

    static func frameIndex(_ anim: ShadowPackAnimation, elapsed: Double, loop: Bool) -> Int {
        guard anim.duration > 0 else { return 0 }
        var t = loop ? elapsed.truncatingRemainder(dividingBy: anim.duration) : min(elapsed, anim.duration)
        for (i, d) in anim.delays.enumerated() {
            if t < d { return i }
            t -= d
        }
        return anim.frames.count - 1
    }
}

// MARK: - Action media

extension ShadowPack {
    /// Shadow President animation and sound for a GTNW action, keyed by the action's case name.
    static func media(forActionCase name: String) -> (animation: String?, sound: String?) {
        switch name {
        case "airStrike", "bombardment", "specialForces", "amphAssault":
            return ("anim.surgical", "sfx.warning")
        case "infiltrate", "deploySpies", "stealSecrets", "stealTech", "humint", "sigint", "imint", "satellite",
             "bugEmbassy", "trackTroops", "infiltrateSci", "doubleAgent", "turnAgent", "extractAsset", "codeBreak":
            return ("anim.spying", nil)
        case "sabotageInfra", "sabotageNuke", "cyberAttack", "disruptComms":
            return ("anim.sabotage.sabotage", nil)
        case "assassinate", "poison":
            return ("anim.death1", "sfx.assassination")
        case "armsControl", "deployMissiles", "removeMissiles":
            return ("anim.negarms", "sfx.negotiation")
        case "nonProliferation", "haltNukes", "noFirstUse", "demandInspect":
            return ("anim.negnuke", "sfx.negotiation")
        case "ceasefire", "peace", "mediateConflict", "summit", "nonAggression", "proposeTreaty", "signTreaty",
             "mutualDefense", "freeTrade", "extradition":
            return ("anim.negpeace", "sfx.negotiation")
        case "foodAid", "economicAid", "techAssist", "forgiveDebt":
            return ("anim.socreform", "sfx.social_reform")
        case "nuclearTest", "sellNukeTech", "nukeSharing":
            return ("anim.threaten", "sfx.nuclear_threat")
        case "launchNukes", "tacticalNuke", "strategicNuke", "preemptive", "retaliate", "firstStrike":
            return (nil, "sfx.nuke_strike")
        case "demandApology", "expelDiplomats", "severRelations", "sanctions", "oilEmbargo", "freezeAssets":
            return (nil, "sfx.condemnation")
        default:
            return (nil, "sfx.popup")
        }
    }
}

// MARK: - Settings (macOS Settings window; iOS 15 lacks LabeledContent/formStyle)

#if os(macOS)
struct ShadowPackSettingsView: View {
    @ObservedObject private var pack = ShadowPack.shared

    var body: some View {
        Form {
            Section("Shadow President pack") {
                LabeledContent("Status", value: pack.isInstalled ? "Installed — \(pack.count) assets" : "Not installed")
                Text(pack.folder.path).font(.scaled(.caption)).foregroundStyle(.secondary).textSelection(.enabled)
                Toggle("Use retro art (portraits, War Room, animations)", isOn: $pack.useRetroArt).toggleStyle(.scaledCheckbox)
                Toggle("Play retro sound effects", isOn: $pack.soundEnabled).toggleStyle(.scaledCheckbox)
                Button("Reload pack") { pack.reload() }
                Button("Test sound") { pack.play("sfx.hail_to_chief") }.disabled(!pack.isInstalled)
            }
            Section {
                Text("The pack is built locally from your own copy of Shadow President (1993) with tools/build_shadow_pack.py. "
                     + "It is personal data and is never part of the GTNW repository.")
                    .font(.scaled(.caption)).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: FontScale.w(460))
        .padding()
    }
}
#endif
