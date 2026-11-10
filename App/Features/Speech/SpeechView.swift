// SPDX-License-Identifier: Apache-2.0
import SwiftUI

struct SpeechView: View {
    @ObservedObject var model: SpeechViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Metin") {
                    TextEditor(text: $model.text)
                        .frame(minHeight: 180)
                        .accessibilityLabel("Okunacak metin")
                    Text("\(model.text.count) / 5.000 karakter")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Sistem sesiyle önizleme") {
                    Text(model.engineName)
                    Text("EMA/ONNX motorunun yerel iOS entegrasyonu henüz hazır değil. Bu önizleme Apple’ın sistem sesini kullanır.")
                        .font(.footnote).foregroundStyle(.secondary)
                    HStack {
                        Button("Oku", systemImage: "play.fill", action: model.speak)
                        Spacer()
                        Button("Durdur", systemImage: "stop.fill", action: model.stop)
                    }
                }
                if let message = model.errorMessage {
                    Section("Hata") { Text(message).foregroundStyle(.red) }
                }
                Section("Açık kaynak") {
                    Text("EMA Lightning: Canberk Aslan\nONNX uyarlaması: Özcan Çelik")
                    Text("iOS kaynak kodu: Apache-2.0")
                    Link("Kaynak kodu ve katkı", destination: URL(string: "https://github.com/Ezakamak/ema-lightning-ios")!)
                }
            }
            .navigationTitle("EMA Lightning iOS")
            .onDisappear(perform: model.stop)
        }
    }
}
