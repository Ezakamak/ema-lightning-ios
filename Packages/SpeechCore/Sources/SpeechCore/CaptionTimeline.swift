// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Estimated phrase timing, not forced alignment. Inference does not return word timestamps.
public struct CaptionCue: Equatable, Sendable {
    public let text: String
    public let start: Double
    public let end: Double
}

public enum CaptionTimeline {
    public static func cues(text: String, duration: Double) -> [CaptionCue] {
        guard duration.isFinite, duration > 0 else { return [] }
        var phrases: [String] = []
        var words: [String] = []
        for word in text.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
            if !words.isEmpty && (words.count >= 7 || words.joined(separator: " ").count + word.count > 72) {
                phrases.append(words.joined(separator: " ")); words = []
            }
            words.append(word)
            if word.last.map({ ".!?;:".contains($0) }) == true {
                phrases.append(words.joined(separator: " ")); words = []
            }
        }
        if !words.isEmpty { phrases.append(words.joined(separator: " ")) }
        let total = Double(phrases.reduce(0) { $0 + max(1, $1.count) })
        var offset = 0.0
        return phrases.enumerated().map { index, phrase in
            let start = offset
            offset += duration * Double(max(1, phrase.count)) / total
            return CaptionCue(text: phrase, start: start, end: index == phrases.count - 1 ? duration : offset)
        }
    }
}
