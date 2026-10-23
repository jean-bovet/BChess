//
//  GameStateCodingTests.swift
//  BChessTests
//
//  The file format: every game file an earlier BChess wrote must keep opening (invariant I1).
//

import Foundation
import Testing
import UniformTypeIdentifiers

struct GameStateCodingTests {

    // A file as the first BChess versions wrote it, without the players
    private let legacyWithoutPlayers = #"{"pgn":"1. e4 e5 *","rotated":true}"#
    private let legacyWithPlayers = #"{"pgn":"1. e4 e5 *","rotated":false,"white":{"name":"Ann","computer":false,"level":1},"black":{"name":"Bot","computer":true,"level":3}}"#

    @Test func decodesLegacyJSON() throws {
        let bare = try GameState(data: Data(legacyWithoutPlayers.utf8), contentType: .json)
        #expect(bare.pgn == "1. e4 e5 *")
        #expect(bare.rotated)
        #expect(bare.white == GamePlayer(name: "", computer: false, level: 0))
        // A file without a black player gets the Club player
        #expect(bare.black == .computer(.club))

        let full = try GameState(data: Data(legacyWithPlayers.utf8), contentType: .json)
        #expect(full.white == GamePlayer(name: "Ann", computer: false, level: 1))
        #expect(full.black == GamePlayer(name: "Bot", computer: true, level: 3))
    }

    /// The meaning of level changed (APP-3): old levels 0-3 are Beginner...Strong, 4-6 are Maximum at 5, 10 and 30
    /// seconds, anything else is Club. The keys and types of the file are unchanged.
    @Test func oldLevelsStillOpen() throws {
        let full = try GameState(data: Data(legacyWithPlayers.utf8), contentType: .json)
        #expect(full.white.strength == .casual)
        #expect(full.black.strength == .strong)
        #expect(full.black.thinkingTime == 0)

        func black(level: Int) throws -> GamePlayer {
            let json = #"{"pgn":"*","rotated":false,"white":{"name":"","computer":false,"level":0},"black":{"name":"","computer":true,"level":\#(level)}}"#
            return try GameState(data: Data(json.utf8), contentType: .json).black
        }
        #expect(try black(level: 9).strength == .club)
        #expect(try black(level: -1).strength == .club)
        for (level, seconds) in [(4, 5.0), (5, 10.0), (6, 30.0)] {
            let player = try black(level: level)
            #expect(player.strength == .maximum)
            #expect(player.thinkingTime == seconds)
            let data = try GameState(pgn: "*", black: player).data(for: .json)
            #expect(try GameState(data: data, contentType: .json).black == player)
        }
    }

    @Test func strengthAndTimeFollowTheLevel() {
        let table: [(Int, EngineStrength, TimeInterval)] = [(0, .beginner, 0), (1, .casual, 0), (2, .club, 0), (3, .strong, 0),
                                                           (4, .maximum, 5), (5, .maximum, 10), (6, .maximum, 30), (7, .club, 0)]
        for (level, strength, seconds) in table {
            let player = GamePlayer(name: "", computer: true, level: level)
            #expect(player.strength == strength, "level \(level)")
            #expect(player.thinkingTime == seconds, "level \(level)")
        }
        #expect(GamePlayer.computer(.club).level == 2)
        #expect(GamePlayer.computer(.maximum, thinkingTime: 5).level == 4)
        #expect(GamePlayer.computer(.maximum).level == 5)
        #expect(GamePlayer.computer(.maximum, thinkingTime: 30).level == 6)
        #expect(GamePlayer.computer(.beginner, thinkingTime: 30).level == 0)
        #expect(GamePlayer.defaultBlack == .computer(.club))
    }

