//
//  GameShell.swift
//  BChess
//
//  The state of the iOS shell: which library game is open, its session, and the rule that unsaved
//  changes are never lost silently. The view only renders it.
//

import Foundation
import Observation
import UniformTypeIdentifiers

/// The formats a game can be exported in. PGN first: it is what other chess apps read.
enum ExportFormat: CaseIterable, Sendable {
    case pgn
    case bchess

    var contentType: UTType {
        switch self {
        case .pgn: .pgn
        case .bchess: .bchessGame
        }
    }

    var fileExtension: String {
        switch self {
        case .pgn: "pgn"
        case .bchess: "bchess"
        }
    }
}

@MainActor @Observable
final class GameShell {

    let library: GameLibrary
    private(set) var current: GameFile
    private(set) var session: GameSession
    private(set) var saveError: Error?

    /// The state last read from or written to `current`.
    private var savedState: GameState

    init(library: GameLibrary) throws {
        self.library = library
        let file = try library.initialGame()
        let state = try library.open(file)
        current = file
        savedState = state
        session = GameSession(state: state)
    }

    /// Writes the session to the current file when it changed. A failure is kept in `saveError`, and the
    /// edits stay in the session.
    @discardableResult
    func save() -> Bool {
        let state = session.gameState
        if state == savedState {
            saveError = nil
            return true
        }
        do {
            try library.save(state, to: current)
            savedState = state
            saveError = nil
            return true
        } catch {
            saveError = error
            return false
        }
    }

    func dismissSaveError() {
        saveError = nil
    }

    /// Opens another game. Returns false, changing nothing, when the current game cannot be saved and
    /// the changes were not discarded explicitly. Throws, changing nothing, when the target cannot be read.
    @discardableResult
    func open(_ file: GameFile, discardingUnsavedChanges: Bool = false) throws -> Bool {
        guard canLeaveCurrent(discardingUnsavedChanges) else {
            return false
        }
        install(file, state: try library.open(file))
        return true
    }

    /// Creates a game in the library and opens it.
    @discardableResult
    func createGame(white: GamePlayer, black: GamePlayer, rotated: Bool = false, discardingUnsavedChanges: Bool = false) throws -> Bool {
        guard canLeaveCurrent(discardingUnsavedChanges) else {
            return false
        }
        let state = GameState(pgn: "*", rotated: rotated, white: white, black: black)
        install(try library.create(state), state: state)
        return true
    }

    @discardableResult
    func importFile(at url: URL, discardingUnsavedChanges: Bool = false) throws -> Bool {
        guard canLeaveCurrent(discardingUnsavedChanges) else {
            return false
        }
        let file = try library.importFile(at: url)
        install(file, state: try library.open(file))
        return true
    }

    /// Deleting the current game discards its edits, so it is never saved first. The fallback is chosen,
    /// read and installed before the file goes, so a failure leaves everything as it was.
    func delete(_ file: GameFile) throws {
        guard file.url == current.url else {
            try library.delete(file)
            return
        }
        let fallback: GameFile
        let state: GameState
        if let other = library.games.first(where: { $0.url != file.url }) {
            fallback = other
            state = try library.open(other)
        } else {
            state = .newGame
            fallback = try library.create(state)
        }
        install(fallback, state: state)
        try library.delete(file)
    }

    enum ExportError: LocalizedError {
        case libraryFolder

        var errorDescription: String? {
            String(localized: "Choose a folder outside BChess's own games: exporting there would list every game twice.")
        }
    }

    /// The bytes of a library game in a format. The open game is exported as the session shows it, saved
    /// or not; any other game is read from its file. Never saves, never touches the library.
    func exportData(of file: GameFile, as format: ExportFormat) throws -> Data {
        let state = file.url == current.url ? session.gameState : try library.open(file)
        return try state.data(for: format.contentType)
    }

    /// Writes every game of the library as its own file into `folder`, never replacing a file there
    /// (`Game.pgn`, then `Game 2.pgn`). Every game is read before the first is written; the writes run
    /// off the main actor. Files written before a write error stay. Refuses the library's own folder.
    func exportAll(to folder: URL, as format: ExportFormat,
                   beforeWrite: @Sendable (URL) throws -> Void = { _ in }) async throws -> [URL] {
        func resolved(_ url: URL) -> String {
            url.standardizedFileURL.resolvingSymlinksInPath().path
        }
        guard resolved(folder) != resolved(library.directory) else {
            throw ExportError.libraryFolder
        }
        let files = try library.games.map { ExportFile(baseName: $0.title, data: try exportData(of: $0, as: format)) }
        return try await GameLibrary.writeExports(files, to: folder, extension: format.fileExtension, beforeWrite: beforeWrite)
    }

    // The current game is saved first, whether or not the view's autosave has run yet
    private func canLeaveCurrent(_ discardingUnsavedChanges: Bool) -> Bool {
        save() || discardingUnsavedChanges
    }

    private func install(_ file: GameFile, state: GameState) {
        session.cancelSearch()
        current = file
        savedState = state
        session = GameSession(state: state)
        saveError = nil
        library.lastOpenedName = file.name
    }
}
