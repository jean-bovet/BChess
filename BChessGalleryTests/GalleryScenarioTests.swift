import Foundation
import Testing
@testable import BChess

/// Both gallery suites in one serialized parent: the fixtures write the scratch defaults that the snapshot
/// test reads through every @AppStorage while it awaits each settle, so no other test may run beside it.
@MainActor @Suite(.serialized)
enum GallerySuites {}

extension GallerySuites {

    /// The scenario list feeds the gallery renderer (`SnapshotGalleryTests`).
    @MainActor @Suite struct GalleryScenarioTests {

        @Test("every scenario has a non-empty name and group and a unique slug")
        func everyScenarioHasANameAGroupAndAUniqueSlug() {
            var seen = Set<String>()
            for scenario in GalleryScenarios.all {
                #expect(!scenario.name.isEmpty)
                #expect(!scenario.group.isEmpty, "\(scenario.name)")
                #expect(!scenario.slug.isEmpty, "\(scenario.name)")
                #expect(seen.insert(scenario.slug).inserted, "duplicate slug \(scenario.slug)")
            }
            #expect(!GalleryScenarios.all.isEmpty)
        }

        @Test("the slug is derived from the name")
        func slugIsDerivedFromTheName() {
            #expect(GalleryScenario.slug(of: "Game screen · Tall") == "game-screen-tall")
            #expect(GalleryScenario.slug(of: "New game · Players & Level") == "new-game-players-level")
            #expect(GalleryScenario.slug(of: "Board · White at the bottom") == "board-white-at-the-bottom")
        }

        @Test("the ONLY filter matches names or slugs, comma-separated, case-insensitive; empty means all")
        func onlyFilter() {
            #expect(GalleryScenarios.matching("").count == GalleryScenarios.all.count)
            #expect(GalleryScenarios.matching("  , ").count == GalleryScenarios.all.count)
            #expect(GalleryScenarios.matching("Engine · Equal").map(\.slug) == ["engine-equal"])
            #expect(GalleryScenarios.matching("engine-equal").map(\.slug) == ["engine-equal"])
            #expect(GalleryScenarios.matching("GAME-SCREEN-TALL, engine · equal").map(\.slug) == ["game-screen-tall", "engine-equal"])
            #expect(GalleryScenarios.matching("nothing").isEmpty)
        }

        @Test("the Tall and Wide fixture has a human to move, so the app starts no search")
        func contentFixtureHasAHumanToMove() {
            let session = GalleryScenarios.humanToMoveSession()
            #expect(session.mode.value == .play)
            #expect(session.isWhiteToMove)
            #expect(!session.gameState.white.computer)
        }

        @Test("the games fixture lists four games through the production library")
        func gamesFixtureListsFourGames() throws {
            let shell = try GalleryScenarios.gamesShell()
            shell.library.reload()
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            let days = Dictionary(uniqueKeysWithValues: shell.library.games.map { file in
                (file.title, calendar.dateComponents([.day], from: calendar.startOfDay(for: file.modified), to: today).day)
            })
            #expect(days == ["You vs Computer": 0, "Ruy Lopez practice": 0, "Anna vs Jean": 1, "Imported game": 9])
        }

        @Test("the scheme passes -uiTestingFreshLibrary to the test host")
        func schemePassesTheFreshLibraryArgument() {
            #expect(ProcessInfo.processInfo.arguments.contains("-uiTestingFreshLibrary"))
        }

        @Test("every PGN fixture parses", arguments: GalleryScenarios.Fixture.allPGNs)
        func everyPGNFixtureParses(pgn: String) {
            #expect(FEngine().loadAllGames(pgn), "\(pgn)")
        }

        @Test("the fixture sessions hold the positions their cards claim")
        func fixtureSessionsHoldTheirPositions() {
            let ruyLopez = GalleryScenarios.humanToMoveSession()
            #expect(ruyLopez.game.rows.count == 3)
            #expect(ruyLopez.fen != GameSession().fen)
            #expect(ruyLopez.isWhiteToMove)

            for pgn in [GalleryScenarios.Fixture.arrowsAndCards, GalleryScenarios.Fixture.moveStripVariations,
                        GalleryScenarios.Fixture.commented, GalleryScenarios.Fixture.card] {
                #expect(GameSession(state: GameState(pgn: pgn)).game.variationCount > 0, "\(pgn)")
            }
            let commented = GameSession(state: GameState(pgn: GalleryScenarios.Fixture.commented))
            #expect(commented.pgnCurrentGame.contains("{King's pawn}"))
            #expect(commented.pgnCurrentGame.contains("{Sicilian}"))

            let checkmate = GameSession(state: GameState(pgn: GalleryScenarios.Fixture.checkmate, white: .human, black: .human))
            #expect(checkmate.gameEnd == .checkmate)

            let captures = GameSession(state: GameState(pgn: GalleryScenarios.Fixture.captures))
            #expect(!captures.capturedPieces(white: true).isEmpty)
            #expect(!captures.capturedPieces(white: false).isEmpty)
        }
    }
}
