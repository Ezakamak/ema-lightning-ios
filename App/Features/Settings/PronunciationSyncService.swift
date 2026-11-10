// SPDX-License-Identifier: Apache-2.0
import Foundation
import Combine
import CryptoKit
import SpeechCore

struct CentralDictionary: Codable {
    let version: Int
    let schemaVersion: Int
    let locale: String
    let ruleCount: Int
    let updatedAt: String
    let checksum: String
    let rules: [PronunciationRule]

    func validate() throws {
        guard version > 0, schemaVersion == 1, locale == "tr-TR", ruleCount > 0,
              ruleCount <= 5000, rules.count == ruleCount,
              Set(rules.map(\.id)).count == ruleCount,
              ISO8601DateFormatter().date(from: updatedAt) != nil else { throw SyncFailure.invalid }
        for rule in rules {
            let valid = try PronunciationRule.validated(word: rule.word, pronunciation: rule.pronunciation)
            guard valid.word == rule.word, valid.pronunciation == rule.pronunciation,
                  !rule.category.isEmpty, rule.category.count <= 80 else { throw SyncFailure.invalid }
        }
        guard checksum == Self.digest(rules) else { throw SyncFailure.invalid }
    }
    static func digest(_ rules: [PronunciationRule]) -> String {
        func hex(_ s: String) -> String { s.utf8.map { String(format: "%02x", $0) }.joined() }
        let canonical = rules.map { [ $0.id, $0.word, $0.pronunciation, $0.category ].map(hex).joined(separator: ":") }.sorted().joined(separator: "\n")
        return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
private enum SyncFailure: Error { case invalid, response }

@MainActor
final class PronunciationSyncService: ObservableObject {
    @Published private(set) var dictionary: CentralDictionary?
    @Published private(set) var lastSuccess: Date?
    @Published private(set) var checking = false
    @Published private(set) var message = "Kayıtlı sözlük çevrimdışı kullanıma hazır."
    private let session: URLSession
    private let directory: URL
    private let defaults: UserDefaults
    private let baseURL: URL
    private let now: () -> Date
    private var nextAttempt: Date
    private var failures: Int
    private var etag: String?
    private let maxBytes = 1_048_576
    private var file: URL { directory.appendingPathComponent("central-v1.json") }

    init(session: URLSession? = nil, directory: URL? = nil, defaults: UserDefaults = .standard,
         baseURL: URL = URL(string: "https://speak.ekatech.net/api/v1/pronunciations")!,
         now: @escaping () -> Date = Date.init) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.waitsForConnectivity = false
        self.session = session ?? URLSession(configuration: config)
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Pronunciations", isDirectory: true)
        self.defaults = defaults; self.baseURL = baseURL; self.now = now
        nextAttempt = defaults.object(forKey: "pronunciation.nextCheck") as? Date ?? .distantPast
        failures = defaults.integer(forKey: "pronunciation.syncFailures")
        lastSuccess = defaults.object(forKey: "pronunciation.lastSuccess") as? Date
        if let data = try? Data(contentsOf: self.directory.appendingPathComponent("central-v1.json")), data.count <= maxBytes,
           let cached = try? JSONDecoder().decode(CentralDictionary.self, from: data), (try? cached.validate()) != nil {
            dictionary = cached
            etag = defaults.string(forKey: "pronunciation.versionETag")
        } else {
            // Corrupt cache must trigger a fresh full download even after a recent successful check.
            nextAttempt = .distantPast
        }
    }

    func check(force: Bool = false) async {
        guard !checking, force || now() >= nextAttempt else { return }
        checking = true; message = "Güncelleme kontrol ediliyor…"
        defer { checking = false }
        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("version"))
            if dictionary != nil, let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            let (data, response) = try await fetch(request)
            if response.statusCode == 304 {
                guard dictionary != nil else { throw SyncFailure.invalid }
                succeeded(updated: false); return
            }
            guard response.statusCode == 200 else { throw SyncFailure.response }
            struct Version: Decodable { let version: Int; let schemaVersion: Int; let locale: String; let ruleCount: Int; let checksum: String }
            let version = try JSONDecoder().decode(Version.self, from: data)
            guard version.schemaVersion == 1, version.locale == "tr-TR", version.version > 0,
                  version.ruleCount > 0, version.ruleCount <= 5000 else { throw SyncFailure.invalid }
            if let current = dictionary {
                guard version.version >= current.version else { throw SyncFailure.invalid }
                if version.version == current.version {
                    guard version.checksum == current.checksum, version.ruleCount == current.ruleCount else { throw SyncFailure.invalid }
                    etag = response.value(forHTTPHeaderField: "ETag")
                    succeeded(updated: false); return
                }
            }
            let (snapshotData, snapshotResponse) = try await fetch(URLRequest(url: baseURL))
            guard snapshotResponse.statusCode == 200 else { throw SyncFailure.response }
            let snapshot = try stageAndValidate(snapshotData)
            // Different edge entries can be up to five minutes apart: retry later, never install a mismatch.
            guard snapshot.version == version.version, snapshot.checksum == version.checksum,
                  snapshot.ruleCount == version.ruleCount else { throw SyncFailure.invalid }
            try persist(snapshotData)
            dictionary = snapshot
            etag = response.value(forHTTPHeaderField: "ETag")
            succeeded(updated: true)
        } catch {
            failures = min(failures + 1, 8)
            nextAttempt = now().addingTimeInterval(min(86400, 300 * pow(2, Double(failures - 1))))
            defaults.set(nextAttempt, forKey: "pronunciation.nextCheck")
            defaults.set(failures, forKey: "pronunciation.syncFailures")
            if let network = error as? URLError, network.code == .notConnectedToInternet {
                message = "İnternet bağlantısı yok. Kayıtlı sözlük kullanılıyor."
            } else { message = "Güncelleme kontrol edilemedi. Seslendirme çevrimdışı çalışmaya devam ediyor." }
        }
    }
    private func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Stream with a hard decoded byte cap; partial and oversized downloads cannot replace the cache.
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.url?.scheme == "https",
              http.url?.host == baseURL.host, http.url?.path == request.url?.path,
              http.expectedContentLength <= maxBytes else { throw SyncFailure.response }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maxBytes else { throw SyncFailure.invalid }
            data.append(byte)
        }
        return (data, http)
    }
    private func stageAndValidate(_ data: Data) throws -> CentralDictionary {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let temporary = directory.appendingPathComponent(".download-\(UUID().uuidString).json")
        defer { try? manager.removeItem(at: temporary) }
        try data.write(to: temporary, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let staged = try Data(contentsOf: temporary)
        let snapshot = try JSONDecoder().decode(CentralDictionary.self, from: staged)
        try snapshot.validate()
        return snapshot
    }
    private func persist(_ data: Data) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        // Foundation atomic writes create a sibling temporary file then rename it into place.
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var url = file
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
    private func succeeded(updated: Bool) {
        failures = 0; lastSuccess = now(); nextAttempt = now().addingTimeInterval(86400)
        defaults.set(lastSuccess, forKey: "pronunciation.lastSuccess")
        defaults.set(nextAttempt, forKey: "pronunciation.nextCheck")
        defaults.set(0, forKey: "pronunciation.syncFailures")
        defaults.set(etag, forKey: "pronunciation.versionETag")
        message = updated ? "Yeni telaffuz kuralları indirildi." : "Türkçe telaffuz sözlüğü güncel."
    }
}
