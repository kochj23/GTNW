//
//  AIOptionsTests.swift
//  GTNWTests
//
//  The AI options layer (3.23.0): global switch, canonical backend ids + migration, Auto order and failover,
//  editable endpoints, Keychain-only keys (OpenRouter brains now send theirs), https-only keys, output sanitising,
//  status and settings UI. One XCTestCase per category: Unit, Security, Retry, Performance, Integration,
//  Functional, Frame. No real network and no real Keychain items (tests use a per-run service prefix).
//
//  Created by Jordan Koch on 2026.
//

import XCTest
import SwiftUI
@testable import GTNW

// MARK: - Shared helpers

/// Records every request a transport sees (thread-safe).
final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { _requests } }
    func record(_ r: URLRequest) { lock.withLock { _requests.append(r) } }

    /// Transport that records and then answers every request with `status` + `body`.
    func transport(status: Int = 200, body: String) -> HTTPTransport {
        { [self] request in
            record(request)
            return (Data(body.utf8), Stub.response(status, url: request.url))
        }
    }
}

enum AIFixtures {
    static func chat(_ json: String) -> String {
        let escaped = json.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return #"{"choices":[{"message":{"content":""# + escaped + #""}}]}"#
    }
    static let declareWarOnUSA = chat(#"{"action":"DECLARE_WAR","target":"USA","rationale":"test"}"#)
    static let openRouterBrain = AIBrain.model(id: "anthropic/claude-sonnet-4.5",
                                               endpoint: "https://openrouter.ai/api/v1/chat/completions",
                                               backend: .openRouter)

    static var request: MoveRequest {
        MoveRequest(gameId: "g", countryId: "RUS", turn: 1, year: 1962, defcon: 3,
                    worldStateSummary: "world", legalActions: ["WAIT", "DECLARE_WAR"])
    }

    /// Put the shared manager back to the state a fresh test host has (no probing under XCTest).
    @MainActor
    static func resetManager() {
        let m = AIBackendManager.shared
        m.aiEnabled = true
        m.selectedBackend = .auto
        m.isOllamaAvailable = false; m.isMLXAvailable = false; m.isTinyLLMAvailable = false
        m.isTinyChatAvailable = false; m.isOpenWebUIAvailable = false; m.isNovaGatewayAvailable = false
        m.isOpenRouterAvailable = false; m.isOpenAIAvailable = false
        m.activeBackend = nil
        m.httpTransport = HTTP.live
        m.retrySleep = Retry.realSleep
        m.generationRetryPolicy = .network
        m.ollamaBaseURL = AIEndpointSettings.ollamaDefault
        m.novaGatewayURL = AIEndpointSettings.novaGatewayDefault
        AIEndpointSettings.defaults.removeObject(forKey: AIEndpointSettings.Keys.ollamaURL)
        AIEndpointSettings.defaults.removeObject(forKey: AIEndpointSettings.Keys.novaGatewayURL)
        AIEndpointSettings.aiEnabled = true
        for slot in AIKeyStore.Slot.allCases { AIKeyStore.store(slot).delete() }
        m.refreshKeyPresence()
    }

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    static func source(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }
}

// MARK: - Unit

final class AIOptionsUnitTests: XCTestCase {

    func testCanonicalBackendIds() {
        XCTAssertEqual(LLMBackendType.allCases.map(\.rawValue),
                       ["auto", "ollama", "mlx", "tinyllm", "tinychat", "openwebui", "novagateway", "openrouter", "openai"])
        XCTAssertEqual(LLMBackendType.autoOrder,
                       [.ollama, .mlx, .tinyChat, .tinyLLM, .openWebUI, .novaGateway, .openRouter, .openAI])
        XCTAssertFalse(LLMBackendType.autoOrder.contains(.auto))
        XCTAssertTrue(LLMBackendType.pickerCases.contains(.mlx), "MLX is offered on macOS")
    }

