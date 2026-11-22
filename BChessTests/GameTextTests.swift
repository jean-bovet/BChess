//
//  GameTextTests.swift
//  BChessTests
//

import Testing

private let human = GamePlayer.human
private let computer = GamePlayer.defaultBlack // Club

struct GameTextTests {

    @Test func names() {
        #expect(GameText.name(of: human, isWhite: true, opponent: computer) == "You")
        #expect(GameText.name(of: human, isWhite: false, opponent: computer) == "You")
        #expect(GameText.name(of: computer, isWhite: false, opponent: human) == "Club Player")
        #expect(GameText.name(of: human, isWhite: true, opponent: human) == "White")
        #expect(GameText.name(of: human, isWhite: false, opponent: human) == "Black")
        #expect(GameText.name(of: computer, isWhite: true, opponent: computer) == "Club Player")
        let ann = GamePlayer(name: "Ann", computer: false, level: 0)
        #expect(GameText.name(of: ann, isWhite: true, opponent: computer) == "Ann")
        let spaces = GamePlayer(name: "   ", computer: false, level: 0)
        #expect(GameText.name(of: spaces, isWhite: true, opponent: computer) == "You")
        #expect(GameText.name(of: spaces, isWhite: false, opponent: human) == "Black")
    }

    @Test func titles() {
        let ann = GamePlayer(name: "Ann", computer: false, level: 0)
        #expect(GameText.title(white: human, black: computer) == "You vs Club Player")
        #expect(GameText.title(white: computer, black: human) == "Club Player vs You")
        #expect(GameText.title(white: human, black: human) == "White vs Black")
        #expect(GameText.title(white: computer, black: computer) == "Club Player vs Club Player")
        #expect(GameText.title(white: ann, black: computer) == "Ann vs Club Player")
    }

    /// Every level: the name, the title, the status and the row detail. Below Maximum the name already says the
    /// level, so the detail is the bare colour; at Maximum it adds the thinking time ("" means no suffix).
    @Test(arguments: [(0, "Beginner Player", ""), (1, "Casual Player", ""), (2, "Club Player", ""),
                      (3, "Strong Player", ""), (4, "Full Engine", " \u{00B7} 5 s"),
                      (5, "Full Engine", " \u{00B7} 10 s"), (6, "Full Engine", " \u{00B7} 30 s")])
    func computerNamesAndDetails(_ level: Int, _ name: String, _ suffix: String) {
        let player = GamePlayer(name: "", computer: true, level: level)
        #expect(GameText.name(of: player, isWhite: false, opponent: human) == name)
        #expect(GameText.title(white: human, black: player) == "You vs \(name)")
        #expect(GameText.title(white: player, black: human) == "\(name) vs You")
        #expect(GameText.sideDetail(of: player, isWhite: false, opponent: human, toMove: true, isThinking: false) == "Black" + suffix)
        #expect(GameText.sideDetail(of: player, isWhite: true, opponent: human, toMove: false, isThinking: false) == "White" + suffix)
        // A given name wins, and then the level appears nowhere else, so the detail keeps it (D1)
        let ann = GamePlayer(name: "Ann", computer: true, level: level)
        #expect(GameText.name(of: ann, isWhite: false, opponent: human) == "Ann")
        let annDetail = GameText.sideDetail(of: ann, isWhite: false, opponent: human, toMove: true, isThinking: false)
        #expect(annDetail == (suffix.isEmpty ? "Black \u{00B7} \(String(localized: ann.strength.displayName))" : "Black" + suffix))
        // A blank name is no name: the same trimming as `name(of:)`
        let blank = GamePlayer(name: "   ", computer: true, level: level)
        #expect(GameText.name(of: blank, isWhite: false, opponent: human) == name)
        #expect(GameText.sideDetail(of: blank, isWhite: false, opponent: human, toMove: true, isThinking: false) == "Black" + suffix)
    }

    @Test func sideDetails() {
        #expect(GameText.sideDetail(of: human, isWhite: true, opponent: computer, toMove: true, isThinking: false) == "White \u{00B7} your move")
        #expect(GameText.sideDetail(of: human, isWhite: false, opponent: computer, toMove: false, isThinking: false) == "Black")
        #expect(GameText.sideDetail(of: computer, isWhite: false, opponent: human, toMove: true, isThinking: false) == "Black")
    }

    /// D6: a human with no name is named by its colour, so the detail never says the colour again.
    @Test func unnamedHumanDetailDoesNotRepeatTheColour() {
        #expect(GameText.name(of: human, isWhite: false, opponent: human) == "Black")
        #expect(GameText.sideDetail(of: human, isWhite: false, opponent: human, toMove: true, isThinking: false) == "to move")
        #expect(GameText.sideDetail(of: human, isWhite: true, opponent: human, toMove: false, isThinking: false) == "")
        // A named human keeps the colour: the name does not say it
        let ann = GamePlayer(name: "Ann", computer: false, level: 0)
        #expect(GameText.sideDetail(of: ann, isWhite: false, opponent: human, toMove: true, isThinking: false) == "Black \u{00B7} to move")
        #expect(GameText.sideDetail(of: ann, isWhite: false, opponent: human, toMove: false, isThinking: false) == "Black")
    }

