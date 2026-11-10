// SPDX-License-Identifier: Apache-2.0
import Foundation

public struct PronunciationRule: Codable, Hashable, Identifiable, Sendable {
    public var word: String
    public var pronunciation: String
    public var category: String
    public var id: String { Self.key(word) }

    public init(word: String, pronunciation: String, category: String = "Kişisel") {
        self.word = word; self.pronunciation = pronunciation; self.category = category
    }
    /// ASCII brands also accept dotted İ (İphone). Turkish words retain the i/ı distinction.
    public static func key(_ value: String) -> String {
        let value = value.precomposedStringWithCanonicalMapping
        let turkish = value.range(of: "[çğıöşüÇĞÖŞÜ]", options: .regularExpression) != nil
        return (turkish ? value : value.replacingOccurrences(of: "İ", with: "I"))
            .lowercased(with: Locale(identifier: turkish ? "tr_TR" : "en_US_POSIX"))
    }
    public static func validated(word: String, pronunciation: String) throws -> PronunciationRule {
        func tidy(_ input: String) -> String {
            input.precomposedStringWithCanonicalMapping.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        let word = tidy(word), pronunciation = tidy(pronunciation)
        guard !word.isEmpty, word.count <= 64,
              word.range(of: #"\p{L}"#, options: .regularExpression) != nil,
              word.range(of: #"^[\p{L}\p{N} .+#&’'/_-]+$"#, options: .regularExpression) != nil else {
            throw ValidationError.word
        }
        guard !pronunciation.isEmpty, pronunciation.count <= 128,
              pronunciation.range(of: #"^[A-Za-zÇĞİÖŞÜçğıöşü]+(?:[ ’'\-][A-Za-zÇĞİÖŞÜçğıöşü]+)*$"#, options: .regularExpression) != nil else {
            throw ValidationError.pronunciation
        }
        return PronunciationRule(word: word, pronunciation: pronunciation)
    }
    public enum ValidationError: LocalizedError {
        case word, pronunciation
        public var errorDescription: String? {
            switch self {
            case .word: return "Kelime veya ifade 1–64 karakter olmalı ve en az bir harf içermeli."
            case .pronunciation: return "Okunuşu Türkçe harflerle yazın; örneğin Ayfon veya çet ci pi ti. En fazla 128 karakter kullanın."
            }
        }
    }
}
