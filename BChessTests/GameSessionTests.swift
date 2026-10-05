//
//  GameSessionTests.swift
//  BChessTests
//
//  The app logic behind the views: persisted state, navigation, paste, analysis, and the rule that a
//  search result lands only on the position it was computed for (invariant I2).
//

import Foundation
import Testing

private let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
// Outside of the opening book, which answers instantly
private let middlegame = "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 4 4"
private let computerBlack = GamePlayer(name: "", computer: true, level: 0)
private let twoHumans = GameState(pgn: "*", white: .human, black: .human)

/// The PGN of a game that starts from this position.
private func pgn(fen: String) -> String {
    let engine = FEngine()
    engine.setFEN(fen)
    return engine.pgnAllGames()
}

private func fen(after moves: [(String, String)], from start: String = startFEN) -> String {
    let engine = FEngine()
    engine.setFEN(start)
    for (from, to) in moves {
        engine.move(from, to: to)
    }
    return engine.fen()
}

@MainActor
private func halfMoves(_ session: GameSession) -> Int {
    let engine = FEngine()
    guard engine.loadAllGames(session.gameState.pgn) else { return -1 }
    return engine.allMoves().count
}

/// Plays a human move through the board, the way a tap would.
@MainActor
private func play(_ session: GameSession, _ from: String, _ to: String) {
    func square(_ name: String) -> (rank: Int, file: Int) {
        (Int(String(name.last!))! - 1, Int(name.unicodeScalars.first!.value) - 97)
    }
    let source = square(from)
    let target = square(to)
    session.select(rank: source.rank, file: source.file)
    guard let move = session.selection.possibleMove(target.rank, target.file) else {
        Issue.record("\(from)\(to) is not a legal move")
        return
    }
    session.playHuman(move)
}

/// Waits, letting the main queue run, until the condition holds or the time is up.
@MainActor
private func waitUntil(_ seconds: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() && Date() < deadline {
        try? await Task.sleep(for: .milliseconds(20))
    }
    return condition()
}

@MainActor
struct GameSessionTests {

    @Test func selectionDoesNotChangeGameState() {
        let session = GameSession(state: twoHumans)
        play(session, "e2", "e4")
        play(session, "e7", "e5")
        let before = session.gameState

        session.select(rank: 1, file: 3)
        session.undo()
        session.redo()
        session.move(to: .start)
        session.move(to: .end)
        session.toggleAnalyze()
        #expect(session.gameState == before)
    }

