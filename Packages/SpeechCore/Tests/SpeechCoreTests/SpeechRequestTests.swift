import XCTest
@testable import SpeechCore

final class SpeechRequestTests: XCTestCase {
    func testRejectsWhitespace() {
        XCTAssertThrowsError(try SpeechRequest(text: " \n\t "))
    }

    func testPreservesTurkishCharactersAndTrimsEdges() throws {
        XCTAssertEqual(try SpeechRequest(text: "  Iğdır, İstanbul, çığ! \n").text,
                       "Iğdır, İstanbul, çığ!")
    }

    func testLengthBoundary() throws {
        XCTAssertNoThrow(try SpeechRequest(text: String(repeating: "ş", count: 1_000)))
        XCTAssertThrowsError(try SpeechRequest(text: String(repeating: "ş", count: 1_001)))
    }
}
