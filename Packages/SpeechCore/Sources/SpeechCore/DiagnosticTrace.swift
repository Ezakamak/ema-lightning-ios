// SPDX-License-Identifier: Apache-2.0
import Foundation

public enum EMAStage: String, CaseIterable, Codable, Sendable {
    case button, validation, engine, server, webView, page, bridge, worker, runtime, normalizer
    case textModel, soundModel, decoderModel, normalization, synthesis, wav, transfer, player, playback, completed
    public var title: String {
        switch self {
        case .button: return "Oku butonuna basıldı"
        case .validation: return "Metin doğrulandı"
        case .engine: return "EMA motoru başlatılıyor"
        case .server: return "Yerel HTTP sunucusu (127.0.0.1)"
        case .webView: return "WKWebView oluşturuluyor / hazır"
        case .page: return "EMA HTML sayfası yükleniyor"
        case .bridge: return "JavaScript bridge hazır"
        case .worker: return "Web Worker başlatılıyor"
        case .runtime: return "ONNX Runtime WASM yükleniyor"
        case .normalizer: return "Türkçe normalizer yükleniyor"
        case .textModel: return "text.onnx modeli yükleniyor"
        case .soundModel: return "sound.onnx modeli yükleniyor"
        case .decoderModel: return "decoder.onnx modeli yükleniyor"
        case .normalization: return "Türkçe metin normalleştiriliyor"
        case .synthesis: return "ONNX ses sentezi çalışıyor"
        case .wav: return "WAV verisi oluşturuluyor"
        case .transfer: return "Ses dosyası Swift tarafına aktarılıyor"
        case .player: return "AVAudioPlayer hazırlanıyor"
        case .playback: return "Ses oynatılıyor"
        case .completed: return "İşlem tamamlandı"
        }
    }
}

public enum DiagnosticStatus: String, Codable, Sendable {
    case waiting, running, success, error, cancelled
    public var label: String {
        switch self {
        case .waiting: return "⏳ Bekliyor"
        case .running: return "🔄 Çalışıyor"
        case .success: return "✅ Başarılı"
        case .error: return "❌ Hata"
        case .cancelled: return "⏹ İptal edildi"
        }
    }
}

public struct StageRecord: Sendable {
    public let stage: EMAStage
    public var status: DiagnosticStatus = .waiting
    public var started: TimeInterval?
    public var ended: TimeInterval?
    public var detail = ""
    public func elapsed(at now: TimeInterval) -> TimeInterval? {
        guard let started else { return nil }
        return max(0, (ended ?? now) - started)
    }
}

public struct DiagnosticEvent: Identifiable, Sendable {
    public let id: Int
    public let offset: TimeInterval
    public let message: String
}

/// Deterministic, request-scoped state machine. Success requires a real running stage.
public struct DiagnosticTrace: Sendable {
    public let id: UUID
    public let started: TimeInterval
    public let engine: String
    public private(set) var records: [EMAStage: StageRecord]
    public private(set) var events: [DiagnosticEvent] = []
    public private(set) var firstFailure: EMAStage?
    public private(set) var lastSuccess: EMAStage?
    public private(set) var terminal = false
    private var eventNumber = 0

    public init(id: UUID = UUID(), engine: String, now: TimeInterval) {
        self.id = id; self.engine = engine; self.started = now
        records = Dictionary(uniqueKeysWithValues: EMAStage.allCases.map { ($0, StageRecord(stage: $0)) })
    }

    @discardableResult
    public mutating func transition(_ stage: EMAStage, to status: DiagnosticStatus,
                                    detail: String = "", requestID: UUID, now: TimeInterval) -> Bool {
        guard requestID == id, !terminal, var record = records[stage] else { return false }
        switch (record.status, status) {
        case (.waiting, .running): record.started = now
        case (.running, .success), (.running, .error), (.running, .cancelled): record.ended = now
        default: return false
        }
        record.status = status; record.detail = detail; records[stage] = record
        if status == .success { lastSuccess = stage }
        if status == .error && firstFailure == nil { firstFailure = stage }
        note("\(status.label) \(stage.title)\(detail.isEmpty ? "" : " — " + detail)", now: now)
        if stage == .completed && status == .success { terminal = true }
        return true
    }

    public mutating func note(_ message: String, now: TimeInterval) {
        eventNumber += 1
        events.append(DiagnosticEvent(id: eventNumber, offset: max(0, now - started), message: message))
        if events.count > 300 { events.removeFirst(events.count - 300) }
    }

    public mutating func fail(_ stage: EMAStage, message: String, requestID: UUID, now: TimeInterval) {
        guard requestID == id, !terminal else { return }
        if records[stage]?.status == .waiting { transition(stage, to: .running, requestID: id, now: now) }
        transition(stage, to: .error, detail: message, requestID: id, now: now)
        for item in EMAStage.allCases where records[item]?.status == .running {
            transition(item, to: .cancelled, detail: "İşlem hata nedeniyle durduruldu", requestID: id, now: now)
        }
        terminal = true
    }

    public mutating func cancel(requestID: UUID, now: TimeInterval) {
        guard requestID == id, !terminal else { return }
        for stage in EMAStage.allCases {
            if records[stage]?.status == .waiting {
                records[stage]?.status = .cancelled // Never-started stages have no invented duration.
            } else if records[stage]?.status == .running {
                transition(stage, to: .cancelled, requestID: id, now: now)
            }
        }
        note("⏹ İstek iptal edildi", now: now)
        terminal = true
    }
}

public enum DiagnosticPrivacy {
    public static func sanitize(_ message: String, sensitive: [String]) -> String {
        var text = message
        // Whole input and its constituent words are private, including errors that echo a token.
        for value in sensitive where !value.isEmpty {
            text = text.replacingOccurrences(of: value, with: "[metin gizlendi]", options: .caseInsensitive)
            for token in value.split(whereSeparator: { $0.isWhitespace }) where token.count >= 2 {
                text = text.replacingOccurrences(of: String(token), with: "[gizlendi]", options: .caseInsensitive)
            }
        }
        let patterns: [(String, String)] = [
            (#"(?i)(api[_-]?key|access[_-]?token|authorization|bearer|password)\s*[:= ]\s*[^\s,;]+"#, "$1=[gizlendi]"),
            (#"https?://127\.0\.0\.1(?::\d+)?/[0-9A-Fa-f-]{36}/"#, "http://127.0.0.1/[yerel]/"),
            (#"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#, "[kimlik gizlendi]"),
            (#"(https?://[^\s?]+)\?[^\s]*"#, "$1?[parametreler gizlendi]")
        ]
        for (pattern, replacement) in patterns {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return String(text.prefix(6000))
    }
}
