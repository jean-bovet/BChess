//
//  BChessUITests.swift
//  BChessUITests
//

import XCTest

final class BChessUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNewGamePlayE4EngineReplies() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshLibrary"]
        app.launch()

        // More > New Game > Play (white human, black computer: the Club player, the sheet's default)
        app.buttons["More"].tap()
        app.buttons["New Game"].tap()
        app.buttons["new-game-start"].tap()

        let e2 = app.descendants(matching: .any)["square-e2"]
        XCTAssertTrue(e2.waitForExistence(timeout: 10))
        e2.tap()
        app.descendants(matching: .any)["square-e4"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["square-e4"].value as? String, "P")

        // Black replies, and it is White's second move
        let board = app.descendants(matching: .any)["board"]
        let replied = NSPredicate(format: "value MATCHES %@", ".* w .* 2$")
        expectation(for: replied, evaluatedWith: board)
        waitForExpectations(timeout: 20)

        // Back steps to the position after 1. e4, and the screen keeps working
        app.buttons["Back"].tap()
        let back = NSPredicate(format: "value MATCHES %@", ".* b .* 1$")
        expectation(for: back, evaluatedWith: board)
        waitForExpectations(timeout: 10)

        // The engine readout appears when the engine is turned on
        app.buttons["Engine"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["engine-readout"].waitForExistence(timeout: 10))
    }

    /// Replaces what a text field holds.
    @MainActor
    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
    }

    @MainActor
    private func openNewGame(_ app: XCUIApplication) {
        app.buttons["More"].tap()
        app.buttons["New Game"].tap()
        XCTAssertTrue(app.buttons["new-game-start"].waitForExistence(timeout: 10))
    }

    /// The sheet opens on the last choice: the production path of `NewGame(remembered:)`, which the unit tests
    /// and the gallery cannot reach.
    @MainActor
    func testNewGameRemembersTheChoice() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshLibrary"]
        app.launch()

        // A computer game: Maximum, 30 s, Black, named Ann
        openNewGame(app)
        XCTAssertTrue(app.buttons["new-game-opponent-club"].isSelected, "the fresh library starts on Club")
        app.buttons["new-game-opponent-maximum"].tap()
        app.buttons["30 s"].tap()
        app.buttons["Black"].tap()
        replaceText(in: app.textFields["new-game-first-name"], with: "Ann")
        app.buttons["new-game-start"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["board"].waitForExistence(timeout: 10))

        openNewGame(app)
        XCTAssertTrue(app.buttons["new-game-opponent-maximum"].isSelected)
        XCTAssertTrue(app.buttons["30 s"].isSelected)
        XCTAssertTrue(app.buttons["Black"].isSelected)
        XCTAssertEqual(app.textFields["new-game-first-name"].value as? String, "Ann")

        // A friend game: each name field keeps its own name
        app.buttons["new-game-opponent-friend"].tap()
        replaceText(in: app.textFields["new-game-first-name"], with: "Ann")
        replaceText(in: app.textFields["new-game-second-name"], with: "Ben")
        app.buttons["new-game-start"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["board"].waitForExistence(timeout: 10))

        openNewGame(app)
        XCTAssertTrue(app.buttons["new-game-opponent-friend"].isSelected)
        XCTAssertEqual(app.textFields["new-game-first-name"].value as? String, "Ann")
        XCTAssertEqual(app.textFields["new-game-second-name"].value as? String, "Ben")
    }
}
