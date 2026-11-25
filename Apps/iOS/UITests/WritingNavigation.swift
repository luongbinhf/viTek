import XCTest

@MainActor final class WritingNavigation: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.launch()
    }

    func testWritingTabShowsModelState() {
        app.buttons["pencil"].tap()
        XCTAssertTrue(app.staticTexts["writing.readiness"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["writing.readiness"].label.isEmpty)
        XCTAssertTrue(app.textViews["writing.draft"].exists)
        XCTAssertFalse(app.buttons["writing.generate"].isEnabled, "Empty drafts must not start a model request")
    }

    func testWidgetURLColdAndWarmLaunch() {
        app.terminate()
        app.open(URL(string: "vitek://writing")!)
        XCTAssertTrue(app.staticTexts["writing.readiness"].waitForExistence(timeout: 5))
        app.buttons["keyboard"].tap()
        XCTAssertTrue(app.textFields["Thử gõ vieetj"].waitForExistence(timeout: 5))
        app.open(URL(string: "vitek://writing")!)
        XCTAssertTrue(app.staticTexts["writing.readiness"].waitForExistence(timeout: 5))
    }

    func testUnknownRouteDoesNotNavigate() {
        app.open(URL(string: "vitek://writing?draft=untrusted")!)
        XCTAssertTrue(app.textFields["Thử gõ vieetj"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["writing.readiness"].exists)
    }

    func testSettingsTabShowsShortcutsAndCustomWords() {
        app.buttons["gearshape"].tap()
        XCTAssertTrue(app.buttons["settings.shortcuts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.customWords"].exists)
    }
}
