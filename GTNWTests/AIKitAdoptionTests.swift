//
//  AIKitAdoptionTests.swift
//  GTNWTests
//
//  GTNW's contract with NovaAIKit (ADOPTION.md step 8): every AI feature works with AI off and with every backend
//  down, the validators reject nonsense, the Keychain names stay com.jkoch.gtnw.*, old settings migrate, and no
//  copy of the old AI client is left in the sources. In-memory store, stub session — no network, no Keychain.
//
//  Created by Jordan Koch on 2026.
//

import XCTest
import NovaAIKit
@testable import GTNW

final class AIKitAdoptionTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetShared() }
    @MainActor override func tearDown() async throws { AIFixtures.resetShared() }

    /// Feature 1+2: AI off → every AI feature still produces its built-in result, and nothing is sent.
    @MainActor
    func testEveryFeatureWorksWithAIOff() async {
        let rec = RequestRecorder()
        let off = KitTest.ai(KitTest.settings { $0.enabled = false }, transport: rec.transport(body: KitTest.ollama("AI")))
        let text = await GameAI.shared.text(prompt: "p", ai: off, fallback: { "built-in" })
        XCTAssertEqual(text.value, "built-in")
        XCTAssertEqual(text.source, .fallback(.disabled))
        let line = await NovaCommentary.liveLine("headline", system: NovaCommentary.systemPrompt,
                                                 temperature: 0.9, maxTokens: 60, ai: off)
        XCTAssertNil(line, "Nova keeps her template line")
        let gs = GameState(playerCountryID: "USA")
        let advice = await TerminalAdvisor(ai: off).getStrategicAdvice(situation: "what should I do", gameState: gs)
        XCTAssertEqual(advice, TerminalAdvisor.builtInAdvice(gameState: gs))
        var disabled = KitTest.settings()
        disabled.enabled = false
        var c = AIFixtures.config(KitTest.engine(transport: rec.transport(body: AIFixtures.declareWarOnUSA), settings: disabled))
        c.gatewayTimeout = 2
        let move = await BrainClient.requestMove(AIFixtures.request, brain: .gatewayClaude, config: c)
        XCTAssertNil(move, "the country plays rule-based")
        XCTAssertTrue(rec.requests.isEmpty)
    }

    /// Feature 2+7: every backend down → built-in result, no hang.
    @MainActor
    func testEveryFeatureFallsBackWhenOffline() async {
        let down = KitTest.ai()   // every request refused
        let start = Date()
        let text = await GameAI.shared.text(prompt: "p", ai: down, fallback: { "built-in" })
        XCTAssertEqual(text.value, "built-in")
        XCTAssertFalse(text.isAI)
        do { _ = try await GameAI.shared.generate(prompt: "p", ai: down); XCTFail("must throw") } catch {}
        let line = await NovaCommentary.liveLine("h", system: "s", temperature: 0.5, maxTokens: 10, ai: down)
        XCTAssertNil(line)
        let move = await BrainClient.requestMove(AIFixtures.request, brain: .gatewayClaude, config: AIFixtures.config(KitTest.engine()))
        XCTAssertNil(move)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
        await down.refreshStatus()
        XCTAssertEqual(down.status.state, .offline)
        XCTAssertNil(GameAI.shared.activeBackend, "shared AI under XCTest is offline too")
    }

    /// Feature 8: the validators reject out-of-range or junk output.
    func testValidatorRejectsNonsense() throws {
        XCTAssertThrowsError(try GameAI.validateText("   "))
        XCTAssertThrowsError(try GameAI.validateText("<think>only thinking</think>"))
        XCTAssertThrowsError(try GameAI.validateText("?!?! ..."))
        XCTAssertEqual(try GameAI.validateText(" <think>x</think>DEFCON 2. "), "DEFCON 2.")
        XCTAssertNil(MoveResponse.decode(fromText: "I think we should wait."), "moves must be JSON")
        XCTAssertNotNil(MoveResponse.decode(fromText: #"Sure: {"action":"WAIT"}"#))
    }

    /// Feature 4: GTNW's Keychain services (the same items 3.23 used — existing keys keep working).
    func testKeychainServiceNames() {
        let c = AppAI.configuration
        XCTAssertEqual(c.keychainService(for: .openRouter), "com.jkoch.gtnw.openrouter")
        XCTAssertEqual(c.keychainService(for: .openAI), "com.jkoch.gtnw.openai")
        XCTAssertEqual(NovaAIConfiguration.keychainAccount, "apiKey")
        XCTAssertNil(c.keychainAccessGroup, "login keychain, as before")
    }

    /// Step 3: legacy migration maps the old settings (throwaway UserDefaults suite).
    @MainActor
    func testLegacySettingsMigrate() {
        let (d, name) = KitTest.defaultsSuite()
        defer { UserDefaults().removePersistentDomain(forName: name) }
        d.set("MLX Toolkit", forKey: "AIBackendManager_SelectedBackend")
        d.set("http://nova-core8:11434", forKey: "AIBackendManager_OllamaURL")
        let ai = KitTest.ai()
        let report = AppAI.migrateLegacySettings(ai, defaults: d)
        XCTAssertTrue(report.settingsImported)
        XCTAssertEqual(ai.settings.backend, .mlx)
        XCTAssertEqual(ai.settings.url(for: .ollama), "http://nova-core8:11434")
        XCTAssertNil(d.object(forKey: "AIBackendManager_SelectedBackend"))
    }

    /// The shared instance under tests never touches real settings, keys or servers.
    @MainActor
    func testSharedInstanceIsHermeticUnderTests() async {
        let ai = AppAI.shared
        XCTAssertEqual(ai.configuration.appID, "gtnw")
        XCTAssertTrue(ai.keys.store is NovaAIMemoryKeyStore)
        let r = await GameAI.shared.text(prompt: "x", fallback: { "local" })
        XCTAssertEqual(r.value, "local")
    }

    /// No old AI code left (ADOPTION step 7).
    func testNoLegacyAIClientInSources() throws {
        let root = AIFixtures.repoRoot.appendingPathComponent("Shared")
        let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var files = 0
        while let url = e?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            files += 1
            let text = try String(contentsOf: url, encoding: .utf8)
            for gone in ["AIBackendManager.shared", "class AIBackendManager", "EthicalAIGuardian", "AIBackendStatusMenu",
                         "OPENAI_API_KEY", "AIBackend_OpenAI_Key", "OllamaService", "MLXManager", "OpenAICompatibleRequest"] {
                XCTAssertFalse(text.contains(gone), "\(gone) in \(url.lastPathComponent)")
            }
        }
        XCTAssertGreaterThan(files, 50)
        for deleted in ["Shared/Models/AIBackendManager.swift", "Shared/Models/OllamaService.swift", "Shared/Models/MLXIntegration.swift",
                        "Shared/AI/LLMBackendType.swift", "Shared/AI/AIKeyStore.swift", "Shared/AI/AIBackendSettingsView.swift"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: AIFixtures.repoRoot.appendingPathComponent(deleted).path), deleted)
        }
    }
}
