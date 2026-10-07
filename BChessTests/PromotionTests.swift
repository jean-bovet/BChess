//
//  PromotionTests.swift
//  BChessTests
//
//  The choices the promotion picker offers and where its column drops.
//

import Testing

private let whiteToPromote = "8/P6k/8/8/8/8/8/K7 w - - 0 1"
private let blackToPromote = "8/8/7k/8/8/8/p7/7K b - - 0 1"

/// The PGN of a game that starts from this position, after these moves.
private func pgn(fen: String, moves: [String] = []) -> String {
    let engine = FEngine()
    engine.setFEN(fen)
    for move in moves {
        #expect(engine.move(uci: move))
    }
    return engine.pgnAllGames()
}

@MainActor
private func session(fen: String, moves: [String] = []) -> GameSession {
    GameSession(state: GameState(pgn: pgn(fen: fen, moves: moves), white: .human, black: .human))
}

/// Selects the pawn on `from` and starts the promotion to `to`, the way a tap on the board does.
@MainActor
private func beginPromotion(_ session: GameSession, from: (rank: Int, file: Int), to: (rank: Int, file: Int)) {
    session.select(rank: from.rank, file: from.file)
    guard let move = session.selection.possibleMove(to.rank, to.file), move.isPromotion else {
        Issue.record("not a promotion")
        return
    }
    session.beginPromotion(move)
}

@MainActor
struct PromotionTests {

    @Test func offersTheQueenFirst() {
        let white = Promotion(move: FEngineMove(), isWhite: true)
        #expect(white.pieceNames == ["Q", "R", "B", "N"])
        let black = Promotion(move: FEngineMove(), isWhite: false)
        #expect(black.pieceNames == ["q", "r", "b", "n"])
    }

    @Test func screenPositionFollowsTheBoardOrientation() {
        // White promotes on rank 8 (index 7), file h (index 7)
        #expect(Promotion.screenRow(rank: 7, rotated: false) == 0)
        #expect(Promotion.screenRow(rank: 7, rotated: true) == 7)
        #expect(Promotion.screenFile(file: 7, rotated: false) == 7)
        #expect(Promotion.screenFile(file: 7, rotated: true) == 0)
    }

    @Test func columnDropsTowardTheCenterWhateverTheOrientation() {
        // White at the bottom: promoting on the top row drops, Black's promotion on the bottom row rises
        #expect(Promotion.dropsDown(screenRow: Promotion.screenRow(rank: 7, rotated: false)))
        #expect(!Promotion.dropsDown(screenRow: Promotion.screenRow(rank: 0, rotated: false)))
        // Rotated: the same squares are on the other side of the screen
        #expect(!Promotion.dropsDown(screenRow: Promotion.screenRow(rank: 7, rotated: true)))
        #expect(Promotion.dropsDown(screenRow: Promotion.screenRow(rank: 0, rotated: true)))
    }

    @Test func eachChoicePlaysItsPieceForWhite() {
        for piece in ["Q", "R", "B", "N"] {
            let session = session(fen: whiteToPromote)
            beginPromotion(session, from: (6, 0), to: (7, 0))
            #expect(session.pendingPromotion != nil)
            session.choosePromotion(piece)
            #expect(session.pendingPromotion == nil)
            #expect(session.gameState.pgn.contains("a8=\(piece)"))
        }
    }

    @Test func eachChoicePlaysItsPieceForBlack() {
        for piece in ["q", "r", "b", "n"] {
            let session = session(fen: blackToPromote)
            beginPromotion(session, from: (1, 0), to: (0, 0))
            #expect(session.pendingPromotion?.isWhite == false)
            session.choosePromotion(piece)
            #expect(session.gameState.pgn.contains("a1=\(piece.uppercased())"))
        }
    }

    @Test func cancelPlaysNothing() {
        let session = session(fen: whiteToPromote)
        let before = session.fen
        beginPromotion(session, from: (6, 0), to: (7, 0))
        session.cancelPromotion()
        #expect(session.pendingPromotion == nil)
        #expect(session.fen == before)
        // A late choice finds nothing to play
        session.choosePromotion("Q")
        #expect(session.fen == before)
    }

    @Test func aPositionChangeClosesThePickerAndNothingIsPlayed() {
        let moves = ["a6a7", "h6g7"]
        let start = "8/8/P6k/8/8/8/8/K7 w - - 0 1"
        let changes: [(String, (GameSession) -> Void)] = [
            ("back", { $0.move(to: .backward) }),
            ("paste", { _ = $0.paste("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1") }),
            ("analyze", { $0.toggleAnalyze() }),
            ("train", { $0.toggleTrain() }),
            ("players", { $0.setPlayers(white: .human, black: GamePlayer(name: "", computer: true, level: 0)) }),
        ]
        for (name, change) in changes {
            let session = session(fen: start, moves: moves)
            session.move(to: .end)
            beginPromotion(session, from: (6, 0), to: (7, 0))
            #expect(session.pendingPromotion != nil, "\(name)")
            change(session)
            let afterChange = session.fen
            let pgnAfterChange = session.gameState.pgn
            #expect(session.pendingPromotion == nil, "\(name)")
            session.choosePromotion("Q")
            #expect(session.fen == afterChange, "\(name)")
            #expect(session.gameState.pgn == pgnAfterChange, "\(name)")
        }
    }

    @Test func columnDropsTowardTheCenterOfTheBoard() {
        // Screen rows count from the top of the board: 0...3 are its upper half
        for row in 0...3 {
            #expect(Promotion.dropsDown(screenRow: row))
        }
        for row in 4...7 {
            #expect(!Promotion.dropsDown(screenRow: row))
        }
    }
}
