//
//  GalleryScenarios.swift
//  BChessGalleryTests
//
//  Every screen state the gallery renders, set up once, in the order of the page. The app has no preview
//  macro: this list is the one source, `SnapshotGalleryTests` renders it in light and dark, and
//  scripts/snapshot-gallery.sh builds the page from the manifest the test writes.
//
//  Rules (scripts/preview-gallery.py --check enforces the last):
//  - a name is "Screen · State" and unique; the slug is derived from it
//  - every PGN a scenario loads is a constant of `Fixture`, so a test can parse each one
//  - no forced appearance or locale in this file
//

import SwiftUI
@testable import BChess

/// The size a card renders at. The phone sizes follow the hosting scene's screen (402 x 874 on the pool's iPhone
/// 17 Pro, 466 x 678 on a folded iPhone Duo) and keep the scene's own size classes; the others are fixed windows
/// with the size classes of the device they stand for.
enum GallerySize: Equatable {
    /// The hosting scene's screen.
    case phone
    /// 375 x 667.
    case smallPhone
    /// 1180 x 820, regular / regular.
    case ipadLandscape
    /// The Duo's inner display in landscape, 951 x 669, regular / regular, the hinge vertical.
    case duoInnerLandscape
    /// The Duo's inner display in portrait, 669 x 951, regular / regular, the hinge horizontal (tabletop pose).
    case duoInnerPortrait

    /// The window size in points; `screen` is the hosting scene's screen in its portrait orientation.
    func points(screen: CGSize) -> CGSize {
        switch self {
        case .phone: return screen
        case .smallPhone: return CGSize(width: 375, height: 667)
        case .ipadLandscape: return CGSize(width: 1180, height: 820)
        case .duoInnerLandscape: return CGSize(width: 951, height: 669)
        case .duoInnerPortrait: return CGSize(width: 669, height: 951)
        }
    }

    /// The size classes forced on the window and the host; nil keeps the scene's own.
    var sizeClasses: (horizontal: UIUserInterfaceSizeClass, vertical: UIUserInterfaceSizeClass)? {
        switch self {
        case .phone, .smallPhone: return nil
        case .ipadLandscape, .duoInnerLandscape, .duoInnerPortrait: return (.regular, .regular)
        }
    }

    /// The capture scale: the Duo's displays are 3x, so the inner sizes and every capture of the Duo pass use 3.
    func scale(duoPass: Bool) -> CGFloat {
        duoPass || isDuoInner ? 3 : 2
    }

    var isDuoInner: Bool {
        self == .duoInnerLandscape || self == .duoInnerPortrait
    }

    /// The manifest field, and the folder of the card in the gallery.
    var platform: String {
        isDuoInner ? "duo-inner" : "iphone"
    }
}

/// One named screen state: the card title, the page section, the render size and how long to let it settle.
@MainActor
struct GalleryScenario {
    let name: String
    let group: String
    var size = GallerySize.phone
    /// How long the render waits for onAppear, tasks and List layout before the picture is taken.
    var settle: Duration = .milliseconds(400)
    /// The scenario mounts the production shell, whose navigation and bottom bars the system places itself.
    var usesSystemBars = false
    /// The card is dark in both appearances by design (a document canvas, full-bleed imagery): `--check` then judges
    /// the pair (the dark image at least 0.05 mean luminance below the light one) instead of each image.
    var documentCanvas = false
    /// The screen draws nothing by design: `--check` accepts its blank images (otherwise a blank render fails).
    var drawsNothing = false
    /// Throws when a fixture cannot be set up, which fails the render.
    let build: @MainActor () throws -> AnyView

    /// Why this card cannot be rendered honestly on the pass, or nil. A skipped card is listed in the manifest with
    /// the reason and has no images: a capture the harness cannot place never passes as coverage.
    func skipReason(duoPass: Bool) -> String? {
        guard duoPass else { return nil }
        if usesSystemBars && size.isDuoInner {
            return "the folded Duo places the system bars against its own 466 x 678 screen, not the 951 x 669 window"
        }
        return nil
    }

    /// The file name stem of the card: "Game screen · Tall" is "game-screen-tall".
    var slug: String { Self.slug(of: name) }

    static func slug(of name: String) -> String {
        let folded = name.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        let mapped = folded.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "-" }
        return String(mapped).split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
    }

    /// Isolated settings: every @AppStorage reads its declared default, and nothing writes the app's
    /// real defaults.
    func view() throws -> some View {
        try build().defaultAppStorage(GalleryScenarios.defaults)
    }
}

