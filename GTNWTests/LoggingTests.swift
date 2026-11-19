//
//  LoggingTests.swift
//  GTNWTests
//
//  3.33.0: `print` replaced by one `os.Logger` per subsystem area (Shared/Engine/Log.swift). Unit, Functional and
//  Security.
//

import XCTest
import OSLog
@testable import GTNW

// MARK: - Unit

final class LoggingUnitTests: XCTestCase {

    func testOneCategoryPerSubsystemArea() {
        XCTAssertEqual(Set(Log.categories).count, Log.categories.count, "categories are distinct")
        XCTAssertEqual(Log.categories.count, 10)
        XCTAssertFalse(Log.subsystem.isEmpty)
    }
}

// MARK: - Functional

final class LoggingFunctionalTests: XCTestCase {

    /// A note written through `Log` reaches the unified log under GTNW's subsystem and the right category.
    func testANoteReachesTheUnifiedLog() throws {
        let marker = "gtnw-log-test-\(UUID().uuidString)"
        Log.engine.note(marker)
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let since = store.position(date: Date().addingTimeInterval(-60))
        let hit = try store.getEntries(at: since)
            .compactMap { $0 as? OSLogEntryLog }
            .first { $0.composedMessage == marker }
        let entry = try XCTUnwrap(hit, "the note is in the log")
        XCTAssertEqual(entry.subsystem, Log.subsystem)
        XCTAssertEqual(entry.category, "engine")
    }
}

// MARK: - Security

final class LoggingSecurityTests: XCTestCase {

    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent() }

    /// No `print` in the app's sources except real command-line output, marked `// cli output`.
    func testNoPrintOutsideCommandLineOutput() throws {
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root.appendingPathComponent("Shared"), includingPropertiesForKeys: nil))
        var offenders: [String] = [], scanned = 0
        let call = try NSRegularExpression(pattern: #"(^|[^A-Za-z0-9_.])print\("#)
        for case let url as URL in files where url.pathExtension == "swift" {
            scanned += 1
            for (n, line) in try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n").enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), call.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil,
                      !line.contains("// cli output") else { continue }
                offenders.append("\(url.lastPathComponent):\(n + 1)")
            }
        }
        XCTAssertGreaterThan(scanned, 100)
        XCTAssertEqual(offenders, [], "use Log.<area>.trace/note/failure")
    }

    /// Failure text can name a host or a path; it is logged private.
    func testFailuresAreLoggedPrivate() throws {
        let src = try String(contentsOf: root.appendingPathComponent("Shared/Engine/Log.swift"), encoding: .utf8)
        let line = try XCTUnwrap(src.components(separatedBy: "\n").first { $0.contains("func failure(") })
        XCTAssertTrue(line.contains("privacy: .private"))
    }
}
