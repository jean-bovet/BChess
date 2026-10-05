//
//  GameSession.swift
//  BChess
//
//  The runtime half of a game: the engine, the selection, the move list, the analysis mode and the
//  search. It publishes the persisted `GameState` and reads external changes through `load(_:)`.
//

import Foundation
import Observation

// The mode of game
struct GameMode {
    enum Value {
        case play
        case analyze
        case train
    }

    // Contains the PGN before the analyze started, so we can restore it
    var pgnBeforeAnalyzing = ""

    // The index of the game that was shown before the analyze started
    var gameIndexBeforeAnalyzing = 0

    // The state of the board (see enum above)
    var value: Value = .play
}

// Structure used to hold information about the current variations
// that the user can choose a move from. This is used when the user
// move forward in a game and a choice must be made because more than
// one move is available as the next move.
struct Variations {
    var show = false {
        didSet {
            selectedVariationIndex = 0
        }
    }
    var selectedVariationIndex = 0
    var variations = [FEngineMoveNode]()
}

extension GamePlayer {
    /// The time the engine thinks when it plays this player's side.
    var thinkingTime: TimeInterval {
        switch level {
        case 0: return 2
        case 1: return 5
        case 2: return 10
        case 3: return 15
        default: return 2
        }
    }
}

@MainActor @Observable
final class GameSession {

    private static let openingsPGN: String = {
        let url = Bundle(for: GameSession.self).url(forResource: "Openings", withExtension: "pgn")
        return url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }()

    private let engine = FEngine()

    /// The persisted value. It changes only with the content of the game: moves, new game, paste,
    /// players and rotation. Selection, navigation and analysis never change it.
    private(set) var gameState: GameState

    var selection = Selection.empty()
    var lastMove: FEngineMove?
    var info: FEngineInfo?
    var variations = Variations()
    var mode = GameMode()
    private(set) var game = Game()

    /// Bumped on every change to the engine, so that views reading engine-derived values refresh.
    private(set) var revision = 0

    /// Identifies the position that a search result may be played on. Bumped on every change to the
    /// position, the players or the mode: a result computed for an earlier value is dropped.
    private(set) var positionID = 0

    /// Runs a state change with the animation of its time, and calls `completion` when that animation
    /// has finished. The default runs both at once; the views install the SwiftUI animation.
    @ObservationIgnored
    var animate: @MainActor (_ change: () -> Void, _ completion: @escaping @MainActor () -> Void) -> Void = { change, completion in
        change()
        completion()
    }

    init(state: GameState = .newGame, mode: GameMode = GameMode()) {
        gameState = state
        self.mode = mode
        engine.useOpeningBook = true
        _ = engine.loadOpening(Self.openingsPGN)
        if !engine.loadAllGames(state.pgn) {
            _ = engine.loadAllGames("*")
        }
        game.rebuild(engine: engine)
    }

    // MARK: Engine-derived values

    var pieces: [Piece] {
        _ = revision
        return PiecesFactory().pieces(forState: engine.state)
    }

    var isWhiteToMove: Bool {
        _ = revision
        return engine.isWhite()
    }

    func canMove(to direction: Direction) -> Bool {
        _ = revision
        return engine.canMove(to: direction)
    }

    var openingName: String? {
        _ = revision
        return engine.openingName()
    }

    var isValidOpeningMoves: Bool {
        _ = revision
        return engine.isValidOpeningMoves()
    }

    var games: [FEngineGame] {
        _ = revision
        return engine.games
    }

    var currentGameIndex: Int {
        _ = revision
        return Int(engine.currentGameIndex)
    }

    var currentMoveUUID: UInt {
        _ = revision
        return engine.currentMoveNodeUUID
    }

    var fen: String {
        _ = revision
        return engine.fen()
    }

    var pgnCurrentGame: String {
        _ = revision
        return engine.getPGNCurrentGame()
    }

    /// The time limit that the next search of the engine will use.
    var searchTimeLimit: TimeInterval {
        engine.thinkingTime
    }

    func capturedPieces(white: Bool) -> [String] {
        _ = revision
        return engine.allMoves()
            .filter { $0.isCapture }
            .filter { $0.isWhite == white }
            .compactMap { $0.capturedPiece as String? }
            .sorted()
    }

