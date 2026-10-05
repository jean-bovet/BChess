//
//  GameLibrary.swift
//  BChess
//
//  The games that the iOS app lists: the files of one directory, in any of the formats BChess reads.
//

import Foundation
import Observation
import UniformTypeIdentifiers

/// A game file of the library.
struct GameFile: Identifiable, Hashable, Sendable {
    let url: URL
    var modified: Date

    // A file is identified by where it is, not by when it was last written
    static func == (lhs: GameFile, rhs: GameFile) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }

    var id: URL { url }
    var name: String { url.lastPathComponent }
    /// The name without its extension, for display.
    var title: String { url.deletingPathExtension().lastPathComponent }
}

@MainActor @Observable
final class GameLibrary {

    private static let extensions: [String: UTType] = ["bchess": .bchessGame, "json": .json, "pgn": .pgn]
    private static let lastOpenedKey = "lastOpenedGame"

    /// The app's Documents folder: visible in Files, and where the document-based app saved its games.
    static var documents: GameLibrary {
        GameLibrary(directory: URL.documentsDirectory)
    }

    let directory: URL
    private(set) var games: [GameFile] = []

    @ObservationIgnored private let defaults: UserDefaults

    init(directory: URL, defaults: UserDefaults = .standard) {
        self.directory = directory
        self.defaults = defaults
        reload()
    }

    var lastOpenedName: String? {
        get { defaults.string(forKey: Self.lastOpenedKey) }
        set { defaults.set(newValue, forKey: Self.lastOpenedKey) }
    }

    private static func contentType(of url: URL) -> UTType? {
        extensions[url.pathExtension.lowercased()]
    }

    /// Lists the readable games, newest first. A file that does not decode is skipped, not deleted.
    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                 includingPropertiesForKeys: [.contentModificationDateKey],
                                                                 options: [.skipsHiddenFiles])) ?? []
        games = urls
            .filter { Self.contentType(of: $0) != nil }
            .map { GameFile(url: $0, modified: (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
            .filter { (try? open($0)) != nil }
            .sorted { $0.modified > $1.modified }
    }

    func open(_ file: GameFile) throws -> GameState {
        guard let type = Self.contentType(of: file.url) else {
            throw CocoaError(.fileReadUnknown)
        }
        return try GameState(data: Data(contentsOf: file.url), contentType: type)
    }

    /// Writes atomically, in the file's own format: `.json` stays `GameState` JSON, `.pgn` stays PGN.
    func save(_ state: GameState, to file: GameFile) throws {
        guard let type = Self.contentType(of: file.url) else {
            throw CocoaError(.fileWriteUnsupportedScheme)
        }
        try state.data(for: type).write(to: file.url, options: .atomic)
        // Only this file changed: refresh its date and place, without validating every game again
        // (URL resource values are cached per URL object, so ask the file manager)
        let modified = (try? FileManager.default.attributesOfItem(atPath: file.url.path)[.modificationDate] as? Date) ?? Date()
        if let index = games.firstIndex(of: file) {
            games[index].modified = modified
        } else {
            games.append(GameFile(url: file.url, modified: modified))
        }
        games.sort { $0.modified > $1.modified }
    }

    /// Creates `Game yyyy-MM-dd HH.mm.ss.bchess`, or the given base name, avoiding a collision.
    @discardableResult
    func create(_ state: GameState, baseName: String? = nil) throws -> GameFile {
        let base = baseName ?? "Game " + Self.timestamp(Date())
        var url = directory.appendingPathComponent(base).appendingPathExtension("bchess")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(base) \(counter)").appendingPathExtension("bchess")
            counter += 1
        }
        try state.data(for: .bchessGame).write(to: url, options: .atomic)
        reload()
        // The listed file, so that its URL is the one the directory listing returns
        return games.first { $0.name == url.lastPathComponent } ?? GameFile(url: url, modified: Date())
    }

    /// Copies a game from outside the library (Files, share sheet) into it as a `.bchess` file.
    func importFile(at url: URL) throws -> GameFile {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let type = Self.contentType(of: url) else {
            throw CocoaError(.fileReadUnknown)
        }
        let state = try GameState(data: Data(contentsOf: url), contentType: type)
        return try create(state, baseName: url.deletingPathExtension().lastPathComponent)
    }

    func delete(_ file: GameFile) throws {
        try FileManager.default.removeItem(at: file.url)
        reload()
    }

    /// The game to show at launch: the last opened one, else the newest, else a new game.
    func initialGame() throws -> GameFile {
        let file: GameFile
        if let name = lastOpenedName, let last = games.first(where: { $0.name == name }) {
            file = last
        } else if let newest = games.first {
            file = newest
        } else {
            file = try create(.newGame)
        }
        lastOpenedName = file.name
        return file
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: date)
    }
}
