//
//  ShadowPackTests.swift
//  GTNWTests
//
//  The Shadow Pack is optional local data; these tests build a tiny throwaway pack in a temp folder.
//

import XCTest
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
@testable import GTNW

final class ShadowPackTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("ShadowPackTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("pics"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func writePNG(_ name: String, size: Int = 4) throws {
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let dest = CGImageDestinationCreateWithURL(dir.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
    }

    private func writeGIF(_ name: String, frames: Int, delay: Double) throws {
        let dest = CGImageDestinationCreateWithURL(dir.appendingPathComponent(name) as CFURL, UTType.gif.identifier as CFString, frames, nil)!
        for i in 0..<frames {
            let ctx = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            // distinct frames: the GIF encoder merges identical consecutive frames
            ctx.setFillColor(CGColor(red: CGFloat(i) / CGFloat(max(frames - 1, 1)), green: 0.2, blue: 0.5, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            CGImageDestinationAddImage(dest, ctx.makeImage()!,
                                       [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(dest))
    }

    private func writeCatalog(_ entries: [[String: Any]]) throws {
        let data = try JSONSerialization.data(withJSONObject: ["version": 1, "entries": entries])
        try data.write(to: dir.appendingPathComponent("CATALOG.json"))
    }

    // MARK: unit

    func testMissingPackFallsBackCleanly() {
        let pack = ShadowPack(folder: dir)
        XCTAssertFalse(pack.isInstalled)
        XCTAssertNil(pack.image("advisor.cia.portrait"))
        XCTAssertNil(pack.animation("anim.surgical"))
        XCTAssertFalse(pack.play("sfx.nuke_strike"))
    }

    func testCatalogImagesAndAnimationsLoad() throws {
        try writePNG("pics/cia.png")
        try writeGIF("pics/spy.gif", frames: 3, delay: 0.2)
        try writeCatalog([
            ["id": "advisor.cia.portrait", "kind": "image", "path": "pics/cia.png", "width": 4, "height": 4],
            ["id": "anim.spying", "kind": "animation", "path": "pics/spy.gif"],
            ["id": "sfx.missing", "kind": "sound", "path": "sounds/none.wav"],
        ])
        let pack = ShadowPack(folder: dir)
        pack.useRetroArt = true
        XCTAssertTrue(pack.isInstalled)
        XCTAssertEqual(pack.count, 3)
        XCTAssertNotNil(pack.image("advisor.cia.portrait"))
        XCTAssertNotNil(pack.advisorPortrait(title: "CIA Director"))
        XCTAssertNil(pack.url("sfx.missing"), "catalog entries without a file are treated as absent")
        let anim = try XCTUnwrap(pack.animation("anim.spying"))
        XCTAssertEqual(anim.frames.count, 3)
        XCTAssertEqual(anim.duration, 0.6, accuracy: 0.05)
    }

    func testRetroArtToggleHidesArt() throws {
        try writePNG("pics/cia.png")
        try writeCatalog([["id": "advisor.cia.portrait", "kind": "image", "path": "pics/cia.png"]])
        let pack = ShadowPack(folder: dir)
        pack.useRetroArt = false
        XCTAssertNil(pack.image("advisor.cia.portrait"))
        pack.useRetroArt = true
        XCTAssertNotNil(pack.image("advisor.cia.portrait"))
    }

    func testAdvisorTitlesMapToShadowPresidentPortraits() {
        XCTAssertEqual(ShadowPack.advisorKey(forTitle: "Secretary of State"), "state")
        XCTAssertEqual(ShadowPack.advisorKey(forTitle: "Secretary of Defense"), "defense")
        XCTAssertEqual(ShadowPack.advisorKey(forTitle: "Secretary of War"), "defense")
        XCTAssertEqual(ShadowPack.advisorKey(forTitle: "Chairman, Joint Chiefs"), "defense")
        XCTAssertEqual(ShadowPack.advisorKey(forTitle: "Secretary of Treasury"), "economic")
        XCTAssertEqual(ShadowPack.advisorKey(forTitle: "CIA Director"), "cia")
        XCTAssertEqual(ShadowPack.advisorKey(forTitle: "Director of National Intelligence"), "cia")
        XCTAssertEqual(ShadowPack.advisorKey(forTitle: "National Security Advisor"), "nsa")
        XCTAssertEqual(ShadowPack.advisorKey(forTitle: "Chief of Staff"), "whc")
        XCTAssertEqual(ShadowPack.advisorKey(forTitle: "Press Secretary"), "press")
        XCTAssertNil(ShadowPack.advisorKey(forTitle: "Secretary of Homeland Security"))
        XCTAssertNil(ShadowPack.advisorKey(forTitle: "Attorney General"))
    }

    func testEveryActionHasMediaAndSignatureActionsAnimate() {
        for action in PresidentialAction.allCases {
            let m = ShadowPack.media(forActionCase: String(describing: action))
            XCTAssertTrue(m.animation != nil || m.sound != nil, "\(action) has no media")
        }
        XCTAssertEqual(ShadowPack.media(forActionCase: "assassinate").animation, "anim.death1")
        XCTAssertEqual(ShadowPack.media(forActionCase: "airStrike").animation, "anim.surgical")
        XCTAssertEqual(ShadowPack.media(forActionCase: "strategicNuke").sound, "sfx.nuke_strike")
    }

    func testAnimationFrameTiming() {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let img = ctx.makeImage()!
        let anim = ShadowPackAnimation(frames: [img, img, img], delays: [0.1, 0.2, 0.3])
        XCTAssertEqual(PackAnimationView<EmptyView>.frameIndex(anim, elapsed: 0.05, loop: false), 0)
        XCTAssertEqual(PackAnimationView<EmptyView>.frameIndex(anim, elapsed: 0.25, loop: false), 1)
        XCTAssertEqual(PackAnimationView<EmptyView>.frameIndex(anim, elapsed: 5, loop: false), 2)
        XCTAssertEqual(PackAnimationView<EmptyView>.frameIndex(anim, elapsed: 0.65, loop: true), 0)
    }

    // MARK: security / licensing

    func testPackLivesOutsideTheAppAndRepo() {
        // Shadow President art is personal local data: it must load from Application Support, never the bundle/repo.
        // (.gitignore coverage is checked by tools/build_shadow_pack.py's sibling guard in CI/pre-commit, not here:
        // reading the repo from a test host triggers a removable-volume privacy prompt.)
        let path = ShadowPack.defaultFolder.path
        XCTAssertTrue(path.contains("Application Support/GTNW/ShadowPack"), path)
        XCTAssertFalse(path.hasPrefix(Bundle.main.bundlePath))
    }

    // MARK: performance

    func testLargeCatalogLoadsQuickly() throws {
        let entries = (0..<5000).map { ["id": "city.tile\($0)", "kind": "sprite", "path": "pics/t\($0).png"] }
        try writeCatalog(entries)
        // plain timing instead of measure{}: XCTest's metric reporting symbolicates from /Volumes/Data, which can
        // block on a removable-volume privacy prompt in the test host
        let start = Date()
        XCTAssertEqual(ShadowPack(folder: dir).count, 5000)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
    }
}
