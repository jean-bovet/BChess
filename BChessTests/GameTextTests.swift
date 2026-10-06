//
//  GameTextTests.swift
//  BChessTests
//

import Testing

private let human = GamePlayer.human
private let computer = GamePlayer(name: "", computer: true, level: 0)

struct GameTextTests {

    @Test func names() {
        #expect(GameText.name(of: human, isWhite: true, opponent: computer) == "You")
        #expect(GameText.name(of: human, isWhite: false, opponent: computer) == "You")
        #expect(GameText.name(of: computer, isWhite: false, opponent: human) == "Computer")
        #expect(GameText.name(of: human, isWhite: true, opponent: human) == "White")
        #expect(GameText.name(of: human, isWhite: false, opponent: human) == "Black")
        #expect(GameText.name(of: computer, isWhite: true, opponent: computer) == "Computer")
        let ann = GamePlayer(name: "Ann", computer: false, level: 0)
        #expect(GameText.name(of: ann, isWhite: true, opponent: computer) == "Ann")
        let spaces = GamePlayer(name: "   ", computer: false, level: 0)
        #expect(GameText.name(of: spaces, isWhite: true, opponent: computer) == "You")
        #expect(GameText.name(of: spaces, isWhite: false, opponent: human) == "Black")
    }

    @Test func titles() {
        let ann = GamePlayer(name: "Ann", computer: false, level: 0)
        #expect(GameText.title(white: human, black: computer) == "You vs Computer")
        #expect(GameText.title(white: computer, black: human) == "Computer vs You")
        #expect(GameText.title(white: human, black: human) == "White vs Black")
        #expect(GameText.title(white: computer, black: computer) == "Computer vs Computer")
        #expect(GameText.title(white: ann, black: computer) == "Ann vs Computer")
    }

    @Test func details() {
        #expect(GameText.detail(of: human, toMove: true) == "to move")
        #expect(GameText.detail(of: human, toMove: false) == nil)
        for (level, seconds) in [(0, 2), (1, 5), (2, 10), (3, 15)] {
            let player = GamePlayer(name: "", computer: true, level: level)
            #expect(GameText.detail(of: player, toMove: true) == "\(seconds) s")
            #expect(GameText.detail(of: player, toMove: false) == "\(seconds) s")
        }
    }

    @Test func sideDetails() {
        #expect(GameText.sideDetail(of: human, isWhite: true, opponent: computer, toMove: true) == "White \u{00B7} your move")
        #expect(GameText.sideDetail(of: human, isWhite: false, opponent: human, toMove: true) == "Black \u{00B7} to move")
        #expect(GameText.sideDetail(of: human, isWhite: false, opponent: computer, toMove: false) == "Black")
        #expect(GameText.sideDetail(of: computer, isWhite: false, opponent: human, toMove: true) == "Black \u{00B7} 2 s")
        #expect(GameText.sideDetail(of: computer, isWhite: true, opponent: human, toMove: false) == "White \u{00B7} 2 s")
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
        #expect(status(end: .checkmate, whiteToMove: false, last: "2\u{2026}Qh4") == "Checkmate. White wins. Last: 2\u{2026}Qh4")
    }

    @Test func statusWhileThinking() {
        #expect(status(thinking: true, whiteToMove: false) == "Computer is thinking\u{2026}")
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
        #expect(status(whiteToMove: false) == "Computer to move.")
    }

    @Test func statusWithTheLastMove() {
        #expect(status(last: "8. c3") == "Your move. Last: 8. c3")
        #expect(status(whiteToMove: false, last: "8\u{2026}O-O") == "Computer to move. Last: 8\u{2026}O-O")
        #expect(status(thinking: true, whiteToMove: false, last: "8. c3") == "Computer is thinking\u{2026} Last: 8. c3")
    }
}
