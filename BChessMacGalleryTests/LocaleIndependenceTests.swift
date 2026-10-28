//
//  LocaleIndependenceTests.swift
//  BChessMacGalleryTests
//
//  I1 and the notation under a locale: with the process really set to a language (`-testLanguage`/`-testRegion`, and
//  `BCHESS_EXPECT_LANGUAGE`/`BCHESS_EXPECT_REGION` as `TEST_RUNNER_…` variables naming it), the bytes of the files
//  and the notation on screen are what they are in English. Skipped only when no language is expected (the English
//  gate). The expected values are literals, never the output of the same run.
//

import Foundation
import Testing
@testable import BChess

private let expectedLanguage = ProcessInfo.processInfo.environment["BCHESS_EXPECT_LANGUAGE"]
private let expectedRegion = ProcessInfo.processInfo.environment["BCHESS_EXPECT_REGION"]

@MainActor
@Suite(.enabled(if: expectedLanguage != nil, "no BCHESS_EXPECT_LANGUAGE: the English gate"))
struct LocaleIndependenceTests {

    /// The process really is in the language the run names: a skipped or mistyped run is red, not green.
    @Test func theProcessLocaleIsTheExpectedOne() throws {
        let language = try #require(expectedLanguage)
        let region = try #require(expectedRegion, "BCHESS_EXPECT_REGION is not set")
        #expect(Locale.current.language.languageCode?.identifier == language)
        #expect(Locale.current.region?.identifier == region)
    }