extension View {
    /// The Walnut background over the whole render, not just behind the content.
    fileprivate func walnutBackdrop() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Walnut.background.ignoresSafeArea())
    }
}

@MainActor
enum GalleryScenarios {
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
        static let card = "1. e4 e5 2. Nf3 Nc6 3. Bb5 (3. Bc4 Bc5) a6 4. Bxc6 dxc6 5. O-O f6 *"

        /// The widest rows: white captured fifteen pieces by the position before the last move, and that position has a
        /// variation, so the capture strip is long and the variation cards show (`worstRowSession`).
        static let worstRow = "1. h4 g5 2. hxg5 d5 3. Rxh7 a5 4. Rxh8 Bh3 5. Rxh3 Bh6 6. Rxh6 f5 7. gxf6 Qd7 8. fxe7 Nc6 9. Rxc6 Qe6 "
            + "10. Rxe6 Rb8 11. Nh3 d4 12. b3 Kd7 13. e4 Ke8 14. f4 Rd8 15. exd8=R+ Kf7 16. Rxg8 b5 17. Bxb5 c5 18. g4 a4 "
            + "19. bxa4 c4 20. Bxc4 d3 21. cxd3 Kxg8 22. Re8+ (22. Re7+) *"

        static let allPGNs = [ruyLopez, empty, openingE4E5, captures, yourMove, checkmate, arrowsAndCards,
                              moveStripMiddle, moveStripVariations, shortGame, commented, card, worstRow]
    }

    // MARK: Fixtures

    /// White (human) is to move, so `requestEngineMoveIfNeeded` returns and no search starts
    /// (`GalleryScenarioTests` checks it).
    static func humanToMoveSession() -> GameSession {
        GameSession(state: GameState(pgn: Fixture.ruyLopez))
    }

    /// A library of a few games from fixed times of day. It never touches the real defaults.
    /// A filesystem error throws, so it fails the scenario instead of photographing an empty card.
    static func gamesShell() throws -> GameShell {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Gallery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let library = GameLibrary(directory: directory, defaults: defaults)
        // Calendar arithmetic, so a daylight-saving change cannot move a time of day
        let calendar = Calendar.current
        func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: .now))!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }
        let games: [(String, Date)] = [
            ("You vs Computer", date(daysAgo: 0, hour: 9, minute: 30)),
            ("Ruy Lopez practice", date(daysAgo: 0, hour: 9, minute: 0)),
            ("Anna vs Jean", date(daysAgo: 1, hour: 18, minute: 15)),
            ("Imported game", date(daysAgo: 9, hour: 11, minute: 0)),
        ]
        for (name, date) in games {
            let file = try library.create(GameState(pgn: Fixture.empty), baseName: name)
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.url.path)
        }
        library.reload()
        return try GameShell(library: library)
    }

    /// The production shell on an empty library (the launch screen), with the fold's region when given.
    /// A filesystem error throws, so it fails the scenario.
    static func emptyLibraryShell(fold: FoldRegion? = nil) throws -> AnyView {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Gallery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return AnyView(GameRootView(library: GameLibrary(directory: directory, defaults: defaults), foldRegions: fold.map { [$0] }))
    }

    // MARK: Scenarios

    private static func boardFrame(_ state: GameState? = nil) -> some View {
        let session = state.map { GameSession(state: $0) } ?? GameSession()
        return BoardFrame(session: session) {
            BoardView(session: session)
        }
        .padding()
    }

    private static func piecesOnBoard(_ session: GameSession) -> some View {
        ZStack {
            BoardView(session: session)
            PiecesView(session: session)
        }
    }

    static let groupDuo = "iPhone Duo · inner display"

    // Game
    static let gameScreenTall = GalleryScenario(name: "Game screen · Tall", group: "Game") {
        AnyView(ContentView(session: humanToMoveSession()))
    }
    // iPad landscape
    static let gameScreenWide = GalleryScenario(name: "Game screen · Wide", group: "Game", size: .ipadLandscape) {
        AnyView(ContentView(session: humanToMoveSession())
            .frame(width: 1180, height: 820))
    }
    static let gameScreenAnalyze = GalleryScenario(name: "Game screen · Analyze", group: "Game") {
        AnyView(ContentView(session: GameSession(mode: GameMode(value: .analyze))))
    }
    /// The engine readout on, over a live analysis of the position: the evaluation bar beside the board and the
    /// engine card under the moves. The numbers come from the real engine, so they differ from run to run.
    static let gameScreenEngineOn = GalleryScenario(name: "Game screen · Engine on", group: "Game", settle: .seconds(2)) {
        AnyView(ContentView(session: humanToMoveSession())
            .defaultAppStorage(engineOnDefaults))
    }
    static let gameScreenTrain = GalleryScenario(name: "Game screen · Train", group: "Game") {
        AnyView(ContentView(session: GameSession(mode: GameMode(value: .train))))
    }
    static let gameScreenRotated = GalleryScenario(name: "Game screen · Rotated", group: "Game") {
        AnyView(ContentView(session: GameSession(state: GameState(pgn: Fixture.empty, rotated: true))))
    }
    static let playerRowToMove = GalleryScenario(name: "Player row · To move", group: "Game") {
        AnyView(VStack(alignment: .leading) {
            PlayerRow(session: GameSession(state: GameState(pgn: Fixture.openingE4E5, white: .human, black: .human)), isWhite: false)
            PlayerRow(session: GameSession(state: GameState(pgn: Fixture.openingE4E5, white: .human, black: .human)), isWhite: true)
        })
    }
    static let playerRowCaptures = GalleryScenario(name: "Player row · Captures", group: "Game") {
        AnyView(VStack(alignment: .leading) {
            PlayerRow(session: GameSession(state: GameState(pgn: Fixture.captures)), isWhite: false)
            PlayerRow(session: GameSession(state: GameState(pgn: Fixture.captures)), isWhite: true)
        })
    }
    static let statusLineYourMove = GalleryScenario(name: "Status line · Your move", group: "Game") {
        AnyView(StatusLine(session: GameSession(state: GameState(pgn: Fixture.yourMove))))
    }
    static let statusLineCheckmate = GalleryScenario(name: "Status line · Checkmate", group: "Game") {
        AnyView(StatusLine(session: GameSession(state: GameState(pgn: Fixture.checkmate, white: .human, black: .human))))
    }
    static let navigationButtons = GalleryScenario(name: "Navigation buttons", group: "Game") {
        AnyView(HStack {
            NavigationButtons(session: GameSession(state: GameState(pgn: Fixture.yourMove)))
        }
        .padding())
    }

    // iPhone Duo · inner display. The regions are the stand-in hinge in the content's coordinates (the window minus
    // the 16 pt padding): 40 pt wide at the window's centre, the width the reference gives. The real frame is read
    // off a device in Device Hub later and these are updated then. Only the source of the regions is injected.
    static let duoLandscapeHinge = FoldRegion(frame: CGRect(x: 439.5, y: 0, width: 40, height: 637), isActive: true)
    static let duoLandscapeSeam = FoldRegion(frame: CGRect(x: 439.5, y: 0, width: 40, height: 637), isActive: false)
    static let duoPortraitTabletop = FoldRegion(frame: CGRect(x: 0, y: 439.5, width: 637, height: 40), isActive: true)
    static let duoPortraitFlat = FoldRegion(frame: CGRect(x: 0, y: 439.5, width: 637, height: 40), isActive: false)

    /// Two humans on the arrows-and-cards game, on the position that has variation arrows and cards.
    static func variationsSession() -> GameSession {
        let session = GameSession(state: GameState(pgn: Fixture.arrowsAndCards, white: .human, black: .human))
        session.move(to: .start)
        session.move(to: .forward)
        session.move(to: .forward)
        return session
    }

    /// Two humans on the worst-row game, on the position before its last move: fifteen white captures and the
    /// variation cards offered.
    static func worstRowSession() -> GameSession {
        let session = GameSession(state: GameState(pgn: Fixture.worstRow, white: .human, black: .human))
        session.move(to: .end)
        session.move(to: .backward)
        // Forward from a position with two continuations offers them
        session.move(to: .forward)
        return session
    }

    /// The game screen in a bare window, as the scenarios and the oracle tests build it: it ignores the safe area
    /// (the fixed windows stand on a phone screen whose insets belong to no inner display), so the content starts
    /// 16 pt inside the window on every side and the fixtures' coordinates hold. Without a fold, none is injected.
    static func gameScreen(_ session: GameSession, fold: FoldRegion?) -> AnyView {
        AnyView(ContentView(session: session, foldRegions: fold.map { [$0] }).ignoresSafeArea())
    }

    static let duoLandscapeGame = GalleryScenario(name: "Duo inner · Landscape · Game screen", group: groupDuo, size: .duoInnerLandscape) {
        gameScreen(humanToMoveSession(), fold: duoLandscapeHinge)
    }
    static let duoLandscapeFlatOpen = GalleryScenario(name: "Duo inner · Landscape · Flat open", group: groupDuo, size: .duoInnerLandscape) {
        gameScreen(humanToMoveSession(), fold: duoLandscapeSeam)
    }
    static let duoLandscapeVariations = GalleryScenario(name: "Duo inner · Landscape · Variations", group: groupDuo, size: .duoInnerLandscape) {
        gameScreen(variationsSession(), fold: duoLandscapeHinge)
    }
    // The production shell with its navigation and bottom bars (horizontal in a fixed window: the vertical side bars
    // exist only on the real inner display). The region is the same stand-in: only its x range and shape matter here.
    static let duoLandscapeShell = GalleryScenario(name: "Duo inner · Landscape · Shell", group: groupDuo, size: .duoInnerLandscape, settle: .seconds(1), usesSystemBars: true) {
        try emptyLibraryShell(fold: duoLandscapeHinge)
    }
    static let duoPortraitGame = GalleryScenario(name: "Duo inner · Portrait · Game screen", group: groupDuo, size: .duoInnerPortrait) {
        gameScreen(humanToMoveSession(), fold: duoPortraitFlat)
    }
    static let duoPortraitTabletopCard = GalleryScenario(name: "Duo inner · Portrait · Tabletop", group: groupDuo, size: .duoInnerPortrait) {
        gameScreen(humanToMoveSession(), fold: duoPortraitTabletop)
    }
    static let duoPortraitTabletopVariations = GalleryScenario(name: "Duo inner · Portrait · Tabletop · Variations", group: groupDuo, size: .duoInnerPortrait) {
        gameScreen(variationsSession(), fold: duoPortraitTabletop)
    }

    // Board
    static let boardWhiteAtTheBottom = GalleryScenario(name: "Board · White at the bottom", group: "Board") {
        AnyView(boardFrame())
    }
    static let boardLabelsRotated = GalleryScenario(name: "Board labels · Rotated", group: "Board") {
        AnyView(boardFrame(GameState(pgn: Fixture.empty, rotated: true)))
    }
    static let piecesWhiteAtTheBottom = GalleryScenario(name: "Pieces · White at the bottom", group: "Board") {
        AnyView(piecesOnBoard(GameSession()))
    }
    static let piecesRotated = GalleryScenario(name: "Pieces · Rotated", group: "Board") {
        AnyView(piecesOnBoard(GameSession(state: GameState(pgn: Fixture.empty, rotated: true))))
    }
    static let promotionDropsFromTheTop = GalleryScenario(name: "Promotion · Drops from the top", group: "Board") {
        AnyView(ZStack {
            BoardView(session: GameSession())
            PromotionView(promotion: Promotion(move: FEngineMove(), isWhite: true),
                          squareSize: 44, screenFile: 6, screenRow: 0) { _ in }
        }
        .frame(width: 352, height: 352))
    }
    static let promotionRisesFromTheBottom = GalleryScenario(name: "Promotion · Rises from the bottom", group: "Board") {
        AnyView(ZStack {
            BoardView(session: GameSession())
            PromotionView(promotion: Promotion(move: FEngineMove(), isWhite: false),
                          squareSize: 44, screenFile: 2, screenRow: 7) { _ in }
        }
        .frame(width: 352, height: 352))
    }
    static let variationsArrowsAndCards = GalleryScenario(name: "Variations · Arrows and cards", group: "Board") {
        let session = variationsSession()
        return AnyView(VStack {
            ZStack {
                BoardView(session: session)
                PiecesView(session: session)
                VariationSelectionView(session: session)
            }
            .frame(width: 330, height: 330)
            VariationCards(session: session)
        }
        .padding()
        .walnutBackdrop())
    }
    static let arrow = GalleryScenario(name: "Arrow", group: "Board") {
        AnyView(GeometryReader { geometry in
            let p = Arrow(start: CGPoint(x: 10, y: 10),
                          end: CGPoint(x: geometry.size.width - 20, y: geometry.size.height - 20),
                          length: 20).path
            p.fill(Color.blue)
            p.stroke(Color.blue, lineWidth: 10)
        })
    }

    // Engine
    static let engineEqual = GalleryScenario(name: "Engine · Equal", group: "Engine") {
        AnyView(EngineView(verdict: Verdict(centipawns: 10, isMate: false), line: "9. h3 d5 10. exd5")
            .padding())
    }
    static let engineSlightlyBetter = GalleryScenario(name: "Engine · Slightly better", group: "Engine") {
        AnyView(EngineView(verdict: Verdict(centipawns: -60, isMate: false), line: "9. h3 d5 10. exd5")
            .padding())
    }
    static let engineMate = GalleryScenario(name: "Engine · Mate", group: "Engine") {
        AnyView(EngineView(verdict: Verdict(centipawns: 100_000, isMate: true), line: "Qh7#")
            .padding())
    }
    static let engineAnalyzing = GalleryScenario(name: "Engine · Analyzing", group: "Engine") {
        AnyView(EngineView(verdict: nil, line: "")
            .padding())
    }
    static let engineStatistics = GalleryScenario(name: "Engine · Statistics", group: "Engine") {
        AnyView(EngineView(verdict: Verdict(centipawns: 120, isMate: false), line: "9. h3 d5 10. exd5",
                           statistics: "Depth 9/12 with 1,234,567 nodes at 410,000 n/s")
            .padding())
    }
    static let engineLongLine = GalleryScenario(name: "Engine · Long line", group: "Engine") {
        AnyView(EngineView(verdict: Verdict(centipawns: 60, isMate: false),
                           line: "6. d4 exd4 7. Qxd4 Qxd4 8. Nxd4 Nc6 9. Nxc6 bxc6 10. Bd3")
            .frame(width: 300)
            .padding())
    }
    static let engineWide = GalleryScenario(name: "Engine · Wide", group: "Engine") {
        AnyView(EngineView(verdict: Verdict(centipawns: 40, isMate: false), line: "6. d4 exd4 7. Qxd4 Qxd4 8. Nxd4",
                           statistics: "Depth 9/14 \u{00B7} 1,234,567 nodes \u{00B7} 410,000 n/s", wide: true)
            .padding())
    }
    static let engineEvaluationBars = GalleryScenario(name: "Engine · Evaluation bars", group: "Engine") {
        AnyView(VStack {
            EngineView(verdict: Verdict(centipawns: 40, isMate: false), line: "6. d4 exd4 7. Qxd4")
            EngineView(verdict: Verdict(centipawns: 40, isMate: false), line: "6. d4 exd4 7. Qxd4 Qxd4 8. Nxd4",
                       statistics: "Depth 9/14", wide: true)
            HStack {
                EvaluationBar(verdict: Verdict(centipawns: 40, isMate: false), rotated: false)
                EvaluationBar(verdict: Verdict(centipawns: -200, isMate: false), rotated: true)
            }
            .frame(height: 200)
        }
        .padding()
        .walnutBackdrop())
    }

    // Moves
    static let moveStripStart = GalleryScenario(name: "Move strip · Start", group: "Moves") {
        AnyView(MoveStrip(session: GameSession(), showAll: {})
            .padding())
    }
    static let moveStripMiddle = GalleryScenario(name: "Move strip · Middle", group: "Moves") {
        AnyView(MoveStrip(session: GameSession(state: GameState(pgn: Fixture.moveStripMiddle)), showAll: {})
            .padding())
    }
    static let moveStripWithVariations = GalleryScenario(name: "Move strip · With variations", group: "Moves") {
        AnyView(MoveStrip(session: GameSession(state: GameState(pgn: Fixture.moveStripVariations)), showAll: {})
            .padding())
    }
    static let moveListShortGame = GalleryScenario(name: "Move list · Short game", group: "Moves") {
        AnyView(MoveListView(session: GameSession(state: GameState(pgn: Fixture.shortGame))))
    }
    static let moveListVariationsAndComments = GalleryScenario(name: "Move list · Variations and comments", group: "Moves") {
        AnyView(MoveListView(session: GameSession(state: GameState(pgn: Fixture.commented))))
    }
    static let moveListCard = GalleryScenario(name: "Move list · Card", group: "Moves") {
        AnyView(MoveListView(session: GameSession(state: GameState(pgn: Fixture.card)), card: true)
            .padding()
            .frame(width: 320, height: 400)
            .walnutBackdrop())
    }

    // Games list
    static let gamesListFourGames = GalleryScenario(name: "Games list · Four games", group: "Games list", settle: .seconds(1)) {
        AnyView(GamesList(shell: try gamesShell(), attempt: { _ in }, onNewGame: {}, actionError: .constant(nil)))
    }
    static let gamesListSmallPhone = GalleryScenario(name: "Games list · Small iPhone", group: "Games list", size: .smallPhone, settle: .seconds(1)) {
        AnyView(GamesList(shell: try gamesShell(), attempt: { _ in }, onNewGame: {}, actionError: .constant(nil)))
    }
    static let launchEmptyLibrary = GalleryScenario(name: "Launch · Empty library", group: "Games list", settle: .seconds(1), usesSystemBars: true) {
        try emptyLibraryShell()
    }
    // The New Game sheet, from its choice: the caller reads the remembered one, so a scenario can open on any opponent.
    // The Mac layout has no card until the Mac renderer exists.
    static let newGameClub = GalleryScenario(name: "New game · Club", group: "Games list") {
        AnyView(NewGameSheet(choice: NewGame(), mode: .new, onDone: { _ in }))
    }
    static let newGameFriend = GalleryScenario(name: "New game · A friend", group: "Games list") {
        var choice = NewGame()
        choice.opponent = .friend
        return AnyView(NewGameSheet(choice: choice, mode: .new, onDone: { _ in }))
    }
    static let newGameMaximum = GalleryScenario(name: "New game · Maximum", group: "Games list") {
        var choice = NewGame()
        choice.opponent = .maximum
        choice.thinkingTime = 10
        return AnyView(NewGameSheet(choice: choice, mode: .new, onDone: { _ in }))
    }
    static let newGamePlayers = GalleryScenario(name: "New game · Players", group: "Games list") {
        AnyView(NewGameSheet(choice: NewGame(white: .human, black: .computer(.club)), mode: .edit, onDone: { _ in }))
    }

    // Settings
    static let settings = GalleryScenario(name: "Settings", group: "Settings") {
        // The sheet on the iPhone sits in a navigation stack, which carries the title
        AnyView(NavigationStack { SettingsView() })
    }

    // Walnut
    static let walnutPalette = GalleryScenario(name: "Walnut · Palette", group: "Walnut") {
        AnyView(VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    (i % 2 == 0 ? Walnut.lightSquare : Walnut.darkSquare).frame(width: 30, height: 30)
                }
            }
            .padding(8)
            .background(Walnut.frame)
            Text("Primary").foregroundStyle(Walnut.textPrimary)
            Text("Secondary").foregroundStyle(Walnut.textSecondary)
            Text("5…f6").padding(.horizontal, 10).padding(.vertical, 6).currentMovePill(true)
            Text("Card").padding().walnutCard()
            Button("Accent") {}
        }
        .padding()
        .walnutBackdrop())
    }

    /// In the order of the page: the groups, and the cards of each group.
    static let all: [GalleryScenario] = [
        gameScreenTall, gameScreenWide, gameScreenAnalyze, gameScreenEngineOn, gameScreenTrain, gameScreenRotated,
        playerRowToMove, playerRowCaptures,
        statusLineYourMove, statusLineCheckmate,
        navigationButtons,
        duoLandscapeGame, duoLandscapeFlatOpen, duoLandscapeVariations, duoLandscapeShell,
        duoPortraitGame, duoPortraitTabletopCard, duoPortraitTabletopVariations,
        boardWhiteAtTheBottom, boardLabelsRotated,
        piecesWhiteAtTheBottom, piecesRotated,
        promotionDropsFromTheTop, promotionRisesFromTheBottom,
        variationsArrowsAndCards,
        arrow,
        engineEqual, engineSlightlyBetter, engineMate, engineAnalyzing, engineStatistics, engineLongLine, engineWide, engineEvaluationBars,
        moveStripStart, moveStripMiddle, moveStripWithVariations,
        moveListShortGame, moveListVariationsAndComments, moveListCard,
        gamesListFourGames, gamesListSmallPhone, launchEmptyLibrary, newGameClub, newGameFriend, newGameMaximum, newGamePlayers,
        settings,
        walnutPalette,
    ]

    /// The scenarios whose name or slug contains one of the comma-separated, case-insensitive patterns;
    /// an empty filter is every scenario.
    static func matching(_ filter: String) -> [GalleryScenario] {
        let patterns = filter.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        guard !patterns.isEmpty else { return all }
        return all.filter { scenario in
            patterns.contains { scenario.name.lowercased().contains($0) || scenario.slug.contains($0) }
        }
    }
}
