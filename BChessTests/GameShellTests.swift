//
//  GameShellTests.swift
//  BChessTests
//
//  The iOS shell never loses an unsaved move silently: it saves before every switch, refuses the
//  switch when it cannot, and installs a replacement before it deletes the current game.
//

import Foundation
import Testing

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
}
