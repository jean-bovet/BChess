//
//  LocalizationTests.swift
//  BChessMacGalleryTests
//
//  The leaf strings of the model and the views resolved in every language of the catalog, through the hosted app's
//  own bundle. The unhosted `BChessTests` cannot do it (its main bundle is the test runner). The expected texts are
//  in `LocalizationExpectations.swift`, written once from the translations for the keys these cases name (edit it
//  with the catalog); each case names the English key it must resolve to, so a swapped or wrong unit fails by name.
//

import Foundation
import Testing
@testable import BChess

@MainActor
struct LocalizationTests {

    nonisolated static let languages = LocalizationExpectations.languages

    /// The resource resolved in a language (`String(localized:)` alone takes the process's locale).
    static func localized(_ resource: LocalizedStringResource, _ language: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }

    /// Foundation sets every `%@` argument of a right-to-left language in a first-strong isolate (U+2068 ... U+2069) so
    /// that it cannot disturb the sentence; the expected text carries them too.
    static func argument(_ text: String, _ language: String) -> String {
        ["he", "ar"].contains(language) ? "\u{2068}\(text)\u{2069}" : text
    }

    /// The translation of an English key in a language.
    static func t(_ key: String, _ language: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> String {
        try #require(LocalizationExpectations.texts[language]?[key], "no expected text for \"\(key)\" in \(language)",
                     sourceLocation: sourceLocation)
    }

    /// The case's resource against the translation of `key`.
    private func check(_ resource: LocalizedStringResource, is key: String, _ language: String,
                       sourceLocation: SourceLocation = #_sourceLocation) throws {
        let expected = try Self.t(key, language, sourceLocation: sourceLocation)
        #expect(Self.localized(resource, language) == expected, "\(key) in \(language)", sourceLocation: sourceLocation)
    }

    @Test(arguments: languages)
    func levelsAndComputerNames(_ language: String) throws {
        let cases: [(EngineStrength, String, String)] = [
            (.beginner, "Beginner", "Beginner Player"), (.casual, "Casual", "Casual Player"), (.club, "Club", "Club Player"),
            (.strong, "Strong", "Strong Player"), (.maximum, "Maximum", "Full Engine"),
        ]
        for (strength, level, computer) in cases {
            try check(strength.displayName, is: level, language)
            try check(strength.computerName, is: computer, language)
        }
    }

