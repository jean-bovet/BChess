//
//  BChessUIDocument.swift
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

struct BChessUIDocument: FileDocument {
    
    let engine = FEngine()
        
    var pgn: String

    var selection = Selection(position: Position.empty(), possibleMoves: [])
    // TODO: save?
    var lastMove: FEngineMove? = nil
    var info: FEngineInfo? = nil
    // TODO: save
    var level: Int = 0
    var playAgainst: PlayAgainst = .black

    var pieces: [Piece] {
        return PiecesFactory().pieces(forState: engine.state)
    }
    
    init(pgn: String = StartPosFEN, playAgainst: PlayAgainst = .black) {
        self.pgn = pgn
        self.engine.setPGN(pgn)
        self.playAgainst = playAgainst
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
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.init(pgn: string)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = pgn.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
    
    func applyLevelSettings() {
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
    }
    
}
