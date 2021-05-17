//
//  ChessDocument.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var exampleText: UTType {
        UTType(importedAs: "com.example.plain-text")
    }
    static var pgn: UTType {
        UTType(importedAs: "com.apple.chess.pgn")
    }
}

// The state of the game that is saved to the file
struct GameState: Codable {
    let pgn: String
    let rotated: Bool
    let white: GamePlayer? // Optional for backwards compability
    let black: GamePlayer? // Optional for backwards compability
}

// The model of a player
struct GamePlayer: Codable {
    var name: String
    var computer: Bool
    var level: Int
}

// The mode of game
struct GameMode {
    enum Value {
        case play
        case analyze
        case train
    }
    
    // Contains the PGN before the analyze started, so we can restore it
    var pgnBeforeAnalyzing = ""
    
    // The state of the board (see enum above)
    var value: Value = .play
}

// Structure used to hold information about the current variations
// that the user can choose a move from. This is used when the user
// move forward in a game and a choice must be made because more than
// one move is available as the next move.
struct Variations {
    var show = false
    var selectedVariationIndex = 0
    var variations = [FEngineMoveNode]()
}

struct ChessDocument: FileDocument {
    
    static let startPosPGN = "*"
    
    let engine = FEngine()
        
    var pgn: String {
        didSet {
            game.rebuild(engine: engine)
        }
    }
    
    var currentGameIndex: UInt = 0 {
        didSet {
            engine.currentGameIndex = currentGameIndex
            game.rebuild(engine: engine)
        }
    }
    
    var whitePlayer: GamePlayer
    var blackPlayer: GamePlayer

    var rotated = false

    var selection = Selection.empty()
    var lastMove: FEngineMove? = nil
    var info: FEngineInfo? = nil
    var game = Game()
    var variations = Variations()
    
    var mode: GameMode
    
    // This variable is used by any action that needs the engine to move
    // if suitable. For example, after New Game or Edit Game.
    // It is observed in the PiecesView view.
    var engineShouldMove = false
    
    var pieces: [Piece] {
        return PiecesFactory().pieces(forState: engine.state)
    }
    
    init(pgn: String = startPosPGN, white: GamePlayer? = nil, black: GamePlayer? = nil, rotated: Bool = false, mode: GameMode = GameMode(value: .play)) {
        self.pgn = pgn
        self.engine.loadAllGames(pgn)
        self.whitePlayer = white ?? GamePlayer(name: "", computer: false, level: 0)
        self.blackPlayer = black ?? GamePlayer(name: "", computer: true, level: 0)
        self.rotated = rotated
        self.mode = mode

        game.rebuild(engine: engine)
        
        loadOpenings()
    }

    func loadOpenings() {
        engine.useOpeningBook = true
        
        let path = Bundle.main.path(forResource: "Openings", ofType: "pgn")
        assert(path != nil)
        
        let pgn = try! String(contentsOfFile: path!)
        let result = engine.loadOpening(pgn);
        assert(result)
    }
    
    static var readableContentTypes: [UTType] { [.exampleText, .pgn] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        if configuration.contentType == .exampleText {
            let decoder = JSONDecoder()
            let state = try decoder.decode(GameState.self, from: data)

            self.init(pgn: state.pgn, white: state.white, black: state.black, rotated: state.rotated)
        } else if configuration.contentType == .pgn {
            self.init(pgn: String(decoding: data, as: UTF8.self),
                      white: GamePlayer(name: "", computer: false, level: 0),
                      black: GamePlayer(name: "", computer: false, level: 0))
        } else {
            throw CocoaError(.fileReadUnknown)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let pgnToWrite = mode.value != .play ? mode.pgnBeforeAnalyzing : pgn
        switch configuration.contentType {
        case .exampleText:
            let state = GameState(pgn: pgnToWrite, rotated: rotated, white: whitePlayer, black: blackPlayer)
            let encoder = JSONEncoder()
            let data = try encoder.encode(state)
            return .init(regularFileWithContents: data)
        case .pgn:
            if let data = pgnToWrite.data(using: .utf8) {
                return .init(regularFileWithContents: data)
            } else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
        default:
            throw CocoaError(.fileWriteUnsupportedScheme)
        }
    }
    
    func applyEngineSettings() {
        switch engine.isWhite() ? whitePlayer.level : blackPlayer.level {
        case 0:
            engine.thinkingTime = 2
        case 1:
            engine.thinkingTime = 5
        case 2:
            engine.thinkingTime = 10
        case 3:
            engine.thinkingTime = 15
        default:
            engine.thinkingTime = 2
        }

        engine.ttEnabled = UserDefaults.standard.bool(forKey: "useTranspositionTable")
    }
    
}
