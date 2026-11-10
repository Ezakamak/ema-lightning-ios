// SPDX-License-Identifier: Apache-2.0
import SwiftUI

@MainActor
struct LibraryView: View {
    @ObservedObject var library: RecordingStore
    @ObservedObject var playback: RecordingPlayback
    @ObservedObject var exporter: ExportCoordinator
    @ObservedObject var model: SpeechViewModel
    @State private var search = ""
    private var filtered: [SpeechRecording] {
        library.recordings.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.text.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            Group {
                if library.recordings.isEmpty {
                    StudioEmptyState(title: "Ses arşivin", message: "EMA ile oluşturduğun kayıtları burada bulabilir, yeniden dinleyebilir ve paylaşabilirsin.", symbol: "waveform.badge.plus")
                } else {
                    List {
                        Section {
                            ForEach(filtered) { recording in
                                NavigationLink(value: recording) { RecordingRow(recording: recording) }.listRowSeparator(.hidden)
                            }
                        } header: { Text("\(filtered.count) kayıt · yalnızca bu cihazda") }
                        if filtered.isEmpty { Text("Bu aramayla eşleşen kayıt yok.").foregroundStyle(.secondary) }
                    }.listStyle(.insetGrouped).scrollContentBackground(.hidden).searchable(text: $search, prompt: "Kayıtlarda ara")
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(StudioStyle.background).navigationTitle("Geçmiş")
                .navigationDestination(for: SpeechRecording.self) { recording in
                    RecordingDetailView(recordingID: recording.id, library: library, playback: playback, exporter: exporter, model: model)
                }
        }
    }
}
