//
//  GTNWRetryTests.swift
//  GTNWTests
//
//  // MARK: - Retry
//  Every external call (LLM HTTP, Ollama, live-session bridge, MLX subprocess)
//  must retry 2–3 times with backoff and never fail silently on the first attempt.
//  All tests use stub transports and a recording no-op sleep — no network, fast.
//
//  Created by Jordan Koch on 2026.
//

import XCTest
@testable import GTNW

// MARK: - Test doubles

/// Thread-safe call counter + recorded sleeps.
final class RetryProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var _calls = 0
    private var _sleeps: [TimeInterval] = []
    var calls: Int { lock.lock(); defer { lock.unlock() }; return _calls }
    var sleeps: [TimeInterval] { lock.lock(); defer { lock.unlock() }; return _sleeps }
    @discardableResult func hit() -> Int { lock.lock(); defer { lock.unlock() }; _calls += 1; return _calls }
    var sleeper: RetrySleeper { { [self] s in lock.lock(); _sleeps.append(s); lock.unlock() } }
}

enum Stub {
    static func response(_ status: Int, url: URL? = nil) -> HTTPURLResponse {
        HTTPURLResponse(url: url ?? URL(string: "http://127.0.0.1")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    /// Transport that plays back a script: each entry is a status code (with body) or nil for a transport error.
    static func transport(_ probe: RetryProbe, script: [(Int?, String)]) -> HTTPTransport {
        { request in
            let n = probe.hit()
            let step = script[min(n - 1, script.count - 1)]
            guard let status = step.0 else { throw URLError(.cannotConnectToHost) }
            return (Data(step.1.utf8), response(status, url: request.url))
        }
    }

    static let chatOK = #"{"choices":[{"message":{"content":"{\"action\":\"WAIT\",\"rationale\":\"hold\"}"}}]}"#
    static let tagsOK = #"{"models":[{"name":"qwen3:4b","size":2600000000}]}"#
}

struct FlakyError: Error {}

// MARK: - Retry policy & helper

final class RetryPolicyTests: XCTestCase {

    func testDefaultNetworkPolicyIsThreeAttemptsWithExponentialBackoff() {
        let p = RetryPolicy.network
        XCTAssertEqual(p.maxAttempts, 3)
        XCTAssertEqual(p.delay(afterAttempt: 1), 0.5, accuracy: 1e-9)
        XCTAssertEqual(p.delay(afterAttempt: 2), 1.0, accuracy: 1e-9)
        XCTAssertEqual(p.worstCaseSleep, 1.5, accuracy: 1e-9)
    }

    func testDelayIsCappedAtMaxDelay() {
        let p = RetryPolicy(maxAttempts: 10, baseDelay: 1, multiplier: 3, maxDelay: 5)
        XCTAssertEqual(p.delay(afterAttempt: 4), 5)
        XCTAssertEqual(p.delay(afterAttempt: 9), 5)
    }

    func testSubprocessPolicyRetriesAtLeastOnce() {
        XCTAssertGreaterThanOrEqual(RetryPolicy.subprocess.maxAttempts, 2)
    }

    func testRunSucceedsOnThirdAttemptAndBacksOff() async throws {
        let probe = RetryProbe()
        let value = try await Retry.run("t", sleep: probe.sleeper) { () async throws -> Int in
            if probe.hit() < 3 { throw FlakyError() }
            return 42
        }
        XCTAssertEqual(value, 42)
        XCTAssertEqual(probe.calls, 3)
        XCTAssertEqual(probe.sleeps, [0.5, 1.0], "exponential backoff between attempts")
    }

    func testRunExhaustsAttemptsAndThrowsLastError() async {
        let probe = RetryProbe()
        do {
            _ = try await Retry.run("t", sleep: probe.sleeper) { () async throws -> Int in
                probe.hit(); throw FlakyError()
            }
            XCTFail("should throw")
        } catch {
            XCTAssertTrue(error is FlakyError)
        }
        XCTAssertEqual(probe.calls, 3, "never fails on the first attempt")
        XCTAssertEqual(probe.sleeps.count, 2)
    }

    func testNonRetryableErrorFailsFast() async {
        let probe = RetryProbe()
        _ = try? await Retry.run("t", sleep: probe.sleeper, shouldRetry: { _ in false }) { () async throws -> Int in
            probe.hit(); throw FlakyError()
        }
        XCTAssertEqual(probe.calls, 1)
        XCTAssertTrue(probe.sleeps.isEmpty)
    }

    func testZeroAttemptsClampsToOne() async {
        let probe = RetryProbe()
        _ = try? await Retry.run("t", policy: RetryPolicy(maxAttempts: 0), sleep: probe.sleeper) { () async throws -> Int in
            probe.hit(); throw FlakyError()
        }
        XCTAssertEqual(probe.calls, 1)
    }

    func testOptionalTreatsNilAsFailure() async {
        let probe = RetryProbe()
        let v: String? = await Retry.optional("t", sleep: probe.sleeper) {
            probe.hit() < 2 ? nil : "ok"
        }
        XCTAssertEqual(v, "ok")
        XCTAssertEqual(probe.calls, 2)
    }

    func testOptionalReturnsNilAfterExhaustion() async {
        let probe = RetryProbe()
        let v: String? = await Retry.optional("t", sleep: probe.sleeper) { probe.hit(); return nil }
        XCTAssertNil(v)
        XCTAssertEqual(probe.calls, 3)
    }

    func testCancellationStopsRetrying() async {
        let probe = RetryProbe()
        let task = Task { () -> Int? in
            try? await Retry.run("t", policy: RetryPolicy(maxAttempts: 50, baseDelay: 0.05), sleep: Retry.realSleep) { () async throws -> Int in
                probe.hit(); throw FlakyError()
            }
        }
        try? await Task.sleep(nanoseconds: 120_000_000)
        task.cancel()
        _ = await task.value
        XCTAssertLessThan(probe.calls, 10, "cancelled retry loop must stop promptly")
    }

    func testRealSleepActuallyWaits() async throws {
        let start = Date()
        let probe = RetryProbe()
        _ = try? await Retry.run("t", policy: RetryPolicy(maxAttempts: 3, baseDelay: 0.05, multiplier: 2)) { () async throws -> Int in
            probe.hit(); throw FlakyError()
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThanOrEqual(elapsed, 0.14, "0.05 + 0.10 backoff")
        XCTAssertLessThan(elapsed, 3.0)
    }
}

// MARK: - Retry.http status classification

final class RetryHTTPTests: XCTestCase {
    private let req = URLRequest(url: URL(string: "http://127.0.0.1:1/x")!)

    func testTransient5xxThenSuccess() async throws {
        let probe = RetryProbe()
        let (data, _) = try await Retry.http(req, label: "t",
                                             transport: Stub.transport(probe, script: [(503, ""), (502, ""), (200, "ok")]),
                                             sleep: probe.sleeper)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "ok")
        XCTAssertEqual(probe.calls, 3)
    }

    func testRateLimit429IsRetried() async throws {
        let probe = RetryProbe()
        _ = try await Retry.http(req, label: "t",
                                 transport: Stub.transport(probe, script: [(429, ""), (200, "ok")]),
                                 sleep: probe.sleeper)
        XCTAssertEqual(probe.calls, 2)
    }

    func testTransportErrorIsRetried() async throws {
        let probe = RetryProbe()
        _ = try await Retry.http(req, label: "t",
                                 transport: Stub.transport(probe, script: [(nil, ""), (200, "ok")]),
                                 sleep: probe.sleeper)
        XCTAssertEqual(probe.calls, 2)
    }

    func testPermanent4xxFailsFastWithStatus() async {
        let probe = RetryProbe()
        do {
            _ = try await Retry.http(req, label: "t",
                                     transport: Stub.transport(probe, script: [(404, "")]),
                                     sleep: probe.sleeper)
            XCTFail("404 must throw")
        } catch let e as HTTPStatusError {
            XCTAssertEqual(e.statusCode, 404)
        } catch { XCTFail("unexpected \(error)") }
        XCTAssertEqual(probe.calls, 1)
    }

    func testStatusClassification() {
        for code in [408, 429, 500, 502, 503, 504] { XCTAssertTrue(HTTP.isRetryableStatus(code), "\(code)") }
        for code in [200, 400, 401, 403, 404, 422] { XCTAssertFalse(HTTP.isRetryableStatus(code), "\(code)") }
    }
}

// MARK: - AI opponent transports retry

final class AIOpponentRetryTests: XCTestCase {

    private func moveRequest() -> MoveRequest {
        MoveRequest(gameId: "g", countryId: "RUS", turn: 1, year: 1990, defcon: 5,
                    worldStateSummary: "test", legalActions: ["WAIT"])
    }

    func testLLMRequestRetriesThenSucceeds() async {
        let probe = RetryProbe()
        var r = OpenAICompatibleRequest(endpoint: "http://127.0.0.1:1/v1/chat/completions", model: "m",
                                        systemPrompt: "s", userPrompt: "u")
        r.transport = Stub.transport(probe, script: [(nil, ""), (500, ""), (200, Stub.chatOK)])
        r.sleep = probe.sleeper
        let text = await r.send()
        XCTAssertNotNil(text)
        XCTAssertEqual(probe.calls, 3)
    }

    func testLLMRequestGivesUpAfterThreeAttempts() async {
        let probe = RetryProbe()
        var r = OpenAICompatibleRequest(endpoint: "http://127.0.0.1:1/v1", model: "m", systemPrompt: "s", userPrompt: "u")
        r.transport = Stub.transport(probe, script: [(nil, "")])
        r.sleep = probe.sleeper
        let text = await r.send()
        XCTAssertNil(text)
        XCTAssertEqual(probe.calls, 3)
    }

    func testLLMRequestDoesNotRetryUnauthorized() async {
        let probe = RetryProbe()
        var r = OpenAICompatibleRequest(endpoint: "http://127.0.0.1:1/v1", model: "m", systemPrompt: "s", userPrompt: "u")
        r.transport = Stub.transport(probe, script: [(401, "")])
        r.sleep = probe.sleeper
        let text = await r.send()
        XCTAssertNil(text)
        XCTAssertEqual(probe.calls, 1, "bad credentials won't fix themselves")
    }

    func testOllamaModelListRetries() async {
        let probe = RetryProbe()
        let models = await ModelRegistry.fetchLocalModels(
            host: "http://127.0.0.1:1",
            transport: Stub.transport(probe, script: [(503, ""), (200, Stub.tagsOK)]),
            sleep: probe.sleeper)
        XCTAssertEqual(models.map(\.name), ["qwen3:4b"])
        XCTAssertEqual(probe.calls, 2)
    }

    func testLiveSessionPostRetries() async {
        let probe = RetryProbe()
        let ok = await LiveSessionBus.post(moveRequest(), to: "http://127.0.0.1:1/gtnw/move",
                                           transport: Stub.transport(probe, script: [(nil, ""), (200, "")]),
                                           sleep: probe.sleeper)
        XCTAssertTrue(ok)
        XCTAssertEqual(probe.calls, 2)
    }

    func testBrainClientModelMoveRetriesThroughConfig() async {
        let probe = RetryProbe()
        var config = BrainConfig()
        config.transport = Stub.transport(probe, script: [(nil, ""), (200, Stub.chatOK)])
        config.retrySleep = probe.sleeper
        config.modelTimeout = 5
        let resp = await BrainClient.requestMove(moveRequest(),
                                                 brain: .model(id: "qwen3:4b", endpoint: "http://127.0.0.1:1/v1/chat/completions", backend: .ollama),
                                                 config: config)
        XCTAssertEqual(resp?.action, "WAIT")
        XCTAssertEqual(probe.calls, 2)
    }

    @MainActor
    func testOllamaServiceGenerateRetries() async {
        let probe = RetryProbe()
        let svc = OllamaService(monitorSystem: false)
        svc.isConnected = true
        svc.transport = Stub.transport(probe, script: [(nil, ""), (503, ""), (200, #"{"response":" hello "}"#)])
        svc.retrySleep = probe.sleeper
        let text = await svc.generate(prompt: "hi")
        XCTAssertEqual(text, "hello")
        XCTAssertEqual(probe.calls, 3)
    }

    @MainActor
    func testOllamaServiceInitializeRetriesBeforeDeclaringOffline() async {
        let probe = RetryProbe()
        let svc = OllamaService(monitorSystem: false)
        svc.transport = Stub.transport(probe, script: [(nil, ""), (200, Stub.tagsOK)])
        svc.retrySleep = probe.sleeper
        await svc.initialize()
        XCTAssertTrue(svc.isConnected)
        XCTAssertEqual(probe.calls, 2)
    }

    func testMLXSubprocessRetriesOnFailure() async {
        let probe = RetryProbe()
        let mlx = MLXManager()
        mlx.isConnected = true
        mlx.retrySleep = probe.sleeper
        mlx.pythonRunner = { _ in
            switch probe.hit() {
            case 1: return (1, "")                       // crash
            default: return (0, "RECOMMEND_MAINTAIN_STATUS_QUO\n")
            }
        }
        let gs = GameState(playerCountryID: "USA")
        let country = try! XCTUnwrap(gs.getCountry(id: "RUS"))
        let out = await mlx.getCountryAction(country: country, gameState: gs)
        XCTAssertEqual(out, "RECOMMEND_MAINTAIN_STATUS_QUO")
        XCTAssertEqual(probe.calls, 2)
    }

    func testMLXScriptErrorOutputCountsAsFailure() async {
        let probe = RetryProbe()
        let mlx = MLXManager()
        mlx.isConnected = true
        mlx.retrySleep = probe.sleeper
        mlx.pythonRunner = { _ in probe.hit(); return (0, "ERROR: No module named mlx") }
        let gs = GameState(playerCountryID: "USA")
        let out = await mlx.getCountryAction(country: gs.countries[0], gameState: gs)
        XCTAssertNil(out)
        XCTAssertEqual(probe.calls, RetryPolicy.subprocess.maxAttempts)
    }

    @MainActor
    func testAIBackendManagerRetryClassification() {
        XCTAssertFalse(AIBackendManager.isRetryable(AIBackendError.noBackendAvailable))
        XCTAssertFalse(AIBackendManager.isRetryable(AIBackendError.invalidConfiguration))
        XCTAssertFalse(AIBackendManager.isRetryable(AIBackendError.mlxScriptNotConfigured))
        XCTAssertFalse(AIBackendManager.isRetryable(AIBackendError.ethicalViolation("x")))
        XCTAssertTrue(AIBackendManager.isRetryable(AIBackendError.mlxExecutionFailed("oom")))
        XCTAssertTrue(AIBackendManager.isRetryable(URLError(.timedOut)))
        XCTAssertTrue(AIBackendManager.isRetryable(HTTPStatusError(statusCode: 503)))
        XCTAssertFalse(AIBackendManager.isRetryable(HTTPStatusError(statusCode: 400)))
    }

    @MainActor
    func testAIBackendManagerOllamaGenerateRetries() async throws {
        let mgr = AIBackendManager.shared
        let saved = (mgr.activeBackend, mgr.httpTransport, mgr.retrySleep)
        defer { mgr.activeBackend = saved.0; mgr.httpTransport = saved.1; mgr.retrySleep = saved.2 }
        let probe = RetryProbe()
        mgr.activeBackend = .ollama
        mgr.httpTransport = Stub.transport(probe, script: [(nil, ""), (500, ""), (200, #"{"response":"DEFCON 3"}"#)])
        mgr.retrySleep = probe.sleeper
        let text = try await mgr.generate(prompt: "status?")
        XCTAssertEqual(text, "DEFCON 3")
        XCTAssertEqual(probe.calls, 3)
        XCTAssertEqual(probe.sleeps, [0.5, 1.0])
    }

    @MainActor
    func testAIBackendManagerNoBackendFailsFastWithoutCalls() async {
        let mgr = AIBackendManager.shared
        let saved = (mgr.activeBackend, mgr.httpTransport)
        defer { mgr.activeBackend = saved.0; mgr.httpTransport = saved.1 }
        let probe = RetryProbe()
        mgr.activeBackend = nil
        mgr.httpTransport = Stub.transport(probe, script: [(200, "")])
        do { _ = try await mgr.generate(prompt: "x"); XCTFail("should throw") } catch {}
        XCTAssertEqual(probe.calls, 0)
    }
}
