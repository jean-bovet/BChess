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
        #expect(status(thinking: true, black: player, whiteToMove: false) == "\(name) is thinking\u{2026}")
        #expect(GameText.sideDetail(of: player, isWhite: false, opponent: human, toMove: true) == "Black" + suffix)
        #expect(GameText.sideDetail(of: player, isWhite: true, opponent: human, toMove: false) == "White" + suffix)
        // A given name wins, and then the level appears nowhere else, so the detail keeps it (D1)
        let ann = GamePlayer(name: "Ann", computer: true, level: level)
        #expect(GameText.name(of: ann, isWhite: false, opponent: human) == "Ann")
        let annDetail = GameText.sideDetail(of: ann, isWhite: false, opponent: human, toMove: true)
        #expect(annDetail == (suffix.isEmpty ? "Black \u{00B7} \(String(localized: ann.strength.displayName))" : "Black" + suffix))
        // A blank name is no name: the same trimming as `name(of:)`
        let blank = GamePlayer(name: "   ", computer: true, level: level)
        #expect(GameText.name(of: blank, isWhite: false, opponent: human) == name)
        #expect(GameText.sideDetail(of: blank, isWhite: false, opponent: human, toMove: true) == "Black" + suffix)
    }

    @Test func sideDetails() {
        #expect(GameText.sideDetail(of: human, isWhite: true, opponent: computer, toMove: true) == "White \u{00B7} your move")
        #expect(GameText.sideDetail(of: human, isWhite: false, opponent: human, toMove: true) == "Black \u{00B7} to move")
        #expect(GameText.sideDetail(of: human, isWhite: false, opponent: computer, toMove: false) == "Black")
        #expect(GameText.sideDetail(of: computer, isWhite: false, opponent: human, toMove: true) == "Black")
    }

    @Test func moveLabels() {
        #expect(GameText.moveLabel(number: 8, isWhite: true, san: "c3") == "8. c3")
        #expect(GameText.moveLabel(number: 8, isWhite: false, san: "O-O") == "8\u{2026}O-O")
    }

    private func status(_ mode: GameMode.Value = .play, thinking: Bool = false, end: GameEnd = .none,
                        white: GamePlayer = human, black: GamePlayer = computer,
                        whiteToMove: Bool = true, last: String? = nil) -> String {
        GameText.status(mode: mode, isThinking: thinking, gameEnd: end, white: white, black: black,
                        isWhiteToMove: whiteToMove, lastMove: last)
    }

    @Test func statusForModes() {
        #expect(status(.analyze) == "Analyzing. Moves are not saved.")
        #expect(status(.train) == "Practicing openings.")
        #expect(status(.analyze, last: "8. c3") == "Analyzing. Moves are not saved.")
    }

    @Test func statusForGameEnds() {
        // The side to move is the one that is mated
        #expect(status(end: .checkmate, whiteToMove: false) == "Checkmate. White wins.")
        #expect(status(end: .checkmate, whiteToMove: true) == "Checkmate. Black wins.")
        #expect(status(end: .stalemate) == "Stalemate.")
        #expect(status(end: .repetition) == "Draw by repetition.")
        #expect(status(end: .finished) == "Game over.")
        #expect(status(end: .checkmate, whiteToMove: false, last: "2\u{2026}Qh4") == "Checkmate. White wins. Last: \u{2066}2\u{2026}Qh4\u{2069}")
    }

    @Test func statusWhileThinking() {
        #expect(status(thinking: true, whiteToMove: false) == "Club Player is thinking\u{2026}")
        let ann = GamePlayer(name: "Ann", computer: true, level: 1)
        #expect(status(thinking: true, black: ann, whiteToMove: false) == "Ann is thinking\u{2026}")
    }

    @Test func statusForTheMoveToPlay() {
        #expect(status() == "Your move.")
        #expect(status(white: computer, black: human, whiteToMove: false) == "Your move.")
        #expect(status(white: human, black: human) == "White to move.")
        #expect(status(white: human, black: human, whiteToMove: false) == "Black to move.")
        let ann = GamePlayer(name: "Ann", computer: false, level: 0)
        #expect(status(white: ann, black: computer) == "Ann to move.")
        // A computer's turn that is not being played (after going back)
        #expect(status(whiteToMove: false) == "Club Player to move.")
    }

    /// A human who typed "You" as a name is not "you": the sentence follows the structure, never the text.
    @Test func aPlayerNamedYouIsNotYou() {
        let you = GamePlayer(name: "You", computer: false, level: 0)
        let friend = GamePlayer(name: "Ben", computer: false, level: 0)
        #expect(status(white: you, black: friend) == "You to move.")
        #expect(status(white: you, black: computer) == "You to move.")
    }

    /// The notation reads left to right inside a right-to-left sentence: an isolate, never a layout pin (which does not set
    /// a paragraph's bidi base direction).
    @Test func notationIsALeftToRightIsolate() {
        #expect(GameText.notation("8\u{2026}O-O") == "\u{2066}8\u{2026}O-O\u{2069}")
        #expect(GameText.notation("") == "\u{2066}\u{2069}")
        #expect(status(last: "8. c3").hasSuffix("8. c3\u{2069}"))
    }

    @Test func statusWithTheLastMove() {
        #expect(status(last: "8. c3") == "Your move. Last: \u{2066}8. c3\u{2069}")
        #expect(status(whiteToMove: false, last: "8\u{2026}O-O") == "Club Player to move. Last: \u{2066}8\u{2026}O-O\u{2069}")
        #expect(status(thinking: true, whiteToMove: false, last: "8. c3") == "Club Player is thinking\u{2026} Last: \u{2066}8. c3\u{2069}")
    }
}
