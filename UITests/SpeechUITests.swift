import XCTest

final class SpeechUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testReadTapIsAcknowledgedWithoutInvokingStopAndWorkerErrorIsVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["--ema-ui-worker-error"]
        app.launch()
        let read = app.buttons["readButton"]
        XCTAssertTrue(read.waitForExistence(timeout: 15))
        read.tap()
        XCTAssertTrue(app.staticTexts["tapAcknowledgement"].waitForExistence(timeout: 2))
        let error = app.staticTexts["engineError"]
        XCTAssertTrue(error.waitForExistence(timeout: 40))
        XCTAssertTrue(error.label.contains("EMA_TEST_WORKER_ERROR"), error.label)
        XCTAssertTrue(read.isEnabled)
        app.buttons["EMA Motor Durumu"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Durdur çağrısı alındı")).firstMatch.exists)
    }

    func testLegacyFormRowReallyDispatchesBothAutomaticButtonActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--legacy-form-buttons"]
        app.launch()
        app.buttons["legacyRead"].tap()
        XCTAssertEqual(app.staticTexts["legacyReadCount"].label, "read 1")
        XCTAssertEqual(app.staticTexts["legacyStopCount"].label, "stop 1")
    }
}