    /// The computer thinking moves from the status line into its row: "Black \u{00B7} thinking\u{2026}".
    @Test func sideDetailsWhileThinking() {
        #expect(GameText.sideDetail(of: computer, isWhite: false, opponent: human, toMove: true, isThinking: true) == "Black \u{00B7} thinking\u{2026}")
        let maximum = GamePlayer(name: "", computer: true, level: 5)
        #expect(GameText.sideDetail(of: maximum, isWhite: false, opponent: human, toMove: true, isThinking: true) == "Black \u{00B7} thinking\u{2026}")
        #expect(GameText.sideDetail(of: maximum, isWhite: false, opponent: human, toMove: true, isThinking: false) == "Black \u{00B7} 10 s")
        let ann = GamePlayer(name: "Ann", computer: true, level: 1)
        #expect(GameText.sideDetail(of: ann, isWhite: false, opponent: human, toMove: true, isThinking: true) == "Black \u{00B7} thinking\u{2026}")
        // Thinking, but not its move (the flag follows the position): the usual detail
        #expect(GameText.sideDetail(of: computer, isWhite: false, opponent: human, toMove: false, isThinking: true) == "Black")
        #expect(GameText.sideDetail(of: maximum, isWhite: false, opponent: human, toMove: false, isThinking: true) == "Black \u{00B7} 10 s")
        // A human is never "thinking"
        #expect(GameText.sideDetail(of: human, isWhite: true, opponent: computer, toMove: true, isThinking: true) == "White \u{00B7} your move")
        #expect(GameText.sideDetail(of: human, isWhite: false, opponent: human, toMove: true, isThinking: true) == "to move")
    }

    @Test func moveLabels() {
        #expect(GameText.moveLabel(number: 8, isWhite: true, san: "c3") == "8. c3")
        #expect(GameText.moveLabel(number: 8, isWhite: false, san: "O-O") == "8\u{2026}O-O")
    }

    private func status(_ mode: GameMode.Value = .play, end: GameEnd = .none) -> String? {
        GameText.status(mode: mode, gameEnd: end)
    }

    @Test func statusForModes() {
        #expect(status(.analyze) == "Analyzing. Moves are not saved.")
        #expect(status(.train) == "Practicing openings.")
    }

    @Test func resultTitles() {
        #expect(String(localized: GameText.resultTitle(GameResult(winner: .white, reason: .checkmate))) == "White wins")
        #expect(String(localized: GameText.resultTitle(GameResult(winner: .black, reason: .finished))) == "Black wins")
        #expect(String(localized: GameText.resultTitle(GameResult(winner: .draw, reason: .stalemate))) == "Draw")
    }

    @Test func resultDetailIsOneLine() {
        #expect(GameText.resultDetail(GameResult(winner: .white, reason: .checkmate)) == "White wins \u{00B7} Checkmate")
        #expect(GameText.resultDetail(GameResult(winner: .draw, reason: .repetition)) == "Draw \u{00B7} Threefold repetition")
        // A declared result has no reason of its own
        #expect(GameText.resultDetail(GameResult(winner: .black, reason: .finished)) == "Black wins")
    }

    @Test func resultReasons() {
        let reasons: [(GameEnd, String?)] = [
            (.checkmate, "Checkmate"), (.stalemate, "Stalemate"), (.repetition, "Threefold repetition"),
            (.fiftyMoves, "Fifty-move rule"), (.deadPosition, "Insufficient material"),
            (.finished, nil), (.none, nil),
        ]
        for (end, expected) in reasons {
            #expect(GameText.resultReason(end).map { String(localized: $0) } == expected)
        }
    }

    @Test func statusForGameEnds() {
        // A position that cannot be played, in the middle of an imported line: the reason alone (the banner says the result)
        #expect(status(end: .repetition) == "Threefold repetition")
        #expect(status(end: .fiftyMoves) == "Fifty-move rule")
        #expect(status(end: .deadPosition) == "Insufficient material")
        #expect(status(end: .checkmate) == "Checkmate")
        #expect(status(end: .stalemate) == "Stalemate")
        // A declared result has no reason of its own
        #expect(status(end: .finished) == nil)
    }

    /// During play the player rows say whose move it is (and the computer thinking), the strip and the board the last
    /// move: the status line has nothing to add.
    @Test func statusIsNilDuringPlay() {
        #expect(status() == nil)
    }

    /// The notation reads left to right inside a right-to-left sentence: an isolate, never a layout pin (which does not set
    /// a paragraph's bidi base direction).
    @Test func notationIsALeftToRightIsolate() {
        #expect(GameText.notation("8\u{2026}O-O") == "\u{2066}8\u{2026}O-O\u{2069}")
        #expect(GameText.notation("") == "\u{2066}\u{2069}")
    }
}
