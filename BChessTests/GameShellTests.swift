//
//  GameShellTests.swift
//  BChessTests
//
//  The iOS shell never loses an unsaved move silently: it saves before every switch, refuses the
//  switch when it cannot, and installs a replacement before it deletes the current game.
//

import Foundation
import Synchronization
import Testing
import UniformTypeIdentifiers

@MainActor
struct GameShellTests {

    private func makeShell(_ fixture: LibraryFixture, games: [(name: String, pgn: String)] = []) throws -> (GameShell, GameLibrary) {
        for game in games {
            try fixture.write(game.pgn, as: game.name, modified: Date(timeIntervalSinceNow: -Double(games.count) * 10))
        }
        let library = fixture.makeLibrary()
        if let first = games.first {
            library.lastOpenedName = first.name
        }
        return (try GameShell(library: library), library)
    }

    /// A human move on the shell's session, the way a tap would.
    private func playE4(_ shell: GameShell) {
        shell.session.select(rank: 1, file: 4)
        if let move = shell.session.selection.possibleMove(3, 4) {
            shell.session.playHuman(move)
        }
    }

    private func state(of file: GameFile, in library: GameLibrary) throws -> GameState {
        try library.open(file)
    }

    @Test func switchSavesUnsavedMoveFirst() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "*"), ("b.pgn", "1. d4 *")])
        let first = shell.current
        let other = try #require(library.games.first { $0.name == "b.pgn" })

        playE4(shell) // no view, so no autosave observer
        #expect(try shell.open(other))
        #expect(shell.current == other)
        #expect(try state(of: first, in: library).pgn.contains("1. e4"))
    }

    @Test func failedSaveBlocksSwitchUntilConfirmed() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "*"), ("b.pgn", "1. d4 *")])
        let first = shell.current
        let session = shell.session
        let other = try #require(library.games.first { $0.name == "b.pgn" })

        playE4(shell)
        try fixture.setReadOnly(true)
        #expect(try shell.open(other) == false)
        #expect(shell.saveError != nil)
        #expect(shell.current == first)
        #expect(shell.session === session)

        #expect(try shell.open(other, discardingUnsavedChanges: true))
        #expect(shell.current == other)
        #expect(shell.session !== session)
    }

    @Test func unopenableTargetKeepsCurrentGame() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "*"), ("b.pgn", "1. d4 *")])
        let first = shell.current
        let session = shell.session
        let other = try #require(library.games.first { $0.name == "b.pgn" })

        try FileManager.default.removeItem(at: other.url) // behind the library's back
        #expect(throws: (any Error).self) { try shell.open(other) }
        #expect(shell.current == first)
        #expect(shell.session === session)
        #expect(FileManager.default.fileExists(atPath: first.url.path))
    }

    @Test func deleteCurrentSwitchesBeforeDeleting() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "*"), ("b.pgn", "1. d4 *")])
        let a = shell.current
        let b = try #require(library.games.first { $0.name == "b.pgn" })

        playE4(shell) // an unsaved move in A
        try shell.delete(a)
        #expect(shell.current == b)
        #expect(!FileManager.default.fileExists(atPath: a.url.path))
        #expect(!library.games.contains(a))

        // Autosave never recreates the deleted file
        shell.save()
        playE4(shell)
        shell.save()
        #expect(!FileManager.default.fileExists(atPath: a.url.path))
    }

    @Test func deleteCurrentWithUnopenableFallbackKeepsCurrent() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "*"), ("b.pgn", "1. d4 *")])
        let a = shell.current
        let session = shell.session
        let b = try #require(library.games.first { $0.name == "b.pgn" })

        try FileManager.default.removeItem(at: b.url)
        #expect(throws: (any Error).self) { try shell.delete(a) }
        #expect(FileManager.default.fileExists(atPath: a.url.path))
        #expect(shell.current == a)
        #expect(shell.session === session)
    }

    @Test func deleteOnlyGameCreatesFallback() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let (shell, _) = try makeShell(fixture, games: [("a.pgn", "1. e4 *")])
        let a = shell.current

        try shell.delete(a)
        #expect(shell.current != a)
        #expect(shell.current.url.pathExtension == "bchess")
        #expect(!FileManager.default.fileExists(atPath: a.url.path))

        // With a read-only directory the fallback cannot be created: nothing changes
        let fixture2 = try LibraryFixture()
        defer { fixture2.cleanUp() }
        let (shell2, _) = try makeShell(fixture2, games: [("a.pgn", "1. e4 *")])
        let only = shell2.current
        try fixture2.setReadOnly(true)
        #expect(throws: (any Error).self) { try shell2.delete(only) }
        #expect(shell2.current == only)
        #expect(FileManager.default.fileExists(atPath: only.url.path))
    }

    @Test func saveRecoversAfterFailure() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "*")])
        playE4(shell)

        try fixture.setReadOnly(true)
        #expect(!shell.save())
        #expect(shell.saveError != nil)

        try fixture.setReadOnly(false)
        #expect(shell.save())
        #expect(shell.saveError == nil)
        #expect(try state(of: shell.current, in: library).pgn.contains("1. e4"))
    }

    @Test func switchingDoesNotRewriteTheFileJustOpened() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "1. e4 *"), ("b.pgn", "1. d4 *")])
        let b = try #require(library.games.first { $0.name == "b.pgn" })
        // An old date: any write, even of identical bytes, would move it
        let old = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: b.url.path)

        try shell.open(b)
        shell.save()
        // Read through the file manager: URL resource values are cached
        let date = try FileManager.default.attributesOfItem(atPath: b.url.path)[.modificationDate] as? Date
        #expect(date == old)
    }

    @Test func createGameKeepsTheOrientation() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "*")])

        #expect(try shell.createGame(white: .human, black: .computer(.club), rotated: true))
        #expect(shell.session.gameState.rotated)
        #expect(try library.open(shell.current).rotated)

        #expect(try shell.createGame(white: .human, black: .computer(.club)))
        #expect(!shell.session.gameState.rotated)
    }
}

