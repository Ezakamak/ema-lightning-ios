// SPDX-License-Identifier: Apache-2.0
import Foundation

public struct SpeechRequest: Equatable, Sendable {
    public enum ValidationError: Error, LocalizedError {
        case emptyText
        case textTooLong

        public var errorDescription: String? {
            switch self {
            case .emptyText: return "Lütfen okunacak bir metin yazın."
            case .textTooLong: return "Metin en fazla 1.000 karakter olabilir."
            }
        }
    }

    public static let maximumLength = 1_000
    public let text: String

    public init(text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.emptyText }
        guard trimmed.count <= Self.maximumLength else { throw ValidationError.textTooLong }
        self.text = trimmed
    }
}

/// Implement this boundary for an on-device EMA engine without changing the UI.
@MainActor
public protocol SpeechEngine: AnyObject {
    var displayName: String { get }
    func speak(_ request: SpeechRequest) async throws
    func stop()
}
