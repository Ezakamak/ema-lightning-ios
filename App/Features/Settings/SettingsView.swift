// SPDX-License-Identifier: Apache-2.0
import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var model: SpeechViewModel
    @ObservedObject var library: RecordingStore
    @ObservedObject var playback: RecordingPlayback
    @ObservedObject var exporter: ExportCoordinator
    @State private var confirmDeleteAll = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        BrandLogo(size: 64)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("EMA Lightning").font(.headline)
                            Text("Türkçe ses stüdyon.").font(.subheadline).foregroundStyle(.secondary)
                            Text("\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }.padding(.vertical, 8)
                }
                Section {
                    Picker("Görünüm", selection: $settings.appearance) {
                        Text("Sistem").tag(0); Text("Açık").tag(1); Text("Koyu").tag(2)
                    }
                    Picker("Ses motoru", selection: $model.choice) {
                        Text("EMA Lightning").tag(EngineChoice.ema)
                        Text("Apple önizlemesi").tag(EngineChoice.system)
                    }.disabled(model.isGenerating)
                } header: { Text("Kişiselleştir") } footer: { Text("EMA sesi çevrimdışı çalışır ve otomatik kaydedilir. Apple sesi yalnızca alternatif önizlemedir.") }
                Section("Okuma") {
                    NavigationLink {
                        PronunciationDictionaryView(store: model.pronunciations)
                    } label: { Label("Telaffuz sözlüğü", systemImage: "text.book.closed") }
                }
                Section {
                    Toggle("Geliştirici Modu", isOn: $settings.developerMode).accessibilityIdentifier("developerModeToggle")
                    if settings.developerMode {
                        NavigationLink("EMA Motor Durumu") {
                            ScrollView { DiagnosticsPanel(diagnostics: model.diagnostics).padding(20) }
                                .navigationTitle("Tanılama").navigationBarTitleDisplayMode(.inline)
                        }
                    }
                } header: { Text("Gelişmiş") } footer: {
                    Text("Açıldığında teknik aşamalar, süreler ve hata ayrıntıları görünür. Tanılama raporları yazdığın metni içermez.")
                }
                Section {
                    LabeledContent("Saklanan ses", value: "\(library.recordings.count) kayıt")
                    Button("Tüm kayıtları sil", role: .destructive) { confirmDeleteAll = true }
                        .disabled(library.recordings.isEmpty || model.isGenerating || exporter.isExporting)
                } header: { Text("Verilerin") } footer: {
                    Text("Metin ve ses geçmişi uygulamanın yerel alanında saklanır. Paylaş dediğinde seçtiğin platforma aktarılır. Uygulamayı kaldırmak kayıtlarını da siler.")
                }
                Section("Gizlilik ve destek") {
                    Link("Gizlilik politikası", destination: URL(string: "https://speak.ekatech.net/privacy")!)
                    Link("Destek", destination: URL(string: "mailto:contact@ekatech.net")!)
                }
                Section("Açık kaynak") {
                    NavigationLink("Lisanslar ve teşekkür") { LicensesView() }
                    Link("GitHub’da geliştir", destination: URL(string: "https://github.com/Ezakamak/ema-lightning-ios")!)
                    Link("Sorun bildir", destination: URL(string: "https://github.com/Ezakamak/ema-lightning-ios/issues/new/choose")!)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }.navigationTitle("Ayarlar")
                .confirmationDialog("Tüm kayıtlar kalıcı olarak silinsin mi?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                    Button("Tümünü sil", role: .destructive) {
                        playback.stop()
                        do { try library.removeAll() } catch { self.error = error.localizedDescription }
                    }
                }
        }
    }
}

@MainActor
private struct LicensesView: View {
    var body: some View {
        List {
            Section("Katkı ve teşekkür") {
                Text("Canberk Aslan — orijinal EMA Lightning modeli")
                Text("Özcan Çelik — EMA ONNX uyarlaması")
                Text("Erdem Tuna ve katkıda bulunanlar — Türkçe normalizer")
            }
            Section("Uygulama") {
                NavigationLink("Apache-2.0") { LicenseTextView(title: "Apache-2.0", name: "LICENSE", ext: "txt", directory: nil) }
                NavigationLink("Telif bildirimleri") { LicenseTextView(title: "Bildirimler", name: "NOTICE", ext: "txt", directory: nil) }
            }
            Section("MP3 kodlayıcı") {
                Text("LAME / lamejs 1.2.1 · LGPL-3.0. Bu bileşen kendi lisansıyla dağıtılır ve değiştirilebilir. Uygulamanın kaynak kodu Apache-2.0 lisanslıdır.").font(.footnote)
                NavigationLink("LGPL-3.0") { LicenseTextView(title: "LGPL-3.0", name: "COPYING", ext: "LESSER", directory: "MP3") }
                NavigationLink("GPL-3.0 lisans metni") { LicenseTextView(title: "GPL-3.0", name: "COPYING", ext: "", directory: "MP3") }
                if let url = Bundle.main.url(forResource: "lamejs-1.2.1-source", withExtension: "tgz", subdirectory: "MP3") {
                    ShareLink("Kodlayıcının kaynak arşivi", item: url)
                }
                Link("LAME projesi", destination: URL(string: "https://lame.sourceforge.io")!)
            }
            Section("Diğer bileşenler") {
                Text("EMA modeli ve Türkçe normalizer: Apache-2.0. ONNX Runtime: MIT. Tam lisanslar, bildirimler ve kaynak sürümleri uygulama paketinde ve GitHub’daki bağımlılık dökümünde korunur.").font(.footnote)
                Link("Bağımlılık lisans dökümü", destination: URL(string: "https://github.com/Ezakamak/ema-lightning-ios/blob/main/docs/DEPENDENCIES.md")!)
            }
        }.navigationTitle("Lisanslar").navigationBarTitleDisplayMode(.inline)
    }
}
@MainActor
private struct LicenseTextView: View {
    let title: String
    let name: String
    let ext: String
    let directory: String?
    var body: some View {
        ScrollView {
            Text(contents).font(.system(.caption, design: .monospaced)).textSelection(.enabled).padding()
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
    private var contents: String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? nil : ext, subdirectory: directory),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "Lisans metni okunamadı." }
        return text
    }
}
