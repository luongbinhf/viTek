import XCTest

@MainActor final class WritingNavigation: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.launch()
    }

    private func tapTab(identifier: String, index: Int) {
        let byId = app.buttons[identifier]
        if byId.waitForExistence(timeout: 2) {
            byId.tap()
            return
        }
        let tabButton = app.tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5), "Tab \(index) (\(identifier)) should exist")
        tabButton.tap()
    }

    func testWidgetURLColdAndWarmLaunch() {
        app.terminate()
        app.open(URL(string: "vitek://writing")!)
        XCTAssertTrue(app.staticTexts["writing.readiness"].waitForExistence(timeout: 5))
        app.swipeDown(velocity: .fast)
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
        tapTab(identifier: "gearshape", index: 1)
        XCTAssertTrue(app.buttons["settings.customWords"].waitForExistence(timeout: 5))
        let shortcuts = app.buttons["settings.shortcuts"]
        if !shortcuts.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(shortcuts.waitForExistence(timeout: 5))
    }
}
