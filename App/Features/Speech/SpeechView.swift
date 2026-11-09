// SPDX-License-Identifier: Apache-2.0
import SwiftUI

private struct RequestStatus: View {
    @ObservedObject var diagnostics: EMADiagnostics
    let working: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if diagnostics.tapAcknowledged {
                Text("✅ Oku butonuna basıldı").accessibilityIdentifier("tapAcknowledgement")
            }
            if working {
                HStack {
                    ProgressView()
                    Text(diagnostics.currentStage?.title ?? "İstek hazırlanıyor…")
                }.accessibilityIdentifier("liveStage")
            }
        }.font(.footnote)
    }
}

struct SpeechView: View {
    @ObservedObject var model: SpeechViewModel
    var body: some View {
        NavigationStack {
            Form {
                Section("Ses motoru") {
                    Picker("Motor", selection: $model.choice) {
                        ForEach(EngineChoice.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text(model.choice == .ema ? "Gerçek EMA ONNX · çevrimdışı CPU/WASM · 48 kHz" : "Apple sistem sesi alternatifi; EMA modeli kullanılmaz.")
                        .font(.footnote)
                }
                Section("Metin") {
                    TextEditor(text: $model.text).frame(minHeight: 110)
                        .accessibilityLabel("Okunacak metin").accessibilityIdentifier("speechInput")
                    Text("\(model.text.count) / 1.000 karakter").font(.caption)
                }
                Section {
                    HStack {
                        // Explicit styles prevent Form's automatic row action from invoking BOTH buttons.
                        Button("Oku", systemImage: "play.fill", action: model.speak)
                            .buttonStyle(.borderedProminent).disabled(model.isGenerating)
                            .accessibilityIdentifier("readButton")
                        Spacer()
                        Button("Durdur", systemImage: "stop.fill", action: model.stop)
                            .buttonStyle(.bordered).accessibilityIdentifier("stopButton")
                    }
                    RequestStatus(diagnostics: model.diagnostics, working: model.isGenerating)
                }
                if let message = model.errorMessage {
                    Section("EMA hata ayrıntısı") {
                        Text(message).foregroundStyle(.red).textSelection(.enabled)
                            .accessibilityIdentifier("engineError")
                    }
                }
                DiagnosticsPanel(diagnostics: model.diagnostics)
                Section("Açık kaynak") {
                    Text("EMA: Canberk Aslan · ONNX: Özcan Çelik").font(.footnote)
                    Link("Kaynak kodu ve katkı", destination: URL(string: "https://github.com/Ezakamak/ema-lightning-ios")!)
                }
            }
            .navigationTitle("EMA Lightning iOS")
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("Yerel EMA çalışma alanı").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    InferenceViewport(engine: model.ema).frame(width: 80, height: 48)
                        .accessibilityHidden(true)
                }.padding(.horizontal).background(.bar)
            }
            .onDisappear(perform: model.stop)
        }
    }
}