    func testOldDisplayNameSelectionsMigrate() {
        XCTAssertEqual(LLMBackendType.migrate(persisted: "Ollama"), .ollama)
        XCTAssertEqual(LLMBackendType.migrate(persisted: "MLX Toolkit"), .mlx)
        XCTAssertEqual(LLMBackendType.migrate(persisted: "TinyLLM"), .tinyLLM)
        XCTAssertEqual(LLMBackendType.migrate(persisted: "TinyChat"), .tinyChat)
        XCTAssertEqual(LLMBackendType.migrate(persisted: "OpenWebUI"), .openWebUI)
        XCTAssertEqual(LLMBackendType.migrate(persisted: "OpenAI"), .openAI)
        XCTAssertEqual(LLMBackendType.migrate(persisted: "Auto (Prefer Ollama)"), .auto)
        for removed in ["Google Cloud AI", "Microsoft Azure", "AWS AI Services", "IBM Watson"] {
            XCTAssertEqual(LLMBackendType.migrate(persisted: removed), .auto, removed)
        }
        XCTAssertEqual(LLMBackendType.migrate(persisted: nil), .auto)
        XCTAssertEqual(LLMBackendType.migrate(persisted: "openrouter"), .openRouter)
        XCTAssertEqual(LLMBackendType.migrate(persisted: "garbage"), .auto)
    }

    func testAutoPicksFirstReachableInOrder() {
        XCTAssertEqual(LLMBackendType.resolve(selected: .auto, available: [.openRouter, .tinyLLM]), .tinyLLM)
        XCTAssertEqual(LLMBackendType.resolve(selected: .auto, available: [.openAI, .novaGateway]), .novaGateway)
        XCTAssertEqual(LLMBackendType.resolve(selected: .auto, available: [.ollama, .mlx]), .ollama)
        XCTAssertNil(LLMBackendType.resolve(selected: .auto, available: []))
    }

    func testExplicitChoiceOnlyWhenReachable() {
        XCTAssertEqual(LLMBackendType.resolve(selected: .novaGateway, available: [.novaGateway, .ollama]), .novaGateway)
        XCTAssertNil(LLMBackendType.resolve(selected: .ollama, available: [.novaGateway]))
    }

    func testFailoverChain() {
        XCTAssertEqual(LLMBackendType.failoverChain(selected: .auto, active: .ollama, available: [.ollama, .openAI, .novaGateway]),
                       [.ollama, .novaGateway, .openAI])
        XCTAssertEqual(LLMBackendType.failoverChain(selected: .ollama, active: .ollama, available: [.ollama, .openAI]), [.ollama])
        XCTAssertEqual(LLMBackendType.failoverChain(selected: .auto, active: nil, available: [.ollama]), [])
    }

    func testSanitizerCleansModelOutput() {
        XCTAssertEqual(AIOutputSanitizer.clean("<think>plan the war</think>  DEFCON 3. "), "DEFCON 3.")
        XCTAssertEqual(AIOutputSanitizer.clean("Moscow\u{07}\u{1B}[31m blinks"), "Moscow[31m blinks")
        XCTAssertNil(AIOutputSanitizer.clean("   \n "))
        XCTAssertNil(AIOutputSanitizer.clean("<think>never finished"))
        XCTAssertNil(AIOutputSanitizer.clean("!!! ... ???"))
        XCTAssertEqual(AIOutputSanitizer.clean(String(repeating: "a", count: 10_000))?.count, AIOutputSanitizer.maxCharacters)
        XCTAssertEqual(AIOutputSanitizer.clean("line one\nline two"), "line one\nline two")
    }

    func testEndpointPolicy() {
        XCTAssertTrue(AIEndpointPolicy.isValidServerURL("http://nova-core8:11434"))
        XCTAssertTrue(AIEndpointPolicy.isValidServerURL("https://openrouter.ai/api/v1"))
        XCTAssertFalse(AIEndpointPolicy.isValidServerURL("file:///etc/passwd"))
        XCTAssertFalse(AIEndpointPolicy.isValidServerURL("localhost:11434"))
        XCTAssertFalse(AIEndpointPolicy.isValidServerURL(""))
        XCTAssertTrue(AIEndpointPolicy.mayCarryKey(URL(string: "https://openrouter.ai/x")))
        XCTAssertFalse(AIEndpointPolicy.mayCarryKey(URL(string: "http://openrouter.ai/x")))
        XCTAssertFalse(AIEndpointPolicy.mayCarryKey(nil))
        XCTAssertEqual(AIEndpointPolicy.normalized(" http://h:1/// "), "http://h:1")
    }

