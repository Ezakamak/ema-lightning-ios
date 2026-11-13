// SPDX-License-Identifier: Apache-2.0
import Foundation

/// A conservative prefix index: JS remains the authority for boundaries and suffixes.
/// Sends only potentially matching rules across WebKit, never the entire dictionary.
public final class PronunciationIndex {
    private final class Node {
        var children: [String: Node] = [:]
        var entries: [Int] = []
    }
    private let roots = [Node(), Node()]
    private let rules: [PronunciationRule]
    public init(rules: [PronunciationRule]) {
        self.rules = rules
        for (index, rule) in rules.enumerated() {
            let tr = rule.word.range(of: "[çğıöşüÇĞÖŞÜ]", options: .regularExpression) != nil
            var node = roots[tr ? 1 : 0]
            for character in rule.word.precomposedStringWithCanonicalMapping {
                let key = Self.fold(character, turkish: tr)
                if node.children[key] == nil { node.children[key] = Node() }
                node = node.children[key]!
            }
            node.entries.append(index)
        }
    }
    private static func fold(_ character: Character, turkish: Bool) -> String {
        if character == " " || character == "\t" { return " " }
        if !turkish && ["i", "I", "İ"].contains(character) { return "i" }
        return String(character).lowercased(with: Locale(identifier: "tr_TR"))
    }
    public func candidates(in text: String) -> [PronunciationRule] {
        let chars = Array(text.precomposedStringWithCanonicalMapping)
        var found = Set<Int>()
        for start in chars.indices {
            // Include punctuation starts (C++, .NET), and preserve all JS boundary cases.
            for mode in 0...1 {
                var node = roots[mode]
                var offset = start
                while offset < chars.count {
                    let key = Self.fold(chars[offset], turkish: mode == 1)
                    guard let next = node.children[key] else { break }
                    node = next
                    for entry in node.entries { found.insert(entry) }
                    if key == " ", node.children[" "] == nil {
                        while offset + 1 < chars.count && (chars[offset + 1] == " " || chars[offset + 1] == "\t") { offset += 1 }
                    }
                    offset += 1
                }
            }
        }
        return found.sorted().map { rules[$0] }
    }
}
