//
//  GTNWRetryTests.swift
//  GTNWTests
//
//  // MARK: - Retry
//  Every external call (LLM backends via NovaAIKit, live-session bridge, Games DB sync)
//  must retry 2–3 times with backoff and never fail silently on the first attempt.
//  All tests use stub transports and a recording no-op sleep — no network, fast.
//
//  Created by Jordan Koch on 2026.
//

import XCTest
import NovaAIKit
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
    var sleeper: RetrySleeper { { [self] s in lock.withLock { _sleeps.append(s) } } }
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

    private static let ollamaBrain = AIBrain.model(id: "qwen3:4b", endpoint: "http://127.0.0.1:1/v1/chat/completions", backend: .ollama)

    private func config(_ transport: @escaping HTTPTransport, _ probe: RetryProbe) -> BrainConfig {
        var c = BrainConfig()
        c.engine = KitTest.engine(transport: transport, sleep: probe.sleeper)
        c.modelTimeout = 5
        return c
    }

    // LLM brains (NovaAIKit): 408/429/5xx retried with backoff, three attempts per backend.

    func testLLMRequestRetriesThenSucceeds() async {
        let probe = RetryProbe()
        let c = config(Stub.transport(probe, script: [(502, ""), (500, ""), (200, Stub.chatOK)]), probe)
        let resp = await BrainClient.requestMove(moveRequest(), brain: Self.ollamaBrain, config: c)
        XCTAssertEqual(resp?.action, "WAIT")
        XCTAssertEqual(probe.calls, 3)
        XCTAssertEqual(probe.sleeps, [0.5, 1.0])
    }

    func testLLMRequestGivesUpAfterThreeAttempts() async {
        let probe = RetryProbe()
        let c = config(Stub.transport(probe, script: [(503, "")]), probe)
        let resp = await BrainClient.requestMove(moveRequest(), brain: Self.ollamaBrain, config: c)
        XCTAssertNil(resp)
        XCTAssertEqual(probe.calls, 3)
    }

    func testLLMRequestDoesNotRetryUnauthorized() async {
        let probe = RetryProbe()
        let c = config(Stub.transport(probe, script: [(401, "")]), probe)
        let resp = await BrainClient.requestMove(moveRequest(), brain: Self.ollamaBrain, config: c)
        XCTAssertNil(resp)
        XCTAssertEqual(probe.calls, 1, "bad credentials won't fix themselves")
    }

    func testLLMRequestDoesNotRetryRefusedConnection() async {
        let probe = RetryProbe()
        let c = config(Stub.transport(probe, script: [(nil, "")]), probe)
        let resp = await BrainClient.requestMove(moveRequest(), brain: Self.ollamaBrain, config: c)
        XCTAssertNil(resp)
        XCTAssertEqual(probe.calls, 1, "a server that refuses is down: fall back at once")
    }

    func testOllamaModelListAsksOnceAndFallsBack() async {
        let probe = RetryProbe()
        let up = KitTest.engine(transport: Stub.transport(probe, script: [(200, Stub.tagsOK)]))
        let models = await up.listModels(.ollama)
        XCTAssertEqual(models, ["qwen3:4b"])
        XCTAssertEqual(probe.calls, 1)
        let down = KitTest.engine(transport: Stub.transport(RetryProbe(), script: [(503, "")]))
        let fallback = await down.listModels(.ollama)
        XCTAssertEqual(fallback, NovaAIBackend.ollama.fallbackModels)
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
        let c = config(Stub.transport(probe, script: [(503, ""), (200, Stub.chatOK)]), probe)
        let resp = await BrainClient.requestMove(moveRequest(), brain: Self.ollamaBrain, config: c)
        XCTAssertEqual(resp?.action, "WAIT")
        XCTAssertEqual(probe.calls, 2)
    }

    /// Side features (shared AI): Ollama 503 twice, then an answer.
    @MainActor
    func testFeatureGenerateRetries() async throws {
        let probe = RetryProbe()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .ollama },
                            transport: Stub.transport(probe, script: [(503, ""), (503, ""), (200, KitTest.ollama(" hello "))]),
                            sleep: probe.sleeper)
        let text = try await GameAI.shared.generate(prompt: "hi", ai: ai)
        XCTAssertEqual(text, "hello")
        XCTAssertEqual(probe.calls, 3)
    }

    /// The status check marks Ollama online from its model list (one probe, short timeout).
    @MainActor
    func testStatusCheckMarksOllamaOnline() async {
        let probe = RetryProbe()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .ollama },
                            transport: Stub.transport(probe, script: [(200, Stub.tagsOK)]))
        await ai.refreshStatus()
        XCTAssertTrue(ai.status.isReachable)
        XCTAssertEqual(ai.status.activeBackend, .ollama)
        XCTAssertEqual(probe.calls, 1)
    }

    /// MLX is an HTTP server now (mlx_lm.server, default :8081): retried like any backend.
    @MainActor
    func testMLXBackendRetriesOnFailure() async throws {
        let probe = RetryProbe()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .mlx },
                            transport: Stub.transport(probe, script: [(500, ""), (200, AIFixtures.chat("RECOMMEND_MAINTAIN_STATUS_QUO"))]),
                            sleep: probe.sleeper)
        let text = try await GameAI.shared.generate(prompt: "advice", ai: ai)
        XCTAssertEqual(text, "RECOMMEND_MAINTAIN_STATUS_QUO")
        XCTAssertEqual(probe.calls, 2)
        XCTAssertEqual(ai.status.activeBackend, .mlx)
    }

    /// Junk output counts as a failure: re-asked once, then the built-in answer.
    @MainActor
    func testJunkOutputCountsAsFailure() async {
        let probe = RetryProbe()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .mlx },
                            transport: Stub.transport(probe, script: [(200, AIFixtures.chat("??? !!!"))]))
        let gs = GameState(playerCountryID: "USA")
        let advice = await TerminalAdvisor(ai: ai).getStrategicAdvice(situation: "what should I do", gameState: gs)
        XCTAssertEqual(advice, TerminalAdvisor.builtInAdvice(gameState: gs))
        XCTAssertEqual(probe.calls, 2, "asked, rejected, asked once more, then the fallback")
    }

    func testRetryClassification() {
        XCTAssertFalse(NovaAIRetry.isRetryable(NovaAIError.disabled))
        XCTAssertFalse(NovaAIRetry.isRetryable(NovaAIError.noBackendAvailable))
        XCTAssertFalse(NovaAIRetry.isRetryable(NovaAIError.missingKey(.openAI)))
        XCTAssertTrue(NovaAIRetry.isRetryable(URLError(.networkConnectionLost)))
        XCTAssertTrue(NovaAIRetry.isRetryable(NovaAIError.httpStatus(503)))
        XCTAssertTrue(NovaAIRetry.isRetryable(NovaAIError.httpStatus(408)))
        XCTAssertFalse(NovaAIRetry.isRetryable(NovaAIError.httpStatus(400)))
        XCTAssertEqual(AppAI.configuration.retry.worstCaseSleep, 1.5, accuracy: 1e-9)
    }

    @MainActor
    func testOllamaGenerateRetriesWithBackoff() async throws {
        let probe = RetryProbe()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .ollama },
                            transport: Stub.transport(probe, script: [(500, ""), (500, ""), (200, KitTest.ollama("DEFCON 3"))]),
                            sleep: probe.sleeper)
        let text = try await GameAI.shared.generate(prompt: "status?", ai: ai)
        XCTAssertEqual(text, "DEFCON 3")
        XCTAssertEqual(probe.calls, 3)
        XCTAssertEqual(probe.sleeps, [0.5, 1.0])
    }

    @MainActor
    func testAIOffFailsFastWithoutCalls() async {
        let probe = RetryProbe()
        let ai = KitTest.ai(KitTest.settings { $0.enabled = false }, transport: Stub.transport(probe, script: [(200, "")]))
        do { _ = try await GameAI.shared.generate(prompt: "x", ai: ai); XCTFail("should throw") } catch {}
        XCTAssertEqual(probe.calls, 0)
    }
}
