import XCTest

@MainActor final class Typing: XCTestCase {
    private let app = XCUIApplication()
    private var first: XCUIElement { app.textFields["first"] }
    private var second: XCUIElement { app.textFields["second"] }
    private let space = "Dấu cách"

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app.launch()
        first.tap()
        let key = app.buttons[space]
        let globe = app.buttons["Next keyboard"]
        for _ in 0..<4 {
            if key.waitForExistence(timeout: 4) { break }
            guard globe.exists else { break }
            globe.tap()
        }
        XCTAssertTrue(key.exists, "Install and enable the viTek software keyboard on this simulator.")
    }

    private func keys(_ labels: String...) {
        for label in labels { app.buttons[label].tap() }
    }

    private func expect(_ field: XCUIElement, _ text: String, line: UInt = #line) {
        let match = NSPredicate(format: "value == %@", text)
        let wait = XCTNSPredicateExpectation(predicate: match, object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 3), .completed,
                       "Expected <\(text)>, got <\(field.value ?? "nil")>", line: line)
    }

    func testTelexAndVNI() {
        keys("v", "i", "e", "e", "t", "j", space)
        expect(first, "việt ")
        keys("v", "i", "e", "123", "6", "5", "ABC", "t", space)
        expect(first, "việt việt ")
    }

    func testMoveInComposingWord() {
        keys("b", "a", "n")
        expect(first, "ban")
        app.buttons["Move before last character"].tap()
        keys("m", space)
        expect(first, "bam n")
    }

    func testSwitchBeforeCommit() {
        keys("v", "i", "e", "e")
        expect(first, "viê")
        second.tap()
        keys("d", "d", "a", "s", space)
        expect(second, "đá ")
        expect(first, "viê")
        first.tap()
        expect(first, "viê")
        // A UITextField can select its contents on refocus. Place a caret explicitly
        // to test appending; selection replacement is covered separately.
        app.buttons["Place caret at end of first field"].tap()
        keys(space)
        expect(first, "viê ")
        expect(second, "đá ")
    }

    func testMoveAndDeleteInsideVNIWord() {
        keys("v", "i", "e", "123", "6", "5", "ABC", "t")
        expect(first, "việt")
        app.buttons["Move before last character"].tap()
        keys("Xoá")
        expect(first, "vit")
        keys("e", "123", "6")
        expect(first, "viêt")
    }

    func testReplaceSelectionInUnfinishedWord() {
        keys("v", "i", "e", "e", "t", "j")
        expect(first, "việt")
        app.buttons["Select middle of first word"].tap()
        keys("d", "d", "a", "s")
        expect(first, "vđát")
    }

    func testSwitchWhileUsingVNIDigits() {
        keys("v", "i", "e", "123", "6")
        expect(first, "viê")
        second.tap()
        if app.buttons["ABC"].exists { keys("ABC") }
        keys("d", "123", "9", "ABC", "a", "123", "1", space)
        expect(second, "đá ")
        expect(first, "viê")
    }

    func testDoubleSpaceInsertsPeriod() {
        keys("c", "h", "a", "o", space, space)
        expect(first, "chao. ")
    }

    func testSymbolsPageInput() {
        keys("123", "Ký hiệu", "[", "]", "ABC")
        expect(first, "[]")
    }

    func testEmojiPickerInsertsEmoji() {
        keys("Emoji")
        let firstEmoji = app.buttons["emoji.0"]
        XCTAssertTrue(firstEmoji.waitForExistence(timeout: 3))
        firstEmoji.tap()
        keys("ABC")
        expect(first, "😀")
    }

    func testEmojiSearchInsertsVietnameseMatch() {
        keys("Emoji")
        let searchButton = app.buttons["emoji.search"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 3))
        searchButton.tap()
        keys("t", "i", "m")
        let topResult = app.buttons["emoji.result.0"]
        XCTAssertTrue(topResult.waitForExistence(timeout: 3))
        topResult.tap()
        keys("ABC")
        expect(first, "❤️")
    }

    func testLanguageToggleSwitchesBetweenVietnameseAndEnglish() {
        let langToggle = app.buttons["keyboard.languageToggle"]
        XCTAssertTrue(langToggle.waitForExistence(timeout: 3))
        langToggle.tap()
        keys("v", "i", "e", "e", "t", "j", space)
        expect(first, "vieetj ")
        langToggle.tap()
        keys("v", "i", "e", "e", "t", "j", space)
        expect(first, "vieetj việt ")
    }
}
