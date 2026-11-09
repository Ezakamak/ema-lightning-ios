// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import SpeechCore

final class CaptionTimelineTests: XCTestCase {
    func testPhrasesPreserveTurkishTextAndExactlyCoverAudio() {
        let text = "İstanbul ve Iğdır. Bu metnin tüm kelimeleri sırayla videoda gösterilmeli; hiçbir kelime kaybolmamalı."
        let cues = CaptionTimeline.cues(text: text, duration: 8.75)
        XCTAssertEqual(cues.map(\.text).joined(separator: " "), text)
        XCTAssertEqual(cues.first?.start, 0)
        XCTAssertEqual(cues.last?.end, 8.75)
        for index in cues.indices {
            XCTAssertGreaterThan(cues[index].end, cues[index].start)
            if index > 0 { XCTAssertEqual(cues[index].start, cues[index - 1].end) }
        }
    }
    func testEmptyAndInvalidAudioHaveNoCaptions() {
        XCTAssertTrue(CaptionTimeline.cues(text: "", duration: 2).isEmpty)
        XCTAssertTrue(CaptionTimeline.cues(text: "merhaba", duration: 0).isEmpty)
        XCTAssertTrue(CaptionTimeline.cues(text: "merhaba", duration: .nan).isEmpty)
    }
}
