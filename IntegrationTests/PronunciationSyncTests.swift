// SPDX-License-Identifier: Apache-2.0
import XCTest
import UIKit
import SpeechCore
@testable import EMALightning

private final class DictionaryURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data, [String: String]))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data, headers) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@MainActor
final class PronunciationSyncTests: XCTestCase {
    private func fixture(_ version: Int = 1) -> CentralDictionary {
        let rules = [PronunciationRule(word: "İphone", pronunciation: "ayfon", category: "Apple"), PronunciationRule(word: "Işık", pronunciation: "ışık", category: "Türkçe")]
        return CentralDictionary(version: version, schemaVersion: 1, locale: "tr-TR", ruleCount: rules.count,
                                 updatedAt: "2026-11-10T00:00:00Z", checksum: CentralDictionary.digest(rules), rules: rules)
    }
    private func make(_ directory: URL, _ defaults: UserDefaults) -> PronunciationSyncService {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 30
        config.protocolClasses = [DictionaryURLProtocol.self]
        return PronunciationSyncService(session: URLSession(configuration: config), directory: directory, defaults: defaults, enableV2: false)
    }
    private func setup() -> (URL, UserDefaults) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        addTeardownBlock { try? FileManager.default.removeItem(at: directory); DictionaryURLProtocol.handler = nil }
        return (directory, defaults)
    }
    private func serve(_ snapshot: CentralDictionary, calls: @escaping (String) -> Void = { _ in }) throws {
        let data = try JSONEncoder().encode(snapshot)
        DictionaryURLProtocol.handler = { request in
            calls(request.url!.path)
            XCTAssertEqual(request.httpMethod, "GET"); XCTAssertNil(request.httpBody); XCTAssertNil(request.url?.query)
            return (200, data, ["ETag": "\"test-\(snapshot.version)\""])
        }
    }
    func testBundledChecksumMatchesPublishedSnapshot() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "pronunciations", withExtension: "json", subdirectory: "EMA"))
        let rules = try JSONDecoder().decode([PronunciationRule].self, from: Data(contentsOf: url))
        XCTAssertEqual(CentralDictionary.digest(rules), "25c58ac2debbef6e9af15d3c5a895c8153f785070139897938e13ade0ef248b1")
    }
    func testFirstLaunchDownloadPersistenceSameVersionAndNewVersion() async throws {
        let (directory, defaults) = setup(), service = make(directory, defaults)
        XCTAssertNil(service.dictionary)
        var count = 0
        try serve(fixture(), calls: { _ in count += 1 })
        await service.check(force: true)
        XCTAssertEqual(count, 2); XCTAssertEqual(service.dictionary?.version, 1)
        let restored = make(directory, defaults)
        XCTAssertEqual(restored.dictionary?.version, 1)
        await restored.check() // 24 hour interval survives relaunch.
        XCTAssertEqual(count, 2)
        await restored.check(force: true)
        XCTAssertEqual(count, 3) // version only
        DictionaryURLProtocol.handler = { request in
            XCTAssertNotNil(request.value(forHTTPHeaderField: "If-None-Match"))
            return (304, Data(), [:])
        }
        await restored.check(force: true)
        XCTAssertEqual(restored.dictionary?.version, 1)
        try serve(fixture(2)); await restored.check(force: true)
        XCTAssertEqual(restored.dictionary?.version, 2)
    }
    func testOfflineTimeout500InvalidJSONPartialAndSchemaRetainLastGoodCache() async throws {
        let (directory, defaults) = setup(), service = make(directory, defaults)
        try serve(fixture()); await service.check(force: true)
        let before = try Data(contentsOf: directory.appendingPathComponent("central-v1.json"))
        for code in [URLError.notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost] {
            DictionaryURLProtocol.handler = { _ in throw URLError(code) }
            await service.check(force: true)
            XCTAssertEqual(service.dictionary?.version, 1); XCTAssertFalse(service.checking)
        }
        for (status, data) in [(500, Data()), (200, Data("{".utf8)), (200, Data("{\"version\":2".utf8)), (200, Data(repeating: 65, count: 1_048_577))] {
            DictionaryURLProtocol.handler = { _ in (status, data, [:]) }
            await service.check(force: true); XCTAssertEqual(service.dictionary?.version, 1)
        }
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture(2))) as! [String: Any]
        for schema in [2, 0] {
            object["schemaVersion"] = schema
            let data = try JSONSerialization.data(withJSONObject: object)
            DictionaryURLProtocol.handler = { _ in (200, data, [:]) }
            await service.check(force: true); XCTAssertEqual(service.dictionary?.version, 1)
        }
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("central-v1.json")), before)
    }
    func testInvalidDownloadedChecksumAndDowngrade() async throws {
        let (directory, defaults) = setup(), service = make(directory, defaults)
        try serve(fixture(2)); await service.check(force: true)
        try serve(fixture(1)); await service.check(force: true)
        XCTAssertEqual(service.dictionary?.version, 2)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture(3))) as! [String: Any]
        object["checksum"] = String(repeating: "0", count: 64)
        let bad = try JSONSerialization.data(withJSONObject: object)
        DictionaryURLProtocol.handler = { _ in (200, bad, [:]) }
        await service.check(force: true); XCTAssertEqual(service.dictionary?.version, 2)
    }
    func testCorruptCacheAndFirstInstallOfflineFallBackToBundle() async throws {
        let (directory, defaults) = setup()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("central-v1.json"))
        let service = make(directory, defaults)
        DictionaryURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await service.check(force: true)
        let store = PronunciationStore(defaults: defaults, sync: service)
        XCTAssertNil(service.dictionary); XCTAssertFalse(store.effectiveRules.isEmpty)
        XCTAssertEqual(store.effectiveRules.count, store.builtIns.count)
    }
    func testPersonalOverrideDisabledTombstoneDeletionAndRequestSnapshot() async throws {
        let (directory, defaults) = setup(), service = make(directory, defaults)
        let store = PronunciationStore(defaults: defaults, sync: service)
        try store.save(word: "iPhone", pronunciation: "telefon", enabled: true, replacingID: nil)
        let activeRequestRules = store.effectiveRules // EMA takes this value snapshot before its first await.
        try serve(fixture()); await service.check(force: true)
        XCTAssertEqual(store.effectiveRules.first { $0.id == "iphone" }?.pronunciation, "telefon")
        XCTAssertEqual(activeRequestRules.first { $0.id == "iphone" }?.pronunciation, "telefon")
        let entry = try XCTUnwrap(store.personal.first)
        try store.save(word: "iPhone", pronunciation: "telefon", enabled: false, replacingID: entry.id)
        XCTAssertNil(store.effectiveRules.first { $0.id == "iphone" })
        try store.remove(try XCTUnwrap(store.personal.first))
        XCTAssertEqual(store.effectiveRules.first { $0.id == "iphone" }?.pronunciation, "ayfon")
        XCTAssertEqual(PronunciationStore(defaults: defaults, sync: service).personal.count, 0)
    }
    func testRealEMARequestKeepsSnapshotDuringSyncAndNextRequestWorksOffline() async throws {
        let (directory, defaults) = setup(), service = make(directory, defaults)
        try serve(fixture()); await service.check(force: true)
        let store = PronunciationStore(defaults: defaults, sync: service)
        let engine = EMASpeechEngine(pronunciations: store)
        let window = UIWindow(frame: UIScreen.main.bounds)
        let controller = UIViewController()
        window.rootViewController = controller; window.makeKeyAndVisible()
        let host = InferenceHostView(engine: engine)
        controller.view.addSubview(host)
        host.frame = CGRect(x: 0, y: 0, width: 160, height: 80)
        host.layoutIfNeeded()
        defer { engine.stop(); window.isHidden = true }
        var finished = false
        let rendering = Task { @MainActor in
            defer { finished = true }
            return try await engine.render(SpeechRequest(text: "iPhone."))
        }
        defer { rendering.cancel() }
        // perform() captures its lexicon before its first await and begins diagnostics in that turn.
        while engine.diagnostics.trace == nil { await Task.yield() }
        let rules = [PronunciationRule(word: "iPhone", pronunciation: "telefon", category: "Apple")]
        let updated = CentralDictionary(version: 2, schemaVersion: 1, locale: "tr-TR", ruleCount: 1,
            updatedAt: "2026-11-10T00:00:00Z", checksum: CentralDictionary.digest(rules), rules: rules)
        try serve(updated); await service.check(force: true)
        XCTAssertEqual(service.dictionary?.version, 2)
        XCTAssertFalse(finished, "The dictionary update must overlap the real request")
        let first = try await rendering.value
        XCTAssertTrue(first.normalizedText.contains("ayfon"))
        XCTAssertFalse(first.normalizedText.contains("telefon"))
        XCTAssertGreaterThan(first.rms, 1e-5)
        DictionaryURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await service.check(force: true)
        let next = try await engine.render(SpeechRequest(text: "iPhone."))
        XCTAssertTrue(next.normalizedText.contains("telefon"))
        XCTAssertGreaterThan(next.sampleCount, 4800)
        XCTAssertGreaterThan(next.rms, 1e-5)
    }
    func testBackoffAndSingleFlight() async throws {
        let (directory, defaults) = setup(), service = make(directory, defaults)
        var calls = 0
        DictionaryURLProtocol.handler = { _ in calls += 1; throw URLError(.timedOut) }
        async let first: Void = service.check(force: true)
        async let second: Void = service.check(force: true)
        _ = await (first, second)
        XCTAssertEqual(calls, 1)
        await service.check(); XCTAssertEqual(calls, 1)
        await make(directory, defaults).check(); XCTAssertEqual(calls, 1)
        await service.check(force: true); XCTAssertEqual(calls, 2)
    }
}
