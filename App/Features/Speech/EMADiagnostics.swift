// SPDX-License-Identifier: Apache-2.0
import Foundation
import Combine
import UIKit
import Darwin
import SpeechCore

@MainActor
final class EMADiagnostics: ObservableObject {
    @Published private(set) var trace: DiagnosticTrace?
    private var sensitive: [String] = []
    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    var currentStage: EMAStage? {
        EMAStage.allCases.last { trace?.records[$0]?.status == .running }
    }
    var tapAcknowledged: Bool { trace?.records[.button]?.status == .success }

    @discardableResult
    func begin(engine: String, input: String = "") -> UUID {
        sensitive = input.isEmpty ? [] : [input]
        let value = DiagnosticTrace(engine: engine, now: now)
        trace = value
        return value.id
    }
    func protect(_ value: String) { sensitive.append(value) }
    func clean(_ value: String) -> String { DiagnosticPrivacy.sanitize(value, sensitive: sensitive) }
    func note(_ value: String, id: UUID) {
        guard trace?.id == id else { return }
        trace?.note(clean(value), now: now)
    }
    @discardableResult
    func update(_ stage: EMAStage, _ status: DiagnosticStatus, id: UUID, detail: String = "") -> Bool {
        trace?.transition(stage, to: status, detail: clean(detail), requestID: id, now: now) ?? false
    }
    func fail(_ stage: EMAStage, error: String, id: UUID) {
        trace?.fail(stage, message: clean(error), requestID: id, now: now)
    }
    func cancel(id: UUID) { trace?.cancel(requestID: id, now: now) }

    static func duration(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "—" }
        return seconds < 1 ? String(format: "%.0f ms", seconds * 1000) : String(format: "%.2f s", seconds)
    }
    static func timestamp(_ offset: TimeInterval) -> String {
        let ms = Int(offset * 1000)
        return String(format: "%02d:%02d.%03d", ms / 60000, (ms / 1000) % 60, ms % 1000)
    }
    func report() -> String {
        var machine = utsname()
        uname(&machine)
        let machineCapacity = MemoryLayout.size(ofValue: machine.machine)
        let identifier = withUnsafePointer(to: &machine.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: machineCapacity) { String(cString: $0) }
        }
        var length = 0
        sysctlbyname("kern.osversion", nil, &length, nil, 0)
        var osBuild = [CChar](repeating: 0, count: max(1, length))
        sysctlbyname("kern.osversion", &osBuild, &length, nil, 0)
        let bundle = Bundle.main
        let modelName = identifier == "iPhone16,2" ? "iPhone 15 Pro Max" : UIDevice.current.model
        var lines = ["EMA Lightning iOS — Tanılama raporu", "Cihaz modeli: \(modelName) / \(identifier)",
                     "iOS: \(UIDevice.current.systemVersion) / build \(String(cString: osBuild))",
                     "Uygulama: \(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "?") (\(bundle.object(forInfoDictionaryKey: "CFBundleVersion") ?? "?"))"]
        guard let trace else { return lines.joined(separator: "\n") + "\nHenüz istek yok." }
        lines += ["Seçilen motor: \(trace.engine)", "Son başarılı aşama: \(trace.lastSuccess?.title ?? "Yok")",
                  "İlk başarısız aşama: \(trace.firstFailure?.title ?? "Yok")", "", "Aşamalar:"]
        for (index, stage) in EMAStage.allCases.enumerated() {
            guard let record = trace.records[stage] else { continue }
            lines.append("\(index + 1). \(record.status.label) \(stage.title) [\(Self.duration(record.elapsed(at: now)))] \(record.detail)")
        }
        lines += ["", "Olaylar:"]
        lines += trace.events.map { "[\(Self.timestamp($0.offset))] \($0.message)" }
        lines += ["", "Girilen metin, ses verisi, erişim anahtarı, cihaz adı veya benzersiz cihaz kimliği rapora eklenmez."]
        return clean(lines.joined(separator: "\n"))
    }
}
