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
                if index == 0 {
                    // Persistent live WebKit host, integrated into the existing tab icon.
                    // Keep it attached and visible across navigation; no extra status bar.
                    InferenceViewport(engine: model.ema).frame(width: 32, height: 24)
                        .saturation(tab == index ? 1 : 0).accessibilityHidden(true).allowsHitTesting(false)
                } else {
                    Image(systemName: symbol).font(.system(size: 20, weight: tab == index ? .semibold : .regular)).frame(height: 24)
                }
                Text(title).font(.system(size: 10, weight: .semibold))
            }.frame(maxWidth: .infinity).frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(tab == index ? StudioStyle.accent : Color.secondary)
            .accessibilityIdentifier("tab-\(index)").accessibilityAddTraits(tab == index ? [.isSelected] : [])
    }
}
