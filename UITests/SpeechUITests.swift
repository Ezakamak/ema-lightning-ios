import XCTest

final class SpeechUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testReadTapIsAcknowledgedWithoutInvokingStopAndWorkerErrorIsVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["--ema-ui-worker-error"]
        app.launch()
        screenshot(app, name: "Studio")
        let read = app.buttons["readButton"]
        XCTAssertTrue(read.waitForExistence(timeout: 15))
        read.tap()
        XCTAssertTrue(app.staticTexts["tapAcknowledgement"].waitForExistence(timeout: 2))
        let error = app.staticTexts["engineError"]
        XCTAssertTrue(error.waitForExistence(timeout: 40))
        XCTAssertTrue(error.label.contains("EMA_TEST_WORKER_ERROR"), error.label)
        XCTAssertTrue(read.isEnabled)
        // A real Worker error proves Read was not immediately routed to Stop.
        // Verify that retry and an explicit Stop leave the control usable as well.
        read.tap()
        app.buttons["stopButton"].tap()
        XCTAssertTrue(read.isEnabled)
        XCTAssertTrue(app.staticTexts["tapAcknowledgement"].exists)
    }

    func testLegacyFormRowReallyDispatchesBothAutomaticButtonActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--legacy-form-buttons"]
        app.launch()
        app.buttons["legacyRead"].tap()
        XCTAssertEqual(app.staticTexts["legacyReadCount"].label, "read 1")
        XCTAssertEqual(app.staticTexts["legacyStopCount"].label, "stop 1")
    }

    func testModernNavigationAndDeveloperModeIsOptIn() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-clean"]
        app.launch()
        XCTAssertTrue(app.buttons["readButton"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.otherElements["diagnosticsPanel"].exists)
        screenshot(app, name: "Studio-clean")
        app.buttons["tab-1"].tap()
        XCTAssertTrue(app.navigationBars["Geçmiş"].exists)
        screenshot(app, name: "History")
        app.buttons["tab-2"].tap()
        let toggle = app.switches["developerModeToggle"]
        if !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        screenshot(app, name: "Settings")
        toggle.tap()
        app.buttons["tab-0"].tap()
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["diagnosticsPanel"].exists)
    }

    private func screenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

// Separate opt-in suite: no inference faults, fake records or changes to shipping UI.
final class IPadAppStoreScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["EMA_IPAD_SCREENSHOTS"] == "1" else {
            throw XCTSkip("Run the dedicated iPad screenshots workflow to capture App Store screens")
        }
    }

    func testTurkishAppStoreScreens() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-clean", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launch()
        XCTAssertTrue(app.buttons["readButton"].waitForExistence(timeout: 30))
        // Populate using the real example-text action; no keyboard in the screenshot.
        app.buttons["Metin seçenekleri"].tap()
        app.buttons["Örnek metin"].tap()
        capture(app, name: "01-Olustur", title: "Oluştur")
        app.buttons["tab-1"].tap()
        capture(app, name: "02-Gecmis", title: "Geçmiş")
        app.buttons["tab-2"].tap()
        capture(app, name: "03-Ayarlar", title: "Ayarlar")
        app.buttons["Telaffuz sözlüğü"].tap()
        let builtIns = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Hazır (")).firstMatch
        XCTAssertTrue(builtIns.waitForExistence(timeout: 10))
        builtIns.tap()
        capture(app, name: "04-Telaffuz", title: "Telaffuz sözlüğü")
    }

    private func capture(_ app: XCUIApplication, name: String, title: String) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertFalse(app.staticTexts["engineError"].exists)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "EMA-iPad-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