    func materialPoints(white: Bool) -> String? {
        _ = revision
        let captures = engine.allMoves()
            .filter { $0.isCapture }
        var points = 0
        for move in captures {
            switch move.capturedPiece {
            case "P":
                points += 1
            case "p":
                points -= 1
            case "N", "B":
                points += 3
            case "n", "b":
                points -= 3
            case "R":
                points += 5
            case "r":
                points -= 5
            case "Q":
                points += 9
            case "q":
                points -= 9
            default:
                break
            }
        }

        if white && points < 0 {
            return "+\(abs(points))"
        }
        if !white && points > 0 {
            return "+\(abs(points))"
        }

        return nil
    }

    // MARK: Funnels

    /// Any change to the position, the players or the mode: the pending search is dropped.
    private func invalidate() {
        positionID += 1
        engine.cancel()
        revision += 1
    }

    /// A change to the content of the game: persist it and rebuild the move list.
    private func contentDidChange() {
        invalidate()
        gameState.pgn = mode.value == .play ? engine.pgnAllGames() : mode.pgnBeforeAnalyzing
        game.rebuild(engine: engine)
    }

    // MARK: Actions

    /// Drops any pending search; used when the session is replaced.
    func cancelSearch() {
        invalidate()
    }

    func rotate() {
        gameState.rotated.toggle()
    }

    /// Replaces the game with a value that was changed outside of the session (File ▸ Revert, Undo).
    func load(_ state: GameState) {
        guard state != gameState, engine.loadAllGames(state.pgn) else {
            return
        }
        gameState = state
        mode = GameMode()
        selection = Selection.empty()
        lastMove = nil
        info = nil
        variations = Variations()
        game.rebuild(engine: engine)
        invalidate()
    }

    func select(rank: Int, file: Int) {
        selection = Selection(position: Position(rank: rank, file: file),
                              possibleMoves: engine.moves(at: UInt(rank), file: UInt(file)))
    }

    func undo() {
        guard engine.canMove(to: .backward) else {
            return
        }
        clearSelection()
        engine.move(to: .backward, variation: 0)
        invalidate()
    }

    func redo() {
        guard engine.canMove(to: .forward) else {
            return
        }
        clearSelection()
        // Along the current line, which may be a variation
        engine.move(to: .forward, variation: engine.nextVariation())
        invalidate()
    }

    func move(to direction: Direction) {
        guard engine.canMove(to: direction) else {
            return
        }
        let choice = variations.show ? variations.selectedVariationIndex : nil
        clearSelection()

        if direction == .forward {
            let choices = engine.nextMoveChoices()
            if let choice, choice < choices.count {
                // The user chose one of the moves that were offered
                engine.move(to: .forward, variation: UInt(choice))
            } else if choices.count > 1 {
                // More than one move can follow this position: let the user pick one
                variations.show = true
                variations.variations = choices
            } else {
                engine.move(to: .forward, variation: engine.nextVariation())
            }
        } else {
            // Going back or to an end never asks: it follows the current line
            engine.move(to: direction, variation: 0)
        }
        invalidate()
    }

    func chooseVariation(_ index: Int) {
        variations.selectedVariationIndex = index
        move(to: .forward)
    }

    func selectMove(uuid: UInt) {
        engine.currentMoveNodeUUID = uuid
        selection = Selection.empty()
        variations.show = false
        invalidate()
    }

    func selectGame(_ index: Int) {
        engine.currentGameIndex = UInt(index)
        clearSelection()
        game.rebuild(engine: engine)
        invalidate()
    }

    func setPlayers(white: GamePlayer, black: GamePlayer) {
        gameState.white = white
        gameState.black = black
        invalidate()
    }

    func newGame(white: GamePlayer, black: GamePlayer) {
        gameState.white = white
        gameState.black = black
        mode = GameMode()
        engine.setFEN(StartPosFEN)
        info = nil
        clearSelection()
        variations = Variations()
        contentDidChange()
    }

