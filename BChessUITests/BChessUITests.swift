//
//  BChessUITests.swift
//  BChessUITests
//

import XCTest

final class BChessUITests: XCTestCase {

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
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

    /// The frame of an element once two reads 0.25 s apart agree (a scroll or a sheet still moving would give a stale one).
    @MainActor
    private func settledFrame(_ element: XCUIElement) -> CGRect {
        var frame = element.frame
        for _ in 0..<12 {
            Thread.sleep(forTimeInterval: 0.25)
            let next = element.frame
            if next == frame { return frame }
            frame = next
        }
        XCTFail("\(element) never settled: \(frame)")
        return frame
    }

    /// Scrolls the New Game sheet until the field lies between the sheet's bar and the Start bar. On the iPad's short
    /// sheet the Start bar covers the lower fields, and a tap on a covered point lands on Start. Frames decide, since
    /// `isHittable` accepts a half-covered field (measured: the first name, half under the bar, was hittable; the fully
    /// covered second name was not). Only slow upward drags, from the content's left margin.
    @MainActor
    private func scrollClear(_ field: XCUIElement, in app: XCUIApplication) {
        let top = settledFrame(app.buttons["Cancel"]).maxY
        let start = settledFrame(app.buttons["new-game-start"])
        let bottom = start.minY - 8
        func isClear() -> Bool {
            let frame = settledFrame(field)
            return frame.minY >= top && frame.maxY <= bottom
        }
        for _ in 0..<5 {
            if isClear() { return }
            let frame = field.frame
            if frame.minY < top { break }
            let fromY = start.minY - 24
            let toY = max(top + 12, fromY - (frame.maxY - bottom + 12))
            let x = start.minX - 8
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: x, dy: fromY))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: x, dy: toY)), withVelocity: .slow, thenHoldForDuration: 0.5)
        }
        if isClear() { return }
        XCTFail("\(field.identifier) cannot be scrolled clear of the Start bar: field \(field.frame), Cancel bottom \(top), Start \(start)")
    }

    /// Replaces what a text field holds.
    @MainActor
    private func replaceText(in field: XCUIElement, with text: String, app: XCUIApplication) {
        scrollClear(field, in: app)
        let name = field.identifier
        field.tap()
        // A tap that reached the Start bar closes the sheet; the wait observes the whole dismissal
        XCTAssertFalse(app.buttons["new-game-start"].waitForNonExistence(timeout: 2), "the tap on \(name) closed the sheet")
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
        replaceText(in: app.textFields["new-game-first-name"], with: "Ann", app: app)
        app.buttons["new-game-start"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["board"].waitForExistence(timeout: 10))

        openNewGame(app)
        XCTAssertTrue(app.buttons["new-game-opponent-maximum"].isSelected)
        XCTAssertTrue(app.buttons["30 s"].isSelected)
        XCTAssertTrue(app.buttons["Black"].isSelected)
        XCTAssertEqual(app.textFields["new-game-first-name"].value as? String, "Ann")

        // A friend game: each name field keeps its own name
        app.buttons["new-game-opponent-friend"].tap()
        replaceText(in: app.textFields["new-game-first-name"], with: "Ann", app: app)
        replaceText(in: app.textFields["new-game-second-name"], with: "Ben", app: app)
        app.buttons["new-game-start"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["board"].waitForExistence(timeout: 10))

        openNewGame(app)
        XCTAssertTrue(app.buttons["new-game-opponent-friend"].isSelected)
        XCTAssertEqual(app.textFields["new-game-first-name"].value as? String, "Ann")
        XCTAssertEqual(app.textFields["new-game-second-name"].value as? String, "Ben")
    }

    /// Settings ▸ About BChess on the iPhone: the production path to the notices of the shipped app.
    @MainActor
    func testSettingsAboutShowsTheNotices() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshLibrary"]
        app.launch()

        app.buttons["More"].tap()
        app.buttons["Settings"].tap()
        let row = app.buttons["settings-about"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let notices = app.descendants(matching: .any)["about-notices"]
        XCTAssertTrue(notices.waitForExistence(timeout: 10))
        let text = (notices.value as? String ?? "") + notices.label
        XCTAssertTrue(text.contains("Colin M.L. Burnett"), "the notices lack the pieces credit")
        XCTAssertTrue(text.contains("Pradyumna Kannan"), "the notices lack the magicmoves credit")
    }

    // MARK: - Two boards against a friend (APP-15)

    /// More > New Game > Friend > Play, on the fresh library.
    @MainActor
    private func startFriendGame(_ app: XCUIApplication) {
        openNewGame(app)
        app.buttons["new-game-opponent-friend"].tap()
        // The first player is White, on the near half: Black sits on the far, turned one (the default is a random seat)
        app.buttons["White"].tap()
        app.buttons["new-game-start"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["board"].waitForExistence(timeout: 10))
    }

    /// The element with this identifier (waits up to ten seconds for it). Only the half of the player on move has the plain
    /// identifiers (the other's are `inactive-square-…` and `board-inactive`; XCUITest lists hidden elements too), so a
    /// second match fails the query, never a guess.
    @MainActor
    private func live(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 10), "no \(identifier)")
        return element
    }

    @MainActor
    private func boardValue(_ app: XCUIApplication) -> String {
        live(app, "board").value as? String ?? ""
    }

    /// Waits until the window is wider than tall (or taller than wide).
    @MainActor
    private func waitForWindow(_ app: XCUIApplication, wide: Bool, timeout: TimeInterval = 15) {
        let window = app.windows.firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let frame = window.frame
            if (frame.width > frame.height) == wide {
                return
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTFail("the window did not turn \(wide ? "landscape" : "portrait"): \(window.frame)")
    }

    /// Waits until the board's FEN matches the pattern (the board that answers is the one on move).
    @MainActor
    private func waitForBoard(_ app: XCUIApplication, matching pattern: String, timeout: TimeInterval = 10) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if boardValue(app).range(of: pattern, options: .regularExpression) != nil {
                return
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTFail("the live board never matched \(pattern): \(boardValue(app))")
    }

    /// One move through the identifiers, which always belong to the board of the player on move; returns once
    /// the position has changed, that is once the other board is the live one.
    @MainActor
    private func play(_ app: XCUIApplication, _ from: String, _ to: String) {
        let before = boardValue(app)
        let source = live(app, "square-\(from)")
        source.tap()
        let target = live(app, "square-\(to)")
        target.tap()
        if app.buttons["promote-Q"].exists || app.buttons["promote-q"].exists {
            return
        }
        let deadline = Date().addingTimeInterval(10)
        while boardValue(app) == before, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertNotEqual(boardValue(app), before, "\(from)\(to) was not played")
    }

    /// A point in the window: a coordinate tap lands wherever the screen shows the point, whatever the accessibility
    /// tree holds there.
    @MainActor
    private func coordinate(_ app: XCUIApplication, _ point: CGPoint) -> XCUICoordinate {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        return origin.withOffset(CGVector(dx: point.x, dy: point.y))
    }

    /// The two boards show the position the same way up (each from its own player's side, the players facing each
    /// other), and the halves are equal around the bar: a square of the hidden board is the same square of the
    /// live one, moved by the vector between the boards' centres, which mirror each other through the bar's middle.
    @MainActor
    private func inactiveCentre(of square: String, in app: XCUIApplication) -> CGPoint {
        let squareFrame = live(app, "square-\(square)").frame
        let board = live(app, "board").frame
        let undo = app.buttons["Undo"].frame
        let more = app.buttons["More"].frame
        let middle = CGPoint(x: (undo.minX + more.maxX) / 2, y: (undo.minY + more.maxY) / 2)
        let otherBoard = CGPoint(x: 2 * middle.x - board.midX, y: 2 * middle.y - board.midY)
        return CGPoint(x: squareFrame.midX + otherBoard.x - board.midX, y: squareFrame.midY + otherBoard.y - board.midY)
    }

    /// A friend game on the iPhone: each move is made on the board of the player on move (the other half is not
    /// in the accessibility tree), Undo steps back, and a tap on the half that cannot move does nothing.
    @MainActor
    func testFaceToFaceEachBoardPlaysItsSide() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshLibrary"]
        app.launch()
        startFriendGame(app)
        waitForBoard(app, matching: ".* w .* 1$")
        // Each identifier is unique: the half that cannot move carries its own
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "square-e4").count, 1)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "board").count, 1)

        // The board on move is White's; after e4 the identifiers belong to the other board
        play(app, "e2", "e4")
        waitForBoard(app, matching: ".* b .* 1$")
        play(app, "e7", "e5")
        waitForBoard(app, matching: ".* w .* 2$")

        // Undo: Black to move again
        app.buttons["Undo"].tap()
        waitForBoard(app, matching: ".* b .* 1$")
        XCTAssertEqual(live(app, "square-e4").value as? String, "P")

        // A coordinate tap on the half that cannot move: Black's pawn e7 and its target e5, on White's board
        let fen = boardValue(app)
        let e7 = inactiveCentre(of: "e7", in: app)
        let e5 = inactiveCentre(of: "e5", in: app)
        let selected = app.descendants(matching: .any).matching(NSPredicate(format: "identifier CONTAINS 'square-' AND selected == true"))
        coordinate(app, e7).tap()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(selected.count, 0, "a tap on the inactive half selected a square")
        coordinate(app, e5).tap()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(selected.count, 0, "a second tap on the inactive half selected a square")
        XCTAssertEqual(boardValue(app), fen, "a tap on the inactive half moved a piece")
        XCTAssertEqual(live(app, "square-e5").value as? String, "empty")

        // The same two squares, on the board on move: the first tap selects (so the check above can fail), the second moves
        live(app, "square-e7").tap()
        // Both boards draw the selection, the live one is the one tapped
        XCTAssertTrue(live(app, "square-e7").isSelected, "a tap on the live board selected nothing")
        XCTAssertGreaterThanOrEqual(selected.count, 1)
        live(app, "square-e5").tap()
        waitForBoard(app, matching: ".* w .* 2$")
    }

    /// 1. a4 h5 2. a5 h4 3. a6 h3 4. axb7 hxg2 5. h4 and Black promotes on h1, through the picker of the board on move.
    @MainActor
    private func playToBlackPromotion(_ app: XCUIApplication) {
        let moves = [("a2", "a4"), ("h7", "h5"), ("a4", "a5"), ("h5", "h4"), ("a5", "a6"), ("h4", "h3"),
                     ("a6", "b7"), ("h3", "g2"), ("h2", "h4")]
        for (from, to) in moves {
            play(app, from, to)
        }
        let source = live(app, "square-g2")
        source.tap()
        live(app, "square-h1").tap()
        let queen = app.buttons["promote-Q"]
        XCTAssertTrue(queen.waitForExistence(timeout: 10))
        // Black sits on the far half: the top of a tall window, the right of a wide one
        let window = app.windows.firstMatch.frame
        if window.width > window.height {
            XCTAssertGreaterThan(queen.frame.midX, window.midX, "the picker is not on the far (right) half")
        } else {
            XCTAssertLessThan(queen.frame.midY, window.midY, "the picker is not on the far (top) half")
        }
        queen.tap()
        let h1 = live(app, "square-h1")
        let queened = NSPredicate(format: "value == %@", "q")
        expectation(for: queened, evaluatedWith: h1)
        waitForExpectations(timeout: 10)
    }

    @MainActor
    func testFaceToFacePromotionOnTheTurnedBoard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshLibrary"]
        app.launch()
        startFriendGame(app)
        playToBlackPromotion(app)
    }

    @MainActor
    func testFaceToFacePromotionOnTheTurnedBoardInLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshLibrary"]
        app.launch()
        startFriendGame(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        waitForWindow(app, wide: true)
        playToBlackPromotion(app)
    }

    /// More > Two Boards in a friend game: off gives the single board (one e2, its navigation bar), on the two boards again;
    /// the way back is in the bar's menu. On the iPhone, sideways while on, then off, the window turns back to portrait.
    @MainActor
    func testFriendGameSwitchesBetweenTwoBoardsAndOne() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshLibrary"]
        app.launch()
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        startFriendGame(app)
        XCTAssertTrue(app.descendants(matching: .any)["board-inactive"].exists, "a friend game starts on two boards")
        XCTAssertFalse(app.buttons["Games"].exists)

        func toggle(keepScreenshot name: String? = nil) {
            app.buttons["More"].tap()
            let item = app.buttons["Two Boards"]
            XCTAssertTrue(item.waitForExistence(timeout: 10), "the menu offers Two Boards")
            if let name {
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = name
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            item.tap()
        }

        toggle(keepScreenshot: "More menu, Two Boards checked")
        XCTAssertTrue(app.buttons["Games"].waitForExistence(timeout: 10), "the single board has its navigation bar")
        XCTAssertFalse(app.descendants(matching: .any)["board-inactive"].exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "square-e2").count, 1)

        toggle(keepScreenshot: "More menu, Two Boards unchecked")
        XCTAssertTrue(app.descendants(matching: .any)["board-inactive"].waitForExistence(timeout: 10), "the two boards are back")
        XCTAssertFalse(app.buttons["Games"].exists)

        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.orientation = .landscapeLeft
            waitForWindow(app, wide: true)
            toggle()
            waitForWindow(app, wide: false)
            XCTAssertTrue(app.buttons["Games"].waitForExistence(timeout: 10))
        }
    }

    /// The iPhone turns sideways only in a friend game: GameView, `OrientationLock`, the delegate, the rotation.
    @MainActor
    func testLandscapeOnlyFaceToFace() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the iPad turns in every game")
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshLibrary"]
        app.launch()
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        startFriendGame(app)

        XCUIDevice.shared.orientation = .landscapeLeft
        waitForWindow(app, wide: true)

        // Still sideways, a computer game starts: the app turns back to portrait
        openNewGame(app)
        app.buttons["new-game-opponent-club"].tap()
        app.buttons["new-game-start"].tap()
        waitForWindow(app, wide: false)
    }
}
