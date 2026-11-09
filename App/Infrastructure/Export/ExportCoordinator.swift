// SPDX-License-Identifier: Apache-2.0
import Foundation
import Combine
import SwiftUI
import UIKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case mp3 = "MP3", mp4 = "MP4"
    var id: String { rawValue }
    var detail: String { self == .mp3 ? "Ses dosyası · 128 kbps" : "Dikey video · ilerleyen metin" }
    var icon: String { self == .mp3 ? "waveform" : "text.below.photo" }
}
struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class ExportCoordinator: ObservableObject {
    @Published private(set) var isExporting = false
    @Published private(set) var progress: Double?
    @Published private(set) var label = ""
    @Published var errorMessage: String?
    @Published var shareFile: ShareFile?
    private var task: Task<Void, Never>?
    private var worker: Task<URL, Error>?
    private var operationID: UUID?

    func export(_ recording: SpeechRecording, source: URL, format: ExportFormat) {
        guard !isExporting else { return }
        let id = UUID(); operationID = id; errorMessage = nil; shareFile = nil
        isExporting = true; progress = nil; label = "\(format.rawValue) hazırlanıyor…"
        let library = Bundle.main.url(forResource: "lame.all", withExtension: "js", subdirectory: "MP3")
        let logo = Bundle.main.url(forResource: "Logo-original", withExtension: "jpg", subdirectory: "Brand")
        let worker = Task.detached(priority: .userInitiated) { () async throws -> URL in
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("EMA-Exports", isDirectory: true)
            let directory = root.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let title = recording.title.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }.joined()
            let url = directory.appendingPathComponent("EMA-\(String(title.prefix(48))).\(format.rawValue.lowercased())")
            do {
                try Task.checkCancellation()
                if format == .mp3 {
                    guard let library else { throw MediaExportError.failed("Paketlenmiş MP3 kodlayıcı bulunamadı.") }
                    try MP3Encoder.encode(source: source, destination: url, library: library)
                } else {
                    try await CaptionVideoExporter.export(recording: recording, audioURL: source, destination: url, logoURL: logo) { value in
                        Task { @MainActor [weak self] in
                            guard self?.operationID == id else { return }; self?.progress = value
                        }
                    }
                }
                try Task.checkCancellation()
                return url
            } catch { try? FileManager.default.removeItem(at: directory); throw error }
        }
        self.worker = worker
        task = Task { [weak self] in
            do {
                let url = try await worker.value
                guard let self, self.operationID == id else { return }
                self.shareFile = ShareFile(url: url)
            } catch is CancellationError { }
            catch { if self?.operationID == id { self?.errorMessage = error.localizedDescription } }
            if self?.operationID == id { self?.isExporting = false; self?.task = nil; self?.worker = nil; self?.operationID = nil }
        }
    }
    func cancel() {
        worker?.cancel(); task?.cancel(); worker = nil; task = nil
        operationID = nil; isExporting = false; progress = nil
    }
    /// Called at launch, never while a share extension may still be reading its URL.
    static func cleanOldExports() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("EMA-Exports", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for url in contents {
            if let created = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate, Date().timeIntervalSince(created) > 86400 {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

struct FileShareSheet: UIViewControllerRepresentable {
    let file: ShareFile
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [file.url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