    /// Replaces the current game with a FEN or PGN text. A text that does not parse leaves the game
    /// untouched: it is tried on a throwaway engine first.
    func paste(_ text: String) -> Bool {
        let probe = FEngine()
        if probe.setFEN(text) {
            engine.setFEN(text)
        } else if probe.setPGN(text) {
            engine.setPGN(text)
        } else {
            return false
        }
        clearSelection()
        variations = Variations()
        contentDidChange()
        return true
    }

    func toggleAnalyze() {
        changeMode(to: .analyze)
    }

    func toggleTrain() {
        changeMode(to: .train)
    }

    private func changeMode(to value: GameMode.Value) {
        if mode.value == .play {
            mode.value = value
            mode.pgnBeforeAnalyzing = gameState.pgn
            mode.gameIndexBeforeAnalyzing = currentGameIndex
            if value == .train {
                engine.setFEN(StartPosFEN)
                contentDidChange()
            } else {
                invalidate()
            }
        } else {
            mode.value = .play
            analyzeReset()
        }
    }

    /// Restores the game as it was before the analysis or the practice started.
    func analyzeReset() {
        clearSelection()
        variations = Variations()
        if engine.loadAllGames(mode.pgnBeforeAnalyzing) {
            engine.currentGameIndex = UInt(min(mode.gameIndexBeforeAnalyzing, engine.games.count - 1))
        }
        invalidate()
        // The text as it was, not re-serialized: leaving the analysis must not dirty the document
        gameState.pgn = mode.pgnBeforeAnalyzing
        game.rebuild(engine: engine)
    }

    private func clearSelection() {
        selection = Selection.empty()
        lastMove = nil
        // Offered moves are only valid for the position they were offered at
        variations = Variations()
    }

    // MARK: Playing

    /// A move made by a human, from the board or the promotion sheet. The engine replies, if it plays
    /// the side to move, once the move animation has completed.
    func playHuman(_ move: FEngineMove) {
        perform(animated: {
            self.play(rawMove: move.rawMoveValue, lastMove: move, info: nil)
        }, then: {
            self.requestEngineMoveIfNeeded()
        })
    }

    private func play(rawMove: UInt, lastMove: FEngineMove?, info: FEngineInfo?) {
        selection = Selection.empty()
        self.lastMove = lastMove
        if let info {
            self.info = info
        }
        engine.move(rawMove)
        contentDidChange()
    }

    /// Runs `change` animated, then `next` when the animation has completed, unless the position has
    /// changed in the meantime (undo, new game, players edited...).
    private func perform(animated change: @escaping @MainActor () -> Void, then next: @escaping @MainActor () -> Void) {
        var token = positionID
        animate({
            change()
            token = self.positionID
        }, {
            if self.positionID == token {
                next()
            }
        })
    }

    /// Starts a search if the side to move is a computer and the game can be played.
    func requestEngineMoveIfNeeded() {
        // Don't play the engine while the user is analyzing the board
        guard mode.value == .play else {
            return
        }

        // Only play the computer if the current color matches a player who is a computer
        let white = engine.isWhite()
        let player = white ? gameState.white : gameState.black
        guard player.computer else {
            return
        }

        // Ensure the engine internal state allows it to play
        guard engine.canPlay() else {
            return
        }

        engine.thinkingTime = player.thinkingTime
        engine.ttEnabled = UserDefaults.standard.bool(forKey: "useTranspositionTable")

        // The search runs off the main thread; its result is applied only if it is still for this position
        let token = positionID
        engine.evaluate { [weak self] info, completed in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.searchDidUpdate(info, completed: completed, token: token)
                }
            }
        }
    }

    /// The authority for I2 in the app: a result applies only to the position it was computed for.
    func searchDidUpdate(_ info: FEngineInfo, completed: Bool, token: Int) {
        guard token == positionID else {
            return
        }
        if completed {
            // A search that found no move (the position is over) plays nothing
            guard info.hasBestMove else {
                return
            }
            perform(animated: {
                self.play(rawMove: info.bestMove, lastMove: info.bestEngineMove, info: info)
            }, then: {
                self.requestEngineMoveIfNeeded()
            })
        } else {
            self.info = info
        }
    }
}