    @Test func jsonRoundTrip() throws {
        let state = GameState(pgn: "1. d4 d5 *", rotated: true,
                              white: GamePlayer(name: "W", computer: true, level: 2),
                              black: GamePlayer(name: "B", computer: false, level: 0))
        let data = try state.data(for: .json)
        #expect(try GameState(data: data, contentType: .json) == state)

        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["pgn", "rotated", "white", "black"])
    }

    @Test func bchessAndJSONShareTheFormat() throws {
        let data = Data(legacyWithPlayers.utf8)
        let asBChess = try GameState(data: data, contentType: .bchessGame)
        let asJSON = try GameState(data: data, contentType: .json)
        #expect(asBChess == asJSON)
        #expect(try asBChess.data(for: .bchessGame) == asJSON.data(for: .json))
    }

    @Test func pgnRoundTrip() throws {
        let pgn = "[Event \"Test\"]\n[Site \"?\"]\n\n1. e4 e5 2. Nf3 Nc6 *"
        let state = try GameState(data: Data(pgn.utf8), contentType: .pgn)
        #expect(state.pgn == pgn)
        #expect(state.white == .human)
        #expect(state.black == .human)
        #expect(try state.data(for: .pgn) == Data(pgn.utf8))
    }

    @Test func generatedFENGameIsStandardPGN() {
        let fen = "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 3 3"
        let engine = FEngine()
        #expect(engine.setFEN(fen))
        engine.move(uci: "a7a6")

        let pgn = engine.pgnAllGames()
        #expect(pgn.contains("[FEN \"\(fen)\"]"))
        #expect(pgn.contains("[SetUp \"1\"]"))
        #expect(!pgn.contains("[Setup"))

        // Standard PGN: one FEN and one SetUp tag, numbered from the position (Black to move at move 3)
        #expect(pgn.hasSuffix("[SetUp \"1\"]\n\n 3... a6 *"))

        // The text loads back to the same game, and saving it again does not pile up tags
        let reopened = FEngine()
        #expect(reopened.loadAllGames(pgn))
        let resaved = reopened.pgnAllGames()
        #expect(resaved == pgn)
        #expect(resaved.components(separatedBy: "[FEN").count == 2)
        #expect(resaved.components(separatedBy: "[SetUp").count == 2)

        // The text loads back to the same game
        let again = FEngine()
        #expect(again.loadAllGames(pgn))
        #expect(again.fen() == engine.fen())
        #expect(again.allMoves().count == 1)
        again.move(to: .start, variation: 0)
        engine.move(to: .start, variation: 0)
        #expect(again.fen() == engine.fen())
    }

    @Test func legacySetupTagStillLoads() {
        let fen = "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 3 3"
        let engine = FEngine()
        #expect(engine.loadAllGames("[Setup \"1\"]\n[FEN \"\(fen)\"]\n\n3... a6 *"))
        engine.move(to: .start, variation: 0)
        let expected = FEngine()
        expected.setFEN(fen)
        #expect(engine.fen() == expected.fen())
        #expect(engine.allMoves().isEmpty)
    }

    @Test func invalidPGNThrows() {
        #expect(throws: CocoaError.self) {
            try GameState(data: Data("this is not a game".utf8), contentType: .pgn)
        }
        #expect(throws: CocoaError.self) {
            try GameState(data: Data(#"{"pgn":"1. e9 *","rotated":false}"#.utf8), contentType: .bchessGame)
        }
        #expect(throws: (any Error).self) {
            try GameState(data: Data("not json".utf8), contentType: .json)
        }
    }

    @Test func unknownTypeThrows() {
        #expect(throws: CocoaError.self) {
            try GameState(data: Data(legacyWithPlayers.utf8), contentType: .png)
        }
        #expect(throws: CocoaError.self) {
            try GameState.newGame.data(for: .png)
        }
    }

    // Files saved with a FEN the parser used to take at face value: the tag keeps its text, the
    // position that is played is the sanitized one (no castling rights or en passant square that cannot exist)
    private let legacyFENTag = #"[FEN "4k3/8/8/8/8/8/8/4K3 w KXq e4 0 1"]"#

    @Test func legacyFENFilesOpen() throws {
        let pgn = "[Event \"Test\"]\n\(legacyFENTag)\n[SetUp \"1\"]\n\n1. Ke2 *"
        let json = #"{"pgn":"[Event \"Test\"]\n[FEN \"4k3/8/8/8/8/8/8/4K3 w KXq e4 0 1\"]\n[SetUp \"1\"]\n\n1. Ke2 *","rotated":false}"#

        for (data, type) in [(Data(pgn.utf8), UTType.pgn), (Data(json.utf8), UTType.json)] {
            let state = try GameState(data: data, contentType: type)
            let engine = FEngine()
            #expect(engine.loadAllGames(state.pgn))
            #expect(engine.fen() == "4k3/8/8/8/8/8/4K3/8 b - - 1 1")
            #expect(engine.allMoves().count == 1)
            engine.move(to: .start, variation: 0)
            #expect(engine.fen() == "4k3/8/8/8/8/8/8/4K3 w - - 0 1")
            // Saving again keeps the original text of the tag
            #expect(engine.pgnAllGames().contains(legacyFENTag))
        }
    }

    // A rank that runs past the 8th file, with empty squares or with a piece that is then ignored, was accepted
    // before and was saved as it was typed
    @Test(arguments: ["4k4/8/8/8/8/8/8/4K3 w - - 0 1", "4k3k/8/8/8/8/8/8/4K3 w - - 0 1"])
    func overlongRankFilesOpen(fen: String) throws {
        let tag = "[FEN \"\(fen)\"]"
        let pgn = "[Event \"Test\"]\n\(tag)\n[SetUp \"1\"]\n\n1. Ke2 *"
        let escapedTag = tag.replacingOccurrences(of: "\"", with: "\\\"")
        let json = "{\"pgn\":\"[Event \\\"Test\\\"]\\n\(escapedTag)\\n[SetUp \\\"1\\\"]\\n\\n1. Ke2 *\",\"rotated\":false}"

        for (data, type) in [(Data(pgn.utf8), UTType.pgn), (Data(json.utf8), UTType.json)] {
            let state = try GameState(data: data, contentType: type)
            let engine = FEngine()
            #expect(engine.loadAllGames(state.pgn))
            #expect(engine.fen() == "4k3/8/8/8/8/8/4K3/8 b - - 1 1")
            #expect(engine.pgnAllGames().contains(tag))
        }
    }

    // The file counter of earlier versions wrapped after 256 empty squares: the king lands on a8
    @Test func wrappedFileCounterFilesOpen() throws {
        let fen = String(repeating: "8", count: 32) + "k7/8/8/8/8/8/8/4K3 b - - 0 1"
        let tag = "[FEN \"\(fen)\"]"
        let pgn = "[Event \"Test\"]\n\(tag)\n[SetUp \"1\"]\n\n1... Ka7 *"
        let json = "{\"pgn\":\"[Event \\\"Test\\\"]\\n[FEN \\\"\(fen)\\\"]\\n[SetUp \\\"1\\\"]\\n\\n1... Ka7 *\",\"rotated\":false}"

        for (data, type) in [(Data(pgn.utf8), UTType.pgn), (Data(json.utf8), UTType.json)] {
            let state = try GameState(data: data, contentType: type)
            let engine = FEngine()
            #expect(engine.loadAllGames(state.pgn))
            #expect(engine.fen() == "8/k7/8/8/8/8/8/4K3 w - - 1 2")
            #expect(engine.pgnAllGames().contains(tag))
        }
    }
}
