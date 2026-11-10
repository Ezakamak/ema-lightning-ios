// SPDX-License-Identifier: Apache-2.0
import SwiftUI

@MainActor
struct RecordingDetailView: View {
    let recordingID: UUID
    @ObservedObject var library: RecordingStore
    @ObservedObject var playback: RecordingPlayback
    @ObservedObject var exporter: ExportCoordinator
    @ObservedObject var model: SpeechViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var rename = false
    @State private var title = ""
    @State private var confirmDelete = false
    @State private var error: String?
    private var recording: SpeechRecording? { library.recordings.first { $0.id == recordingID } }
    var body: some View {
        ScrollView {
            if let recording {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 18) {
                        BrandLogo(size: 100).padding(.top, 12)
                        Text(recording.title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                        Text(recording.createdAt, format: .dateTime.day().month(.wide).year().hour().minute()).font(.caption).foregroundStyle(.secondary)
                        player(recording)
                    }.padding(22).frame(maxWidth: .infinity).background(StudioStyle.card, in: RoundedRectangle(cornerRadius: 28))
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Paylaşmaya hazır").font(.title3.weight(.bold))
                        HStack(spacing: 12) {
                            ForEach(ExportFormat.allCases) { format in
                                Button { playback.pause(); exporter.export(recording, source: library.url(for: recording), format: format) } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Image(systemName: format.icon).font(.title2)
                                        Text(format.rawValue).font(.headline)
                                        Text(format.detail).font(.caption).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(StudioStyle.card, in: RoundedRectangle(cornerRadius: 22))
                                }.buttonStyle(.plain).disabled(exporter.isExporting || model.isGenerating).accessibilityIdentifier("export-\(format.rawValue)")
                            }
                        }
                        Text("MP4: 9:16 dikey video ve ilerleyen metin. Metin geçişleri ses süresine göre yaklaşık eşleştirilir.").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Metin").font(.headline); Spacer()
                            Button("Yeniden kullan", systemImage: "doc.on.doc") { model.text = recording.text }.font(.caption).buttonStyle(.borderless)
                        }
                        Text(recording.text).font(.body).lineSpacing(5).textSelection(.enabled)
                    }.padding(20).background(StudioStyle.card, in: RoundedRectangle(cornerRadius: 24))
                    if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                }.padding(20)
            }
        }.background(StudioStyle.background).navigationTitle("Ses kaydı").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Yeniden adlandır", systemImage: "pencil") { title = recording?.title ?? ""; rename = true }
                        Button("Kaydı sil", systemImage: "trash", role: .destructive) { confirmDelete = true }
                            .disabled(exporter.isExporting || model.isGenerating)
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Kayıt seçenekleri")
                }
            }
            .alert("Kaydı yeniden adlandır", isPresented: $rename) {
                TextField("Kayıt adı", text: $title)
                Button("Kaydet") { if let recording { do { try library.rename(recording, title: title) } catch { self.error = error.localizedDescription } } }
                Button("Vazgeç", role: .cancel) { }
            }
            .confirmationDialog("Bu kayıt kalıcı olarak silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Kaydı sil", role: .destructive) {
                    guard let recording else { return }
                    if playback.recordingID == recording.id { playback.stop() }
                    do { try library.remove(recording); dismiss() } catch { self.error = error.localizedDescription }
                }
            }.onDisappear { playback.pause() }
    }
    private func player(_ recording: SpeechRecording) -> some View {
        VStack(spacing: 12) {
            if playback.recordingID == recording.id {
                Slider(value: Binding(get: { playback.position }, set: playback.seek), in: 0...max(0.01, playback.duration)).accessibilityLabel("Oynatma konumu")
            }
            HStack {
                Text(recording.durationLabel).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary); Spacer()
                Button {
                    do { try playback.play(recording, url: library.url(for: recording)) } catch { self.error = error.localizedDescription }
                } label: {
                    Image(systemName: playback.recordingID == recording.id && playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2).frame(width: 64, height: 64).foregroundStyle(.white).background(StudioStyle.accent, in: Circle())
                }.buttonStyle(.plain).disabled(model.isGenerating).accessibilityLabel("Kaydı oynat veya duraklat")
                Spacer(); Text("48 kHz").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }
}
