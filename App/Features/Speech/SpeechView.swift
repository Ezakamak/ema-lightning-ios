// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import WebKit

private struct InferenceWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
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
                    if model.choice == .ema {
                        Text("Gerçek EMA ONNX modeli · CPU/WASM · 48 kHz. Model, Türkçe normalizer ve çalışma zamanı uygulamanın içindedir; internetten dosya indirilmez.")
                            .font(.footnote)
                        Text("İlk üretim model yüklenirken zaman alabilir. Ses hazır olduğunda çalınır. Fiziksel cihazda uçak modu doğrulaması bekleniyor.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Bu alternatif Apple’ın Türkçe sistem sesidir; EMA modeli kullanılmaz.")
                            .font(.footnote)
                    }
                }
                Section("Metin") {
                    TextEditor(text: $model.text)
                        .frame(minHeight: 160).accessibilityLabel("Okunacak metin")
                    Text("\(model.text.count) / 1.000 karakter")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    if model.isGenerating { ProgressView("Ses üretiliyor…") }
                    HStack {
                        Button("Oku", systemImage: "play.fill", action: model.speak)
                            .disabled(model.isGenerating)
                        Spacer()
                        Button("Durdur", systemImage: "stop.fill", action: model.stop)
                    }
                }
                if let message = model.errorMessage {
                    Section("Hata") { Text(message).foregroundStyle(.red) }
                }
                Section("Açık kaynak") {
                    Text("EMA Lightning: Canberk Aslan\nONNX uyarlaması: Özcan Çelik")
                    Text("Apache-2.0 · ONNX Runtime: MIT")
                    Link("Kaynak kodu ve katkı", destination: URL(string: "https://github.com/Ezakamak/ema-lightning-ios")!)
                }
            }
            .navigationTitle("EMA Lightning iOS")
            .background(InferenceWebView(webView: model.ema.webView)
                .frame(width: 1, height: 1).accessibilityHidden(true))
            .onDisappear(perform: model.stop)
        }
    }
}
