import Foundation
import SwiftUI
import Testing
import UIKit
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

        @Test("every scenario has a platform, and the inner sizes are the duo-inner ones")
        func everyScenarioHasAPlatform() {
            for scenario in GalleryScenarios.all {
                #expect(["iphone", "duo-inner"].contains(scenario.size.platform), "\(scenario.name)")
                #expect((scenario.size.platform == "duo-inner") == scenario.size.isDuoInner, "\(scenario.name)")
            }
            #expect(GalleryScenarios.all.filter { $0.group == GalleryScenarios.groupDuo }.allSatisfy { $0.size.isDuoInner })
        }

        // MARK: Size classes

        private final class ProbeResult {
            var horizontal: UserInterfaceSizeClass?
            var vertical: UserInterfaceSizeClass?
            /// What the mounted hierarchy measured, not what was requested.
            var size: CGSize?
        }

        private struct SizeClassProbe: View {
            let result: ProbeResult
            @Environment(\.horizontalSizeClass) private var horizontal
            @Environment(\.verticalSizeClass) private var vertical

            var body: some View {
                Color.clear
                    .ignoresSafeArea()
                    .onAppear {
                        result.horizontal = horizontal
                        result.vertical = vertical
                    }
                    // The window's size: the proxy's own plus the safe area the window reports
                    .onGeometryChange(for: CGSize.self) { proxy in
                        CGSize(width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                               height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
                    } action: { size in
                        result.size = size
                    }
            }
        }

        private func probe(_ size: GallerySize) async throws -> (UserInterfaceSizeClass?, UserInterfaceSizeClass?, CGSize) {
            let result = ProbeResult()
            let screen = try SnapshotGalleryTests.screenSize()
            let points = size.points(screen: screen)
            _ = try await SnapshotGalleryTests.render(AnyView(SizeClassProbe(result: result)), size: points,
                                                      sizeClasses: size.sizeClasses, style: .light)
            let measured = try #require(result.size, "the probe measured nothing")
            return (result.horizontal, result.vertical, measured)
        }

        @Test("the inner sizes read regular both ways, the phone sizes the scene's own classes")
        func innerSizesReadRegularBothWays() async throws {
            let screen = try SnapshotGalleryTests.screenSize()

            let landscape = try await probe(.duoInnerLandscape)
            #expect(landscape.0 == .regular && landscape.1 == .regular)
            #expect(landscape.2 == CGSize(width: 951, height: 669))
            let portrait = try await probe(.duoInnerPortrait)
            #expect(portrait.0 == .regular && portrait.1 == .regular)
            #expect(portrait.2 == CGSize(width: 669, height: 951))
            let ipad = try await probe(.ipadLandscape)
            #expect(ipad.0 == .regular)

            let phone = try await probe(.phone)
            let traits = try SnapshotGalleryTests.scene().traitCollection
            #expect(phone.0 == UserInterfaceSizeClass(traits.horizontalSizeClass))
            #expect(phone.1 == UserInterfaceSizeClass(traits.verticalSizeClass))
            #expect(phone.2 == screen)
        }

        @Test("a card the Duo pass cannot render honestly is skipped with a reason; the iPhone pass skips none")
        func skippedCardsAreTheOnesTheDuoCannotMount() {
            for scenario in GalleryScenarios.all {
                #expect(scenario.skipReason(duoPass: false) == nil, "\(scenario.name)")
            }
            let skipped = GalleryScenarios.all.filter { $0.skipReason(duoPass: true) != nil }.map(\.slug)
            #expect(skipped == ["duo-inner-landscape-shell"])
            #expect(GalleryScenarios.all.filter { $0.usesSystemBars }.map(\.slug) == ["duo-inner-landscape-shell", "launch-empty-library"])
        }

        // MARK: Pixel oracles (the production layout through the production render)

        private let styles: [UIUserInterfaceStyle] = [.light, .dark]

        private func image(_ view: AnyView, size: CGSize, style: UIUserInterfaceStyle) async throws -> UIImage {
            try await SnapshotGalleryTests.render(AnyView(view.defaultAppStorage(GalleryScenarios.defaults)), size: size,
                                                  sizeClasses: (.regular, .regular), scale: 3, style: style)
        }

        private func scenarioImage(_ scenario: GalleryScenario, style: UIUserInterfaceStyle) async throws -> UIImage {
            try await SnapshotGalleryTests.renderImage(scenario, style: style)
        }

        private func box(_ color: Color, _ style: UIUserInterfaceStyle, in image: UIImage, region: CGRect? = nil) -> CGRect? {
            GalleryPixels.boundingBox(of: GalleryPixels.resolved(color, style: style), in: image,
                                      region: region ?? CGRect(origin: .zero, size: image.size))
        }

        /// The board frame's box and the card box searched only outside it, on its trailing side (`trailing`) or
        /// below it, where no white piece can be.
        private func boxes(in image: UIImage, style: UIUserInterfaceStyle, trailing: Bool) throws -> (frame: CGRect, card: CGRect) {
            let frame = try #require(box(Walnut.frame, style, in: image), "no board frame in the capture")
            let region = trailing
                ? CGRect(x: frame.maxX, y: 0, width: image.size.width - frame.maxX, height: image.size.height)
                : CGRect(x: 0, y: frame.maxY, width: image.size.width, height: image.size.height - frame.maxY)
            let card = try #require(box(Walnut.card, style, in: image, region: region), "no card in the capture")
            return (frame, card)
        }

        private func noCaptures(_ session: GameSession) {
            #expect(session.capturedPieces(white: true).isEmpty)
            #expect(session.capturedPieces(white: false).isEmpty)
        }

        @Test("the landscape fold keeps the board and the sidebar off the hinge")
        func landscapeFoldKeepsTheBoardAndTheSidebarOffTheHinge() async throws {
            noCaptures(GalleryScenarios.humanToMoveSession())
            let hinge = 455.5...495.5
            let size = GallerySize.duoInnerLandscape.points(screen: try SnapshotGalleryTests.screenSize())
            for style in styles {
                let active = try await scenarioImage(GalleryScenarios.duoLandscapeGame, style: style)
                let found = try boxes(in: active, style: style, trailing: true)
                #expect(found.frame.maxX <= hinge.lowerBound - 12 + 0.5, "\(style.rawValue): the board reaches \(found.frame.maxX)")
                #expect(found.frame.minX >= 16 - 0.5)
                #expect(found.card.minX >= hinge.upperBound + 12 - 0.5, "\(style.rawValue): the card starts at \(found.card.minX)")
                #expect(!(found.frame.minX...found.frame.maxX).overlaps(hinge))
                #expect(!(found.card.minX...found.card.maxX).overlaps(hinge))

                let flat = try await scenarioImage(GalleryScenarios.duoLandscapeFlatOpen, style: style)
                #expect(flat.pngData() == active.pngData(), "\(style.rawValue): flat open differs from the active fold")

                // Without a region the board crosses the hinge: the finding this layout answers
                let without = try await image(GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: nil), size: size, style: style)
                let crossing = try #require(box(Walnut.frame, style, in: without))
                #expect(crossing.maxX > hinge.upperBound, "\(style.rawValue)")
            }
        }

        @Test("the tabletop fold keeps the board above it and the strip below, the flat pose is unchanged")
        func tabletopKeepsTheBoardAboveTheFoldAndTheStripBelow() async throws {
            noCaptures(GalleryScenarios.humanToMoveSession())
            let hinge = 455.5...495.5
            let size = GallerySize.duoInnerPortrait.points(screen: try SnapshotGalleryTests.screenSize())
            for style in styles {
                let tabletop = try await scenarioImage(GalleryScenarios.duoPortraitTabletopCard, style: style)
                let found = try boxes(in: tabletop, style: style, trailing: false)
                #expect(found.frame.maxY <= hinge.lowerBound - 12 + 0.5, "\(style.rawValue): the board reaches \(found.frame.maxY)")
                #expect(found.card.minY >= hinge.upperBound + 12 - 0.5, "\(style.rawValue): the strip starts at \(found.card.minY)")
                // No card pixel outside the frame box above the fold
                let above = CGRect(x: 0, y: 0, width: size.width, height: found.frame.minY)
                let between = CGRect(x: 0, y: found.frame.maxY, width: size.width, height: hinge.lowerBound - found.frame.maxY)
                let left = CGRect(x: 0, y: found.frame.minY, width: found.frame.minX, height: found.frame.height)
                let right = CGRect(x: found.frame.maxX, y: found.frame.minY, width: size.width - found.frame.maxX, height: found.frame.height)
                for region in [above, between, left, right] where region.width > 0 && region.height > 0 {
                    #expect(box(Walnut.card, style, in: tabletop, region: region) == nil, "\(style.rawValue): a card in \(region)")
                }

                let flat = try await scenarioImage(GalleryScenarios.duoPortraitGame, style: style)
                let plain = try await image(GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: nil), size: size, style: style)
                #expect(box(Walnut.frame, style, in: flat) == box(Walnut.frame, style, in: plain), "\(style.rawValue): the flat pose changed")
            }
        }

        @Test("a narrow tabletop reserves the whole extent above the fold")
        func narrowTabletopReservesTheWholeCap() async throws {
            let region = FoldRegion(frame: CGRect(x: 0, y: 439.5, width: 268, height: 40), isActive: true)
            for style in styles {
                let view = GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: region)
                let capture = try await image(view, size: CGSize(width: 300, height: 919), style: style)
                let found = try boxes(in: capture, style: style, trailing: false)
                #expect(found.frame.width <= 268 + 0.5)
                #expect(found.frame.maxY <= 443.5 + 0.5, "\(style.rawValue): the board reaches \(found.frame.maxY)")
                #expect(found.card.minY >= 507.5 - 0.5, "\(style.rawValue): the strip starts at \(found.card.minY)")
            }
        }

        @Test("edge folds keep the wide layout in the usable area")
        func edgeFoldsKeepTheWideLayoutInTheUsableArea() async throws {
            let size = CGSize(width: 951, height: 669)
            for style in styles {
                let leading = FoldRegion(frame: CGRect(x: 10, y: 0, width: 40, height: 637), isActive: true)
                let capture = try await image(GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: leading),
                                              size: size, style: style)
                let found = try boxes(in: capture, style: style, trailing: true)
                #expect(found.frame.minX >= 16 + 62 - 0.5, "\(style.rawValue): the board starts at \(found.frame.minX)")
                #expect(found.card.minX >= found.frame.maxX)

                let trailing = FoldRegion(frame: CGRect(x: 869, y: 0, width: 40, height: 637), isActive: true)
                let other = try await image(GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: trailing),
                                            size: size, style: style)
                let seen = try boxes(in: other, style: style, trailing: true)
                #expect(seen.card.maxX <= 16 + 857 + 0.5, "\(style.rawValue): the card ends at \(seen.card.maxX)")
                let band = CGRect(x: 16 + 869, y: 0, width: 40, height: size.height)
                #expect(box(Walnut.frame, style, in: other, region: band) == nil)
                #expect(box(Walnut.card, style, in: other, region: band) == nil)
            }
        }

        @Test("edge folds keep the tall layout in the usable area")
        func edgeFoldsKeepTheTallLayoutInTheUsableArea() async throws {
            let size = CGSize(width: 669, height: 951)
            for style in styles {
                let top = FoldRegion(frame: CGRect(x: 0, y: 10, width: 637, height: 40), isActive: true)
                let capture = try await image(GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: top),
                                              size: size, style: style)
                let found = try boxes(in: capture, style: style, trailing: false)
                #expect(found.frame.minY >= 16 + 62 - 0.5, "\(style.rawValue): the board starts at \(found.frame.minY)")

                let bottom = FoldRegion(frame: CGRect(x: 0, y: 869, width: 637, height: 40), isActive: true)
                let other = try await image(GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: bottom),
                                            size: size, style: style)
                let seen = try boxes(in: other, style: style, trailing: false)
                #expect(seen.card.maxY <= 16 + 857 + 0.5, "\(style.rawValue): the strip ends at \(seen.card.maxY)")
            }
        }

        @Test("a fold that leaves a narrow strip falls back to the tall layout inside it")
        func narrowFallbackGoesTallInsideTheUsableArea() async throws {
            let region = FoldRegion(frame: CGRect(x: 140, y: 0, width: 40, height: 240), isActive: true)
            for style in styles {
                let capture = try await image(GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: region),
                                              size: CGSize(width: 332, height: 272), style: style)
                let frame = try #require(box(Walnut.frame, style, in: capture))
                #expect(frame.minX >= 16 - 0.5 && frame.maxX <= 144 + 0.5, "\(style.rawValue): the board spans \(frame.minX)...\(frame.maxX)")
                let below = CGRect(x: 0, y: frame.maxY, width: capture.size.width, height: capture.size.height - frame.maxY)
                let card = try #require(box(Walnut.card, style, in: capture, region: below), "\(style.rawValue): the Moves card is not in the capture")
                #expect(card.minX >= 16 - 0.5 && card.maxX <= 144 + 0.5, "\(style.rawValue): the card spans \(card.minX)...\(card.maxX)")
                #expect(card.maxY <= 272 - 16 + 0.5, "\(style.rawValue): the card ends at \(card.maxY)")
                let beyond = CGRect(x: 156, y: 0, width: capture.size.width - 156, height: capture.size.height)
                #expect(box(Walnut.frame, style, in: capture, region: beyond) == nil)
                #expect(box(Walnut.card, style, in: capture, region: beyond) == nil)
            }
        }
    }
}
