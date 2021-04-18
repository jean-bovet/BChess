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
    let level: Int
    let playAgainst: Int
    let rotated: Bool
}

struct ChessDocument: FileDocument {
    
    let engine = FEngine()
        
    var pgn: String
    var playAgainst: PlayAgainst = .black
    var level: Int = 0
    var rotated = false

    var selection = Selection(position: Position.empty(), possibleMoves: [])
    var lastMove: FEngineMove? = nil
    var info: FEngineInfo? = nil

    var pieces: [Piece] {
        return PiecesFactory().pieces(forState: engine.state)
    }
    
    init(pgn: String = StartPosFEN, playAgainst: PlayAgainst = .black, level: Int = 0, rotate: Bool = false) {
        self.pgn = pgn
        self.engine.setPGN(pgn)
        self.playAgainst = playAgainst
        self.level = level
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

        self.init(pgn: state.pgn, playAgainst: PlayAgainst(rawValue: state.playAgainst) ?? .black, level: state.level, rotate: state.rotated)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let state = GameState(pgn: pgn, level: level, playAgainst: playAgainst.rawValue, rotated: rotated)
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        return .init(regularFileWithContents: data)
    }
    
    func applyEngineSettings() {
        switch level {
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
