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
        #expect(engine.move(uci: from + to))
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

/// Counts the moves that the engine's search pushes, through the test hook: proof that a search runs.
private final class SearchProbe: @unchecked Sendable {
    private let condition = NSCondition()
    private var moves = 0
    private var holding = false

    var count: Int {
        condition.withLock { moves }
    }

    init(_ engine: FEngine) {
        engine.setSearchCheckpoint { [self] in
            condition.lock()
            moves += 1
            while holding {
                condition.wait()
            }
            condition.unlock()
        }
    }

    /// Parks every search at its next checkpoint, so none can report until `release()`.
    func hold() {
        condition.withLock { holding = true }
    }

    func release() {
        condition.lock()
        holding = false
        condition.broadcast()
        condition.unlock()
    }
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
        session.move(to: .backward)
        session.move(to: .forward)
        session.move(to: .start)
        session.move(to: .end)
        session.toggleAnalyze()
        #expect(session.gameState == before)
    }

    @Test func navigationKeepsUnnormalizedPGN() throws {
        let legacy = Data(#"{"pgn":"1. e4 e5 *","rotated":false}"#.utf8)
        let state = try GameState(data: legacy, contentType: .json)
        let session = GameSession(state: state)

        session.move(to: .backward)
        session.move(to: .start)
        let uuid = try #require(session.game.rows.first?.white?.uuid)
        session.selectMove(uuid: uuid)
        #expect(session.gameState == state)
    }

    @Test func selectMoveRebuildsPosition() throws {
        let session = GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 *", white: .human, black: .human))
        let uuid = try #require(session.game.rows.first?.white?.uuid)
        session.selectMove(uuid: uuid)

        #expect(session.fen == fen(after: [("e2", "e4")]))
        #expect(!session.isWhiteToMove)
        #expect(session.canMove(to: .forward))
        #expect(session.canMove(to: .backward))
    }

    @Test func backAndForward() {
        let session = GameSession(state: twoHumans)
        play(session, "e2", "e4")
        play(session, "e7", "e5")
        let pgn = session.gameState.pgn

        session.move(to: .backward)
        #expect(session.fen == fen(after: [("e2", "e4")]))
        #expect(session.canMove(to: .forward))
        #expect(session.gameState.pgn == pgn)

        session.move(to: .forward)
        #expect(session.fen == fen(after: [("e2", "e4"), ("e7", "e5")]))
        #expect(session.gameState.pgn == pgn)
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
        // A stalemate: the engine finds no move. (A drawn-by-rule root is searched like any other since ENGINE-3
        // search step 2, so a repetition no longer gives an empty result.)
        let stalemate = "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"
        let session = GameSession(state: GameState(pgn: pgn(fen: stalemate), white: .human, black: .human))
        let position = session.fen

        let engine = FEngine()
        engine.useOpeningBook = false
        engine.setFEN(stalemate)
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
        let moves = session.game.rows.count

        #expect(!session.paste("this is neither a FEN nor a PGN"))
        #expect(session.fen == position)
        #expect(session.gameState == state)
        #expect(session.game.rows.count == moves)
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

    @Test func everyPositionChangeBumpsPositionID() throws {
        let session = GameSession(state: twoHumans)
        session.showsEngine = true
        defer { session.cancelSearch() }
        var last = session.positionID
        var lastAnalysis = session.analysisID
        func expectBump(_ what: String, sourceLocation: SourceLocation = #_sourceLocation, _ change: () -> Void) {
            change()
            #expect(session.positionID > last, "\(what) did not bump the position", sourceLocation: sourceLocation)
            last = session.positionID
            // The readout belongs to the new position: cleared, and a new analysis runs
            #expect(session.info == nil, "\(what) kept the readout of the old position", sourceLocation: sourceLocation)
            #expect(session.isAnalyzing, "\(what) did not analyze the new position", sourceLocation: sourceLocation)
            #expect(session.analysisID > lastAnalysis, "\(what) reused an analysis", sourceLocation: sourceLocation)
            lastAnalysis = session.analysisID
        }

        expectBump("play") { play(session, "e2", "e4") }
        expectBump("play") { play(session, "e7", "e5") }
        expectBump("back") { session.move(to: .backward) }
        expectBump("forward") { session.move(to: .forward) }
        expectBump("move(to:)") { session.move(to: .start) }
        let uuid = try #require(session.game.rows.first?.white?.uuid)
        expectBump("selectMove") { session.selectMove(uuid: uuid) }
        expectBump("selectGame") { session.selectGame(0) }
        expectBump("setPlayers") { session.setPlayers(white: .human, black: .human) }
        expectBump("paste") { _ = session.paste("1. d4 *") }
        expectBump("toggleAnalyze") { session.toggleAnalyze() }
        expectBump("toggleAnalyze back") { session.toggleAnalyze() }
        expectBump("toggleTrain") { session.toggleTrain() }
        expectBump("toggleTrain back") { session.toggleTrain() }
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
        session.move(to: .backward)
        session.move(to: .forward)
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

        // Making both players human stops the game
        session.setPlayers(white: .human, black: .human)
        let stopped = halfMoves(session)
        try? await Task.sleep(for: .milliseconds(500))
        #expect(halfMoves(session) == stopped)
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

    // MARK: Analysis of the position on screen

    /// A White-to-move middlegame as a game with one move, so that Black is to move and one step back exists.
    private func blackToMoveAfterAMove(white: GamePlayer = .human, black: GamePlayer = .human) -> GameSession {
        let state = GameState(pgn: pgn(fen: middlegame.replacingOccurrences(of: " b ", with: " w ")), white: white, black: black)
        let session = GameSession(state: state)
        play(session, "h2", "h3")
        return session
    }

    @Test func analysisRunsOnAHumanTurnWhenShown() async {
        let session = GameSession(state: twoHumans)
        defer { session.cancelSearch() }
        #expect(!session.isAnalyzing)

        session.showsEngine = true
        #expect(session.isAnalyzing)
        #expect(await waitUntil { session.info != nil })
        // Not a book move: a real search with a depth
        #expect((session.info?.depth ?? 0) > 0)
        #expect(session.fen == startFEN)
        #expect(halfMoves(session) == 0)
    }

    @Test func analysisNeverPlaysAMove() throws {
        let session = GameSession(state: twoHumans)
        session.showsEngine = true
        let info = try #require(searchResult())
        #expect(info.hasBestMove)

        session.analysisDidUpdate(info, completed: true, token: session.analysisID)
        #expect(halfMoves(session) == 0)
        #expect(session.fen == startFEN)
        #expect(!session.isAnalyzing)
        #expect(session.info === info)
    }

    @Test func staleAnalysisIsIgnored() throws {
        let session = GameSession(state: twoHumans)
        defer { session.cancelSearch() }
        session.showsEngine = true
        let info = try #require(searchResult())

        // The position changes: the old token no longer applies
        let old = session.analysisID
        play(session, "e2", "e4")
        session.analysisDidUpdate(info, completed: false, token: old)
        #expect(session.info !== info)
        session.analysisDidUpdate(info, completed: true, token: old)
        #expect(session.info !== info)
        #expect(session.isAnalyzing)

        // The same position analyzed a second time gets a new token
        let first = session.analysisID
        session.showsEngine = false
        session.showsEngine = true
        #expect(session.analysisID > first)
        session.analysisDidUpdate(info, completed: true, token: first)
        #expect(session.info !== info)
        #expect(session.isAnalyzing)
    }

    @Test func staleAnalysisIsIgnoredAcrossAModeChange() throws {
        let session = GameSession(state: twoHumans)
        defer { session.cancelSearch() }
        session.showsEngine = true
        let oldID = session.analysisID
        let info = try #require(searchResult())

        // Same position, same side to move, new analysis
        session.toggleAnalyze()
        #expect(session.analysisID > oldID)
        #expect(session.isAnalyzing)

        session.analysisDidUpdate(info, completed: false, token: oldID)
        #expect(session.info !== info)
        session.analysisDidUpdate(info, completed: true, token: oldID)
        #expect(session.info !== info)
        #expect(session.isAnalyzing)
    }

    @Test func hidingTheEngineKeepsTheComputersMove() async {
        let session = GameSession(state: GameState(pgn: pgn(fen: middlegame), white: .human, black: computerBlack))
        session.showsEngine = true
        #expect(session.isAnalyzing)

        session.requestEngineMoveIfNeeded()
        #expect(session.isThinking)
        #expect(!session.isAnalyzing)
        session.showsEngine = false

        #expect(await waitUntil(4) { halfMoves(session) >= 1 })
    }

    @Test func hidingTheEngineStopsAnAnalysis() async {
        let session = GameSession(state: twoHumans)
        defer { session.cancelSearch() }
        let probe = SearchProbe(session.engine)
        session.showsEngine = true
        #expect(session.isAnalyzing)
        #expect(await waitUntil { probe.count > 0 })

        session.showsEngine = false
        #expect(!session.isAnalyzing)
        // The search itself stops: it pushes no more moves
        try? await Task.sleep(for: .milliseconds(200))
        let settled = probe.count
        try? await Task.sleep(for: .milliseconds(300))
        #expect(probe.count == settled, "the search kept running after the engine was hidden")
    }

    @Test func backToAComputerTurnIsAnalyzed() async {
        for shownFromTheStart in [false, true] {
            let session = GameSession(state: GameState(pgn: "*", white: .human, black: computerBlack))
            defer { session.cancelSearch() }
            session.showsEngine = shownFromTheStart
            play(session, "e2", "e4")
            #expect(await waitUntil { halfMoves(session) >= 2 })

            // Black, a computer, is to move again, but nobody is about to play it
            session.move(to: .backward)
            #expect(!session.isWhiteToMove)
            session.showsEngine = true
            #expect(!session.isThinking)
            #expect(session.isAnalyzing)
            #expect(await waitUntil { session.info != nil })
        }
    }

    /// After `change`, the readout must never show a result computed for the position before it.
    private func expectNoStaleReadout(_ session: GameSession, change: () -> Void,
                                      sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await waitUntil { session.info != nil }, sourceLocation: sourceLocation)
        #expect(session.info?.isWhite == false, sourceLocation: sourceLocation)
        let id = session.analysisID

        change()
        #expect(session.analysisID > id, sourceLocation: sourceLocation)
        #expect(session.isWhiteToMove, sourceLocation: sourceLocation)
        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            if let info = session.info {
                #expect(info.isWhite == session.isWhiteToMove, "a result for the other side landed", sourceLocation: sourceLocation)
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func realAnalysisIsDroppedOnPositionChange() async {
        let back = blackToMoveAfterAMove()
        defer { back.cancelSearch() }
        back.showsEngine = true
        await expectNoStaleReadout(back) { back.move(to: .backward) }

        let pasted = blackToMoveAfterAMove()
        defer { pasted.cancelSearch() }
        pasted.showsEngine = true
        let whiteToMove = middlegame.replacingOccurrences(of: " b ", with: " w ")
        await expectNoStaleReadout(pasted) { _ = pasted.paste(whiteToMove) }
    }

    @Test func noAnalysisWhileTheComputerIsToPlay() async {
        let session = GameSession(state: GameState(pgn: "*", white: .human, black: computerBlack))
        defer { session.cancelSearch() }
        var completion: (@MainActor () -> Void)?
        session.animate = { change, done in
            change()
            completion = done
        }
        session.showsEngine = true
        #expect(session.isAnalyzing)

        // The move animation runs and the computer is about to reply
        play(session, "e2", "e4")
        #expect(session.isThinking)
        #expect(!session.isAnalyzing)

        completion?()
        #expect(await waitUntil { halfMoves(session) >= 2 })
        #expect(!session.isThinking)
        #expect(session.isAnalyzing)
    }

    @Test func noAnalysisWhenTheGameIsOver() async throws {
        let session = GameSession(state: GameState(pgn: "1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8 *", white: .human, black: .human))
        #expect(session.gameEnd == .repetition)
        session.showsEngine = true
        #expect(!session.isAnalyzing)
        try await Task.sleep(for: .milliseconds(300))
        #expect(session.info == nil)
    }

    @Test func cancelSearchStartsNothing() async throws {
        let session = GameSession(state: twoHumans)
        session.showsEngine = true
        #expect(session.isAnalyzing)

        session.cancelSearch()
        #expect(!session.isAnalyzing)
        try await Task.sleep(for: .milliseconds(500))
        #expect(!session.isAnalyzing)
    }

    @Test(.timeLimit(.minutes(1)))
    func analysisStopsAtItsTimeLimit() async {
        #expect(GameSession.analysisTime == 10)
        #expect(GameSession().analysisBudget == GameSession.analysisTime)

        // The budget that the session holds is the one that reaches the search
        let session = GameSession(state: twoHumans)
        session.analysisBudget = 3
        session.showsEngine = true
        try? await Task.sleep(for: .milliseconds(1500))
        #expect(session.isAnalyzing, "the search stopped long before its budget")
        #expect(await waitUntil(8) { !session.isAnalyzing })
        // The last result stays on screen
        #expect(session.info != nil)
    }

    @Test func aStaleCallbackQueuedBeforeAChangeIsRejected() async {
        let session = blackToMoveAfterAMove()
        defer { session.cancelSearch() }
        let probe = SearchProbe(session.engine)
        defer { probe.release() }
        session.showsEngine = true

        // Without yielding to the main queue, so that the callbacks of the search pile up behind us:
        // the search has gone well past its first depth, whose callback is then queued
        while probe.count < 5_000 {
            usleep(1_000)
        }
        // From here no search can report: the old one stops at its next checkpoint while unwinding,
        // and the new one waits behind it on the search queue. Only the callbacks already queued
        // can reach the main queue.
        probe.hold()
        let id = session.analysisID
        session.move(to: .backward)
        #expect(session.analysisID > id)
        #expect(session.isWhiteToMove)

        // The main queue now runs the queued callbacks of the old analysis (Black to move) and then
        // this continuation
        await Task.yield()
        #expect(session.info == nil, "a result for the old position landed")
    }

    @Test func theBoardAppearingAgainDoesNotStartTheComputer() async throws {
        let session = GameSession(state: GameState(pgn: "*", white: .human, black: computerBlack))
        defer { session.cancelSearch() }
        session.startIfNeeded()
        play(session, "e2", "e4")
        #expect(await waitUntil { halfMoves(session) >= 2 })
        // Back to Black's turn, which the computer plays but not from here
        session.move(to: .backward)
        #expect(!session.isWhiteToMove)
        let count = halfMoves(session)

        // A layout change recreates the board, which asks to start the game again
        session.startIfNeeded()
        #expect(!session.isThinking)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!session.isThinking)
        #expect(halfMoves(session) == count)
    }

    @Test func theComputerPlaysTheGameItOpensOn() async {
        let state = GameState(pgn: pgn(fen: middlegame), white: .human, black: computerBlack)
        let session = GameSession(state: state)
        defer { session.cancelSearch() }
        session.startIfNeeded()
        #expect(session.isThinking)
        #expect(await waitUntil { halfMoves(session) >= 1 })
    }

    @Test func cancelledSearchNeverPlaysItsMove() async throws {
        let state = GameState(pgn: pgn(fen: middlegame.replacingOccurrences(of: " b ", with: " w ")), white: .human, black: computerBlack)
        let session = GameSession(state: state)
        let before = session.fen

        // White plays, which starts Black's search; then White takes the move back
        play(session, "h2", "h3")
        session.move(to: .backward)
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
