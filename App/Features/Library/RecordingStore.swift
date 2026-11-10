// SPDX-License-Identifier: Apache-2.0
import Foundation
import Combine

struct SpeechRecording: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    let text: String
    let createdAt: Date
    let duration: Double
    let engine: String
    var filename: String { id.uuidString + ".wav" }
    var durationLabel: String {
        let seconds = Int(duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

@MainActor
final class RecordingStore: ObservableObject {
    @Published private(set) var recordings: [SpeechRecording] = []
    @Published var errorMessage: String?
    let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("recordings.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EMA/Recordings", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: indexURL.path) {
                recordings = try JSONDecoder().decode([SpeechRecording].self, from: Data(contentsOf: indexURL))
                recordings = recordings.filter { FileManager.default.fileExists(atPath: url(for: $0).path) }
                    .sorted { $0.createdAt > $1.createdAt }
            }
        } catch { errorMessage = "Kayıt arşivi açılamadı: \(error.localizedDescription)" }
    }
    func url(for recording: SpeechRecording) -> URL { directory.appendingPathComponent(recording.filename) }

    @discardableResult
    func add(wav: Data, text: String, duration: Double, engine: String) async throws -> SpeechRecording {
        let title = String(text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(52))
        let recording = SpeechRecording(id: UUID(), title: title, text: text, createdAt: Date(), duration: duration, engine: engine)
        let destination = url(for: recording)
        try await Task.detached(priority: .utility) {
            try Task.checkCancellation()
            try wav.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }.value
        do {
            let updated = [recording] + recordings
            try persist(updated)
            recordings = updated
            return recording
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
    func rename(_ recording: SpeechRecording, title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        var updated = recordings
        updated[index].title = String(trimmed.prefix(100))
        try persist(updated); recordings = updated
    }
    func remove(_ recording: SpeechRecording) throws {
        let updated = recordings.filter { $0.id != recording.id }
        try persist(updated); recordings = updated
        if FileManager.default.fileExists(atPath: url(for: recording).path) { try FileManager.default.removeItem(at: url(for: recording)) }
    }
    func removeAll() throws {
        let old = recordings
        try persist([]); recordings = []
        for recording in old { try? FileManager.default.removeItem(at: url(for: recording)) }
    }
    private func persist(_ value: [SpeechRecording]) throws {
        try JSONEncoder().encode(value).write(to: indexURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
