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

        // More > New Game > New Game (white human, black computer at level 0)
        app.buttons["More"].tap()
        app.buttons["New Game"].tap()
        app.buttons["New Game"].tap()

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
}