    @Test func namedPlayersWriteTheSameBytes() throws {
        let scripts = GameState(pgn: "*", rotated: true, white: GamePlayer(name: "דני", computer: false, level: 0),
                                black: .computer(.maximum, thinkingTime: 30))
        #expect(try scripts.data(for: .json) == Data(
            "{\"black\":{\"computer\":true,\"level\":6,\"name\":\"\"},\"pgn\":\"*\",\"rotated\":true,\"white\":{\"computer\":false,\"level\":0,\"name\":\"דני\"}}".utf8))
        let arabic = GameState(pgn: "*", white: GamePlayer(name: "سامي", computer: false, level: 0), black: .computer(.maximum))
        #expect(try arabic.data(for: .bchessGame) == Data(
            "{\"black\":{\"computer\":true,\"level\":5,\"name\":\"\"},\"pgn\":\"*\",\"rotated\":false,\"white\":{\"computer\":false,\"level\":0,\"name\":\"سامي\"}}".utf8))
        let ann = GameState(pgn: "*", white: GamePlayer(name: "Ann", computer: false, level: 0), black: .computer(.club))
        #expect(try ann.data(for: .bchessGame) == Data(
            #"{"black":{"computer":true,"level":2,"name":""},"pgn":"*","rotated":false,"white":{"computer":false,"level":0,"name":"Ann"}}"#.utf8))
    }

    @Test func chessDataIsStandardEnglishNotation() throws {
        let engine = FEngine()
        for move in ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5"] {
            #expect(engine.move(uci: move))
        }
        #expect(engine.pgnAllGames() == """
            [Event ""]
            [Site ""]
            [Date ""]
            [Round ""]
            [White ""]
            [Black ""]
            [Result "*"]

             1. e4 e5 2. Nf3 Nc6 3. Bb5 *
            """)
        #expect(engine.fen() == "r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3")
        let nodes = engine.moveNodesTree()
        #expect(nodes.map(\.name) == ["e4", "e5", "Nf3", "Nc6", "Bb5"])
        #expect(nodes.map { GameText.moveLabel(number: Int($0.moveNumber), isWhite: $0.whiteMove, san: $0.name) }
                == ["1. e4", "1\u{2026}e5", "2. Nf3", "2\u{2026}Nc6", "3. Bb5"])
    }

    /// No scalar of Eastern Arabic-Indic (U+0660…0669) or Extended (U+06F0…06F9) digits, compared by scalar:
    /// `String.contains` folds digit forms.
    private func hasEasternDigit(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0660...0x0669).contains($0.value) || (0x06F0...0x06F9).contains($0.value) }
    }

    @Test func notationKeepsWesternDigits() {
        #expect(!hasEasternDigit(GameText.moveLabel(number: 12, isWhite: false, san: "O-O")))
        #expect(!hasEasternDigit(Verdict(centipawns: -120, isMate: false).score))
        let depth = EngineView.statistics(depth: 9, quiescenceDepth: 12, nodes: 0, speed: 0)
        #expect(depth.contains("9/12"))
        #expect(!hasEasternDigit(GameLibrary.timestamp(Date())))
        #expect(GameLibrary.timestamp(Date()).wholeMatch(of: /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}\.[0-9]{2}\.[0-9]{2}/) != nil)
    }

    /// A translation reached the composed sentences: under another language the status is not the English one.
    @Test func statusIsNotEnglish() throws {
        try #require(expectedLanguage != "en")
        let status = GameText.status(mode: .play, isThinking: false, gameEnd: .none, white: .human, black: .defaultBlack,
                                     isWhiteToMove: true, lastMove: nil)
        #expect(status != "Your move.")
        #expect(GameText.title(white: .human, black: .defaultBlack) != "You vs Club Player")
    }

    // MARK: Through the production path, under the process locale the run really set

    private var language: String { expectedLanguage ?? "en" }

    private func t(_ key: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> String {
        try LocalizationTests.t(key, language, sourceLocation: sourceLocation)
    }

    /// The expected text of a key whose arguments are substituted the way Foundation does under this language.
    private func filled(_ key: String, _ arguments: [String], sourceLocation: SourceLocation = #_sourceLocation) throws -> String {
        var text = try t(key, sourceLocation: sourceLocation)
        for (index, argument) in arguments.enumerated() {
            let wrapped = LocalizationTests.argument(argument, language)
            text = text.replacingOccurrences(of: "%\(index + 1)$@", with: wrapped)
        }
        return text.replacingOccurrences(of: "%@", with: LocalizationTests.argument(arguments.first ?? "", language))
    }

    /// The statistics sentence is the catalog's unit for this language (so it cannot be English text in the code), with
    /// the depth isolated and the counts formatted by the locale.
    @Test func statisticsSentenceIsTheCatalogUnit() throws {
        let nodes = 1_234_567, speed = 410_000
        let text = EngineView.statistics(depth: 9, quiescenceDepth: 12, nodes: nodes, speed: speed)
        let expected = try filled("Depth %@ with %@ nodes at %@ n/s",
                                  [GameText.notation("9/12"), nodes.formatted(.number), speed.formatted(.number)])
        #expect(text == expected)
        #expect(text != "Depth \(GameText.notation("9/12")) with \(nodes.formatted(.number)) nodes at \(speed.formatted(.number)) n/s")
    }

    /// The thinking time keeps Western digits under the real process locale (a `String(n)` argument, never a formatted
    /// number), inside the language's own "%@ s".
    @Test func thinkingTimeIsTheCatalogUnitWithWesternDigits() throws {
        let text = String(localized: GameText.seconds(10))
        #expect(text == (try filled("%@ s", ["10"])))
        #expect(!hasEasternDigit(text))
        let elo = String(localized: try #require(NewGame.Opponent.club.elo))
        #expect(elo == (try t("about 1350")) && !hasEasternDigit(elo))
    }

    @Test func mateScoreAndLabelAreLocalizedForBothColours() throws {
        for centipawns in [30000, -30000] {
            let verdict = Verdict(centipawns: centipawns, isMate: true)
            #expect(verdict.score == (try t("Mate")))
            #expect(String(localized: verdict.accessibilityLabel) == (try filled("Evaluation %@", [try t("Mate")])))
        }
        let number = Verdict(centipawns: -120, isMate: false)
        #expect(String(localized: number.accessibilityLabel) == (try filled("Evaluation %@", [number.score])))
    }

    @Test func exportErrorTextIsTheCatalogUnit() throws {
        let text = try #require(GameShell.ExportError.libraryFolder.errorDescription)
        #expect(text == (try t("Choose a folder outside BChess's own games: exporting there would list every game twice.")))
    }

    /// The saved PGN bytes, the session's FEN and the captures of a game with a Hebrew-named player are what they are in
    /// English: literals, never the output of the same run.
    @Test func savedPGNFENAndCapturesAreLocaleIndependent() throws {
        let pgn = "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *"
        let state = GameState(pgn: pgn, white: GamePlayer(name: "דני", computer: false, level: 0), black: .computer(.club))
        #expect(try state.data(for: .pgn) == Data(pgn.utf8))
        let session = GameSession(state: state)
        #expect(session.fen == "rnbqkb1r/ppp2ppp/5n2/4p3/4P3/2N5/PPPP1PPP/R1BQKB1R w KQkq - 0 5")
        #expect(session.capturedPieces(white: true) == ["p"])
        #expect(session.capturedPieces(white: false) == ["N"])
        // The players' names are never written to the PGN
        #expect(session.pgnCurrentGame == """
            [Event ""]
            [Site ""]
            [Date ""]
            [Round ""]
            [White ""]
            [Black ""]
            [Result "*"]

             1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *
            """)
    }
}
