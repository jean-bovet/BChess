//
//  GalleryFixtures.swift
//  BChessGalleryTests
//
//  What the iOS and the Mac gallery targets share: the scratch preference suites, the PGN fixtures, and the rules
//  that name and filter a scenario. Compiled by `BChessGalleryTests` and `BChessMacGalleryTests`; each declares its
//  own `GalleryScenarios` enum (the list of its screens).
//

import Foundation
@testable import BChess

/// The file name stem of a card: "Game screen · Tall" is "game-screen-tall".
func gallerySlug(of name: String) -> String {
    let folded = name.folding(options: .diacriticInsensitive, locale: nil).lowercased()
    let mapped = folded.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "-" }
    return String(mapped).split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
}

/// Whether a scenario is selected by the `BCHESS_SNAPSHOT_ONLY` filter: comma-separated, trimmed, case-insensitive
/// substrings of its name or slug; an empty filter selects every scenario.
func galleryMatches(name: String, slug: String, filter: String) -> Bool {
    let patterns = filter.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .filter { !$0.isEmpty }
    guard !patterns.isEmpty else { return true }
    return patterns.contains { name.lowercased().contains($0) || slug.contains($0) }
}

/// One scenario's line of `manifest.json`, the file `scripts/preview-gallery.py` reads. An unset optional is left out of
/// the JSON, so the Mac pass (no flags, nothing skipped) writes the same shape as the iOS pass.
struct GalleryManifestEntry: Encodable {
    let name: String
    let group: String
    let slug: String
    /// The window size in points, "WxH".
    let size: String
    /// The window `[width, height]` in points, as captured.
    let points: [Double]
    /// The capture scale: the PNG is `points` x `scale` pixels (`--check` reads both).
    let scale: Double
    let platform: String
    /// Why the card has no images on this pass (nil: it has); the page shows it, `--check` accepts the gap.
    var skipped: String?
    /// The scenario's `documentCanvas`, `drawsNothing` and `imagery`, written only when set (`--check` reads them).
    var documentCanvas: Bool?
    var drawsNothing: Bool?
    var imagery: Bool?
}

extension GalleryScenarios {
    /// A scratch suite, emptied once per process, shared by the @AppStorage of every scenario and by the
    /// fixture libraries.
    static let defaults: UserDefaults = {
        let suite = UserDefaults(suiteName: "BChessGallery")!
        suite.removePersistentDomain(forName: "BChessGallery")
        return suite
    }()

    /// The scratch suite with the engine readout switched on, for the one scenario that shows it; the other
    /// scenarios keep `defaults`, so none of them starts an analysis.
    static let engineOnDefaults: UserDefaults = {
        let suite = UserDefaults(suiteName: "BChessGalleryEngineOn")!
        suite.removePersistentDomain(forName: "BChessGalleryEngineOn")
        suite.set(true, forKey: "showEngine")
        return suite
    }()

    /// The long given names of the many-captures players: the names that used to truncate beside the capture strip.
    static let longNamedWhite = GamePlayer(name: "Jeanne Blanchard", computer: false, level: 0)
    static let longNamedBlack = GamePlayer(name: "Nikolai Weissmann", computer: false, level: 0)

