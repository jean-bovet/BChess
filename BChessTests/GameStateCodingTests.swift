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
        #expect(bare.black == GamePlayer(name: "", computer: true, level: 0))

        let full = try GameState(data: Data(legacyWithPlayers.utf8), contentType: .json)
        #expect(full.white == GamePlayer(name: "Ann", computer: false, level: 1))
        #expect(full.black == GamePlayer(name: "Bot", computer: true, level: 3))
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
}
