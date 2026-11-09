// SPDX-License-Identifier: Apache-2.0
import SwiftUI

@MainActor
struct StudioRootView: View {
    @ObservedObject var model: SpeechViewModel
    @StateObject private var settings = AppSettings()
    @StateObject private var playback = RecordingPlayback()
    @StateObject private var exporter = ExportCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var playbackError: String?
    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    ExportProgressView(exporter: exporter)
                    dock
                    Divider().opacity(0.35)
                    HStack(spacing: 0) {
                        tabButton("Oluştur", symbol: "waveform.badge.plus", index: 0)
                        tabButton("Geçmiş", symbol: "clock.arrow.circlepath", index: 1)
                        tabButton("Ayarlar", symbol: "slider.horizontal.3", index: 2)
                    }.padding(.top, 8).padding(.bottom, 4)
                }.background(.bar)
            }
            .tint(StudioStyle.accent)
            .preferredColorScheme(settings.appearance == 1 ? .light : settings.appearance == 2 ? .dark : nil)
            .sheet(item: $exporter.shareFile) { FileShareSheet(file: $0).presentationDetents([.medium, .large]) }
            .alert("Paylaşım hazırlanamadı", isPresented: Binding(get: { exporter.errorMessage != nil }, set: { if !$0 { exporter.errorMessage = nil } })) {
                Button("Tamam", role: .cancel) { exporter.errorMessage = nil }
            } message: { Text(exporter.errorMessage ?? "") }
            .alert("Kayıt açılamadı", isPresented: Binding(get: { playbackError != nil }, set: { if !$0 { playbackError = nil } })) {
                Button("Tamam", role: .cancel) { playbackError = nil }
            } message: { Text(playbackError ?? "") }
            .onAppear { ExportCoordinator.cleanOldExports() }
            .onChange(of: scenePhase) { _, phase in if phase == .background { exporter.cancel() } }
            .onChange(of: model.isGenerating) { _, generating in if generating { playback.stop() } }
    }
    @ViewBuilder private var content: some View {
        switch tab {
        case 1: LibraryView(library: model.library, playback: playback, exporter: exporter, model: model)
        case 2: SettingsView(settings: settings, model: model, library: model.library, playback: playback, exporter: exporter)
        default: SpeechView(model: model, library: model.library, settings: settings, playback: playback, exporter: exporter)
        }
    }
    private func tabButton(_ title: String, symbol: String, index: Int) -> some View {
        Button { tab = index } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 20, weight: tab == index ? .semibold : .regular))
                Text(title).font(.system(size: 10, weight: .semibold))
            }.frame(maxWidth: .infinity).frame(minHeight: 42).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(tab == index ? StudioStyle.accent : Color.secondary)
            .accessibilityIdentifier("tab-\(index)").accessibilityAddTraits(tab == index ? [.isSelected] : [])
    }
    private var dock: some View {
        HStack(spacing: 10) {
            // This stays attached across tab/navigation changes. It is the actual EMA WebKit host.
            InferenceViewport(engine: model.ema).frame(width: 80, height: 48).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
            DockStatus(model: model)
            Spacer(minLength: 0)
            if model.isGenerating {
                Button(action: model.stop) { Image(systemName: "stop.circle.fill").font(.title).foregroundStyle(StudioStyle.accent) }
                    .buttonStyle(.plain).accessibilityLabel("Ses oluşturmayı durdur").accessibilityIdentifier("dockStop")
            }
        }.padding(.horizontal, 20).padding(.vertical, 6)
    }
}

@MainActor
private struct DockStatus: View {
    @ObservedObject var model: SpeechViewModel
    @ObservedObject private var library: RecordingStore
    init(model: SpeechViewModel) { self.model = model; library = model.library }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.isGenerating ? "Sesin hazırlanıyor…" : "EMA Lightning").font(.caption.weight(.semibold))
            Text(model.isGenerating ? "Birazdan burada." : library.recordings.isEmpty ? "Bir fikirle başla." : "\(library.recordings.count) ses kaydı hazır.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
