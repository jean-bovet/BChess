//
//  GalleryFixtures.swift
//  BChessGalleryTests
//
//  What the iOS and the Mac gallery targets share: the scratch preference suites, the PGN fixtures, and the rules
//  that name and filter a scenario. Compiled by `BChessGalleryTests` and `BChessMacGalleryTests`; each declares its
//  own `GalleryScenarios` enum (the list of its screens).
//

import Foundation

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
    let platform: String
    /// Why the card has no images on this pass (nil: it has); the page shows it, `--check` accepts the gap.
    var skipped: String?
    /// The scenario's `documentCanvas`, `drawsNothing` and `imagery`, written only when set (`--check` reads them).
    var documentCanvas: Bool?
    var drawsNothing: Bool?
    var imagery: Bool?
    /// True for the Duo's inner-display sizes, captured at 3x on every pass (`--check` expects that scale).
    var duoInner: Bool?
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

        static let allPGNs = [ruyLopez, empty, openingE4E5, captures, yourMove, checkmate, arrowsAndCards,
                              moveStripMiddle, moveStripVariations, shortGame, commented, mixedScript, card, worstRow, middlegame]
    }
}