    func testStatusText() {
        XCTAssertEqual(AIStatusText.line(enabled: false, active: .ollama), "AI off — built-in logic")
        XCTAssertEqual(AIStatusText.line(enabled: true, active: nil), "No backend reachable — built-in logic")
        XCTAssertEqual(AIStatusText.line(enabled: true, active: .novaGateway), "Active: Nova Gateway (reachable)")
    }

    func testOnlyCloudBackendsNeedKeys() {
        XCTAssertEqual(Set(LLMBackendType.allCases.filter(\.needsAPIKey)), [.openRouter, .openAI])
    }
}

// MARK: - Security

final class AIOptionsSecurityTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetManager() }
    @MainActor override func tearDown() async throws { AIFixtures.resetManager() }

    private func config(_ rec: RequestRecorder, key: String?) -> BrainConfig {
        var c = BrainConfig()
        c.transport = rec.transport(body: AIFixtures.chat(#"{"action":"WAIT"}"#))
        c.retrySleep = { _ in }
        c.openRouterKey = { key }
        return c
    }

    /// The 3.22 bug: OpenRouter brains posted the world state with no key, got a 401 every turn.
    func testOpenRouterBrainCarriesBearerKey() async throws {
        let rec = RequestRecorder()
        let resp = await BrainClient.requestMove(AIFixtures.request, brain: AIFixtures.openRouterBrain,
                                                 config: config(rec, key: "sk-or-test-123"))
        XCTAssertEqual(resp?.action, "WAIT")
        let req = try XCTUnwrap(rec.requests.first)
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-or-test-123")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Title"), "GTNW")
        XCTAssertEqual(req.url?.scheme, "https")
    }

    func testOpenRouterBrainWithoutKeySendsNothing() async {
        let rec = RequestRecorder()
        let resp = await BrainClient.requestMove(AIFixtures.request, brain: AIFixtures.openRouterBrain,
                                                 config: config(rec, key: nil))
        XCTAssertNil(resp)
        XCTAssertTrue(rec.requests.isEmpty, "no key = the world state never leaves the Mac")
    }

    func testOpenRouterKeyIsNeverSentOverHTTP() async {
        let rec = RequestRecorder()
        let downgraded = AIBrain.model(id: "x", endpoint: "http://openrouter.ai/api/v1/chat/completions", backend: .openRouter)
        let resp = await BrainClient.requestMove(AIFixtures.request, brain: downgraded, config: config(rec, key: "sk-or-test"))
        XCTAssertNil(resp)
        XCTAssertTrue(rec.requests.isEmpty)
        XCTAssertNil(OpenAICompatibleRequest(endpoint: "http://example.com/v1", model: "m", systemPrompt: "s",
                                             userPrompt: "u", apiKey: "k").makeURLRequest())
        XCTAssertThrowsError(try AIBackendManager.makeChatRequest(url: "http://api.example.com/v1/chat/completions", model: "m",
                                                                 messages: [], temperature: 0, maxTokens: 1,
                                                                 headers: ["Authorization": "Bearer k"], timeout: 5)) {
            XCTAssertEqual($0 as? AIBackendError, .insecureEndpoint)
        }
    }

    func testLocalAndGatewayBrainsSendNoAuthorization() async throws {
        for brain in [AIBrain.gatewayClaude,
                      .model(id: "qwen3:4b", endpoint: "http://127.0.0.1:1/v1/chat/completions", backend: .ollama)] {
            let rec = RequestRecorder()
            _ = await BrainClient.requestMove(AIFixtures.request, brain: brain, config: config(rec, key: "sk-or-secret"))
            let req = try XCTUnwrap(rec.requests.first, "\(brain)")
            XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"), "the OpenRouter key leaked to \(brain)")
            XCTAssertFalse(String(data: req.httpBody ?? Data(), encoding: .utf8)!.contains("sk-or-secret"))
        }
    }

    func testKeychainRoundTripUsesTestService() {
        XCTAssertTrue(AIKeyStore.servicePrefix.hasPrefix("com.jkoch.gtnw.tests."), "tests must never touch real items")
        XCTAssertFalse(AIKeyStore.hasKey(.openRouter))
        XCTAssertTrue(AIKeyStore.setKey("  sk-or-abc  ", for: .openRouter))
        XCTAssertEqual(AIKeyStore.key(.openRouter), "sk-or-abc", "trimmed")
        XCTAssertTrue(AIKeyStore.setKey("sk-or-def", for: .openRouter), "replace in place")
        XCTAssertEqual(AIKeyStore.key(.openRouter), "sk-or-def")
        XCTAssertTrue(AIKeyStore.setKey("", for: .openRouter), "empty deletes instead of storing \"\"")
        XCTAssertNil(AIKeyStore.key(.openRouter))
        XCTAssertNil(KeychainStore(service: AIKeyStore.store(.openRouter).service).get())
    }

    func testLegacyOpenAIKeyMigratesOnce() {
        let legacy = KeychainStore(service: AIKeyStore.legacyService, account: AIKeyStore.legacyOpenAIAccount)
        defer { legacy.delete() }
        XCTAssertTrue(legacy.set("sk-legacy"))
        AIKeyStore.migrateLegacyKeys()
        XCTAssertEqual(AIKeyStore.key(.openAI), "sk-legacy")
        XCTAssertNil(legacy.get(), "old item removed after the copy")
        AIKeyStore.migrateLegacyKeys()   // idempotent
        XCTAssertEqual(AIKeyStore.key(.openAI), "sk-legacy")
    }

    @MainActor
    func testKeysNeverLandInUserDefaults() {
        let m = AIBackendManager.shared
        m.setAPIKey("sk-or-defaults-probe", for: .openRouter)
        m.saveSettings()
        XCTAssertTrue(m.hasOpenRouterKey)
        let dump = AIEndpointSettings.defaults.dictionaryRepresentation().values.map { "\($0)" }.joined()
        XCTAssertFalse(dump.contains("sk-or-defaults-probe"))
        XCTAssertFalse(String(describing: m).contains("sk-or-defaults-probe"))
    }

    func testSourceHasNoRemovedOrUnsafeBackends() throws {
        let manager = try AIFixtures.source("Shared/Models/AIBackendManager.swift")
        for gone in ["YOUR_PROJECT_ID", "googleCloud", "azureCognitive", "awsAI", "ibmWatson"] {
            XCTAssertFalse(manager.contains(gone), "\(gone) is back in AIBackendManager.swift")
        }
        let keys = try AIFixtures.source("Shared/AI/AIKeyStore.swift")
        XCTAssertTrue(keys.contains("\"com.jkoch.gtnw\""), "GTNW's own Keychain service")
        XCTAssertFalse(keys.contains("aistudio"), "never another app's Keychain service")
        // No AI key is read from the environment anywhere in the app.
        let e = FileManager.default.enumerator(at: AIFixtures.repoRoot.appendingPathComponent("Shared"), includingPropertiesForKeys: nil)
        while let url = e?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.contains("OPENAI_API_KEY") || text.contains("OPENROUTER_API_KEY"), url.lastPathComponent)
        }
    }

    @MainActor
    func testAIOffSendsNothing() async {
        let m = AIBackendManager.shared
        let rec = RequestRecorder()
        m.httpTransport = rec.transport(body: #"{"response":"hi"}"#)
        m.isOllamaAvailable = true
        m.setAIEnabled(false)
        XCTAssertNil(m.activeBackend)
        do { _ = try await m.generate(prompt: "x"); XCTFail("must throw") } catch {
            XCTAssertEqual(error as? AIBackendError, .noBackendAvailable)
        }
        XCTAssertTrue(rec.requests.isEmpty)
    }
}

