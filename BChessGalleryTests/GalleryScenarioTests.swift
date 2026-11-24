import Foundation
import SwiftUI
import Testing
import UIKit
@testable import BChess

/// Polls a main-actor condition for up to ten seconds (the mounted-screen tests wait for the production observation).
@MainActor private func wait(_ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + .seconds(10)
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return condition()
}

/// Both gallery suites in one serialized parent: the fixtures write the scratch defaults that the snapshot
/// test reads through every @AppStorage while it awaits each settle, so no other test may run beside it.
@MainActor @Suite(.serialized)
enum GallerySuites {}

extension GallerySuites {

    /// The scenario list feeds the gallery renderer (`SnapshotGalleryTests`).
    @MainActor @Suite struct GalleryScenarioTests {

        @Test("the manifest records every scenario's window in points and its capture scale")
        func manifestRecordsPointsAndScale() {
            let screen = CGSize(width: 402, height: 874)
            let entries = SnapshotGalleryTests.manifestEntries(screen: screen)
            #expect(entries.count == GalleryScenarios.all.count)
            for (scenario, entry) in zip(GalleryScenarios.all, entries) {
                let points = scenario.size.points(screen: screen)
                #expect(entry.slug == scenario.slug)
                #expect(entry.points == [Double(points.width), Double(points.height)], "\(scenario.slug)")
                // The Duo pass captures everything at the display's 3x; otherwise only the Duo inner poses are 3x
                let expectedScale: Double = SnapshotGalleryTests.duoPass || scenario.size.isDuoInner ? 3 : 2
                #expect(entry.scale == expectedScale, "\(scenario.slug)")
                #expect(entry.size == "\(Int(points.width))x\(Int(points.height))", "\(scenario.slug)")
            }
        }

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
        func fixtureSessionsHoldTheirPositions() async throws {
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

            // The long game: 62 moves ending in checkmate; the two strip cards sit on a castling and a capturing promotion
            let long = GalleryScenarios.longCheckmateSession()
            #expect(long.gameEnd == .checkmate)
            #expect(long.game.path(to: long.currentMoveUUID).count == 123)
            let castling = GalleryScenarios.longCheckmateSession(atPly: 39)
            #expect(castling.game.recentMoves(current: castling.currentMoveUUID, count: 1) == [
                .move("20\u{2026}O-O-O", uuid: castling.currentMoveUUID)])
            let promotion = GalleryScenarios.longCheckmateSession(atPly: 92)
            #expect(promotion.game.recentMoves(current: promotion.currentMoveUUID, count: 1) == [
                .move("47. hxg8=Q", uuid: promotion.currentMoveUUID)])
            // The largest-text card's position: a Black promotion with check as the current move, and a variation
            let blackPromotion = GalleryScenarios.blackPromotionSession()
            #expect(blackPromotion.game.recentMoves(current: blackPromotion.currentMoveUUID, count: 1) == [
                .move("10\u{2026}exd1=Q+", uuid: blackPromotion.currentMoveUUID)])
            #expect(blackPromotion.game.variationCount == 1)
            #expect(GalleryScenarios.blackPromotionSession(pgn: GalleryScenarios.Fixture.blackPromotionPlain).game.variationCount == 0)

            let checkmate = GameSession(state: GameState(pgn: GalleryScenarios.Fixture.checkmate, white: .human, black: .human))
            #expect(checkmate.gameEnd == .checkmate)

            // The computer's turn: the human's move is played and its reply is pending, with no search started (the move
            // animation never completes), so no reply can land before or during a capture
            let thinking = GalleryScenarios.computerThinkingSession()
            defer { thinking.cancelSearch() }
            #expect(thinking.isThinking)
            #expect(!thinking.isWhiteToMove)
            #expect(!thinking.isAnalyzing)
            #expect(thinking.game.recentMoves(current: thinking.currentMoveUUID, count: 1) == [
                .move("17. a3", uuid: thinking.currentMoveUUID)])
            try await Task.sleep(for: .milliseconds(500))
            #expect(thinking.isThinking)
            #expect(!thinking.isWhiteToMove)

            let captures = GameSession(state: GameState(pgn: GalleryScenarios.Fixture.captures))
            #expect(!captures.capturedPieces(white: true).isEmpty)
            #expect(!captures.capturedPieces(white: false).isEmpty)

            // Past the twelve-piece overlap on one side, under the fifteen maximum, and at least ten on each
            let many = GalleryScenarios.manyCapturesSession()
            let white = many.capturedPieces(white: true).count
            let black = many.capturedPieces(white: false).count
            #expect(min(white, black) >= 10)
            #expect((13...15).contains(max(white, black)))
            #expect(many.gameEnd == .none)
            #expect(many.gameState.white.name == "Jeanne Blanchard")
            #expect(many.gameState.black.name == "Nikolai Weissmann")
        }

        @Test("the result fixtures end the way their cards claim")
        func resultFixturesHoldTheirResults() {
            typealias Fixture = GalleryScenarios.Fixture
            let expected: [(String, GameResult)] = [
                (Fixture.whiteMates, GameResult(winner: .white, reason: .checkmate)),
                (Fixture.checkmate, GameResult(winner: .black, reason: .checkmate)),
                (Fixture.stalemate, GameResult(winner: .draw, reason: .stalemate)),
                (Fixture.insufficientMaterial, GameResult(winner: .draw, reason: .deadPosition)),
                (Fixture.fiftyMoves, GameResult(winner: .draw, reason: .fiftyMoves)),
                (Fixture.declaredBlackWins, GameResult(winner: .black, reason: .finished)),
            ]
            for (pgn, result) in expected {
                #expect(GalleryScenarios.finishedSession(pgn).result == result, "\(pgn)")
            }
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
            #expect(skipped == ["duo-inner-landscape-shell", "face-to-face-iphone-landscape"])
            #expect(GalleryScenarios.all.filter { $0.usesSystemBars }.map(\.slug) == ["duo-inner-landscape-shell", "face-to-face-shell", "face-to-face-two-boards-off", "launch-empty-library"])
        }

        // MARK: Pixel oracles (the production layout through the production render)

        private let styles: [UIUserInterfaceStyle] = [.light, .dark]

        /// Whether the run's language reads right to left: a row's leading edge is then its right one.
        private var rightToLeft: Bool {
            UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        }

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

        /// Collects the frames the views name with `probeFrame`, in the window's coordinates.
        @MainActor private final class FrameBox {
            var frames: [String: CGRect] = [:]
        }

        /// The capture, then the layout frames of the views that name themselves (`probeFrame`), from one render.
        private func layout(_ view: AnyView, size: CGSize, style: UIUserInterfaceStyle = .light,
                            defaults: UserDefaults = GalleryScenarios.defaults, settle: Duration = .milliseconds(400),
                            sizeClasses: (horizontal: UIUserInterfaceSizeClass, vertical: UIUserInterfaceSizeClass)? = nil)
            async throws -> (image: UIImage, frames: [String: CGRect]) {
            let box = FrameBox()
            let probed = view
                .defaultAppStorage(defaults)
                .overlayPreferenceValue(FrameProbeKey.self) { anchors in
                    GeometryReader { proxy in
                        let origin = proxy.frame(in: .global).origin
                        let frames = anchors.mapValues { proxy[$0].offsetBy(dx: origin.x, dy: origin.y) }
                        Color.clear.onChange(of: frames, initial: true) { _, new in box.frames = new }
                    }
                }
            let image = try await SnapshotGalleryTests.render(AnyView(probed), size: size, sizeClasses: sizeClasses, scale: 3, style: style, settle: settle)
            return (image, box.frames)
        }

        @Test("the status line is one line tall, blank or with a sentence too long for the width")
        func statusLineKeepsItsHeight() async throws {
            let size = CGSize(width: 150, height: 100)
            let blank = try await layout(AnyView(StatusLine(session: GameSession(state: GameState(pgn: GalleryScenarios.Fixture.yourMove)))
                .padding()), size: size)
            let ended = try await layout(AnyView(StatusLine(session: GameSession(state: GameState(pgn: GalleryScenarios.Fixture.checkmate, white: .human, black: .human))).padding()), size: size)
            let blankFrame = try #require(blank.frames["status"], "no status element: \(blank.frames)")
            let endedFrame = try #require(ended.frames["status"], "no status element: \(ended.frames)")
            #expect(blankFrame.height > 0)
            #expect(abs(endedFrame.height - blankFrame.height) <= 0.5, "\(endedFrame.height) pt with a sentence, \(blankFrame.height) pt blank")
        }

        @Test("the move strip's last candidate leaves out the variation badge, whose width the budget does not count")
        func moveStripLastCandidateHasNoVariationBadge() async throws {
            // Too narrow for two moves beside the icon: only the one-move fallback is left
            let size = CGSize(width: 190, height: 120)
            func buttonWidth(_ pgn: String) async throws -> CGFloat {
                let result = try await layout(AnyView(MoveStrip(session: GalleryScenarios.blackPromotionSession(pgn: pgn), showAll: {})
                    .padding()), size: size, settle: .seconds(1))
                return try #require(result.frames["moves-button"], "no Moves button in \(result.frames)").width
            }
            let withVariation = try await buttonWidth(GalleryScenarios.Fixture.blackPromotion)
            let without = try await buttonWidth(GalleryScenarios.Fixture.blackPromotionPlain)
            #expect(abs(withVariation - without) <= 0.5, "\(withVariation) pt with a variation, \(without) pt without")
        }

        @Test("the tall layout centres the board block: growing the window by 40 pt moves the board down by 20")
        func tallLayoutCentresTheBoardBlock() async throws {
            let screen = try SnapshotGalleryTests.screenSize()
            let growth: CGFloat = 40
            for style in styles {
                let session = GalleryScenarios.humanToMoveSession()
                let (short, frames) = try await layout(GalleryScenarios.gameScreen(session, fold: nil), size: screen, style: style,
                                                       sizeClasses: (.regular, .regular))
                let tall = try await image(GalleryScenarios.gameScreen(session, fold: nil),
                                           size: CGSize(width: screen.width, height: screen.height + growth), style: style)
                let before = try #require(box(Walnut.frame, style, in: short), "no board frame in the capture")
                let after = try #require(box(Walnut.frame, style, in: tall), "no board frame in the capture")
                let shift = after.minY - before.minY
                #expect(abs(shift - growth / 2) <= 1, "\(style.rawValue): the board moved \(shift) pt")

                // The block itself is centred, not only moved by half the growth: the free space above the top player row
                // equals the free space below the strip (layout frames, 16 pt of padding each side)
                let column = try #require(frames["tall-column"], "\(style.rawValue): no column frame in \(frames)")
                let strip = try #require(frames["move-strip"], "\(style.rawValue): no strip frame in \(frames)")
                let above = column.minY - 16
                let below = screen.height - 16 - strip.maxY
                #expect(abs(above - below) <= 1, "\(style.rawValue): \(above) pt free above the block, \(below) pt below")
            }
        }

        @Test("a phone portrait window gets the tall layout with thirteen captures, in both appearances, at 375 and 320 pt")
        func manyCapturesKeepTheTallLayoutOnEveryPhoneWidth() async throws {
            let screen = try SnapshotGalleryTests.screenSize()
            for size in [GallerySize.smallPhone, .narrow, .phone] {
                for style in styles {
                    let label = "\(size), \(style.rawValue)"
                    let (_, frames) = try await layout(AnyView(ContentView(session: GalleryScenarios.manyCapturesSession())),
                                                       size: size.points(screen: screen), style: style, sizeClasses: size.sizeClasses)
                    #expect(frames["tall-column"] != nil, "\(label): the tall layout was not chosen (frames \(frames.keys.sorted()))")
                    #expect(frames["column"] == nil, "\(label): the wide layout was drawn")
                }
            }
        }

        @Test("under the bars, a phone gets the tall layout: upright, or turned upright from sideways on one or two boards", arguments: [
            CGSize(width: 430, height: 932), CGSize(width: 402, height: 874), CGSize(width: 375, height: 667)])
        func phoneUnderTheBarsIsTallUprightAndAfterTurning(size: CGSize) async throws {
            let sideways = CGSize(width: size.height, height: size.width)
            // (the window it starts in, whether the game starts on two boards)
            for (start, twoBoards) in [(size, false), (sideways, false), (sideways, true)] {
                for style in styles {
                    let label = "\(start) to \(size), \(twoBoards ? "two boards" : "one board"), \(style.rawValue)"
                    let box = FrameBox()
                    let session = GalleryScenarios.manyCapturesSession(rotated: true, faceToFace: twoBoards)
                    let screen = NavigationStack {
                        ContentView(session: session)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .principal) { Text(verbatim: "White vs Black") }
                                ToolbarItem(placement: .bottomBar) { Button(action: {}) { Text(verbatim: "Engine") } }
                            }
                    }
                    .defaultAppStorage(GalleryScenarios.defaults)
                    .overlayPreferenceValue(FrameProbeKey.self) { anchors in
                        GeometryReader { proxy in
                            let frames = anchors.mapValues { proxy[$0] }
                            Color.clear.onChange(of: frames, initial: true) { _, new in box.frames = new }
                        }
                    }
                    let mounted = try SnapshotGalleryTests.mount(AnyView(screen), size: start, style: style)
                    defer { mounted.close() }
                    try await Task.sleep(for: .milliseconds(400))
                    if start != size {
                        if twoBoards {
                            #expect(box.frames["column"] == nil && box.frames["tall-column"] == nil, "\(label): not two boards (frames \(box.frames.keys.sorted()))")
                            session.setFaceToFace(false)
                            try await Task.sleep(for: .milliseconds(200))
                        } else {
                            #expect(box.frames["column"] != nil, "\(label): the turn did not start wide (frames \(box.frames.keys.sorted()))")
                        }
                        mounted.window.frame = CGRect(origin: .zero, size: size)
                        mounted.host.view.frame = mounted.window.bounds
                        mounted.host.view.layoutIfNeeded()
                        try await Task.sleep(for: .milliseconds(400))
                    }
                    #expect(box.frames["column"] == nil, "\(label): the wide layout was drawn (frames \(box.frames.keys.sorted()))")
                    let column = box.frames["tall-column"]
                    #expect(column != nil, "\(label): the tall layout was not chosen (frames \(box.frames.keys.sorted()))")
                    #expect(column.map { $0.minX >= 15.5 && $0.maxX <= size.width - 15.5 } == true, "\(label): the column is \(String(describing: column))")
                }
            }
        }

        @Test("the status slot and the move strip are as tall in every language as in English, so the centred block never moves")
        func blockHeightsDoNotDependOnTheLanguage() async throws {
            // Measured in English at the default text size: the Arabic line is 2 pt (status) and 1.3 pt (strip) taller
            // when it is the font's own line height that sets them. The run's language is the process's
            // (-testLanguage), so the gallery's he and ar passes run this test too.
            let screen = try SnapshotGalleryTests.screenSize()
            for style in styles {
                let (_, frames) = try await layout(GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: nil),
                                                   size: screen, style: style)
                let status = try #require(frames["status"], "\(style.rawValue): no status frame in \(frames)")
                let strip = try #require(frames["move-strip"], "\(style.rawValue): no strip frame in \(frames)")
                #expect(abs(status.height - 18) <= 0.01, "\(style.rawValue): the status slot is \(status.height) pt tall")
                #expect(abs(strip.height - 32) <= 0.01, "\(style.rawValue): the move strip is \(strip.height) pt tall")
            }
        }

        @Test("the engine readout is as tall in every language as in English")
        func engineReadoutHeightDoesNotDependOnTheLanguage() async throws {
            // 59.33 pt in English at the default text size (the Arabic lines are 2 pt taller each when the font sets the
            // height); the readout's height sets the centred block's, so the board must not move with it
            let screen = try SnapshotGalleryTests.screenSize()
            let view = AnyView(GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: nil))
            let (_, frames) = try await layout(view, size: screen, defaults: GalleryScenarios.engineOnDefaults, settle: .seconds(3))
            let readout = try #require(frames["engine-readout"], "no engine readout in \(frames)")
            #expect(abs(readout.height - 59.33) <= 0.4, "the engine readout is \(readout.height) pt tall")
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

        // MARK: The wide layout's board column

        /// The wide game screen as the production layout draws it, the engine readout on or off through the
        /// production `@AppStorage` read of `defaults`, optionally at a larger text size.
        private func wideImage(_ session: GameSession, size: CGSize, style: UIUserInterfaceStyle, defaults: UserDefaults,
                               textSize: DynamicTypeSize? = nil) async throws -> UIImage {
            let screen = GalleryScenarios.gameScreen(session, fold: nil)
            let sized = textSize.map { AnyView(screen.dynamicTypeSize($0)) } ?? screen
            return try await SnapshotGalleryTests.render(AnyView(sized.defaultAppStorage(defaults)), size: size,
                                                         sizeClasses: (.regular, .regular), scale: 3, style: style)
        }

        /// The board's frame: its columns from a band below the corners' rounding, then the topmost contiguous run of
        /// rows holding the frame colour within them, which must be as tall as the board is wide. The selected
        /// variation card draws a border in the same colour below the board, and the sidebar may hold it too, so
        /// neither may stretch the box.
        private func boardBox(in image: UIImage, style: UIUserInterfaceStyle, _ label: String) throws -> CGRect {
            let top = try #require(box(Walnut.frame, style, in: image), "\(label): no board frame in the capture").minY
            let band = try #require(box(Walnut.frame, style, in: image, region: CGRect(x: 0, y: top + 12, width: image.size.width, height: 12)),
                                    "\(label): no board frame band")
            let columns = CGRect(x: band.minX - 1, y: 0, width: band.width + 2, height: image.size.height)
            let run = try #require(GalleryPixels.firstRowRun(of: GalleryPixels.resolved(Walnut.frame, style: style), in: image, region: columns),
                                   "\(label): no board frame rows")
            let height = run.upperBound - run.lowerBound
            #expect(abs(height - band.width) <= 1, "\(label): the board is \(band.width) pt wide and \(height) pt tall")
            return CGRect(x: band.minX, y: run.lowerBound, width: band.width, height: height)
        }

        /// The Moves card's columns, found beside the board (the variation cards and the player rows stand elsewhere);
        /// its vertical bounds are the board's rows, which is all the callers use.
        private func movesCard(in image: UIImage, style: UIUserInterfaceStyle, board: CGRect, _ label: String) throws -> CGRect {
            try #require(box(Walnut.card, style, in: image,
                             region: CGRect(x: board.maxX, y: board.minY, width: image.size.width - board.maxX, height: board.height)),
                         "\(label): no Moves card beside the board")
        }

        @Test("the wide layout puts the move list right beside the board, with the engine readout off and on")
        func wideLayoutPutsTheMoveListBesideTheBoard() async throws {
            let size = GallerySize.ipadLandscape.points(screen: try SnapshotGalleryTests.screenSize())
            let gutter = EvaluationBar.width + 6
            let readouts = [("engine off", GalleryScenarios.defaults, CGFloat(0)), ("engine on", GalleryScenarios.engineOnDefaults, gutter)]
            for style in styles {
                for (name, defaults, reserved) in readouts {
                    let label = "\(style.rawValue), \(name)"
                    let capture = try await wideImage(GalleryScenarios.humanToMoveSession(), size: size, style: style, defaults: defaults)
                    let board = try boardBox(in: capture, style: style, label)
                    let card = try movesCard(in: capture, style: style, board: board, label)
                    #expect(card.minX - board.maxX <= 12.5, "\(label): the card starts \(card.minX - board.maxX) pt after the board")
                    // The card's fill ends inside its 1 pt border, and the capture (3x) snaps that edge to a third of a point:
                    // the fill's last solid pixel is up to 1 + 1/3 pt short of the 16 pt padding
                    #expect(card.maxX >= size.width - 16 - 1 - 1.0 / 3 - 0.01, "\(label): the card ends at \(card.maxX)")
                    #expect(board.minX >= 16 + reserved - 0.5, "\(label): the board starts at \(board.minX)")
                }
            }
        }

        @Test("the widest rows (fifteen captures and variation cards) at the smallest Mac window (740 x 500) and below it: the column ends at its rows, nothing enters the move list or leaves the padding")
        func wideLayoutKeepsTheWorstRowBesideTheMoveList() async throws {
            // The card discovery, the gutter and the overlap checks below read the screen physically: the board on the left, the
            // move list on its right. That holds in a left-to-right run only (the gallery's languages run in their own passes).
            try #require(!rightToLeft, "the wide-layout oracle assumes the sidebar is physically right of the board")
            // The supported minimum, and 20 pt narrower: the column is proposed less than its rows need, the floor decides
            for size in [CGSize(width: 740, height: 500), CGSize(width: 720, height: 500)] {
                let gutter = EvaluationBar.width + 6
                for style in styles {
                    for textSize in [nil, DynamicTypeSize.accessibility1] {
                        let label = "\(Int(size.width)), \(style.rawValue), \(textSize.map { "\($0)" } ?? "default text")"
                        let session = GalleryScenarios.worstRowSession()
                        #expect(max(session.capturedPieces(white: true).count, session.capturedPieces(white: false).count) >= 14)
                        #expect(session.variations.show)
                        let screen = GalleryScenarios.gameScreen(session, fold: nil)
                        let sized = textSize.map { AnyView(screen.dynamicTypeSize($0)) } ?? screen
                        let (capture, frames) = try await layout(sized, size: size, style: style, defaults: GalleryScenarios.engineOnDefaults,
                                                                 sizeClasses: (.regular, .regular))
                        let board = try boardBox(in: capture, style: style, label)
                        // (below the minimum the whole row overflows the window, so only the rows are checked)
                        if size.width >= 740 {
                            #expect(board.minX >= 16 + gutter - 0.5, "\(label): the board starts at \(board.minX)")
                        }
                        let card = try movesCard(in: capture, style: style, board: board, label)

                        // The column's layout boundary is its frame (the rows span it): it ends one spacing before the move list,
                        // so no empty gutter, and never short of the board
                        let column = try #require(frames["column"], "\(label): no column frame in \(frames)")
                        #expect(card.minX - column.maxX <= 12.5, "\(label): the column ends at \(column.maxX), the card starts at \(card.minX)")
                        #expect(column.maxX >= board.maxX - 0.5, "\(label): the column ends at \(column.maxX), the board at \(board.maxX)")

                        let background = GalleryPixels.resolved(Walnut.background, style: style)
                        // The two player rows, above the board (from the column's top to the spacing) and below it (as tall as the
                        // first), over the column's width
                        let rowHeight = board.minY - 10 - column.minY
                        let rows = [CGRect(x: column.minX, y: column.minY, width: column.width, height: rowHeight),
                                    CGRect(x: column.minX, y: board.maxY + 10, width: column.width, height: rowHeight)]
                        var stripPixels = 0
                        for row in rows {
                            let band = CGRect(x: 0, y: row.minY, width: card.minX, height: row.height)
                            #expect(band.height > 0, "\(label): no row band")
                            // The gap before the card is free: no row reaches the card
                            let gap = CGRect(x: card.minX - 6, y: band.minY, width: 4, height: band.height)
                            #expect(GalleryPixels.differing(from: background, in: capture, region: gap).count == 0,
                                    "\(label): a row reaches the card at y \(band.minY)")
                            // Nothing drawn over the card's leading edge (the lower row: the top one is beside the card's header)
                            if band.minY > board.minY {
                                let edge = CGRect(x: card.minX + 1, y: band.minY, width: 3, height: band.height)
                                #expect(GalleryPixels.differing(from: GalleryPixels.resolved(Walnut.card, style: style), in: capture,
                                                                region: edge, tolerance: 60.0 / 255).count == 0,
                                        "\(label): something is drawn over the card's edge at y \(band.minY)")
                            }
                            // The capture line (the row's last 22 pt) has not vanished, from its left edge
                            let probe = row.minX + 2
                            stripPixels += GalleryPixels.differing(from: background, in: capture,
                                                                   region: CGRect(x: probe, y: row.maxY - 22, width: 120, height: 22)).count
                        }
                        #expect(stripPixels > 100, "\(label): the capture strip is not there (\(stripPixels) pixels)")

                        // The column, cards included, ends inside the padding
                        let beyond = CGRect(x: 0, y: size.height - 16 + 0.5, width: size.width, height: 16)
                        #expect(box(Walnut.frame, style, in: capture, region: beyond) == nil, "\(label): the frame colour past the padding")
                        #expect(box(Walnut.card, style, in: capture, region: beyond) == nil, "\(label): a card past the padding")
                    }
                }
            }
        }

        @Test("at 320 pt the capture line of fifteen pieces and its points stay whole inside the padding")
        func captureLineFitsTheNarrowestWindow() async throws {
            let size = GallerySize.narrow.points(screen: try SnapshotGalleryTests.screenSize())
            for style in styles {
                let session = GalleryScenarios.worstRowSession()
                #expect(session.capturedPieces(white: true).count == 15)
                let (capture, frames) = try await layout(GalleryScenarios.gameScreen(session, fold: nil), size: size, style: style)
                let column = try #require(frames["tall-column"], "\(style.rawValue): no tall column frame in \(frames)")
                #expect(column.minX >= 16 - 0.5 && column.maxX <= size.width - 16 + 0.5,
                        "\(style.rawValue): the column spans \(column.minX)...\(column.maxX)")

                // Nothing is drawn past the padding on the trailing side: the capture lines (the pieces and the points), the
                // board and the cards all end inside it
                let background = GalleryPixels.resolved(Walnut.background, style: style)
                let beyond = CGRect(x: size.width - 16 + 0.5, y: 0, width: 16, height: size.height)
                #expect(GalleryPixels.differing(from: background, in: capture, region: beyond).count == 0,
                        "\(style.rawValue): something is drawn past the padding")
                // The content is all there, by layout frames: each capture line inside the column on both edges, and the points
                // label (the side that has material ahead) whole inside its line
                var shownPoints = 0
                for side in ["white", "black"] {
                    let line = try #require(frames["captures-\(side)"], "\(style.rawValue): no \(side) capture line in \(frames)")
                    #expect(line.width > 0 && line.minX >= column.minX - 0.5 && line.maxX <= column.maxX + 0.5,
                            "\(style.rawValue): the \(side) capture line spans \(line.minX)...\(line.maxX), the column \(column.minX)...\(column.maxX)")
                    if let points = frames["points-\(side)"] {
                        shownPoints += 1
                        #expect(points.width > 0 && points.minX >= line.minX - 0.5 && points.maxX <= line.maxX + 0.5,
                                "\(style.rawValue): the \(side) points span \(points.minX)...\(points.maxX), the line \(line.minX)...\(line.maxX)")
                    }
                }
                #expect(shownPoints == 1, "\(style.rawValue): \(shownPoints) points labels, one side is ahead")
                // and the column is drawn
                let rowsRegion = CGRect(x: 16, y: column.minY, width: size.width - 32, height: column.height)
                #expect(GalleryPixels.differing(from: background, in: capture, region: rowsRegion).count > 1000)
            }
        }

        /// Measures what a `CaptureLine` reports for a proposal, from the inside of a layout.
        private struct Reporter: Layout {
            let result: Box
            @MainActor final class Box { var sizes: [String: CGSize] = [:] }
            func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
                guard let line = subviews.first else {
                    return .zero
                }
                let sizes = ["minimum": line.sizeThatFits(ProposedViewSize(width: 0, height: nil)),
                             "ideal": line.sizeThatFits(.unspecified),
                             "narrow": line.sizeThatFits(ProposedViewSize(width: 100, height: nil))]
                MainActor.assumeIsolated { result.sizes = sizes }
                return sizes["ideal"]!
            }
            func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
                subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
            }
        }

        @Test("a capture line asked for its minimum reports the squeezed width, its ideal stays the overlapped one")
        func captureLineReportsItsTrueMinimum() async throws {
            let box = Reporter.Box()
            let pieces = 15
            let view = Reporter(result: box) {
                CaptureLine(overlap: -4, piecesPadding: 6) {
                    ForEach(0..<pieces, id: \.self) { _ in
                        Color.clear.frame(width: CaptureLine.side, height: CaptureLine.side)
                            .layoutValue(key: CaptureLine.Role.self, value: .piece)
                    }
                    Text(verbatim: "+5").font(.footnote).fixedSize()
                        .layoutValue(key: CaptureLine.Role.self, value: .points)
                }
            }
            _ = try await SnapshotGalleryTests.render(AnyView(view), size: CGSize(width: 400, height: 60), scale: 1, style: .light)
            let minimum = try #require(box.sizes["minimum"]).width
            let ideal = try #require(box.sizes["ideal"]).width
            let narrow = try #require(box.sizes["narrow"]).width
            let side = CaptureLine.side
            // Pieces at the squeezed step vs at the ideal overlap, the padding, gap and points being the same
            let squeezed = side + CaptureLine.minimumStep * CGFloat(pieces - 1)
            let overlapped = side * CGFloat(pieces) - 4 * CGFloat(pieces - 1)
            #expect(abs((ideal - minimum) - (overlapped - squeezed)) <= 0.5, "minimum \(minimum), ideal \(ideal)")
            // The points are a few characters wide: the minimum is the pieces' 50 pt, the padding, the gap and them
            #expect(minimum > squeezed + 12 + CaptureLine.gap && minimum < squeezed + 12 + CaptureLine.gap + 40, "the minimum is \(minimum)")
            // A finite width is still filled exactly by squeezing
            #expect(narrow <= 100 + 0.5, "offered 100 pt, \(narrow)")
        }

        @Test("a fold that leaves a narrow strip falls back to the tall layout inside it")
        func narrowFallbackGoesTallInsideTheUsableArea() async throws {
            let region = FoldRegion(frame: CGRect(x: 140, y: 0, width: 40, height: 288), isActive: true)
            for style in styles {
                let capture = try await image(GalleryScenarios.gameScreen(GalleryScenarios.humanToMoveSession(), fold: region),
                                              size: CGSize(width: 332, height: 320), style: style)
                let frame = try #require(box(Walnut.frame, style, in: capture))
                #expect(frame.minX >= 16 - 0.5 && frame.maxX <= 144 + 0.5, "\(style.rawValue): the board spans \(frame.minX)...\(frame.maxX)")
                let below = CGRect(x: 0, y: frame.maxY, width: capture.size.width, height: capture.size.height - frame.maxY)
                let card = try #require(box(Walnut.card, style, in: capture, region: below), "\(style.rawValue): the Moves card is not in the capture")
                #expect(card.minX >= 16 - 0.5 && card.maxX <= 144 + 0.5, "\(style.rawValue): the card spans \(card.minX)...\(card.maxX)")
                #expect(card.maxY <= 320 - 16 + 0.5, "\(style.rawValue): the card ends at \(card.maxY)")
                let beyond = CGRect(x: 156, y: 0, width: capture.size.width - 156, height: capture.size.height)
                #expect(box(Walnut.frame, style, in: capture, region: beyond) == nil)
                #expect(box(Walnut.card, style, in: capture, region: beyond) == nil)
            }
        }

        // MARK: Face to face

        /// A friend game captured as both face-to-face oracles do: the worst row (the longest capture strips) unless a session is given.
        private func faceToFaceCapture(size: GallerySize, textSize: DynamicTypeSize?, style: UIUserInterfaceStyle, fold: FoldRegion? = nil,
                                       session: GameSession = GalleryScenarios.friendSession(GalleryScenarios.Fixture.worstRow),
                                       direction: LayoutDirection? = nil) async throws -> (capture: UIImage, window: CGSize) {
            let window = size.points(screen: try SnapshotGalleryTests.screenSize())
            var screen = GalleryScenarios.friendScreen(session, fold: fold)
            if let textSize {
                screen = AnyView(screen.dynamicTypeSize(textSize))
            }
            if let direction {
                screen = AnyView(screen.environment(\.layoutDirection, direction))
            }
            let capture = try await SnapshotGalleryTests.render(AnyView(screen.defaultAppStorage(GalleryScenarios.defaults)), size: window,
                                                                sizeClasses: size.sizeClasses, scale: 3, style: style)
            return (capture, window)
        }

        /// The rectangle without `cut` (up to four pieces).
        private func rect(_ rect: CGRect, without cut: CGRect) -> [CGRect] {
            let hole = rect.intersection(cut)
            guard !hole.isNull else { return [rect] }
            return [CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: hole.minY - rect.minY),
                    CGRect(x: rect.minX, y: hole.maxY, width: rect.width, height: rect.maxY - hole.maxY),
                    CGRect(x: rect.minX, y: hole.minY, width: hole.minX - rect.minX, height: hole.height),
                    CGRect(x: hole.maxX, y: hole.minY, width: rect.maxX - hole.maxX, height: hole.height)]
                .filter { $0.width > 0 && $0.height > 0 }
        }

        /// What both orientations hold: the bar's strip (`strip`, across the window, its buttons at the two ends) is empty
        /// but for its two 44 pt buttons; each half's board stands in its own half, clear of the strip and of the padding,
        /// at least 100 pt wide; nothing is drawn past the padding. `wide`: the halves are left and right of a vertical strip.
        private func expectHalvesInTheirOwn(_ capture: UIImage, window: CGSize, wide: Bool, strip: CGRect, style: UIUserInterfaceStyle,
                                            label: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> [CGRect] {
            let background = GalleryPixels.resolved(Walnut.background, style: style)
            let button: CGFloat = 44
            let buttons = wide
                ? [CGRect(x: strip.midX - button / 2, y: 16, width: button, height: button),
                   CGRect(x: strip.midX - button / 2, y: window.height - 16 - button, width: button, height: button)]
                : [CGRect(x: 16, y: strip.midY - button / 2, width: button, height: button),
                   CGRect(x: window.width - 16 - button, y: strip.midY - button / 2, width: button, height: button)]
            var pieces = [strip]
            for cut in buttons {
                pieces = pieces.flatMap { rect($0, without: cut) }
            }
            for piece in pieces {
                #expect(GalleryPixels.differing(from: background, in: capture, region: piece).count == 0,
                        "\(label): something is drawn in the bar's strip at \(piece)", sourceLocation: sourceLocation)
            }

            // The two halves, each with its board and its player's row; the strip is between them
            let halves = wide
                ? [CGRect(x: 0, y: 0, width: strip.minX, height: window.height),
                   CGRect(x: strip.maxX, y: 0, width: window.width - strip.maxX, height: window.height)]
                : [CGRect(x: 0, y: 0, width: window.width, height: strip.minY),
                   CGRect(x: 0, y: strip.maxY, width: window.width, height: window.height - strip.maxY)]
            var boards = [CGRect]()
            for (index, half) in halves.enumerated() {
                let board = try #require(box(Walnut.frame, style, in: capture, region: half), "\(label): no board in half \(index)", sourceLocation: sourceLocation)
                #expect(half.insetBy(dx: wide ? 0 : 16 - 0.5, dy: wide ? 16 - 0.5 : 0).contains(board),
                        "\(label): the board \(board) leaves its half \(half)", sourceLocation: sourceLocation)
                #expect(board.minX >= 16 - 0.5 && board.maxX <= window.width - 16 + 0.5 && board.minY >= 16 - 0.5
                        && board.maxY <= window.height - 16 + 0.5, "\(label): the board \(board) reaches the padding", sourceLocation: sourceLocation)
                #expect(board.width >= 100, "\(label): the board is only \(board.width) pt wide", sourceLocation: sourceLocation)
                boards.append(board)
                // The whole column: a half holds only its own player's row, beside the board on the side away from the bar
                // (the opponent's row is on the other half), and no status line
                let before = wide ? CGRect(x: half.minX, y: 0, width: board.minX - half.minX, height: window.height)
                                  : CGRect(x: 0, y: half.minY, width: window.width, height: board.minY - half.minY)
                let after = wide ? CGRect(x: board.maxX, y: 0, width: half.maxX - board.maxX, height: window.height)
                                 : CGRect(x: 0, y: board.maxY, width: window.width, height: half.maxY - board.maxY)
                let counts = [before, after].map { GalleryPixels.differing(from: background, in: capture, region: $0).count }
                if wide {
                    #expect(counts.contains { $0 > 100 }, "\(label): the row of half \(index) is not beside its board (\(counts))", sourceLocation: sourceLocation)
                } else {
                    let away = index == 0 ? counts[0] : counts[1]
                    #expect(away > 100, "\(label): the row of half \(index) is not on the side of the board away from the bar (\(counts))", sourceLocation: sourceLocation)
                }
            }
            let edges = [CGRect(x: 0, y: 0, width: 15.5, height: window.height),
                         CGRect(x: window.width - 15.5, y: 0, width: 15.5, height: window.height),
                         CGRect(x: 0, y: 0, width: window.width, height: 15.5),
                         CGRect(x: 0, y: window.height - 15.5, width: window.width, height: 15.5)]
            for edge in edges {
                #expect(GalleryPixels.differing(from: background, in: capture, region: edge).count == 0, "\(label): drawn past the padding at \(edge)", sourceLocation: sourceLocation)
            }
            return boards
        }

        @Test("each half's whole column (board and its own row) lies inside its half: nothing under the bar, nothing past the window",
              arguments: [GallerySize.smallPhone, GallerySize.phone],
              [nil, DynamicTypeSize.xxxLarge, DynamicTypeSize.accessibility3])
        func faceToFaceColumnsStayInTheirHalves(size: GallerySize, textSize: DynamicTypeSize?) async throws {
            // The requested sizes are the limit and the largest size, which the half clamps to the limit
            #expect(ContentView<EmptyView>.faceToFaceTextLimit == .xxxLarge)
            for style in styles {
                let (capture, window) = try await faceToFaceCapture(size: size, textSize: textSize, style: style)
                let label = "\(Int(window.width)), \(style.rawValue), \(textSize.map { "\($0)" } ?? "default text")"
                let strip = CGRect(x: 0, y: window.height / 2 - 14, width: window.width, height: 28)
                _ = try expectHalvesInTheirOwn(capture, window: window, wide: false, strip: strip, style: style, label: label)
            }
        }

        @Test("side by side, each half's whole column lies inside its half: nothing under the bar, nothing past the window",
              arguments: [GallerySize.phoneLandscape, GallerySize.ipadLandscape],
              [nil, DynamicTypeSize.xxxLarge, DynamicTypeSize.accessibility3])
        func faceToFaceLandscapeColumnsStayInTheirHalves(size: GallerySize, textSize: DynamicTypeSize?) async throws {
            for style in styles {
                let (capture, window) = try await faceToFaceCapture(size: size, textSize: textSize, style: style)
                let label = "\(Int(window.width))x\(Int(window.height)), \(style.rawValue), \(textSize.map { "\($0)" } ?? "default text")"
                let strip = CGRect(x: window.width / 2 - 22, y: 0, width: 44, height: window.height)
                _ = try expectHalvesInTheirOwn(capture, window: window, wide: true, strip: strip, style: style, label: label)
            }
        }

        @Test("on the Duo's inner display neither half reaches the hinge, tall or side by side",
              arguments: [GallerySize.duoInnerPortrait, GallerySize.duoInnerLandscape])
        func faceToFaceHalvesClearTheHinge(size: GallerySize) async throws {
            let wide = size == .duoInnerLandscape
            let hinge = wide ? GalleryScenarios.duoLandscapeHinge : GalleryScenarios.duoPortraitTabletop
            for style in styles {
                let (capture, window) = try await faceToFaceCapture(size: size, textSize: nil, style: style, fold: hinge)
                let label = "\(size), \(style.rawValue)"
                // The region is in content coordinates, 16 pt inside the window; each side keeps a 12 pt gutter, and the
                // bar fills the gap, so the halves start after the gutter
                let frame = hinge.frame.offsetBy(dx: 16, dy: 16)
                let strip = wide ? CGRect(x: frame.minX - 12, y: 0, width: frame.width + 24, height: window.height)
                                 : CGRect(x: 0, y: frame.minY - 12, width: window.width, height: frame.height + 24)
                let boards = try expectHalvesInTheirOwn(capture, window: window, wide: wide, strip: strip, style: style, label: label)
                for (index, board) in boards.enumerated() {
                    let hingeBand = wide ? CGRect(x: frame.minX, y: 0, width: frame.width, height: window.height)
                                         : CGRect(x: 0, y: frame.minY, width: window.width, height: frame.height)
                    #expect(!board.intersects(hingeBand), "\(label): the board \(index) \(board) is on the hinge \(hingeBand)")
                }
                // Not a pixel of either half's column on the hinge outside the two buttons (they stand on it by design)
                let background = GalleryPixels.resolved(Walnut.background, style: style)
                let band = wide ? CGRect(x: frame.minX, y: 16 + 44, width: frame.width, height: window.height - 2 * (16 + 44))
                                : CGRect(x: 16 + 44, y: frame.minY, width: window.width - 2 * (16 + 44), height: frame.height)
                #expect(GalleryPixels.differing(from: background, in: capture, region: band).count == 0, "\(label): something is on the hinge")
            }
        }

        @Test("the first player's half is the left one in every language: the promotion picker of the player on move, Black, shows on the right",
              arguments: [GallerySize.phoneLandscape, GallerySize.ipadLandscape], [LayoutDirection.leftToRight, LayoutDirection.rightToLeft])
        func firstPlayersHalfIsOnTheLeft(size: GallerySize, direction: LayoutDirection) async throws {
            // Black promotes, so Black is on move and only Black's half (the second player's, the right one) shows the picker;
            // were the arrangement mirrored by the language, the picker would show on the left
            func session() throws -> GameSession {
                let session = GalleryScenarios.friendSession(GalleryScenarios.Fixture.blackPromotes)
                session.select(rank: 1, file: 0)
                session.beginPromotion(try #require(session.selection.possibleMove(0, 0)))
                try #require(session.pendingPromotion != nil)
                return session
            }
            for style in styles {
                let (capture, window) = try await faceToFaceCapture(size: size, textSize: nil, style: style, session: try session(), direction: direction)
                let label = "\(Int(window.width))x\(Int(window.height)), \(style.rawValue), \(direction)"
                let left = box(Walnut.pillBackground, style, in: capture, region: CGRect(x: 0, y: 0, width: window.width / 2, height: window.height))
                let right = box(Walnut.pillBackground, style, in: capture, region: CGRect(x: window.width / 2, y: 0, width: window.width / 2, height: window.height))
                #expect(left == nil, "\(label): the picker is on the left half (\(String(describing: left)))")
                #expect(right != nil, "\(label): the picker is not on the right half")
            }
        }

        @Test("an iPhone allows landscape exactly while a friend game is open, an iPad always; the app delegate answers the open game's mask")
        func appDelegateAnswersTheMaskOfTheOpenGame() {
            let friend = GameState(pgn: GalleryScenarios.Fixture.empty, white: .human, black: .human, faceToFace: true)
            let computer = GameState(pgn: GalleryScenarios.Fixture.empty, white: .human, black: .computer(.club))
            let delegate = AppDelegate()
            func answer() -> UIInterfaceOrientationMask {
                delegate.application(.shared, supportedInterfaceOrientationsFor: nil)
            }
            OrientationLock.update(for: friend, isPad: false)
            #expect(answer().contains(.landscapeLeft) && answer().contains(.landscapeRight))
            #expect(!answer().contains(.portraitUpsideDown))
            OrientationLock.update(for: computer, isPad: false)
            #expect(answer() == .portrait)
            OrientationLock.update(for: computer, isPad: true)
            #expect(answer() == .all)
            OrientationLock.update(for: computer, isPad: false)
        }

        @Test("a mounted game screen stops its analysis when the players become friends")
        func mountedScreenStopsAnalysisWhenPlayersBecomeFriends() async throws {
            let session = GameSession(state: GameState(pgn: GalleryScenarios.Fixture.empty, white: .human, black: .computer(.maximum, thinkingTime: 5)))
            defer { session.cancelSearch() }
            let mounted = try SnapshotGalleryTests.mount(AnyView(ContentView(session: session).defaultAppStorage(GalleryScenarios.engineOnDefaults)),
                                                         size: CGSize(width: 402, height: 874), style: .light)
            defer { mounted.close() }

            #expect(await wait { session.isAnalyzing }, "the screen with the engine on analyzes the position")
            #expect(await wait { session.info != nil }, "the analysis reports")
            let stale = try #require(session.info)
            let analysisToken = session.analysisID
            let searchToken = session.positionID

            // The production observation (`ContentView.onChange` of the effective setting), not a hand assignment
            session.setPlayers(white: .human, black: .human)
            #expect(await wait { !session.isAnalyzing }, "the analysis stops in the same screen")
            #expect(session.info == nil)

            // A late callback of the analysis and of the search that were running, with their tokens, lands nowhere (I2)
            let fen = session.fen
            session.analysisDidUpdate(stale, completed: false, token: analysisToken)
            session.analysisDidUpdate(stale, completed: true, token: analysisToken)
            session.searchDidUpdate(stale, completed: false, token: searchToken)
            session.searchDidUpdate(stale, completed: true, token: searchToken)
            #expect(session.info == nil)
            #expect(!session.isAnalyzing)
            #expect(session.fen == fen)
        }

        @Test("a mounted game screen stops its analysis on two boards and restarts it on the single board")
        func mountedScreenFollowsTheTwoBoardsToggle() async throws {
            let session = GameSession(state: GameState(pgn: GalleryScenarios.Fixture.empty, white: .human, black: .human))
            defer { session.cancelSearch() }
            let mounted = try SnapshotGalleryTests.mount(AnyView(ContentView(session: session).defaultAppStorage(GalleryScenarios.engineOnDefaults)),
                                                         size: CGSize(width: 402, height: 874), style: .light)
            defer { mounted.close() }

            #expect(await wait { session.isAnalyzing }, "the single board with the engine on analyzes")
            #expect(await wait { session.info != nil }, "the analysis reports")
            let stale = try #require(session.info)
            let analysisToken = session.analysisID

            // The production observation (`ContentView.onChange` of `showEngine`), not a hand assignment
            session.setFaceToFace(true)
            #expect(await wait { !session.isAnalyzing }, "two boards stop the analysis")
            #expect(session.info == nil)
            #expect(!session.isAnalyzing)

            session.setFaceToFace(false)
            #expect(await wait { session.isAnalyzing }, "the single board analyzes again")
            // No suspension from here to the checks: the readout and the running flag are the new analysis's. The old
            // analysis's late callbacks (its token) must land nowhere, a stale completion included.
            let readout = session.info
            let running = session.isAnalyzing
            session.analysisDidUpdate(stale, completed: false, token: analysisToken)
            session.analysisDidUpdate(stale, completed: true, token: analysisToken)
            #expect(session.info === readout, "a callback with the old token is rejected")
            #expect(session.isAnalyzing == running, "a stale completion does not end the new analysis")
            #expect(await wait { session.info != nil }, "the restarted analysis reports")
            #expect(session.analysisID > analysisToken)
        }
    }
}