    /// The PGNs the scenarios load. `GameSession.init` falls back to an empty game when a PGN is
    /// rejected, so `GalleryScenarioTests` parses each one of `allPGNs`.
    enum Fixture {
        /// White (human) is to move after three moves of each side.
        static let ruyLopez = "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *"
        /// A game without moves.
        static let empty = "*"
        /// Both sides played one move.
        static let openingE4E5 = "1. e4 e5 *"
        /// Black took a knight and white took back: both sides have captured a piece.
        static let captures = "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *"
        /// White to move after two moves and a half.
        static let yourMove = "1. e4 e5 2. Nf3 *"
        /// Fool's mate variant: black checkmates.
        static let checkmate = "1. f3 e5 2. g4 Qh4# *"
        /// Scholar's mate: white checkmates.
        static let whiteMates = "1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# *"
        /// Loyd's ten-move stalemate: a draw.
        static let stalemate = "1. e3 a5 2. Qh5 Ra6 3. Qxa5 h5 4. h4 Rah6 5. Qxc7 f6 6. Qxd7+ Kf7 7. Qxb7 Qd3 8. Qxb8 Qh7 9. Qxc8 Kg6 10. Qe6 *"
        /// King and knight against king, reached by a capture: a draw by insufficient material.
        static let insufficientMaterial = "[SetUp \"1\"]\n[FEN \"4k3/8/8/3n4/8/2N5/8/4K3 w - - 0 1\"]\n\n1. Nxd5 *"
        /// Half-move clock 99 and one quiet move: a draw by the fifty-move rule.
        static let fiftyMoves = "[SetUp \"1\"]\n[FEN \"4k3/8/8/8/8/8/R7/4K3 w - - 99 80\"]\n\n1. Ra3 *"
        /// A declared result with no mate on the board: black wins.
        static let declaredBlackWins = "1. e4 e5 2. Nf3 Nc6 0-1"
        /// One alternative to 1... e5, for the arrows and cards.
        static let arrowsAndCards = "1. e4 e5 (1... c5) 2. Nf3 Nc6 *"
        static let moveStripMiddle = "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 *"
        static let moveStripVariations = "1. e4 e5 (1... c5) 2. Nf3 (2. c3) Nc6 *"
        static let shortGame = "1. e4 e5 2. Nf3 Nc6 *"
        static let commented = "1. e4 {King's pawn} e5 (1... c5 {Sicilian} 2. Nf3 (2. c3 {Alapin}) d6) 2. Nf3 Nc6 3. Bb5 *"
        /// Hebrew and Arabic comments between Latin moves, in a variation and under a row (data in a PGN, not a forced language).
        static let mixedScript = "1. e4 {ملاحظة} e5 (1... c5 {הערה בעברית} 2. Nf3 (2. c3 {Alapin}) d6) 2. Nf3 Nc6 3. Bb5 *"
        static let card = "1. e4 e5 2. Nf3 Nc6 3. Bb5 (3. Bc4 Bc5) a6 4. Bxc6 dxc6 5. O-O f6 *"

        /// The widest rows: white captured fifteen pieces by the position before the last move, and that position has a
        /// variation, so the capture strip is long and the variation cards show (`worstRowSession`).
        /// A Ruy Lopez Closed, Chigorin, sixteen moves each, white to move: the Mac window's move list is full.
        static let middlegame = "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Na5 10. Bc2 c5 11. d4 Qc7 "
            + "12. Nbd2 cxd4 13. cxd4 Nc6 14. Nb3 a5 15. Be3 a4 16. Nbd2 Bd7 *"

        static let worstRow = "1. h4 g5 2. hxg5 d5 3. Rxh7 a5 4. Rxh8 Bh3 5. Rxh3 Bh6 6. Rxh6 f5 7. gxf6 Qd7 8. fxe7 Nc6 9. Rxc6 Qe6 "
            + "10. Rxe6 Rb8 11. Nh3 d4 12. b3 Kd7 13. e4 Ke8 14. f4 Rd8 15. exd8=R+ Kf7 16. Rxg8 b5 17. Bxb5 c5 18. g4 a4 "
            + "19. bxa4 c4 20. Bxc4 d3 21. cxd3 Kxg8 22. Re8+ (22. Re7+) *"

        /// Both sides have captured at least ten pieces: white twelve, black thirteen (past the twelve-piece overlap of the
        /// capture line, under the fifteen maximum). A legal 49-move game, black to have just captured.
        static let manyCaptures = "1. g4 c6 2. Nc3 h5 3. f4 h4 4. e3 c5 5. f5 g6 6. fxg6 fxg6 7. Na4 Na6 8. Nxc5 Nxc5 9. Kf2 Bg7 "
            + "10. Ke2 Bxb2 11. Bxb2 h3 12. Bxh8 Na6 13. Bxh3 g5 14. Kf3 Nc7 15. Kg2 Ne6 16. Rc1 Nh6 17. Qf1 Nxg4 18. Bxg4 b5 "
            + "19. Qxb5 Nc5 20. Qxc5 e5 21. Be2 Qa5 22. Qxe5+ Qxe5 23. Rb1 Qxh2+ 24. Kxh2 Ba6 25. Rd1 Bxe2 26. Nxe2 Kf7 27. e4 Rxh8+ "
            + "28. Kg1 Ra8 29. Rh8 Rxh8 30. Kf1 g4 31. Nc1 Kf6 32. Kf2 Kf7 33. Rh1 Rxh1 34. Ke3 Rxc1 35. c3 Rxc3+ 36. dxc3 Kf6 "
            + "37. a4 Kf7 38. Kf2 Kg7 39. Kf1 Kh8 40. e5 d5 41. a5 Kg8 42. e6 Kh8 43. Ke1 Kg8 44. Kd1 a6 45. Kc1 Kh7 46. Kb1 Kg7 "
            + "47. Ka2 Kf8 48. Kb1 Ke7 49. Ka1 Kxe6 *"

