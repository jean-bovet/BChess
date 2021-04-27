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

struct ChessDocument: FileDocument {
    
    static let startPosPGN = "*"
    
    let engine = FEngine()
        
    var pgn: String
    var whitePlayer: GamePlayer
    var blackPlayer: GamePlayer

    var rotated = false

    var selection = Selection.empty()
    var lastMove: FEngineMove? = nil
    var info: FEngineInfo? = nil
    
    // Contains the PGN before the analyze started, so we can restore it
    var pgnBeforeAnalyzing = ""
    // True when the user is manually analyzing the game
    var analyzing = false

    // This variable is used by any action that needs the engine to move
    // if suitable. For example, after New Game or Edit Game.
    // If is observed in the PiecesView view.
    var engineShouldMove = false
    
    var pieces: [Piece] {
        return PiecesFactory().pieces(forState: engine.state)
    }
    
    init(pgn: String = startPosPGN, white: GamePlayer? = nil, black: GamePlayer? = nil, rotated: Bool = false) {
        self.pgn = pgn
        self.engine.setPGN(pgn)
        self.whitePlayer = white ?? GamePlayer(name: "", computer: false, level: 0)
        self.blackPlayer = black ?? GamePlayer(name: "", computer: true, level: 0)
        self.rotated = rotated
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
    
    static var readableContentTypes: [UTType] { [.exampleText] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        let state = try decoder.decode(GameState.self, from: data)

        self.init(pgn: state.pgn, white: state.white, black: state.black, rotated: state.rotated)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // If analyzing, don't save the pgn but rather the savedPGN which is the PGN before the analyze started
        let actualPGN = analyzing ? pgnBeforeAnalyzing : pgn
        let state = GameState(pgn: actualPGN, rotated: rotated, white: whitePlayer, black: blackPlayer)
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        return .init(regularFileWithContents: data)
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
