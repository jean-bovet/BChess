//
//  MacGalleryScenarios.swift
//  BChessMacGalleryTests
//
//  Every Mac window the gallery renders, in the order of the page. `MacSnapshotGalleryTests` renders the list in
//  light and dark, scripts/snapshot-mac.sh builds the page from the manifest the test writes.
//
//  Rules (scripts/preview-gallery.py --check enforces the last):
//  - a name is "Screen · State" and unique; the slug is derived from it
//  - every PGN a scenario loads is a constant of `Fixture` (GalleryFixtures.swift)
//  - no forced appearance or locale in this file
//

import SwiftUI
@testable import BChess

/// The size of a scenario's window.
enum MacWindowSize: Equatable {
    /// The whole window, title bar included, in points.
    case frame(CGSize)
    /// A window as wide as given and as high as its content wants to be (plus the title bar).
    case fits(width: CGFloat)
}

/// One named window: the card title, the page section, the window size and what the render waits for.
@MainActor
struct MacGalleryScenario {
    let name: String
    let group: String
    let size: MacWindowSize
    /// How long the render waits after the window is ready for SwiftUI's asynchronous work.
    var settle: Duration = .milliseconds(300)
    /// The window title the render waits for; nil for a window whose title the system sets.
    var title: String?
    /// The render waits for the players sheet to attach to the window, and composites it over the window.
    var waitsForSheet = false
    /// Throws when a fixture cannot be set up, which fails the render.
    let build: @MainActor () throws -> AnyView

    var slug: String { gallerySlug(of: name) }

    /// The content as the app shows it: the theme of `BChessUIApp`, and isolated settings (every @AppStorage reads its
    /// declared default, and nothing writes the app's real defaults).
    func view() throws -> some View {
        try build().appTheme().defaultAppStorage(GalleryScenarios.defaults)
    }
}

@MainActor
enum GalleryScenarios {}

@MainActor
enum MacGalleryScenarios {
    static let group = "Mac"
    static let windowFrame = MacWindowSize.frame(CGSize(width: 1440, height: 900))

    /// A document window over a game.
    private static func documentWindow(pgn: String, white: GamePlayer = .defaultWhite, black: GamePlayer = .defaultBlack,
                                       defaults: UserDefaults = GalleryScenarios.defaults) -> AnyView {
        AnyView(DocumentWindow(document: .constant(ChessDocument(state: GameState(pgn: pgn, white: white, black: black))), isNew: false)
            .defaultAppStorage(defaults))
    }

    /// The players sheet of a new game over a scratch suite seeded with `choice`, through the production writer, so
    /// the sheet reads it back with `NewGame(remembered:)` as the app does.
    static func newGameSuite(_ slug: String, seeded choice: NewGame) -> UserDefaults {
        let name = "BChessMacGallery.\(slug)"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        choice.remember(in: suite)
        return suite
    }

    static func newGameWindow(_ suite: UserDefaults) -> DocumentWindow {
        DocumentWindow(document: .constant(ChessDocument()), isNew: true, newGameDefaults: suite)
    }

    /// What each sheet scenario's mounted sheet holds (`MacGalleryScenarioTests` reads them).
    static let clubProbe = NewGameSheetProbe()
    static let friendProbe = NewGameSheetProbe()
    static let maximumProbe = NewGameSheetProbe()

    static let engineOnTitle = GameText.title(white: .defaultWhite, black: .defaultBlack)

    static let documentWindowEngineOn = MacGalleryScenario(
        name: "Document window · Engine on", group: group, size: windowFrame, settle: .seconds(2), title: engineOnTitle
    ) {
        documentWindow(pgn: GalleryScenarios.Fixture.middlegame, defaults: GalleryScenarios.engineOnDefaults)
    }

    static let documentWindowVariations = MacGalleryScenario(
        name: "Document window · Variations", group: group, size: windowFrame,
        title: GameText.title(white: .human, black: .human)
    ) {
        documentWindow(pgn: GalleryScenarios.Fixture.commented, white: .human, black: .human)
    }

    /// The seeded choices of the three sheet scenarios.
    static let clubChoice = NewGame()
    static let friendChoice: NewGame = {
        var choice = NewGame()
        choice.opponent = .friend
        choice.firstName = "Anna"
        choice.secondName = "Jean"
        return choice
    }()
    static let maximumChoice: NewGame = {
        var choice = NewGame()
        choice.opponent = .maximum
        choice.thinkingTime = 10
        return choice
    }()

    static let sheetClubSuite = newGameSuite("club", seeded: clubChoice)
    static let sheetFriendSuite = newGameSuite("friend", seeded: friendChoice)
    static let sheetMaximumSuite = newGameSuite("maximum", seeded: maximumChoice)

    static let documentWindowNewGameSheet = MacGalleryScenario(
        name: "Document window · New game sheet", group: group, size: windowFrame, title: "You vs Club Player",
        waitsForSheet: true
    ) {
        AnyView(newGameWindow(sheetClubSuite).environment(\.newGameSheetProbe, clubProbe))
    }

    static let documentWindowNewGameSheetFriend = MacGalleryScenario(
        name: "Document window · New game sheet · A friend", group: group, size: windowFrame, title: "You vs Club Player",
        waitsForSheet: true
    ) {
        AnyView(newGameWindow(sheetFriendSuite).environment(\.newGameSheetProbe, friendProbe))
    }

    static let documentWindowNewGameSheetMaximum = MacGalleryScenario(
        name: "Document window · New game sheet · Maximum", group: group, size: windowFrame, title: "You vs Club Player",
        waitsForSheet: true
    ) {
        AnyView(newGameWindow(sheetMaximumSuite).environment(\.newGameSheetProbe, maximumProbe))
    }

    static let settingsWindow = MacGalleryScenario(
        name: "Settings window", group: group, size: .fits(width: 460), title: "Settings"
    ) {
        // The Settings scene's window is titled by the system; this one by its content
        AnyView(SettingsView().navigationTitle("Settings"))
    }

    /// In the order of the page.
    static let all: [MacGalleryScenario] = [
        documentWindowEngineOn, documentWindowVariations,
        documentWindowNewGameSheet, documentWindowNewGameSheetFriend, documentWindowNewGameSheetMaximum,
        settingsWindow,
    ]

    /// The scenarios whose name or slug contains one of the comma-separated, case-insensitive patterns;
    /// an empty filter is every scenario.
    static func matching(_ filter: String) -> [MacGalleryScenario] {
        all.filter { galleryMatches(name: $0.name, slug: $0.slug, filter: filter) }
    }
}
