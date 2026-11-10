// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import SpeechCore

@MainActor
struct PronunciationDictionaryView: View {
    @ObservedObject var store: PronunciationStore
    @State private var selection = 0
    @State private var search = ""
    @State private var editor: DictionaryEditorItem?
    @State private var deleting: PersonalPronunciation?
    @State private var error: String?
    private func matches(_ rule: PronunciationRule) -> Bool {
        search.isEmpty || rule.word.localizedCaseInsensitiveContains(search) || rule.pronunciation.localizedCaseInsensitiveContains(search)
    }
    var body: some View {
        List {
            Section {
                Toggle("Hazır telaffuz listesini kullan", isOn: $store.useBuiltIns)
                    .accessibilityIdentifier("useBuiltInPronunciations")
            } footer: { Text("Kişisel kurallarınız hazır listedeki aynı kelimeden önceliklidir. Değişiklikler bir sonraki EMA okumasında uygulanır; metniniz ve eski kayıtlar değişmez.") }
            Section {
                Picker("Sözlük", selection: $selection) {
                    Text("Kişisel (\(store.personal.count))").tag(0)
                    Text("Hazır (\(store.builtIns.count))").tag(1)
                }.pickerStyle(.segmented)
            }
            if let loadError = store.loadError { Section { Text(loadError).foregroundStyle(.red) } }
            if selection == 0 {
                personalSection
            } else {
                ForEach(Array(Set(store.builtIns.map(\.category))).sorted(), id: \.self) { category in
                    let entries = store.builtIns.filter { $0.category == category && matches($0) }.sorted { $0.word.localizedStandardCompare($1.word) == .orderedAscending }
                    if !entries.isEmpty {
                        Section(category) {
                            ForEach(entries) { rule in
                                let custom = store.personalOverride(for: rule)
                                Button { editor = DictionaryEditorItem(rule: custom?.rule ?? rule, personalID: custom?.id, enabled: custom?.enabled ?? true) } label: {
                                    row(custom?.rule ?? rule, enabled: custom?.enabled ?? true, badge: custom == nil ? nil : "Kişisel kural")
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            Section {
                Text("Hazır okunuşlar Türkçe yazımla yaklaşık önerilerdir. EMA’da duyduğunuz sonuca göre değiştirebilirsiniz. Yanlış bir öneriyi kişisel kural olarak açıp devre dışı bırakabilirsiniz.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Telaffuz sözlüğü").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Kelime veya okunuş ara")
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { editor = DictionaryEditorItem(rule: PronunciationRule(word: "", pronunciation: ""), personalID: nil, enabled: true) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Telaffuz ekle").accessibilityIdentifier("addPronunciation")
            } }
            .sheet(item: $editor) { PronunciationEditor(store: store, item: $0) }
            .confirmationDialog("Kişisel kural silinsin mi?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Kuralı sil", role: .destructive) {
                    guard let deleting else { return }
                    do { try store.remove(deleting); self.deleting = nil } catch { self.error = error.localizedDescription }
                }
            } message: { Text("Hazır listede aynı kelime varsa onun okunuşu yeniden geçerli olur.") }
            .alert("Sözlük kaydedilemedi", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Tamam", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
    private var personalSection: some View {
        Section {
            let entries = store.personal.filter { matches($0.rule) }.sorted { $0.rule.word.localizedStandardCompare($1.rule.word) == .orderedAscending }
            if entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.personal.isEmpty ? "Kendi okunuşunu ekle" : "Eşleşen kural yok").font(.headline)
                    Text("Örnek: iPhone → Ayfon. Bir kelime veya kısa ifade ekleyebilirsin.").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }
            ForEach(entries) { entry in
                Button { editor = DictionaryEditorItem(rule: entry.rule, personalID: entry.id, enabled: entry.enabled) } label: {
                    row(entry.rule, enabled: entry.enabled, badge: nil)
                }.buttonStyle(.plain)
                    .swipeActions { Button("Sil", role: .destructive) { deleting = entry } }
            }
        }
    }
    private func row(_ rule: PronunciationRule, enabled: Bool, badge: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(rule.word).font(.subheadline.weight(.semibold))
                Spacer()
                if !enabled { Text("Kapalı").font(.caption).foregroundStyle(.secondary) }
                else if let badge { Text(badge).font(.caption).foregroundStyle(.secondary) }
            }
            Text("→ \(rule.pronunciation)").font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

private struct DictionaryEditorItem: Identifiable {
    let id = UUID()
    let rule: PronunciationRule
    let personalID: UUID?
    let enabled: Bool
}

@MainActor
private struct PronunciationEditor: View {
    @ObservedObject var store: PronunciationStore
    let item: DictionaryEditorItem
    @Environment(\.dismiss) private var dismiss
    @State private var word: String
    @State private var pronunciation: String
    @State private var enabled: Bool
    @State private var error: String?
    init(store: PronunciationStore, item: DictionaryEditorItem) {
        self.store = store; self.item = item
        _word = State(initialValue: item.rule.word)
        _pronunciation = State(initialValue: item.rule.pronunciation)
        _enabled = State(initialValue: item.enabled)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Metinde geçen") {
                    TextField("Örnek: iPhone", text: $word).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("pronunciationWord")
                }
                Section("Böyle oku") {
                    TextField("Örnek: Ayfon", text: $pronunciation).autocorrectionDisabled()
                        .accessibilityIdentifier("pronunciationReading")
                }
                Section {
                    Toggle("Bu kuralı kullan", isOn: $enabled)
                } footer: { Text("Yalnızca tam kelime ve ifadeler eşleşir. Hazır bir kelimenin kuralını kapatırsanız o kelimeye telaffuz düzeltmesi uygulanmaz. Kişisel sözlük yalnızca bu cihazda saklanır.") }
                if let error { Section { Text(error).font(.footnote).foregroundStyle(.red) } }
            }.navigationTitle("Telaffuz kuralı").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Kaydet") {
                            do { try store.save(word: word, pronunciation: pronunciation, enabled: enabled, replacingID: item.personalID); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.accessibilityIdentifier("savePronunciation")
                    }
                }
        }
    }
}
