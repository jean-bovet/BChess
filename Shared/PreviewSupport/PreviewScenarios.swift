//
//  PreviewScenarios.swift
//  Shared
//
//  Every screen state that has a #Preview is set up here, once. The #Preview calls its scenario,
//  and BChessGalleryTests renders the same scenarios in light and dark (scripts/snapshot-gallery.sh).
//
//  Conventions that scripts/preview-gallery.py --check enforces:
//  - one declaration per line start: `static let <ident> = PreviewScenario(file: "<file>", name: "<name>"`
//  - file and name are exactly the file basename and the #Preview name
//  - the #Preview body is exactly `PreviewScenarios.<ident>.view()`
//  - no forced appearance or locale in this file
//

#if DEBUG
import SwiftUI

/// One named screen state, set up in one place: its `#Preview` and the gallery
/// (`BChessGalleryTests`) both render it.
struct PreviewScenario {
    /// The file holding the `#Preview`, e.g. "ContentView.swift".
    let file: String
    /// Exactly the `#Preview` name.
    let name: String
    /// Points; nil is the iPhone screen.
    var size: CGSize? = nil
    /// False keeps the `#Preview` for Xcode but leaves the card out of the gallery.
    var gallery = true
    let build: @MainActor () -> AnyView

    /// Isolated settings for both callers (Xcode previews and the gallery): every @AppStorage
    /// reads its declared default, and nothing writes the app's real defaults.
    @MainActor func view() -> some View {
        build().defaultAppStorage(PreviewScenarios.defaults)
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
enum PreviewScenarios {
    /// A scratch suite, emptied once per process, shared by the @AppStorage of every scenario and by
    /// the fixture libraries.
    static let defaults: UserDefaults = {
        let suite = UserDefaults(suiteName: "BChessPreviews")!
        suite.removePersistentDomain(forName: "BChessPreviews")
        return suite
    }()

    // MARK: ContentView

    /// White (human) is to move, so `requestEngineMoveIfNeeded` returns and no search starts
    /// (`PreviewScenarioTests` checks it).
    static func humanToMoveSession() -> GameSession {
        GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *"))
    }

    static let contentTall = PreviewScenario(file: "ContentView.swift", name: "Tall") {
        AnyView(ContentView(session: humanToMoveSession()))
    }
    // iPad landscape
    static let contentWide = PreviewScenario(file: "ContentView.swift", name: "Wide", size: CGSize(width: 1180, height: 820)) {
        AnyView(ContentView(session: humanToMoveSession())
            .frame(width: 1180, height: 820))
    }
    static let contentAnalyze = PreviewScenario(file: "ContentView.swift", name: "Analyze") {
        AnyView(ContentView(session: GameSession(mode: GameMode(value: .analyze))))
    }
    static let contentTrain = PreviewScenario(file: "ContentView.swift", name: "Train") {
        AnyView(ContentView(session: GameSession(mode: GameMode(value: .train))))
    }
    static let contentRotated = PreviewScenario(file: "ContentView.swift", name: "Rotated") {
        AnyView(ContentView(session: GameSession(state: GameState(pgn: "*", rotated: true))))
    }

    // MARK: Settings

    static let settings = PreviewScenario(file: "SettingsView.swift", name: "Settings") {
        #if os(iOS)
        // The sheet on the iPhone sits in a navigation stack, which carries the title
        AnyView(NavigationStack { SettingsView() })
        #else
        AnyView(SettingsView())
        #endif
    }

    // MARK: PlayerRow

    static let playerRowToMove = PreviewScenario(file: "PlayerRow.swift", name: "To move") {
        AnyView(VStack(alignment: .leading) {
            PlayerRow(session: GameSession(state: GameState(pgn: "1. e4 e5 *", white: .human, black: .human)), isWhite: false)
            PlayerRow(session: GameSession(state: GameState(pgn: "1. e4 e5 *", white: .human, black: .human)), isWhite: true)
        })
    }
    static let playerRowCaptures = PreviewScenario(file: "PlayerRow.swift", name: "Captures") {
        AnyView(VStack(alignment: .leading) {
            PlayerRow(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *")), isWhite: false)
            PlayerRow(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *")), isWhite: true)
        })
    }

    // MARK: StatusLine

    static let statusLineYourMove = PreviewScenario(file: "StatusLine.swift", name: "Your move") {
        AnyView(StatusLine(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 *"))))
    }
    static let statusLineCheckmate = PreviewScenario(file: "StatusLine.swift", name: "Checkmate") {
        AnyView(StatusLine(session: GameSession(state: GameState(pgn: "1. f3 e5 2. g4 Qh4# *", white: .human, black: .human))))
    }

    // MARK: NavigationButtons

    static let navigationButtons = PreviewScenario(file: "NavigationButtons.swift", name: "Navigation", gallery: false) {
        AnyView(HStack {
            NavigationButtons(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 *")))
        }
        .padding())
    }

    // MARK: BoardView

    private static func boardFrame(_ state: GameState? = nil) -> some View {
        let session = state.map { GameSession(state: $0) } ?? GameSession()
        return BoardFrame(session: session) {
            BoardView(session: session)
        }
        .padding()
    }

    static let board = PreviewScenario(file: "BoardView.swift", name: "Board") {
        AnyView(boardFrame())
    }

    // MARK: LabelsView

    static let labelsWhiteAtTheBottom = PreviewScenario(file: "LabelsView.swift", name: "White at the bottom") {
        AnyView(boardFrame())
    }
    static let labelsRotated = PreviewScenario(file: "LabelsView.swift", name: "Rotated") {
        AnyView(boardFrame(GameState(pgn: "*", rotated: true)))
    }

    // MARK: PiecesView

    static let piecesWhiteAtTheBottom = PreviewScenario(file: "PiecesView.swift", name: "White at the bottom") {
        let session = GameSession()
        return AnyView(ZStack {
            BoardView(session: session)
            PiecesView(session: session)
        })
    }
    static let piecesRotated = PreviewScenario(file: "PiecesView.swift", name: "Rotated") {
        let session = GameSession(state: GameState(pgn: "*", rotated: true))
        return AnyView(ZStack {
            BoardView(session: session)
            PiecesView(session: session)
        })
    }

    // MARK: PromotionView

    static let promotionDropsFromTheTop = PreviewScenario(file: "PromotionView.swift", name: "Drops from the top") {
        AnyView(ZStack {
            BoardView(session: GameSession())
            PromotionView(promotion: Promotion(move: FEngineMove(), isWhite: true),
                          squareSize: 44, screenFile: 6, screenRow: 0) { _ in }
        }
        .frame(width: 352, height: 352))
    }
    static let promotionRisesFromTheBottom = PreviewScenario(file: "PromotionView.swift", name: "Rises from the bottom") {
        AnyView(ZStack {
            BoardView(session: GameSession())
            PromotionView(promotion: Promotion(move: FEngineMove(), isWhite: false),
                          squareSize: 44, screenFile: 2, screenRow: 7) { _ in }
        }
        .frame(width: 352, height: 352))
    }

    // MARK: VariationSelectionView

    static let variationArrowsAndCards = PreviewScenario(file: "VariationSelectionView.swift", name: "Arrows and cards") {
        let session = GameSession(state: GameState(pgn: "1. e4 e5 (1... c5) 2. Nf3 Nc6 *", white: .human, black: .human))
        session.move(to: .start)
        session.move(to: .forward)
        session.move(to: .forward)
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

    // MARK: Arrow

    static let arrow = PreviewScenario(file: "Arrow.swift", name: "Arrow", gallery: false) {
        AnyView(GeometryReader { geometry in
            let p = Arrow(start: CGPoint(x: 10, y: 10),
                          end: CGPoint(x: geometry.size.width - 20, y: geometry.size.height - 20),
                          length: 20).path
            p.fill(Color.blue)
            p.stroke(Color.blue, lineWidth: 10)
        })
    }

    // MARK: EngineView

    static let engineEqual = PreviewScenario(file: "EngineView.swift", name: "Equal") {
        AnyView(EngineView(verdict: Verdict(centipawns: 10, isMate: false), line: "9. h3 d5 10. exd5")
            .padding())
    }
    static let engineSlightlyBetter = PreviewScenario(file: "EngineView.swift", name: "Slightly better") {
        AnyView(EngineView(verdict: Verdict(centipawns: -60, isMate: false), line: "9. h3 d5 10. exd5")
            .padding())
    }
    static let engineMate = PreviewScenario(file: "EngineView.swift", name: "Mate") {
        AnyView(EngineView(verdict: Verdict(centipawns: 100_000, isMate: true), line: "Qh7#")
            .padding())
    }
    static let engineAnalyzing = PreviewScenario(file: "EngineView.swift", name: "Analyzing") {
        AnyView(EngineView(verdict: nil, line: "")
            .padding())
    }
    static let engineStatistics = PreviewScenario(file: "EngineView.swift", name: "Statistics") {
        AnyView(EngineView(verdict: Verdict(centipawns: 120, isMate: false), line: "9. h3 d5 10. exd5",
                           statistics: "Depth 9/12 with 1,234,567 nodes at 410,000 n/s")
            .padding())
    }
    static let engineStacked = PreviewScenario(file: "EngineView.swift", name: "Stacked") {
        AnyView(EngineView(verdict: Verdict(centipawns: 40, isMate: false), line: "6. d4 exd4 7. Qxd4 Qxd4 8. Nxd4",
                           statistics: "Depth 9/14 \u{00B7} 1,234,567 nodes \u{00B7} 410,000 n/s", stacked: true)
            .padding())
    }
    static let engineEvaluationBars = PreviewScenario(file: "EngineView.swift", name: "Evaluation bars") {
        AnyView(VStack {
            EngineView(verdict: Verdict(centipawns: 40, isMate: false), line: "6. d4 exd4 7. Qxd4")
            EngineView(verdict: Verdict(centipawns: 40, isMate: false), line: "6. d4 exd4 7. Qxd4 Qxd4 8. Nxd4",
                       statistics: "Depth 9/14", stacked: true)
            HStack {
                EvaluationBar(verdict: Verdict(centipawns: 40, isMate: false), rotated: false)
                EvaluationBar(verdict: Verdict(centipawns: -200, isMate: false), rotated: true)
            }
            .frame(height: 200)
        }
        .padding()
        .walnutBackdrop())
    }

    // MARK: MoveStrip

    static let moveStripStart = PreviewScenario(file: "MoveStrip.swift", name: "Start") {
        AnyView(MoveStrip(session: GameSession(), showAll: {})
            .padding())
    }
    static let moveStripMiddle = PreviewScenario(file: "MoveStrip.swift", name: "Middle") {
        AnyView(MoveStrip(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 *")), showAll: {})
            .padding())
    }
    static let moveStripWithVariations = PreviewScenario(file: "MoveStrip.swift", name: "With variations") {
        AnyView(MoveStrip(session: GameSession(state: GameState(pgn: "1. e4 e5 (1... c5) 2. Nf3 (2. c3) Nc6 *")), showAll: {})
            .padding())
    }

    // MARK: MoveListView

    static let moveListShortGame = PreviewScenario(file: "MoveListView.swift", name: "Short game") {
        AnyView(MoveListView(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nc6 *"))))
    }
    static let moveListVariationsAndComments = PreviewScenario(file: "MoveListView.swift", name: "Variations and comments") {
        AnyView(MoveListView(session: GameSession(state: GameState(
            pgn: "1. e4 {King's pawn} e5 (1... c5 {Sicilian} 2. Nf3 (2. c3 {Alapin}) d6) 2. Nf3 Nc6 3. Bb5 *"))))
    }
    static let moveListCard = PreviewScenario(file: "MoveListView.swift", name: "Card") {
        AnyView(MoveListView(session: GameSession(state: GameState(
            pgn: "1. e4 e5 2. Nf3 Nc6 3. Bb5 (3. Bc4 Bc5) a6 4. Bxc6 dxc6 5. O-O f6 *")), card: true)
            .padding()
            .frame(width: 320, height: 400)
            .walnutBackdrop())
    }

    // MARK: NewGameView

    static let newGamePlayersAndLevel = PreviewScenario(file: "NewGameView.swift", name: "Players & Level") {
        AnyView(NewGameView(session: GameSession()))
    }

    // MARK: Walnut

    static let walnutPalette = PreviewScenario(file: "Walnut.swift", name: "Palette", gallery: false) {
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

    #if os(iOS)
    // MARK: iOS only (NewGameView_iOS is not compiled on macOS; GamesList and GameRootView live in iOS/)

    static let newGameNewGame = PreviewScenario(file: "NewGameView_iOS.swift", name: "New game") {
        AnyView(NewGameView_iOS(session: GameSession(), editMode: false, onNewGame: { _, _ in }))
    }
    static let newGameEditGame = PreviewScenario(file: "NewGameView_iOS.swift", name: "Edit game") {
        AnyView(NewGameView_iOS(session: GameSession(), editMode: true, onNewGame: { _, _ in }))
    }
    static let gamesList = PreviewScenario(file: "GameRootView.swift", name: "Games") {
        AnyView(gamesListPreview())
    }
    static let gamesLaunch = PreviewScenario(file: "GameRootView.swift", name: "Launch") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Preview-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return AnyView(GameRootView(library: GameLibrary(directory: directory, defaults: PreviewScenarios.defaults)))
    }
    #endif

    static let all: [PreviewScenario] = {
        var all: [PreviewScenario] = [
            contentTall, contentWide, contentAnalyze, contentTrain, contentRotated,
            settings,
            playerRowToMove, playerRowCaptures,
            statusLineYourMove, statusLineCheckmate,
            navigationButtons,
            board,
            labelsWhiteAtTheBottom, labelsRotated,
            piecesWhiteAtTheBottom, piecesRotated,
            promotionDropsFromTheTop, promotionRisesFromTheBottom,
            variationArrowsAndCards,
            arrow,
            engineEqual, engineSlightlyBetter, engineMate, engineAnalyzing, engineStatistics, engineStacked, engineEvaluationBars,
            moveStripStart, moveStripMiddle, moveStripWithVariations,
            moveListShortGame, moveListVariationsAndComments, moveListCard,
            newGamePlayersAndLevel,
            walnutPalette,
        ]
        #if os(iOS)
        all += [newGameNewGame, newGameEditGame, gamesList, gamesLaunch]
        #endif
        return all
    }()
}
#endif
