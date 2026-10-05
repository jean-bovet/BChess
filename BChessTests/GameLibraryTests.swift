//
//  GameLibraryTests.swift
//  BChessTests
//
//  The iOS game library: the files of one directory, in the formats that every earlier BChess wrote.
//

import Foundation
import Testing

/// A scratch directory and its own user defaults, removed afterwards.
@MainActor
final class LibraryFixture {
    let directory: URL
    let suite: String
    let defaults: UserDefaults

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("BChessTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suite = "BChessTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    func makeLibrary() -> GameLibrary {
        GameLibrary(directory: directory, defaults: defaults)
    }

    func write(_ text: String, as name: String, modified: Date? = nil) throws {
        let url = directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
    }

    func setReadOnly(_ readOnly: Bool) throws {
        try FileManager.default.setAttributes([.posixPermissions: readOnly ? 0o555 : 0o755], ofItemAtPath: directory.path)
    }

    func cleanUp() {
        try? setReadOnly(false)
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suite)
    }
}

@MainActor
struct GameLibraryTests {

    @Test func firstLaunchCreatesGame() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let library = fixture.makeLibrary()

        let file = try library.initialGame()
        #expect(file.url.pathExtension == "bchess")
        #expect(library.games == [file])
        #expect(library.lastOpenedName == file.name)
    }

    @Test func listsLegacyJSONAndPGN() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        try fixture.write(#"{"pgn":"1. e4 e5 *","rotated":false}"#, as: "old.json")
        try fixture.write("1. d4 d5 *", as: "game.pgn")
        try fixture.write("not a game at all", as: "broken.pgn")
        try fixture.write("{ not json", as: "broken.json")
        try fixture.write("ignored", as: "notes.txt")
        let library = fixture.makeLibrary()

        #expect(Set(library.games.map(\.name)) == ["old.json", "game.pgn"])
        let json = try #require(library.games.first { $0.name == "old.json" })
        #expect(try library.open(json).pgn == "1. e4 e5 *")
        let pgn = try #require(library.games.first { $0.name == "game.pgn" })
        #expect(try library.open(pgn).white == .human)
        // The undecodable files are skipped, not deleted
        #expect(FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent("broken.pgn").path))
    }

    @Test func saveKeepsFileFormat() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        try fixture.write(#"{"pgn":"*","rotated":false}"#, as: "old.json")
        try fixture.write("1. d4 *", as: "game.pgn")
        let library = fixture.makeLibrary()
        let json = try #require(library.games.first { $0.name == "old.json" })
        let pgn = try #require(library.games.first { $0.name == "game.pgn" })

        try library.save(GameState(pgn: "1. e4 *", rotated: true), to: json)
        let jsonObject = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: json.url)) as? [String: Any])
        #expect(jsonObject["pgn"] as? String == "1. e4 *")
        #expect(jsonObject["rotated"] as? Bool == true)

        try library.save(GameState(pgn: "1. c4 *"), to: pgn)
        #expect(try String(contentsOf: pgn.url, encoding: .utf8) == "1. c4 *")
    }

    @Test func saveMovesTheGameToTheTop() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        try fixture.write("1. d4 *", as: "older.pgn", modified: Date(timeIntervalSinceNow: -500))
        try fixture.write("1. c4 *", as: "newer.pgn", modified: Date(timeIntervalSinceNow: -100))
        let library = fixture.makeLibrary()
        #expect(library.games.map(\.name) == ["newer.pgn", "older.pgn"])

        let older = try #require(library.games.last)
        try library.save(GameState(pgn: "1. d4 d5 *"), to: older)
        #expect(library.games.map(\.name) == ["older.pgn", "newer.pgn"])
    }

    @Test func importCopiesIntoLibrary() throws {
        let fixture = try LibraryFixture()
        let other = try LibraryFixture()
        defer { fixture.cleanUp(); other.cleanUp() }
        try other.write("1. e4 e5 2. Nf3 *", as: "Spanish.pgn")
        let library = fixture.makeLibrary()

        let file = try library.importFile(at: other.directory.appendingPathComponent("Spanish.pgn"))
        #expect(file.name == "Spanish.bchess")
        #expect(try library.open(file).pgn == "1. e4 e5 2. Nf3 *")
        #expect(FileManager.default.fileExists(atPath: other.directory.appendingPathComponent("Spanish.pgn").path))
        #expect(library.games.contains(file))
    }

    @Test func deleteCurrentFallsBackToNewest() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        try fixture.write("1. d4 *", as: "oldest.pgn", modified: Date(timeIntervalSinceNow: -300))
        try fixture.write("1. c4 *", as: "newest.pgn", modified: Date(timeIntervalSinceNow: -100))
        try fixture.write("1. e4 *", as: "current.pgn", modified: Date(timeIntervalSinceNow: -200))
        let library = fixture.makeLibrary()
        library.lastOpenedName = "current.pgn"
        let current = try library.initialGame()
        #expect(current.name == "current.pgn")

        try library.delete(current)
        #expect(try library.initialGame().name == "newest.pgn")
    }

    @Test func lastOpenedIsRestored() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        try fixture.write("1. d4 *", as: "a.pgn", modified: Date(timeIntervalSinceNow: -100))
        try fixture.write("1. c4 *", as: "b.pgn", modified: Date(timeIntervalSinceNow: -50))
        let first = fixture.makeLibrary()
        first.lastOpenedName = "a.pgn"

        let second = fixture.makeLibrary()
        #expect(try second.initialGame().name == "a.pgn")
    }

    @Test func createAvoidsNameCollision() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let library = fixture.makeLibrary()

        let one = try library.create(.newGame, baseName: "Same")
        let two = try library.create(.newGame, baseName: "Same")
        let three = try library.create(.newGame)
        let four = try library.create(.newGame)
        #expect(Set([one, two, three, four].map(\.name)).count == 4)
    }

    @Test func saveFailureThrows() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let library = fixture.makeLibrary()
        let file = try library.create(.newGame)

        try fixture.setReadOnly(true)
        #expect(throws: (any Error).self) {
            try library.save(GameState(pgn: "1. e4 *"), to: file)
        }
    }
}
