// SPDX-License-Identifier: Apache-2.0
import Foundation
import Combine
import SpeechCore

struct PersonalPronunciation: Codable, Identifiable {
    let id: UUID
    var rule: PronunciationRule
    var enabled: Bool
}

@MainActor
final class PronunciationStore: ObservableObject {
    @Published private(set) var personal: [PersonalPronunciation] = []
    @Published private(set) var loadError: String?
    @Published var useBuiltIns: Bool { didSet { defaults.set(useBuiltIns, forKey: "pronunciation.useBuiltIns") } }
    let builtIns: [PronunciationRule]
    private let defaults: UserDefaults
    private let storageKey = "pronunciation.personal.v1"

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        useBuiltIns = defaults.object(forKey: "pronunciation.useBuiltIns") as? Bool ?? true
        if let url = bundle.url(forResource: "pronunciations", withExtension: "json", subdirectory: "EMA"),
           let data = try? Data(contentsOf: url), let entries = try? JSONDecoder().decode([PronunciationRule].self, from: data) {
            builtIns = entries
        } else {
            builtIns = []
            loadError = "Hazır telaffuz listesi açılamadı."
        }
        if let data = defaults.data(forKey: storageKey) {
            do { personal = try JSONDecoder().decode([PersonalPronunciation].self, from: data) }
            catch { loadError = "Kişisel sözlük açılamadı; kayıtlı veri korunuyor." }
        }
    }
    var effectiveRules: [PronunciationRule] {
        let overridden = Set(personal.map { $0.rule.id })
        let base = useBuiltIns ? builtIns.filter { !overridden.contains($0.id) } : []
        return base + personal.filter(\.enabled).map(\.rule)
    }
    var privateValues: [String] { personal.flatMap { [$0.rule.word, $0.rule.pronunciation] } }
    func personalOverride(for rule: PronunciationRule) -> PersonalPronunciation? { personal.first { $0.rule.id == rule.id } }

    func save(word: String, pronunciation: String, enabled: Bool, replacingID: UUID?) throws {
        let rule = try PronunciationRule.validated(word: word, pronunciation: pronunciation)
        guard personal.count < 300 || personal.contains(where: { $0.id == replacingID }) else { throw StoreError.limit }
        guard !personal.contains(where: { $0.id != replacingID && $0.rule.id == rule.id }) else { throw StoreError.duplicate }
        var updated = personal.filter { $0.id != replacingID }
        updated.append(PersonalPronunciation(id: replacingID ?? UUID(), rule: rule, enabled: enabled))
        try persist(updated)
    }
    func remove(_ entry: PersonalPronunciation) throws { try persist(personal.filter { $0.id != entry.id }) }
    private func persist(_ updated: [PersonalPronunciation]) throws {
        guard loadError == nil else { throw StoreError.unavailable }
        defaults.set(try JSONEncoder().encode(updated), forKey: storageKey)
        personal = updated
    }
    private enum StoreError: LocalizedError {
        case limit, duplicate, unavailable
        var errorDescription: String? {
            switch self {
            case .limit: return "Kişisel sözlük en fazla 300 kural içerebilir."
            case .duplicate: return "Bu kelime kişisel sözlüğünüzde var. Mevcut kaydı düzenleyin."
            case .unavailable: return "Sözlük yüklenemediği için değişiklik kaydedilemiyor. Uygulamayı yeniden açın."
            }
        }
    }
}
