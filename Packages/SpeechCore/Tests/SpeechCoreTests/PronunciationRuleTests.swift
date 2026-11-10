// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import SpeechCore

final class PronunciationRuleTests: XCTestCase {
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
