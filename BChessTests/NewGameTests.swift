//
//  NewGameTests.swift
//  BChessTests
//
//  The New Game sheet's choices: who plays, the labels of the mockups, and the remembered choice.
//

import Foundation
import Testing

struct NewGameTests {

    private func game(_ opponent: NewGame.Opponent, side: NewGame.Side = .white, name: String = "",
                      second: String = "", time: TimeInterval = 10) -> NewGame {
        var choice = NewGame()
        choice.opponent = opponent
        choice.side = side
        choice.firstName = name
        choice.secondName = second
        choice.thinkingTime = time
        return choice
    }

    @Test func defaultsToClubAsWhite() {
        let choice = NewGame()
        #expect(choice.opponent == .club)
        #expect(choice.side == .white)
        #expect(choice.firstName == "")
        #expect(choice.secondName == "")
        #expect(choice.thinkingTime == 10)
    }

    @Test(arguments: [(NewGame.Opponent.beginner, 0), (.casual, 1), (.club, 2), (.strong, 3)])
    func playersAgainstEachLevel(_ opponent: NewGame.Opponent, _ level: Int) {
        let players = game(opponent, name: "Ann").players(firstPlaysWhite: true)
        #expect(players.white == GamePlayer(name: "Ann", computer: false, level: 0))
        #expect(players.black == GamePlayer(name: "", computer: true, level: level))
        #expect(!players.rotated)
    }

    @Test func maximumKeepsItsThinkingTime() {
        for (time, level) in [(5.0, 4), (10.0, 5), (30.0, 6)] {
            let players = game(.maximum, time: time).players(firstPlaysWhite: true)
            #expect(players.black.level == level)
            #expect(players.black.thinkingTime == time)
        }
    }

    @Test func thinkingTimeOnlyAtMaximum() {
        for opponent in NewGame.Opponent.allCases {
            #expect(game(opponent).showsThinkingTime == (opponent == .maximum))
        }
        // A time left over from Maximum does not reach a lower level
        #expect(game(.strong, time: 30).players(firstPlaysWhite: true).black.level == 3)
    }

    @Test func randomSideUsesTheCoin() {
        let choice = game(.club, side: .random, name: "Ann")
        let first = choice.players(firstPlaysWhite: true)
        #expect(first.white.name == "Ann" && !first.rotated)
        let second = choice.players(firstPlaysWhite: false)
        #expect(second.black.name == "Ann" && second.black.computer == false)
        #expect(second.white.computer)
        #expect(second.rotated)

        // The coin is not asked of a chosen side
        #expect(game(.club, side: .white).players(firstPlaysWhite: false).white.computer == false)
        #expect(game(.club, side: .black).players(firstPlaysWhite: true).black.computer == false)
    }

    @Test func friendNamesFollowTheFirstPlayersColor() {
        let white = game(.friend, side: .white, name: "Ann", second: "Ben").players(firstPlaysWhite: true)
        #expect(white.white.name == "Ann" && white.black.name == "Ben")
        #expect(!white.white.computer && !white.black.computer)
        #expect(!white.rotated)

        let black = game(.friend, side: .black, name: "Ann", second: "Ben").players(firstPlaysWhite: true)
        #expect(black.black.name == "Ann" && black.white.name == "Ben")
        #expect(black.rotated)

        let random = game(.friend, side: .random, name: "Ann", second: "Ben").players(firstPlaysWhite: false)
        #expect(random.black.name == "Ann" && random.white.name == "Ben")
    }

    @Test func rotatedWhenThePlayerHasBlack() {
        for opponent in NewGame.Opponent.allCases {
            #expect(game(opponent, side: .black).players(firstPlaysWhite: true).rotated)
            #expect(!game(opponent, side: .white).players(firstPlaysWhite: false).rotated)
        }
    }

