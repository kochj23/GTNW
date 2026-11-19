//
//  AccessibilityTests.swift
//  GTNWTests
//
//  3.33.0: VoiceOver labels and values for the map and the Situation Room, and Reduce Motion
//  (Shared/Design/Accessibility.swift). Unit, Functional, Security and Frame.
//

import XCTest
import SwiftUI
@testable import GTNW

// MARK: - Unit

final class AccessibilityUnitTests: XCTestCase {

    func testCountryLabelSaysWhoTheyAreToYou() throws {
        let gs = GameState(playerCountryID: "USA", seed: 3)
        let usa = try XCTUnwrap(gs.getCountry(id: "USA"))
        XCTAssertEqual(A11y.countryLabel(usa, in: gs), "\(usa.name), your nation")
        var fra = try XCTUnwrap(gs.getCountry(id: "FRA"))
        fra.atWarWith = ["USA"]
        XCTAssertTrue(A11y.countryLabel(fra, in: gs).hasSuffix("at war with you"))
        let v = A11y.countryValue(fra, in: gs)
        XCTAssertTrue(v.hasPrefix("relations "), v)
        XCTAssertTrue(v.contains("military \(fra.militaryStrength)"), v)
    }

    func testRelationWords() {
        XCTAssertEqual(A11y.relationWord(-90), "hostile")
        XCTAssertEqual(A11y.relationWord(-30), "unfriendly")
        XCTAssertEqual(A11y.relationWord(0), "neutral")
        XCTAssertEqual(A11y.relationWord(40), "friendly")
        XCTAssertEqual(A11y.relationWord(90), "close")
    }

    func testReduceMotionDropsAnimations() {
        defer { Motion.override = nil }
        Motion.override = true
        XCTAssertNil(Motion.allow(.default))
        XCTAssertNil(GTNWAnimations.pulse())
        XCTAssertNil(GTNWAnimations.spring)
        Motion.override = false
        XCTAssertNotNil(Motion.allow(.default))
        XCTAssertNotNil(GTNWAnimations.quick)
    }
}

// MARK: - Functional

final class AccessibilityFunctionalTests: XCTestCase {

    func testEveryNationOnTheMapIsReadableAndThePlayerComesFirst() {
        for year in [1789, 1962, 2025] {
            let gs = GameState(playerCountryID: "USA", boardYear: year, seed: 1)
            let nations = A11y.mapNations(gs)
            XCTAssertEqual(nations.count, gs.countries.filter { !$0.isDestroyed }.count, "\(year)")
            XCTAssertEqual(nations.first?.id, "USA", "\(year)")
            XCTAssertTrue(nations.allSatisfy { !$0.label.isEmpty && !$0.value.isEmpty }, "\(year)")
        }
        let gs = GameState(playerCountryID: "USA", seed: 1)
        XCTAssertTrue(A11y.mapValue(gs, selected: "FRA").hasPrefix("Selected: France."))
        XCTAssertTrue(A11y.statusValue(gs).contains("actions left"))
    }
}

// MARK: - Security (source guards)

final class AccessibilitySecurityTests: XCTestCase {

    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent() }

    private func sources() throws -> [(String, [String])] {
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root.appendingPathComponent("Shared"), includingPropertiesForKeys: nil))
        var out: [(String, [String])] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            out.append((url.lastPathComponent, try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")))
        }
        return out
    }

    /// A bare "−" or "+" button means nothing to VoiceOver; each has a label on its line or the next.
    func testSymbolButtonsHaveLabels() throws {
        var bad: [String] = []
        for (name, lines) in try sources() {
            for (i, l) in lines.enumerated() where l.contains("Button(\"−\")") || l.contains("Button(\"+\")") {
                let next = i + 1 < lines.count ? lines[i + 1] : ""
                if !(l + next).contains("accessibilityLabel") { bad.append("\(name):\(i + 1)") }
            }
        }
        XCTAssertEqual(bad, [])
    }

    /// Endless animations go through `GTNWAnimations` / `Motion`, so Reduce Motion stops them.
    func testRepeatingAnimationsHonourReduceMotion() throws {
        var bad: [String] = []
        for (name, lines) in try sources() {
            for (i, l) in lines.enumerated() where l.contains("repeatForever") {
                // The background blobs (ModernDesign.swift) are guarded by `Motion.reduced` before they start.
                let ok = l.contains("Motion.allow(") || name == "ModernDesign.swift"
                if !ok { bad.append("\(name):\(i + 1)") }
            }
        }
        XCTAssertEqual(bad, [])
    }
}

// MARK: - Frame (the labelled views still render)
//
// SwiftUI builds its accessibility tree only for a live assistive client, so a test host cannot read it back;
// these render the views that now carry labels, in both Reduce Motion states, and check what they are given.

final class AccessibilityFrameTests: XCTestCase {

    @MainActor
    func testLabelledMapAndTickerRenderWithAndWithoutReduceMotion() {
        let gs = GameState(playerCountryID: "USA", seed: 1)
        defer { Motion.override = nil }
        for reduce in [false, true] {
            Motion.override = reduce
            let map = VectorWorldMap(gameState: gs, selectedCountryID: .constant("FRA"), zoom: .constant(.world), filter: .constant(.alignment))
                .frame(width: 900, height: 500)
            XCTAssertNotNil(ImageRenderer(content: map).cgImage, "map, reduce motion \(reduce)")
            let ticker = NewsTicker(items: gs.shadow.ticker).frame(width: 600)
            XCTAssertNotNil(ImageRenderer(content: ticker).cgImage, "ticker, reduce motion \(reduce)")
        }
        XCTAssertTrue(A11y.mapNations(gs).contains { $0.id == "FRA" && $0.label.hasPrefix("France") })
    }
}
