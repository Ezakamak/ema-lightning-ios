// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import SpeechCore

@MainActor
struct DiagnosticsPanel: View {
    @ObservedObject var diagnostics: EMADiagnostics
    @State private var expanded = false
    @State private var copied = false

    var body: some View {
        Section {
            DisclosureGroup("EMA Motor Durumu", isExpanded: $expanded) {
                if expanded {
                TimelineView(.periodic(from: .now, by: diagnostics.trace?.terminal == false ? 0.2 : 3600)) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(EMAStage.allCases.enumerated()), id: \.element) { index, stage in
                            let record = diagnostics.trace?.records[stage]
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(index + 1). \(stage.title)").font(.subheadline)
                                Text("\(record?.status.label ?? DiagnosticStatus.waiting.label) · \(EMADiagnostics.duration(record?.elapsed(at: diagnostics.now)))")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let detail = record?.detail, !detail.isEmpty {
                                    Text(detail).font(.caption).textSelection(.enabled)
                                }
                            }.accessibilityIdentifier("stage-\(stage.rawValue)")
                        }
                    }
                }
                }
                if let trace = diagnostics.trace {
                    Text("Son başarılı: \(trace.lastSuccess?.title ?? "Yok")\nİlk hata: \(trace.firstFailure?.title ?? "Yok")")
                        .font(.footnote)
                    Text(trace.events.map { "[\(EMADiagnostics.timestamp($0.offset))] \($0.message)" }.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        .accessibilityIdentifier("diagnosticEvents")
                }
                Button(copied ? "Loglar Kopyalandı" : "Logları Kopyala") {
                    UIPasteboard.general.string = diagnostics.report()
                    copied = true
                }.buttonStyle(.bordered).accessibilityIdentifier("copyLogsButton")
                ShareLink("Tanılama Raporunu Paylaş", item: diagnostics.report())
                    .buttonStyle(.bordered).accessibilityIdentifier("shareDiagnosticsButton")
            }.accessibilityIdentifier("diagnosticsPanel")
        }
    }
}