    @Test func labelsFollowTheMockups() {
        #expect(String(localized: NewGame().sideLabel) == "You play")
        #expect(String(localized: NewGame().firstNameLabel) == "Your name")
        let labels: [(NewGame.Opponent, String)] = [(.beginner, "Play the Beginner Player"), (.casual, "Play the Casual Player"),
                                                    (.club, "Play the Club Player"), (.strong, "Play the Strong Player"),
                                                    (.maximum, "Play the Full Engine"), (.friend, "Start Game")]
        for (opponent, label) in labels {
            #expect(String(localized: game(opponent).playLabel) == label)
        }

        #expect(String(localized: game(.friend).sideLabel) == "First player plays")
        #expect(String(localized: game(.friend, side: .white).firstNameLabel) == "White")
        #expect(String(localized: game(.friend, side: .white).secondNameLabel) == "Black")
        #expect(String(localized: game(.friend, side: .black).firstNameLabel) == "Black")
        #expect(String(localized: game(.friend, side: .black).secondNameLabel) == "White")
        #expect(String(localized: game(.friend, side: .random).firstNameLabel) == "Random color")
        #expect(String(localized: game(.friend, side: .random).secondNameLabel) == "Random color")

        #expect(String(localized: NewGame.Opponent.club.name) == "Club")
        #expect(String(localized: NewGame.Opponent.friend.name) == "A friend")
        #expect(String(localized: NewGame.Opponent.maximum.name) == "Maximum")
        #expect(NewGame.Opponent.beginner.elo.map { String(localized: $0) } == "about 550")
        #expect(NewGame.Opponent.maximum.elo.map { String(localized: $0) } == "about 2350")
        #expect(NewGame.Opponent.allCases.map { $0.elo.map { String(localized: $0) } } == [nil, "about 550", "about 950", "about 1350", "about 1600", "about 2350"])
        #expect(NewGame.Opponent.friend.elo == nil)
        #expect(String(localized: NewGame.Opponent.beginner.blurb) == "Sees one move ahead, misses threats")
        #expect(String(localized: NewGame.Opponent.strong.blurb) == "Rarely blunders; needs a real plan")
        #expect(String(localized: NewGame.Opponent.maximum.blurb) == "The full engine, no handicap")
        #expect(NewGame.Opponent.allCases.map(\.pieceImage) == ["pawn_w", "pawn_b", "knight_b", "bishop_b", "rook_b", "queen_b"])
    }

    @Test func editReadsTheGamesPlayers() {
        let ann = GamePlayer(name: "Ann", computer: false, level: 0)

        let asWhite = NewGame(white: ann, black: .computer(.strong))
        #expect(asWhite.opponent == .strong && asWhite.side == .white && asWhite.firstName == "Ann")

        let asBlack = NewGame(white: .computer(.maximum, thinkingTime: 30), black: ann)
        #expect(asBlack.opponent == .maximum && asBlack.side == .black && asBlack.firstName == "Ann")
        #expect(asBlack.thinkingTime == 30)

        let friends = NewGame(white: ann, black: GamePlayer(name: "Ben", computer: false, level: 0))
        #expect(friends.opponent == .friend && friends.side == .white)
        #expect(friends.firstName == "Ann" && friends.secondName == "Ben")

        // Applying the edit gives the same players back
        let players = asBlack.players(firstPlaysWhite: true)
        #expect(players.white == .computer(.maximum, thinkingTime: 30))
        #expect(players.black == ann)
    }

    @Test func editOfTwoComputersBecomesYouAgainstBlack() {
        let choice = NewGame(white: .computer(.club), black: .computer(.strong))
        #expect(choice.opponent == .strong)
        #expect(choice.side == .white)
        #expect(choice.firstName == "")
        let players = choice.players(firstPlaysWhite: true)
        #expect(!players.white.computer)
        #expect(players.black == .computer(.strong))
    }

    private func scratchDefaults() throws -> (UserDefaults, String) {
        let name = "NewGameTests-\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test func rememberedChoiceRoundTrips() throws {
        let (defaults, suite) = try scratchDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        // Nothing stored: the defaults
        #expect(NewGame(remembered: defaults) == NewGame())

        let maximum = game(.maximum, side: .black, name: "Ann", time: 30)
        maximum.remember(in: defaults)
        #expect(NewGame(remembered: defaults) == maximum)

        let friend = game(.friend, side: .random, name: "Ann", second: "Ben")
        friend.remember(in: defaults)
        let restored = NewGame(remembered: defaults)
        #expect(restored == friend)
        #expect(restored.secondName == "Ben")

        // An unknown value falls back to the default of that field only
        defaults.set(99, forKey: AppSettings.newGameOpponentKey)
        defaults.set(-1, forKey: AppSettings.newGameSideKey)
        defaults.set(7.0, forKey: AppSettings.newGameThinkingTimeKey)
        defaults.set(5, forKey: AppSettings.newGameNameKey)
        let fallback = NewGame(remembered: defaults)
        #expect(fallback.opponent == .club)
        #expect(fallback.side == .white)
        #expect(fallback.thinkingTime == 10)
        #expect(fallback.firstName == "")
        #expect(fallback.secondName == "Ben")
    }
}