    @Test(arguments: languages)
    func opponentRows(_ language: String) throws {
        let names: [(NewGame.Opponent, String)] = [
            (.friend, "A friend"), (.beginner, "Beginner"), (.casual, "Casual"), (.club, "Club"), (.strong, "Strong"), (.maximum, "Maximum"),
        ]
        for (opponent, key) in names {
            try check(opponent.name, is: key, language)
        }
        let blurbs: [(NewGame.Opponent, String)] = [
            (.friend, "Take turns on this Mac"), (.beginner, "Sees one move ahead, misses threats"),
            (.casual, "Sensible, but blunders under pressure"), (.club, "Solid, with the occasional mistake"),
            (.strong, "Rarely blunders; needs a real plan"), (.maximum, "The full engine, no handicap"),
        ]
        for (opponent, key) in blurbs {
            try check(opponent.blurb, is: key, language)
        }
        let elos: [(NewGame.Opponent, String?)] = [
            (.friend, nil), (.beginner, "about 550"), (.casual, "about 950"), (.club, "about 1350"),
            (.strong, "about 1600"), (.maximum, "about 2350"),
        ]
        for (opponent, key) in elos {
            if let key {
                try check(try #require(opponent.elo), is: key, language)
            } else {
                #expect(opponent.elo == nil)
            }
        }
        let play: [(NewGame.Opponent, String)] = [
            (.friend, "Start Game"), (.beginner, "Play the Beginner Player"), (.casual, "Play the Casual Player"),
            (.club, "Play the Club Player"), (.strong, "Play the Strong Player"), (.maximum, "Play the Full Engine"),
        ]
        for (opponent, key) in play {
            try check(opponent.playLabel, is: key, language)
        }
    }

    @Test(arguments: languages)
    func sideAndNameLabels(_ language: String) throws {
        var friend = NewGame()
        friend.opponent = .friend
        try check(friend.sideLabel, is: "First player plays", language)
        var computer = NewGame()
        computer.opponent = .club
        try check(computer.sideLabel, is: "You play", language)
        try check(computer.firstNameLabel, is: "Your name", language)

        let cases: [(NewGame.Side, String, String)] = [(.white, "White", "Black"), (.black, "Black", "White"),
                                                       (.random, "Random color", "Random color")]
        for (side, first, second) in cases {
            friend.side = side
            try check(friend.firstNameLabel, is: first, language)
            try check(friend.secondNameLabel, is: second, language)
        }
        try check(GameText.color(isWhite: true), is: "White", language)
        try check(GameText.color(isWhite: false), is: "Black", language)
    }

    /// Every branch of the verdict: the equal position, three strengths for each colour, and a mate for each.
    @Test(arguments: languages)
    func verdictSentences(_ language: String) throws {
        let cases: [(Int, Bool, String)] = [
            (0, false, "The position is equal"),
            (50, false, "White is slightly better"), (-50, false, "Black is slightly better"),
            (150, false, "White is better"), (-150, false, "Black is better"),
            (300, false, "White is winning"), (-300, false, "Black is winning"),
            (30000, true, "White has a forced mate"), (-30000, true, "Black has a forced mate"),
        ]
        for (centipawns, isMate, key) in cases {
            try check(Verdict(centipawns: centipawns, isMate: isMate).sentence, is: key, language)
        }
        let label = try Self.t("Evaluation %@", language).replacingOccurrences(of: "%@", with: Self.argument(Verdict(centipawns: 40, isMate: false).score, language))
        #expect(Self.localized(Verdict(centipawns: 40, isMate: false).accessibilityLabel, language) == label)
    }

    @Test(arguments: languages)
    func themesGroupsAndPieces(_ language: String) throws {
        let themes: [(AppTheme, String)] = [(.system, "System"), (.light, "Light"), (.dark, "Dark")]
        for (theme, key) in themes {
            try check(theme.title, is: key, language)
        }
        let groups: [(GameSection.Group, String)] = [(.today, "Today"), (.yesterday, "Yesterday"), (.earlier, "Earlier")]
        for (group, key) in groups {
            try check(group.title, is: key, language)
        }
        let pieces: [(String, String)] = [("Q", "Queen"), ("R", "Rook"), ("B", "Bishop"), ("N", "Knight"), ("q", "Queen")]
        for (name, key) in pieces {
            try check(PromotionView.label(of: name), is: key, language)
        }
    }

    @Test(arguments: languages)
    func exportMessages(_ language: String) throws {
        struct Failure: LocalizedError { var errorDescription: String? { "denied" } }
        let seconds = try Self.t("%@ s", language).replacingOccurrences(of: "%@", with: Self.argument("10", language))
        #expect(Self.localized(GameText.seconds(10), language) == seconds)

        let export = try Self.t("Couldn't export the games. %@", language).replacingOccurrences(of: "%@", with: Self.argument("denied", language))
        #expect(Self.localized(GameText.exportFailed(Failure()), language) == export)
        let delete = try Self.t("Couldn't delete this game. %@", language).replacingOccurrences(of: "%@", with: Self.argument("denied", language))
        #expect(Self.localized(GameText.deleteFailed(Failure()), language) == delete)

        let plural = try #require(LocalizationExpectations.plurals["%lld games exported to “%@”"]?[language])
        for (count, category) in LocalizationExpectations.pluralCounts[language] ?? [] {
            let template = try #require(plural[category], "no \(category) form in \(language)")
            let expected = template.replacingOccurrences(of: "%1$lld", with: String(count)).replacingOccurrences(of: "%2$@", with: Self.argument("Folder", language))
            #expect(Self.localized(GameText.exported(count: count, folder: "Folder"), language) == expected, "\(count) games in \(language)")
        }
    }
}
