// SPDX-License-Identifier: Apache-2.0
import SwiftUI

@MainActor
struct SpeechView: View {
    @ObservedObject var model: SpeechViewModel
    @ObservedObject var library: RecordingStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var playback: RecordingPlayback
    @ObservedObject var exporter: ExportCoordinator
    @FocusState private var editing: Bool
    @State private var confirmClear = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 14) {
                        BrandLogo(size: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EMA LIGHTNING").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
                            Text("Kelimelerin, ses bulsun.").font(.title3.weight(.semibold))
                        }
                    }.padding(.top, 6)
                    editor
                    if let message = model.errorMessage { errorCard(message) }
                    if settings.developerMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GELİŞTİRİCİ").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            DiagnosticsPanel(diagnostics: model.diagnostics)
                        }.padding(18).background(StudioStyle.card, in: RoundedRectangle(cornerRadius: 24))
                    }
                    recent
                    HStack(spacing: 6) { Image(systemName: "lock.shield"); Text("Cihazında oluşturulur. Sana ait kalır.") }
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom, 12)
                }.padding(.horizontal, 20)
            }.scrollDismissesKeyboard(.interactively).background(StudioStyle.background).navigationTitle("Oluştur")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { if editing { Button("Bitti") { editing = false } } } }
                .navigationDestination(for: SpeechRecording.self) { recording in
                    RecordingDetailView(recordingID: recording.id, library: library, playback: playback, exporter: exporter, model: model)
                }
                .confirmationDialog("Metin temizlensin mi?", isPresented: $confirmClear, titleVisibility: .visible) {
                    Button("Metni temizle", role: .destructive) { model.text = "" }
                }
        }
    }
    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(model.choice == .ema ? "EMA sesi" : "Apple önizlemesi", systemImage: "waveform").font(.subheadline.weight(.semibold))
                Spacer()
                if model.choice == .ema {
                    Text("ÇEVRİMDIŞI").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(StudioStyle.accent)
                        .padding(.horizontal, 8).padding(.vertical, 5).background(StudioStyle.accent.opacity(0.08), in: Capsule())
                }
            }
            ZStack(alignment: .topLeading) {
                if model.text.isEmpty {
                    Text("Bir mesaj, bir hikâye, bir fikir…\nSeslendirmek istediğin metni yaz.")
                        .foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                }
                TextEditor(text: $model.text).scrollContentBackground(.hidden).frame(minHeight: 160, maxHeight: 240)
                    .font(.body).focused($editing).accessibilityLabel("Okunacak metin").accessibilityIdentifier("speechInput")
            }
            HStack {
                Text("\(model.text.count) / 1.000").font(.caption.monospacedDigit()).foregroundStyle(model.text.count > 1000 ? Color.red : Color.secondary)
                Spacer()
                Menu {
                    Button("Örnek metin", systemImage: "text.quote") { model.text = "Merhaba! Bugün güzel bir fikri sese dönüştürmek için harika bir gün." }
                    Button("Metni temizle", systemImage: "trash", role: .destructive) { confirmClear = true }
                } label: { Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(.secondary) }
                    .disabled(model.isGenerating).accessibilityLabel("Metin seçenekleri")
            }
            Button { editing = false; playback.stop(); model.speak() } label: {
                HStack(spacing: 10) {
                    if model.isGenerating { ProgressView().tint(.white) } else { Image(systemName: "play.fill") }
                    Text(model.isGenerating ? "Ses oluşturuluyor" : "Oku").fontWeight(.semibold)
                }.frame(maxWidth: .infinity).frame(height: 52)
            }.buttonStyle(.plain).foregroundStyle(.white).background(StudioStyle.accent, in: RoundedRectangle(cornerRadius: 16))
                .opacity(model.isGenerating ? 0.7 : 1).disabled(model.isGenerating || exporter.isExporting).accessibilityIdentifier("readButton")
            ReadStatus(diagnostics: model.diagnostics, working: model.isGenerating, developer: settings.developerMode, stop: model.stop)
            if model.choice == .system {
                Text("Apple sesi yalnızca önizleme içindir. Kayıt ve paylaşım için EMA sesini seç.").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(20).background(StudioStyle.card, in: RoundedRectangle(cornerRadius: 26))
    }
    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ses oluşturulamadı", systemImage: "exclamationmark.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.red)
            Text(settings.developerMode ? message : "İşlem tamamlanamadı. Yeniden deneyebilirsin. Ayrıntılar için Ayarlar’dan Geliştirici Modu’nu aç.")
                .font(.footnote).foregroundStyle(.secondary).textSelection(.enabled).accessibilityIdentifier("engineError")
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(StudioStyle.card, in: RoundedRectangle(cornerRadius: 20))
    }
    private var recent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Son kayıtların").font(.title3.weight(.bold)); Spacer()
                Text("\(library.recordings.count) kayıt").font(.caption).foregroundStyle(.secondary)
            }
            if library.recordings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "tray").font(.title2).foregroundStyle(.tertiary)
                    Text("İlk sesin burada seni bekleyecek.").font(.subheadline.weight(.medium))
                    Text("EMA ile oluşturduğun sesler otomatik kaydedilir.").font(.caption).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(StudioStyle.card, in: RoundedRectangle(cornerRadius: 22))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(library.recordings.prefix(3).enumerated()), id: \.element.id) { index, recording in
                        if index > 0 { Divider().padding(.leading, 60) }
                        NavigationLink(value: recording) { RecordingRow(recording: recording) }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16).padding(.vertical, 6).background(StudioStyle.card, in: RoundedRectangle(cornerRadius: 22))
            }
        }
    }
}
@MainActor
private struct ReadStatus: View {
    @ObservedObject var diagnostics: EMADiagnostics
    let working: Bool
    let developer: Bool
    let stop: () -> Void
    var body: some View {
        if diagnostics.tapAcknowledged {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Oku butonuna basıldı").accessibilityIdentifier("tapAcknowledgement")
                    if working {
                        Text(developer ? diagnostics.currentStage?.title ?? "İstek hazırlanıyor…" : "Sesin hazırlanıyor…").accessibilityIdentifier("liveStage")
                    }
                }.font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if working {
                    Button("Durdur", systemImage: "stop.fill", action: stop).font(.caption.weight(.semibold)).buttonStyle(.bordered).accessibilityIdentifier("stopButton")
                }
            }
        }
    }
}