    @Test func navigationKeepsUnnormalizedPGN() throws {
        let legacy = Data(#"{"pgn":"1. e4 e5 *","rotated":false}"#.utf8)
        let state = try GameState(data: legacy, contentType: .json)
        let session = GameSession(state: state)

        session.undo()
        session.move(to: .start)
        let uuid = try #require(session.game.moves.first?.whiteMove?.uuid)
        session.selectMove(uuid: uuid)
        #expect(session.gameState == state)
    }

    @Test func selectMoveRebuildsPosition() throws {
        let session = GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 *", white: .human, black: .human))
        let uuid = try #require(session.game.moves.first?.whiteMove?.uuid)
        session.selectMove(uuid: uuid)

        #expect(session.fen == fen(after: [("e2", "e4")]))
        #expect(!session.isWhiteToMove)
        #expect(session.canMove(to: .forward))
        #expect(session.canMove(to: .backward))
    }

    @Test func undoRedo() {
        let session = GameSession(state: twoHumans)
        play(session, "e2", "e4")
        play(session, "e7", "e5")
        let pgn = session.gameState.pgn

        session.undo()
        #expect(session.fen == fen(after: [("e2", "e4")]))
        #expect(session.canMove(to: .forward))
        #expect(session.gameState.pgn == pgn)

        session.redo()
        #expect(session.fen == fen(after: [("e2", "e4"), ("e7", "e5")]))
        #expect(session.gameState.pgn == pgn)
    }

    @Test func redoFollowsTheSelectedBranch() throws {
        let state = GameState(pgn: "1. e4 e5 (1... c5 2. Nf3) *", white: .human, black: .human)
        let session = GameSession(state: state)

        // The uuid of c5, the variation of e5
        let reference = FEngine()
        reference.loadAllGames(state.pgn)
        let c5 = try #require(reference.moveNodesTree()[1].variations.first)
        #expect(c5.name == "c5")

        session.selectMove(uuid: c5.uuid)
        let onBranch = fen(after: [("e2", "e4"), ("c7", "c5")])
        #expect(session.fen == onBranch)

        session.undo()
        session.redo()
        #expect(session.fen == onBranch)

        // The forward button at a branch point asks instead (forwardAtABranchPointOffersTheChoices)
        session.undo()
        session.move(to: .forward)
        #expect(session.variations.show)
    }

    @Test func backwardAtABranchPointJustGoesBack() throws {
        let state = GameState(pgn: "1. e4 e5 (1... c5) 2. Nf3 Nc6 *", white: .human, black: .human)
        let session = GameSession(state: state)
        let reference = FEngine()
        reference.loadAllGames(state.pgn)
        let nf3 = reference.moveNodesTree()[2]
        #expect(nf3.name == "Nf3")

        session.selectMove(uuid: nf3.uuid)
        session.move(to: .backward)
        #expect(session.fen == fen(after: [("e2", "e4"), ("e7", "e5")]))
        #expect(!session.variations.show)

        // Going back again, to the position where e5 and c5 are both possible, never asks either
        session.move(to: .backward)
        #expect(session.fen == fen(after: [("e2", "e4")]))
        #expect(!session.variations.show)
    }

    @Test func forwardAtABranchPointOffersTheChoices() {
        let session = GameSession(state: GameState(pgn: "1. e4 e5 (1... c5) 2. Nf3 Nc6 *", white: .human, black: .human))
        session.move(to: .start)
        session.move(to: .forward) // 1. e4: the only move
        #expect(!session.variations.show)

        session.move(to: .forward)
        #expect(session.variations.show)
        #expect(session.variations.variations.map(\.name) == ["e5", "c5"])

        session.chooseVariation(1)
        #expect(!session.variations.show)
        #expect(session.fen == fen(after: [("e2", "e4"), ("c7", "c5")]))
    }

    @Test func drawnPositionNeverPlaysAMove() async throws {
        // Black to move after 9 plies, in a position that occurred three times
        let repeated = "1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8 5. Nf3 Nf6 1/2-1/2"
        let session = GameSession(state: GameState(pgn: repeated, white: .human, black: computerBlack))
        session.move(to: .backward)
        let position = session.fen

        session.requestEngineMoveIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        #expect(session.fen == position)
        #expect(session.lastMove == nil)
    }

    @Test func searchResultWithoutMoveIsIgnored() throws {
        let repeated = "1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8 5. Nf3 Nf6 1/2-1/2"
        let session = GameSession(state: GameState(pgn: repeated, white: .human, black: .human))
        session.move(to: .backward)
        let position = session.fen

        // The engine finds no move in a drawn position
        let engine = FEngine()
        engine.useOpeningBook = false
        engine.loadAllGames(repeated)
        engine.move(to: .backward, variation: 0)
        let result = Locked<FEngineInfo?>(nil)
        let done = DispatchSemaphore(value: 0)
        engine.evaluate(2) { info, completed in
            if completed {
                result.value = info
                done.signal()
            }
        }
        #expect(done.wait(seconds: 10))
        let info = try #require(result.value)
        #expect(!info.hasBestMove)

        session.searchDidUpdate(info, completed: true, token: session.positionID)
        #expect(session.fen == position)
        #expect(session.lastMove == nil)
    }

    @Test func pasteFEN() {
        let session = GameSession(state: twoHumans)
        #expect(session.paste(middlegame))
        #expect(session.fen == fen(after: [], from: middlegame))
        #expect(session.gameState.pgn.contains("[FEN"))
    }

    @Test func pastePGN() {
        let session = GameSession(state: twoHumans)
        #expect(session.paste("1. d4 d5 2. c4 *"))
        #expect(session.fen == fen(after: [("d2", "d4"), ("d7", "d5"), ("c2", "c4")]))
        #expect(session.gameState.pgn.contains("1. d4 d5 2. c4"))
    }

    @Test func pasteGarbageIsRejected() {
        let session = GameSession(state: twoHumans)
        play(session, "e2", "e4")
        let state = session.gameState
        let position = session.fen
        let moves = session.game.moves.count

        #expect(!session.paste("this is neither a FEN nor a PGN"))
        #expect(session.fen == position)
        #expect(session.gameState == state)
        #expect(session.game.moves.count == moves)
    }

    @Test func analyzeThenResetRestoresGame() {
        let session = GameSession(state: twoHumans)
        play(session, "e2", "e4")
        let state = session.gameState
        let position = session.fen

        session.toggleAnalyze()
        #expect(session.mode.value == .analyze)
        play(session, "e7", "e5")
        play(session, "g1", "f3")
        #expect(session.gameState == state)

        session.toggleAnalyze()
        #expect(session.mode.value == .play)
        #expect(session.fen == position)
        #expect(session.gameState == state)
    }

    @Test func analyzeResetKeepsTheTextOfAnUnnormalizedGame() {
        let state = GameState(pgn: "1. e4 e5 *", white: .human, black: .human)
        let session = GameSession(state: state)
        session.toggleAnalyze()
        play(session, "g1", "f3")
        session.analyzeReset()
        #expect(session.gameState == state)
    }

    @Test func trainStartsFromInitialPosition() {
        let session = GameSession(state: GameState(pgn: "1. d4 d5 *", white: .human, black: .human))
        let position = session.fen
        let state = session.gameState

        session.toggleTrain()
        #expect(session.mode.value == .train)
        #expect(session.fen == startFEN)
        #expect(session.gameState == state)

        session.toggleTrain()
        #expect(session.mode.value == .play)
        #expect(session.fen == position)
        #expect(session.gameState == state)
    }

    @Test func newGameResets() {
        let session = GameSession(state: twoHumans)
        play(session, "e2", "e4")
        session.select(rank: 6, file: 4)
        #expect(session.lastMove != nil)

        session.newGame(white: computerBlack, black: .human)
        #expect(session.gameState.white == computerBlack)
        #expect(session.gameState.black == .human)
        #expect(session.fen == startFEN)
        #expect(halfMoves(session) == 0)
        #expect(session.selection.possibleMoves.isEmpty)
        #expect(session.lastMove == nil)
        #expect(session.info == nil)
    }

    @Test func everyPositionChangeBumpsPositionID() throws {
        let session = GameSession(state: twoHumans)
        var last = session.positionID
        func expectBump(_ what: String, sourceLocation: SourceLocation = #_sourceLocation, _ change: () -> Void) {
            change()
            #expect(session.positionID > last, "\(what) did not bump the position", sourceLocation: sourceLocation)
            last = session.positionID
        }

        expectBump("play") { play(session, "e2", "e4") }
        expectBump("play") { play(session, "e7", "e5") }
        expectBump("undo") { session.undo() }
        expectBump("redo") { session.redo() }
        expectBump("move(to:)") { session.move(to: .start) }
        let uuid = try #require(session.game.moves.first?.whiteMove?.uuid)
        expectBump("selectMove") { session.selectMove(uuid: uuid) }
        expectBump("selectGame") { session.selectGame(0) }
        expectBump("setPlayers") { session.setPlayers(white: .human, black: .human) }
        expectBump("paste") { _ = session.paste("1. d4 *") }
        expectBump("toggleAnalyze") { session.toggleAnalyze() }
        expectBump("toggleAnalyze back") { session.toggleAnalyze() }
        expectBump("toggleTrain") { session.toggleTrain() }
        expectBump("toggleTrain back") { session.toggleTrain() }
        expectBump("newGame") { session.newGame(white: .human, black: .human) }
        expectBump("load") { session.load(GameState(pgn: "1. c4 *")) }
    }

    @Test func loadReplacesStateAndDropsPendingSearch() async throws {
        let session = GameSession(state: GameState(pgn: pgn(fen: middlegame), white: .human, black: computerBlack))
        session.requestEngineMoveIfNeeded()
        let staleToken = session.positionID

        let state = GameState(pgn: "1. c4 e5 *", rotated: true, white: .human, black: .human)
        session.load(state)
        #expect(session.gameState == state)
        #expect(session.positionID > staleToken)
        #expect(session.fen == fen(after: [("c2", "c4"), ("e7", "e5")]))

        // The search that was pending for the old state never plays
        try await Task.sleep(for: .milliseconds(2500))
        #expect(session.gameState == state)
    }

    @Test func loadDoesNotEchoState() {
        let session = GameSession(state: twoHumans)
        play(session, "e2", "e4")
        let id = session.positionID
        let state = session.gameState

        session.load(state)
        #expect(session.positionID == id)
        #expect(session.gameState == state)
    }

    @Test func playerChangeDropsPendingSearch() async throws {
        let state = GameState(pgn: pgn(fen: middlegame), white: .human, black: computerBlack)
        let session = GameSession(state: state)
        session.requestEngineMoveIfNeeded()

        // Black becomes a human while its search is running
        session.setPlayers(white: .human, black: .human)
        try await Task.sleep(for: .milliseconds(2500))
        #expect(session.fen == fen(after: [], from: middlegame))
        #expect(halfMoves(session) == 0)
    }

    @Test func staleAnimationCompletionDoesNothing() async throws {
        let session = GameSession(state: GameState(pgn: "*", white: .human, black: computerBlack))
        var completion: (@MainActor () -> Void)?
        session.animate = { change, done in
            change()
            completion = done
        }

        play(session, "e2", "e4")
        let afterE4 = session.fen
        session.undo()
        session.redo()
        completion?()

        // A book reply would come at once
        try await Task.sleep(for: .milliseconds(500))
        #expect(session.fen == afterE4)
    }

    @Test func computerVersusComputerContinues() async {
        let computer = GamePlayer(name: "", computer: true, level: 0)
        let session = GameSession(state: GameState(pgn: "*", white: computer, black: computer))
        session.requestEngineMoveIfNeeded()

        // The opening book answers, one move after the other, without any further call
        #expect(await waitUntil { halfMoves(session) >= 3 })

        session.newGame(white: .human, black: .human)
        try? await Task.sleep(for: .milliseconds(500))
        #expect(halfMoves(session) == 0)
    }

    @Test func staleSearchResultIsIgnored() throws {
        let session = GameSession(state: twoHumans)
        let before = session.fen

        let info = try #require(searchResult())
        session.searchDidUpdate(info, completed: true, token: session.positionID - 1)
        #expect(session.fen == before)
        #expect(halfMoves(session) == 0)

        // The current token is applied
        session.searchDidUpdate(info, completed: true, token: session.positionID)
        #expect(halfMoves(session) == 1)
    }

    /// A completed search result for the start position, from an engine of its own.
    private func searchResult() -> FEngineInfo? {
        let engine = FEngine()
        engine.useOpeningBook = false
        let result = Locked<FEngineInfo?>(nil)
        let done = DispatchSemaphore(value: 0)
        engine.evaluate(2) { info, completed in
            if completed {
                result.value = info
                done.signal()
            }
        }
        _ = done.wait(seconds: 10)
        return result.value
    }

    @Test func cancelledSearchNeverPlaysItsMove() async throws {
        let state = GameState(pgn: pgn(fen: middlegame.replacingOccurrences(of: " b ", with: " w ")), white: .human, black: computerBlack)
        let session = GameSession(state: state)
        let before = session.fen

        // White plays, which starts Black's search; then White takes the move back
        play(session, "h2", "h3")
        session.undo()
        try await Task.sleep(for: .milliseconds(2500))
        #expect(session.fen == before)
        #expect(session.lastMove == nil)
        #expect(halfMoves(session) == 1) // the move is still in the game, only the cursor went back
    }

    @Test func engineRepliesFromBook() async {
        let session = GameSession(state: GameState(pgn: "*", white: .human, black: computerBlack))
        play(session, "e2", "e4")
        #expect(await waitUntil { halfMoves(session) >= 2 })
        #expect(session.isWhiteToMove)
    }

    @Test func thinkingTimeFollowsSideToMove() {
        // White human at level 3, black computer at level 0: Black thinks 2 seconds
        let blackComputer = GameSession(state: GameState(pgn: "*", white: GamePlayer(name: "", computer: false, level: 3), black: computerBlack))
        play(blackComputer, "h2", "h3")
        #expect(blackComputer.searchTimeLimit == 2)

        // White computer at level 3, black human at level 0: White thinks 15 seconds
        let whiteComputer = GameSession(state: GameState(pgn: "*", white: GamePlayer(name: "", computer: true, level: 3), black: .human))
        whiteComputer.requestEngineMoveIfNeeded()
        #expect(whiteComputer.searchTimeLimit == 15)
        whiteComputer.setPlayers(white: .human, black: .human)
    }
}