// MARK: - Retry

final class AIOptionsRetryTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetManager() }
    @MainActor override func tearDown() async throws { AIFixtures.resetManager() }

    /// Auto: Ollama keeps failing → bounded retries (3), then the Nova Gateway answers.
    @MainActor
    func testAutoFailsOverToNextReachableBackend() async throws {
        let m = AIBackendManager.shared
        let ollama = RetryProbe(), gateway = RetryProbe(), sleeps = RetryProbe()
        m.isOllamaAvailable = true
        m.isNovaGatewayAvailable = true
        m.determineActiveBackend()
        XCTAssertEqual(m.activeBackend, .ollama)
        m.retrySleep = sleeps.sleeper
        m.httpTransport = { request in
            if request.url?.port == 11434 {
                ollama.hit()
                return (Data(), Stub.response(503, url: request.url))
            }
            gateway.hit()
            return (Data(AIFixtures.chat("Nova here").utf8), Stub.response(200, url: request.url))
        }
        let text = try await m.generate(prompt: "status?")
        XCTAssertEqual(text, "Nova here")
        XCTAssertEqual(ollama.calls, RetryPolicy.network.maxAttempts)
        XCTAssertEqual(gateway.calls, 1)
        XCTAssertEqual(sleeps.sleeps, [0.5, 1.0], "backoff only inside a backend, not between backends")
    }

    @MainActor
    func testExplicitBackendDoesNotSwitchProvider() async {
        let m = AIBackendManager.shared
        let probe = RetryProbe()
        m.selectedBackend = .ollama
        m.isOllamaAvailable = true
        m.isNovaGatewayAvailable = true
        m.determineActiveBackend()
        m.retrySleep = probe.sleeper
        m.httpTransport = Stub.transport(probe, script: [(500, "")])
        do { _ = try await m.generate(prompt: "x"); XCTFail("must throw") } catch {
            XCTAssertEqual(error as? HTTPStatusError, HTTPStatusError(statusCode: 500))
        }
        XCTAssertEqual(probe.calls, 3, "three attempts at Ollama, never a hop to the gateway")
    }

    @MainActor
    func testMissingKeyFailsFastWithoutRetryOrNetwork() async {
        let m = AIBackendManager.shared
        let probe = RetryProbe()
        m.selectedBackend = .openRouter
        m.isOpenRouterAvailable = true     // stale flag; the key was removed since
        m.determineActiveBackend()
        m.httpTransport = Stub.transport(probe, script: [(200, "")])
        m.retrySleep = probe.sleeper
        do { _ = try await m.generate(prompt: "x"); XCTFail("must throw") } catch {
            XCTAssertEqual(error as? AIBackendError, .missingAPIKey)
        }
        XCTAssertEqual(probe.calls, 0)
        XCTAssertTrue(probe.sleeps.isEmpty)
    }

    func testOpenRouterBrainRetriesRateLimit() async {
        let probe = RetryProbe()
        var c = BrainConfig()
        c.openRouterKey = { "sk-or-test" }
        c.retrySleep = probe.sleeper
        c.transport = Stub.transport(probe, script: [(429, ""), (429, ""), (200, AIFixtures.chat(#"{"action":"WAIT"}"#))])
        let resp = await BrainClient.requestMove(AIFixtures.request, brain: AIFixtures.openRouterBrain, config: c)
        XCTAssertEqual(resp?.action, "WAIT")
        XCTAssertEqual(probe.calls, 3)
    }

    func testOpenRouterUnauthorizedIsNotRetried() async {
        let probe = RetryProbe()
        var c = BrainConfig()
        c.openRouterKey = { "sk-or-wrong" }
        c.retrySleep = probe.sleeper
        c.transport = Stub.transport(probe, script: [(401, "")])
        let resp = await BrainClient.requestMove(AIFixtures.request, brain: AIFixtures.openRouterBrain, config: c)
        XCTAssertNil(resp)
        XCTAssertEqual(probe.calls, 1, "a bad key can't be fixed by retrying")
    }

    func testNewErrorsAreClassified() {
        XCTAssertFalse(AIBackendManager.isRetryable(AIBackendError.missingAPIKey))
        XCTAssertFalse(AIBackendManager.isRetryable(AIBackendError.insecureEndpoint))
        XCTAssertFalse(AIBackendManager.isRetryable(AIBackendError.emptyResponse))
        XCTAssertTrue(AIBackendManager.isRetryable(HTTPStatusError(statusCode: 429)))
    }
}

// MARK: - Performance

final class AIOptionsPerformanceTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetManager() }
    @MainActor override func tearDown() async throws { AIFixtures.resetManager() }

    /// AI off: thirty countries on remote brains resolve locally — no calls, well under a second.
    @MainActor
    func testAIOffTurnMakesNoBrainCalls() async throws {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        let ids = try XCTUnwrap(e.gameState).countries.filter { !$0.isPlayerControlled && !$0.isDestroyed }.prefix(30).map(\.id)
        for id in ids { e.setBrain(.gatewayClaude, for: id) }
        let calls = RetryProbe()
        e.brainTransportOverride = { _, _ in calls.hit(); return MoveResponse(action: "WAIT") }
        AIBackendManager.shared.setAIEnabled(false)
        let start = Date()
        await e.processAITurnsWithBrains()
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
        XCTAssertEqual(calls.calls, 0)
    }

    func testSanitizerIsCheap() {
        let blob = "<think>" + String(repeating: "x", count: 2000) + "</think>" + String(repeating: "Moscow blinks. ", count: 300)
        let start = Date()
        for _ in 0..<500 { _ = AIOutputSanitizer.clean(blob) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    /// Probes use the short probe timeout; generation uses the request timeout (nothing waits on URLSession's 60 s).
    @MainActor
    func testRequestsCarryBoundedTimeouts() async throws {
        let m = AIBackendManager.shared
        let rec = RequestRecorder()
        m.httpTransport = rec.transport(body: #"{"models":[{"name":"llama3.2"}],"response":"ok"}"#)
        m.probeTimeout = 2
        m.requestTimeout = 20
        m.probesNetwork = true
        defer { m.probeTimeout = 3; m.requestTimeout = 30; m.probesNetwork = false }
        await m.checkBackendAvailability()
        XCTAssertTrue(rec.requests.allSatisfy { $0.timeoutInterval == 2 })
        XCTAssertTrue(m.isOllamaAvailable)
        _ = try await m.generate(prompt: "x")
        XCTAssertEqual(rec.requests.last?.timeoutInterval, 20)
    }
}

// MARK: - Integration

final class AIOptionsIntegrationTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetManager() }
    @MainActor override func tearDown() async throws { AIFixtures.resetManager() }

    @MainActor
    private func engine(_ transport: @escaping HTTPTransport, key: String?) -> GameEngine {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        e.brainConfig.transport = transport
        e.brainConfig.retrySleep = { _ in }
        e.brainConfig.modelTimeout = 5
        e.brainConfig.openRouterKey = { key }
        return e
    }

    /// Engine → OpenRouter brain (with key) → HTTP → move → game state.
    @MainActor
    func testOpenRouterBrainMoveReachesGameState() async throws {
        let rec = RequestRecorder()
        let e = engine(rec.transport(body: AIFixtures.declareWarOnUSA), key: "sk-or-int")
        e.setBrain(AIFixtures.openRouterBrain, for: "RUS")
        await e.processAITurnsWithBrains()
        XCTAssertTrue(try XCTUnwrap(e.gameState?.getCountry(id: "RUS")).atWarWith.contains("USA"))
        XCTAssertFalse(e.lastTurnFallbackCountryIDs.contains("RUS"))
        XCTAssertEqual(rec.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-or-int")
    }

    @MainActor
    func testOpenRouterBrainWithoutKeyPlaysRuleBasedOffline() async {
        let rec = RequestRecorder()
        let e = engine(rec.transport(body: AIFixtures.declareWarOnUSA), key: nil)
        e.setBrain(AIFixtures.openRouterBrain, for: "RUS")
        await e.processAITurnsWithBrains()
        XCTAssertTrue(e.lastTurnFallbackCountryIDs.contains("RUS"))
        XCTAssertTrue(rec.requests.isEmpty)
    }

    /// Manager → Ollama (stub) → sanitiser → caller.
    @MainActor
    func testManagerOutputIsSanitised() async throws {
        let m = AIBackendManager.shared
        m.isOllamaAvailable = true
        m.determineActiveBackend()
        m.httpTransport = RequestRecorder().transport(body: #"{"response":"<think>hmm</think> Moscow blinks.\u0007"}"#)
        let text = try await m.generate(prompt: "x")
        XCTAssertEqual(text, "Moscow blinks.")
    }

    @MainActor
    func testEmptyReplyFailsOverInAuto() async throws {
        let m = AIBackendManager.shared
        m.isOllamaAvailable = true
        m.isTinyLLMAvailable = true
        m.determineActiveBackend()
        m.httpTransport = { request in
            if request.url?.port == 11434 { return (Data(#"{"response":"   "}"#.utf8), Stub.response(200, url: request.url)) }
            return (Data(AIFixtures.chat("TinyLLM line").utf8), Stub.response(200, url: request.url))
        }
        let text = try await m.generate(prompt: "x")
        XCTAssertEqual(text, "TinyLLM line")
    }

    /// The Nova Gateway backend speaks the OpenAI-compatible route at the configured URL with the configured model.
    @MainActor
    func testNovaGatewayBackendUsesConfiguredURLAndModel() async throws {
        let m = AIBackendManager.shared
        let rec = RequestRecorder()
        m.selectedBackend = .novaGateway
        m.novaGatewayURL = "http://nova-gw.local:18792/"
        m.isNovaGatewayAvailable = true
        m.determineActiveBackend()
        m.httpTransport = rec.transport(body: AIFixtures.chat("ok"))
        _ = try await m.generate(prompt: "x")
        let req = try XCTUnwrap(rec.requests.first)
        XCTAssertEqual(req.url?.absoluteString, "http://nova-gw.local:18792/v1/chat/completions")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, m.novaGatewayModel)
        XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
    }
}

// MARK: - Functional

final class AIOptionsFunctionalTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetManager() }
    @MainActor override func tearDown() async throws { AIFixtures.resetManager() }

    /// Turning AI off from the menu/settings: the game still plays a full turn, every brain acts rule-based.
    @MainActor
    func testGameIsFullyPlayableWithAIOff() async throws {
        let probe = RetryProbe()
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        e.brainConfig.transport = Stub.transport(probe, script: [(200, AIFixtures.declareWarOnUSA)])
        e.setBrain(.gatewayClaude, for: "RUS")
        AIBackendManager.shared.setAIEnabled(false)
        XCTAssertFalse(AIEndpointSettings.aiEnabled, "the switch persists")
        let turn = e.gameState?.turn ?? 0
        e.endTurn()
        let deadline = Date().addingTimeInterval(10)
        while (e.turnPhase != .playerInput || e.isProcessingAITurn) && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(e.gameState?.turn, turn + 1)
        XCTAssertEqual(e.turnPhase, .playerInput)
        XCTAssertEqual(probe.calls, 0, "AI off: no brain request")
    }

    @MainActor
    func testTurningAIBackOnRestoresActiveBackend() {
        let m = AIBackendManager.shared
        m.isOllamaAvailable = true
        m.setAIEnabled(false)
        XCTAssertNil(m.activeBackend)
        m.setAIEnabled(true)
        XCTAssertEqual(m.activeBackend, .ollama)
    }

    /// The Ollama URL is a real setting now: it reaches the manager, the brain model list and new brains.
    @MainActor
    func testOllamaURLSettingFlowsEverywhere() async throws {
        let m = AIBackendManager.shared
        m.ollamaBaseURL = "http://nova-core8:11434/"
        m.saveSettings()
        XCTAssertEqual(AIEndpointSettings.ollamaURL, "http://nova-core8:11434")
        XCTAssertEqual(ModelRegistry.ollamaHost, "http://nova-core8:11434")
        let rec = RequestRecorder()
        m.httpTransport = rec.transport(body: #"{"response":"ok"}"#)
        m.isOllamaAvailable = true
        m.determineActiveBackend()
        _ = try await m.generate(prompt: "x")
        XCTAssertEqual(rec.requests.first?.url?.host, "nova-core8")
    }

    func testInvalidStoredURLFallsBackToDefault() {
        AIEndpointSettings.defaults.set("not a url", forKey: AIEndpointSettings.Keys.ollamaURL)
        XCTAssertEqual(AIEndpointSettings.ollamaURL, AIEndpointSettings.ollamaDefault)
    }

    func testGatewayURLSettingReachesBrains() {
        AIEndpointSettings.novaGatewayURL = "http://10.0.0.5:18792"
        XCTAssertEqual(BrainConfig().gatewayEndpoint, "http://10.0.0.5:18792/v1/chat/completions")
        var pinned = BrainConfig()
        pinned.gatewayEndpoint = "http://pinned:1/v1/chat/completions"
        XCTAssertEqual(pinned.gatewayEndpoint, "http://pinned:1/v1/chat/completions")
    }

    @MainActor
    func testSavedKeyMakesOpenRouterSelectable() {
        let m = AIBackendManager.shared
        m.selectedBackend = .openRouter
        m.determineActiveBackend()
        XCTAssertNil(m.activeBackend, "no key, not available")
        m.setAPIKey("sk-or-func", for: .openRouter)
        XCTAssertTrue(m.hasOpenRouterKey)
        XCTAssertEqual(m.activeBackend, .openRouter)
        m.setAPIKey("", for: .openRouter)
        XCTAssertFalse(m.hasOpenRouterKey)
        XCTAssertNil(m.activeBackend)
    }

    @MainActor
    func testTestConnectionReportsOutcome() async {
        let m = AIBackendManager.shared
        m.setAIEnabled(false)
        let off = await m.testConnection()
        XCTAssertFalse(off)
        XCTAssertEqual(m.lastTestResult, "AI is off — the game uses its built-in logic.")
        m.setAIEnabled(true)
        m.probesNetwork = true
        defer { m.probesNetwork = false }
        m.httpTransport = { request in
            if request.url?.path == "/api/tags" { return (Data(#"{"models":[{"name":"m1"}]}"#.utf8), Stub.response(200, url: request.url)) }
            if request.url?.port == 11434 { return (Data(#"{"response":"OK"}"#.utf8), Stub.response(200, url: request.url)) }
            throw URLError(.cannotConnectToHost)
        }
        let on = await m.testConnection()
        XCTAssertTrue(on)
        XCTAssertTrue(m.lastTestResult?.hasPrefix("Ollama answered") ?? false, m.lastTestResult ?? "nil")
    }
}

// MARK: - Frame

final class AIOptionsFrameTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetManager() }
    @MainActor override func tearDown() async throws { AIFixtures.resetManager() }

    @MainActor
    private func render<V: View>(_ view: V, _ w: CGFloat = 800, _ h: CGFloat = 900) -> CGImage? {
        let r = ImageRenderer(content: view.frame(width: w, height: h))
        r.scale = 1
        return r.cgImage
    }

    @MainActor
    func testSettingsRendersOnAndOff() {
        XCTAssertNotNil(render(AIBackendSettingsView()))
        AIBackendManager.shared.setAIEnabled(false)
        XCTAssertNotNil(render(AIBackendSettingsView()))
    }

    @MainActor
    func testStatusLineAndMenuItemsRender() {
        XCTAssertNotNil(render(AIStatusLine(manager: AIBackendManager.shared), 400, 40))
        XCTAssertNotNil(render(VStack { AIStatusMenuItems() }, 400, 160))
    }

    @MainActor
    func testBrainAssignmentRendersWithAndWithoutKey() {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        XCTAssertNotNil(render(BrainAssignmentView().environmentObject(e), 600, 600))
        AIBackendManager.shared.setAPIKey("sk-or-frame", for: .openRouter)
        AIBackendManager.shared.setAIEnabled(false)
        XCTAssertNotNil(render(BrainAssignmentView().environmentObject(e), 600, 600))
    }
}
