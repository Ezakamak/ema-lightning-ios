import XCTest
@testable import SpeechCore

final class DiagnosticTraceTests: XCTestCase {
    func testAllTwentyStagesRequireRunningEventBeforeSuccess() {
        var trace = DiagnosticTrace(engine: "EMA", now: 10)
        XCTAssertEqual(EMAStage.allCases.count, 20)
        for stage in EMAStage.allCases {
            XCTAssertFalse(trace.transition(stage, to: .success, requestID: trace.id, now: 11))
            XCTAssertTrue(trace.transition(stage, to: .running, requestID: trace.id, now: 12))
            XCTAssertTrue(trace.transition(stage, to: .success, requestID: trace.id, now: 12.25))
            XCTAssertEqual(trace.records[stage]?.elapsed(at: 50), 0.25)
        }
        XCTAssertTrue(trace.terminal)
    }
    func testCancellationDoesNotInventDurationsOrAcceptLateEvents() {
        var trace = DiagnosticTrace(engine: "EMA", now: 0)
        trace.transition(.worker, to: .running, requestID: trace.id, now: 1)
        trace.cancel(requestID: trace.id, now: 2)
        XCTAssertEqual(trace.records[.worker]?.status, .cancelled)
        XCTAssertEqual(trace.records[.worker]?.elapsed(at: 4), 1)
        XCTAssertNil(trace.records[.runtime]?.elapsed(at: 4))
        XCTAssertFalse(trace.transition(.worker, to: .success, requestID: trace.id, now: 4))
    }
    func testErrorPreservesActualFirstFailureAndUnstartedStages() {
        var trace = DiagnosticTrace(engine: "EMA", now: 0)
        trace.transition(.server, to: .running, requestID: trace.id, now: 1)
        trace.transition(.server, to: .success, requestID: trace.id, now: 2)
        trace.transition(.worker, to: .running, requestID: trace.id, now: 3)
        trace.fail(.worker, message: "CSP error", requestID: trace.id, now: 4)
        XCTAssertEqual(trace.firstFailure, .worker)
        XCTAssertEqual(trace.lastSuccess, .server)
        XCTAssertEqual(trace.records[.runtime]?.status, .waiting)
    }
    func testStaleRequestCannotMutateNewTrace() {
        var trace = DiagnosticTrace(engine: "EMA", now: 0)
        XCTAssertFalse(trace.transition(.worker, to: .running, requestID: UUID(), now: 1))
        XCTAssertTrue(trace.events.isEmpty)
    }
    func testReportRedactionRetainsErrorKindAndRemovesPrivateContent() {
        let input = "Gizli müşteri metni 12345"
        let result = DiagnosticPrivacy.sanitize("WASM Error: \(input); api_key=SECRET at http://127.0.0.1:9999/12345678-1234-1234-1234-123456789abc/worker.js", sensitive: [input])
        XCTAssertTrue(result.contains("WASM Error"))
        XCTAssertFalse(result.contains(input)); XCTAssertFalse(result.contains("SECRET"))
        XCTAssertFalse(result.contains("12345678-1234-1234-1234-123456789abc"))
        let auth = DiagnosticPrivacy.sanitize("Authorization: Bearer PRIVATE_AUTH", sensitive: [])
        XCTAssertFalse(auth.contains("PRIVATE_AUTH"))
        let technical = "EMASpeechEngine.Failure: EMA_TEST_WORKER_ERROR"
        XCTAssertEqual(DiagnosticPrivacy.sanitize(technical, sensitive: ["Merhaba! EMA Lightning artık kendi modelini kullanıyor."]), technical)
        let once = DiagnosticPrivacy.sanitize("http://127.0.0.1:90/12345678-1234-1234-1234-123456789abc/worker.js?request=SECRET", sensitive: [])
        XCTAssertEqual(DiagnosticPrivacy.sanitize(once, sensitive: []), once)
    }
}