        /// A 62-move game ending in checkmate (White mates on move 62), so the strip shows high move numbers and the result banner
        /// the game end. Black castles queenside on move 20 (ply 39 of `longCheckmateSession(atPly:)`), and White
        /// promotes with a capture on move 47 (`hxg8=Q`, the longest move SAN it has).
        static let longCheckmate = "1. a4 e5 2. b3 d5 3. e3 h5 4. Be2 Nc6 5. Ba3 Qg5 6. Nf3 Bf5 7. Nxg5 Be7 8. g4 Nb4 9. Bb2 hxg4 10. d3 e4 11. Nxe4 "
            + "Bg6 12. Na3 Nc6 13. Ng3 Nf6 14. h4 Bxa3 15. h5 Bxb2 16. a5 Bf5 17. d4 Be4 18. Bd3 Bxa1 19. Rh4 Bc3+ 20. Kf1 O-O-O "
            + "21. Ke2 Bf3+ 22. Kf1 Be2+ 23. Qxe2 Bxa5 24. Bc4 Nb4 25. Bb5 a6 26. c3 axb5 27. Qxg4+ Nxg4 28. Rxg4 Rhf8 29. Nf5 Na2 "
            + "30. Rxg7 Kb8 31. Rg8 c5 32. dxc5 Bxc3 33. Rg7 Rc8 34. h6 Bd4 35. Nxd4 Nc3 36. h7 Ne4 37. Nxb5 b6 38. c6 Ka8 39. c7 "
            + "Nc3 40. Nxc3 d4 41. Ne4 dxe3 42. Nd6 Rce8 43. Nxe8 e2+ 44. Kxe2 Rxe8+ 45. Kf1 Ka7 46. Rg8 Rxg8 47. hxg8=Q f5 48. "
            + "c8=Q b5 49. Qxf5 Kb6 50. Qd8+ Ka6 51. Qa8+ Kb6 52. Qc2 b4 53. Qd3 Kc7 54. Qb5 Kd6 55. Qe4 Kc7 56. Qf4+ Kc8 57. Qg3 "
            + "Kd8 58. Qge5 Kc8 59. f3 Kd8 60. Qh5 Ke7 61. Qbd5 Kf6 62. Qhg5# *"

        /// A Black promotion with capture and check on move 10, from a FEN: the rook walks to d1 over nine moves while the
        /// black king shuffles, and the e2 pawn takes it (`10\u{2026}exd1=Q+`, a two-digit move number like the budget's `62\u{2026}exd1=Q+`:
        /// the engine numbers the moves from the start of the game, so a FEN cannot start at move 62). It has the alternative
        /// `10... e1=Q+`, so the strip's variation badge is on the page.
        static let blackPromotion = "[SetUp \"1\"]\n[FEN \"7k/8/8/8/8/8/4p3/R5K1 w - - 0 1\"]\n\n"
            + "1. Ra3 Kg8 2. Rb3 Kh8 3. Rb4 Kg8 4. Rc4 Kh8 5. Rc5 Kg8 6. Rd5 Kh8 7. Rd6 Kg8 8. Rd7 Kh8 9. Rd4 Kg8 10. Rd1 exd1=Q+ (10... e1=Q+) *"
        /// The same moves without the alternative: no variation badge.
        static let blackPromotionPlain = "[SetUp \"1\"]\n[FEN \"7k/8/8/8/8/8/4p3/R5K1 w - - 0 1\"]\n\n"
            + "1. Ra3 Kg8 2. Rb3 Kh8 3. Rb4 Kg8 4. Rc4 Kh8 5. Rc5 Kg8 6. Rd5 Kh8 7. Rd6 Kg8 8. Rd7 Kh8 9. Rd4 Kg8 10. Rd1 exd1=Q+ *"

        static let allPGNs = [ruyLopez, empty, openingE4E5, captures, yourMove, checkmate, whiteMates, stalemate,
                              insufficientMaterial, fiftyMoves, declaredBlackWins, arrowsAndCards,
                              moveStripMiddle, moveStripVariations, shortGame, commented, mixedScript, card, worstRow, middlegame,
                              manyCaptures, longCheckmate, blackPromotion, blackPromotionPlain]
    }
}
