//
//  RepoHygieneTests.swift
//  GTNWTests
//
//  3.33.0: the repository root stays tidy and the README's test count stays true. Unit and Security.
//

import XCTest

private let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

// MARK: - Unit

final class RepoHygieneUnitTests: XCTestCase {

    /// The Tests badge and the Testing section name the number of test methods in GTNWTests.
    func testReadmeTestCountMatchesTheSuite() throws {
        let tests = repoRoot.appendingPathComponent("GTNWTests")
        let decl = try NSRegularExpression(pattern: #"^\s*(@MainActor\s+)?func test[A-Za-z0-9_]*\("#, options: .anchorsMatchLines)
        var count = 0
        for name in try FileManager.default.contentsOfDirectory(atPath: tests.path) where name.hasSuffix(".swift") {
            let src = try String(contentsOf: tests.appendingPathComponent(name), encoding: .utf8)
            count += decl.numberOfMatches(in: src, range: NSRange(src.startIndex..., in: src))
        }
        let readme = try String(contentsOf: repoRoot.appendingPathComponent("README.md"), encoding: .utf8)
        XCTAssertTrue(readme.contains("badge/tests-\(count)-"), "README badge should say \(count)")
        XCTAssertTrue(readme.contains("The suite has **\(count) tests"), "README Testing section should say \(count)")
    }
}

// MARK: - Security (nothing stale or one-off at the root)

final class RepoHygieneSecurityTests: XCTestCase {

    func testRootHoldsOnlyTheStandardDocsAndNoPatchScripts() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: repoRoot.path)
        let docs = Set(names.filter { $0.hasSuffix(".md") })
        XCTAssertEqual(docs, ["README.md", "CHANGELOG.md", "CODE_OF_CONDUCT.md", "CONTRIBUTING.md", "SECURITY.md"],
                       "status and plan notes belong in Documentation/archive")
        XCTAssertEqual(names.filter { $0.hasSuffix(".rb") }, [], "one-off project patch scripts are not kept at the root")
    }
}
