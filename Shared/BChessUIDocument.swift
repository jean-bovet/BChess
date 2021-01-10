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

struct BChessEngineFactory {
    static let engine = FEngine()

}

struct BChessUIDocument: FileDocument {
    
    let engine = FEngine()
    
    var pgn: String

    var pieces: [Piece] {
        return PiecesFactory().pieces(forState: engine.state)
    }
    
    init(pgn: String = BChessEngineFactory.engine.pgn()) {
        self.pgn = pgn
        self.engine.thinkingTime = 2
        self.engine.setPGN(pgn)
    }

    static var readableContentTypes: [UTType] { [.exampleText] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        pgn = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = pgn.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