// MARK: Export (APP-7)

@MainActor
extension GameShellTests {

    private static let spanish = "1. e4 e5 2. Nf3 Nc6 3. Bb5 *"

    private func type(of name: String) -> UTType {
        switch (name as NSString).pathExtension {
        case "bchess": .bchessGame
        case "json": .json
        default: .pgn
        }
    }

    /// Writes the games in the format their name asks for, `a` newest, then `b`, then `c`.
    private func seed(_ fixture: LibraryFixture, _ games: [(name: String, state: GameState)]) throws {
        for (index, game) in games.enumerated() {
            let data = try game.state.data(for: type(of: game.name))
            try fixture.write(String(decoding: data, as: UTF8.self), as: game.name, modified: Date(timeIntervalSinceNow: -Double(index + 1) * 10))
        }
    }

    private func threeGames(_ fixture: LibraryFixture) throws -> [(name: String, state: GameState)] {
        let games = [("a.pgn", GameState(pgn: "1. e4 *")), ("b.pgn", GameState(pgn: "1. d4 *")), ("c.pgn", GameState(pgn: "1. c4 *"))]
        try seed(fixture, games)
        return games
    }

    private func file(_ name: String, in library: GameLibrary) throws -> GameFile {
        try #require(library.games.first { $0.name == name })
    }

    private func names(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    @Test func exportPGNIsTheGamePGN() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let state = GameState(pgn: Self.spanish, rotated: true, white: .human, black: .computer(.club))
        try seed(fixture, [("open.pgn", GameState(pgn: "*")), ("club.bchess", state)])
        let (shell, library) = try makeShell(fixture)
        let club = try file("club.bchess", in: library)

        let data = try shell.exportData(of: club, as: .pgn)
        #expect(data == Data(state.pgn.utf8))
        let back = try GameState(data: data, contentType: .pgn)
        #expect(back.white == .human)
        #expect(back.black == .human)
        #expect(back.rotated == false)
    }

    @Test func exportBChessRoundTripsPlayersAndRotation() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let state = GameState(pgn: Self.spanish, rotated: true, white: .computer(.maximum, thinkingTime: 30), black: .human)
        try seed(fixture, [("a.pgn", GameState(pgn: "*")), ("old.json", state)])
        let (shell, library) = try makeShell(fixture)

