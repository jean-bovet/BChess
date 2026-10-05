//
//  ChessDocument.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// The macOS document: a pure value. The runtime state lives in `GameSession`, which `DocumentWindow`
/// keeps in sync with this value.
struct ChessDocument: FileDocument {

    var state: GameState

    init(state: GameState = .newGame) {
        self.state = state
    }

    static var readableContentTypes: [UTType] { [.bchessGame, .json, .pgn] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        state = try GameState(data: data, contentType: configuration.contentType)
    }

    // Writes the format the document was opened as
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: try state.data(for: configuration.contentType))
    }
}
