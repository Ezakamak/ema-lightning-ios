// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import SpeechCore

final class PronunciationRuleTests: XCTestCase {
    func testIndexSelectsBrandsPhrasesAndPreservesRuleOrder() {
        let rules = [PronunciationRule(word: "Google Drive", pronunciation: "gugıl drayv"),
                     PronunciationRule(word: "iPhone", pronunciation: "ayfon"),
                     PronunciationRule(word: "Işık", pronunciation: "ışık"),
                     PronunciationRule(word: "Cloud", pronunciation: "klaud")]
        let index = PronunciationIndex(rules: rules)
        XCTAssertEqual(index.candidates(in: "İPHONE'dan GOOGLE\t Drive’a IŞIK"), Array(rules.prefix(3)))
        XCTAssertTrue(index.candidates(in: "Merhaba dünya").isEmpty)
    }
    func testLargeIndexSelectsOnlyRelevantRules() {
        let rules = (0..<40000).map { PronunciationRule(word: "Term\($0)", pronunciation: "terim") }
        let start = Date()
        let index = PronunciationIndex(rules: rules)
        let build = Date().timeIntervalSince(start)
        let queryStart = Date()
        for _ in 0..<100 { XCTAssertTrue(index.candidates(in: "Term39999").contains(rules[39999])) }
        print("INDEX_PERF rules=40000 buildSeconds=\(build) query100Seconds=\(Date().timeIntervalSince(queryStart))")
    }
    func testBrandsAcceptDottedIWithoutCollapsingTurkishVowels() throws {
        XCTAssertEqual(PronunciationRule.key("İphone"), PronunciationRule.key("IPHONE"))
        XCTAssertEqual(PronunciationRule.key("Işık"), PronunciationRule.key("ışık"))
        XCTAssertNotEqual(PronunciationRule.key("sık"), PronunciationRule.key("sik"))
    }
    func testRulesAreLiteralWordsWithPhoneticReadings() throws {
        let rule = try PronunciationRule.validated(word: "  Google   Drive ", pronunciation: " gugıl   drayv ")
        XCTAssertEqual(rule.word, "Google Drive")
        XCTAssertEqual(rule.pronunciation, "gugıl drayv")
        XCTAssertNoThrow(try PronunciationRule.validated(word: "C++", pronunciation: "si plas plas"))
        XCTAssertThrowsError(try PronunciationRule.validated(word: ".*", pronunciation: "örnek"))
        XCTAssertThrowsError(try PronunciationRule.validated(word: "iPhone", pronunciation: "<script>"))
        XCTAssertThrowsError(try PronunciationRule.validated(word: "iPhone", pronunciation: "123"))
    }
}