        let data = try shell.exportData(of: try file("old.json", in: library), as: .bchess)
        #expect(try GameState(data: data, contentType: .bchessGame) == state)
    }

    @Test func exportOfOpenGameIncludesUnsavedMove() throws {
        let fixture = try LibraryFixture()
        defer { fixture.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "*")])
        let open = shell.current

        playE4(shell)
        for format in ExportFormat.allCases {
            let text = String(decoding: try shell.exportData(of: open, as: format), as: UTF8.self)
            #expect(text.contains("1. e4"))
        }
        #expect(try library.open(open).pgn.contains("1. e4") == false)
    }

    @Test(arguments: ExportFormat.allCases)
    func exportAllWritesOneFilePerGame(format: ExportFormat) async throws {
        let fixture = try LibraryFixture()
        let target = try LibraryFixture()
        defer { fixture.cleanUp(); target.cleanUp() }
        try seed(fixture, [
            ("a.bchess", GameState(pgn: "1. e4 e5 *", rotated: true, white: .human, black: .computer(.club))),
            ("b.json", GameState(pgn: "1. d4 *")),
            ("c.pgn", GameState(pgn: "1. e4 (1. d4 d5 {a comment}) 1... e5 *", white: .human, black: .human)),
        ])
        let (shell, library) = try makeShell(fixture)
        shell.library.lastOpenedName = "a.bchess"

        let urls = try await shell.exportAll(to: target.directory, as: format)
        #expect(urls.count == 3)
        let ext = format.fileExtension
        #expect(try names(in: target.directory) == ["a.\(ext)", "b.\(ext)", "c.\(ext)"])
        let exported = GameLibrary(directory: target.directory, defaults: target.defaults)
        for source in library.games {
            let written = try file(source.title + "." + ext, in: exported)
            #expect(try exported.open(written) == GameState(data: try shell.exportData(of: source, as: format), contentType: format.contentType))
        }
    }

    @Test func exportAllIncludesUnsavedMoveOfOpenGame() async throws {
        let fixture = try LibraryFixture()
        let target = try LibraryFixture()
        defer { fixture.cleanUp(); target.cleanUp() }
        let (shell, _) = try makeShell(fixture, games: [("a.pgn", "*")])
        let name = shell.current.title

        playE4(shell)
        _ = try await shell.exportAll(to: target.directory, as: .pgn)
        let text = try String(contentsOf: target.directory.appendingPathComponent(name + ".pgn"), encoding: .utf8)
        #expect(text.contains("1. e4"))
    }

    @Test func exportAllNeverOverwrites() async throws {
        let fixture = try LibraryFixture()
        let target = try LibraryFixture()
        defer { fixture.cleanUp(); target.cleanUp() }
        try seed(fixture, [("Game.bchess", GameState(pgn: "1. e4 *")), ("Game.pgn", GameState(pgn: "1. d4 *", white: .human, black: .human))])
        let (shell, _) = try makeShell(fixture)
        try target.write("old bytes", as: "Game.pgn")

        let urls = try await shell.exportAll(to: target.directory, as: .pgn)
        #expect(try String(contentsOf: target.directory.appendingPathComponent("Game.pgn"), encoding: .utf8) == "old bytes")
        #expect(urls.map(\.lastPathComponent).sorted() == ["Game 2.pgn", "Game 3.pgn"])
        #expect(try names(in: target.directory) == ["Game 2.pgn", "Game 3.pgn", "Game.pgn"])
    }

    @Test func exportAllRefusesLibraryFolder() async throws {
        let fixture = try LibraryFixture()
        let target = try LibraryFixture()
        defer { fixture.cleanUp(); target.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "*")])
        let before = try names(in: fixture.directory)
        let games = library.games
        let link = target.directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fixture.directory)

        await #expect(throws: GameShell.ExportError.libraryFolder) {
            try await shell.exportAll(to: fixture.directory, as: .pgn)
        }
        await #expect(throws: GameShell.ExportError.libraryFolder) {
            try await shell.exportAll(to: link, as: .bchess)
        }
        #expect(try names(in: fixture.directory) == before)
        #expect(library.games == games)

        // A subfolder is a valid destination, and the list does not change
        let sub = fixture.directory.appendingPathComponent("Backup", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let urls = try await shell.exportAll(to: sub, as: .pgn)
        #expect(urls.count == 1)
        #expect(try names(in: sub).count == 1)
        library.reload()
        #expect(library.games == games)
    }

    @Test func exportAllReadsEveryGameBeforeWriting() async throws {
        let fixture = try LibraryFixture()
        let target = try LibraryFixture()
        defer { fixture.cleanUp(); target.cleanUp() }
        _ = try threeGames(fixture)
        let (shell, library) = try makeShell(fixture)
        try target.write("known", as: "x.pgn")
        let current = shell.current
        let session = shell.session
        try FileManager.default.removeItem(at: try file("b.pgn", in: library).url)

        await #expect(throws: CocoaError.self) {
            try await shell.exportAll(to: target.directory, as: .pgn)
        }
        #expect(try names(in: target.directory) == ["x.pgn"])
        #expect(try String(contentsOf: target.directory.appendingPathComponent("x.pgn"), encoding: .utf8) == "known")
        #expect(shell.current == current)
        #expect(shell.session === session)
    }

    @Test func exportAllWriteFailureKeepsEarlierFiles() async throws {
        let fixture = try LibraryFixture()
        let target = try LibraryFixture()
        defer { fixture.cleanUp(); target.cleanUp() }
        let games = try threeGames(fixture)
        let (shell, _) = try makeShell(fixture)
        let current = shell.current
        let session = shell.session
        let directory = target.directory
        let calls = Mutex(0)

        await #expect(throws: CocoaError.self) {
            try await shell.exportAll(to: directory, as: .pgn) { _ in
                let call = calls.withLock { value -> Int in value += 1; return value }
                if call == 2 {
                    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
                }
            }
        }
        try target.setReadOnly(false)
        #expect(try names(in: directory) == ["a.pgn"])
        let exported = GameLibrary(directory: directory, defaults: target.defaults)
        #expect(try exported.open(file("a.pgn", in: exported)) == GameState(data: Data(games[0].state.pgn.utf8), contentType: .pgn))
        #expect(shell.current == current)
        #expect(shell.session === session)
    }

    @Test func exportAllNeverOverwritesAFileCreatedDuringExport() async throws {
        let fixture = try LibraryFixture()
        let target = try LibraryFixture()
        defer { fixture.cleanUp(); target.cleanUp() }
        try seed(fixture, [("a.pgn", GameState(pgn: "1. e4 *"))])
        let (shell, _) = try makeShell(fixture)
        let calls = Mutex(0)

        // After the name was chosen, before the write: somebody else creates it
        let urls = try await shell.exportAll(to: target.directory, as: .pgn) { candidate in
            if calls.withLock({ value -> Bool in value += 1; return value == 1 }) {
                try Data("competing".utf8).write(to: candidate)
            }
        }
        #expect(try String(contentsOf: target.directory.appendingPathComponent("a.pgn"), encoding: .utf8) == "competing")
        #expect(urls.map(\.lastPathComponent) == ["a 2.pgn"])
        let exported = GameLibrary(directory: target.directory, defaults: target.defaults)
        // a.pgn is the competing text, which is not a game, so only the export is listed
        #expect(try exported.open(file("a 2.pgn", in: exported)).pgn == "1. e4 *")
    }

    @Test func exportAllWritesOffTheMainActor() async throws {
        let fixture = try LibraryFixture()
        let target = try LibraryFixture()
        defer { fixture.cleanUp(); target.cleanUp() }
        _ = try threeGames(fixture)
        let (shell, _) = try makeShell(fixture)
        let onMain = Mutex<[Bool]>([])

        _ = try await shell.exportAll(to: target.directory, as: .pgn) { _ in
            onMain.withLock { $0.append(Thread.isMainThread) }
        }
        let seen = onMain.withLock { $0 }
        #expect(seen.count == 3)
        #expect(seen.allSatisfy { $0 == false })
    }

    @Test(arguments: ExportFormat.allCases)
    func exportedGameReimportsWithPlayersAndRotation(format: ExportFormat) throws {
        let fixture = try LibraryFixture()
        let target = try LibraryFixture()
        defer { fixture.cleanUp(); target.cleanUp() }
        let state = GameState(pgn: "1. e4 e5 2. Nf3 *", rotated: true, white: .human, black: .computer(.club))
        try seed(fixture, [("open.pgn", GameState(pgn: "*")), ("Spanish.bchess", state)])
        let (shell, library) = try makeShell(fixture)
        shell.library.lastOpenedName = "open.pgn"
        let data = try shell.exportData(of: try file("Spanish.bchess", in: library), as: format)
        let url = target.directory.appendingPathComponent("Spanish." + format.fileExtension)
        try data.write(to: url)

        #expect(try shell.importFile(at: url))
        #expect(shell.current.name != "Spanish.bchess")
        #expect(shell.current.title.hasPrefix("Spanish"))
        #expect(shell.session.gameState.pgn == state.pgn)
        if format == .bchess {
            #expect(shell.session.gameState.white == state.white)
            #expect(shell.session.gameState.black == state.black)
            #expect(shell.session.gameState.rotated)
        } else {
            #expect(shell.session.gameState.white == .human)
            #expect(shell.session.gameState.black == .human)
            #expect(shell.session.gameState.rotated == false)
        }
    }

    @Test func exportAllFailureThrows() async throws {
        let fixture = try LibraryFixture()
        let target = try LibraryFixture()
        defer { fixture.cleanUp(); target.cleanUp() }
        let (shell, library) = try makeShell(fixture, games: [("a.pgn", "*")])
        let games = library.games
        let current = shell.current
        try target.setReadOnly(true)

        await #expect(throws: CocoaError.self) {
            try await shell.exportAll(to: target.directory, as: .pgn)
        }
        #expect(library.games == games)
        #expect(shell.current == current)
    }
}
