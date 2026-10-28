//
//  NewGame.swift
//  BChess
//
//  The choices of the New Game sheet, as a value: who plays, the words of the sheet, and the choice that the
//  next sheet opens on. Foundation only, so that the tests reach it.
//

import Foundation

nonisolated struct NewGame: Equatable, Sendable {

    enum Opponent: Int, CaseIterable, Sendable {
        case friend, beginner, casual, club, strong, maximum

        /// The computer's strength, nil for a friend.
        var strength: EngineStrength? {
            switch self {
            case .friend: return nil
            case .beginner: return .beginner
            case .casual: return .casual
            case .club: return .club
            case .strong: return .strong
            case .maximum: return .maximum
            }
        }

        var name: LocalizedStringResource { strength?.displayName ?? "A friend" }

        var blurb: LocalizedStringResource {
            switch self {
            case .friend:
                #if os(macOS)
                return "Take turns on this Mac"
                #else
                return "Pass and play on this device"
                #endif
            case .beginner: return "Sees one move ahead, misses threats"
            case .casual: return "Sensible, but blunders under pressure"
            case .club: return "Solid, with the occasional mistake"
            case .strong: return "Rarely blunders; needs a real plan"
            case .maximum: return "The full engine, no handicap"
            }
        }

        /// The measured strength on Stockfish's UCI_Elo scale, to the nearest 50 (docs/elo.md), nil for a friend.
        /// The digits are part of the text and stay Western in every language (D1).
        var elo: LocalizedStringResource? {
            switch self {
            case .friend: return nil
            case .beginner: return "about 550"
            case .casual: return "about 950"
            case .club: return "about 1350"
            case .strong: return "about 1600"
            case .maximum: return "about 2350"
            }
        }

        /// The image of the row's tile, from the pieces of the board.
        var pieceImage: String {
            switch self {
            case .friend: return "pawn_w"
            case .beginner: return "pawn_b"
            case .casual: return "knight_b"
            case .club: return "bishop_b"
            case .strong: return "rook_b"
            case .maximum: return "queen_b"
            }
        }

        /// The New Game button's words; the computer has the same name on the game screen (D1).
        var playLabel: LocalizedStringResource {
            switch self {
            case .friend: return "Start Game"
            case .beginner: return "Play the Beginner Player"
            case .casual: return "Play the Casual Player"
            case .club: return "Play the Club Player"
            case .strong: return "Play the Strong Player"
            case .maximum: return "Play the Full Engine"
            }
        }
    }

    enum Side: Int, Sendable { case white, random, black }

    /// The thinking times of Maximum, in seconds.
    static let thinkingTimes: [TimeInterval] = [5, 10, 30]

    var opponent = Opponent.club
    var side = Side.white
    /// "Your name", or the first player's name against a friend.
    var firstName = ""
    /// The friend's name.
    var secondName = ""
    /// 5, 10 or 30 seconds; Maximum only.
    var thinkingTime: TimeInterval = 10

    init() {}

    /// The edit mode: the choice that reproduces the game's players.
    init(white: GamePlayer, black: GamePlayer) {
        self.init()
        switch (white.computer, black.computer) {
        case (false, false):
            opponent = .friend
            firstName = white.name
            secondName = black.name
        case (false, true):
            adopt(human: white, computer: black, side: .white)
        case (true, false):
            adopt(human: black, computer: white, side: .black)
        case (true, true):
            // Old games only: you against Black's level
            adopt(human: .human, computer: black, side: .white)
        }
    }

    private mutating func adopt(human: GamePlayer, computer: GamePlayer, side: Side) {
        switch computer.strength {
        case .beginner: opponent = .beginner
        case .casual: opponent = .casual
        case .club: opponent = .club
        case .strong: opponent = .strong
        case .maximum: opponent = .maximum
        }
        if opponent == .maximum {
            thinkingTime = computer.thinkingTime
        }
        self.side = side
        firstName = human.name
    }

    // MARK: Words

    var isFriend: Bool { opponent == .friend }

    var sideLabel: LocalizedStringResource { isFriend ? "First player plays" : "You play" }

    var firstNameLabel: LocalizedStringResource {
        guard isFriend else {
            return "Your name"
        }
        switch side {
        case .white: return "White"
        case .black: return "Black"
        case .random: return "Random color"
        }
    }

    var secondNameLabel: LocalizedStringResource {
        switch side {
        case .white: return "Black"
        case .black: return "White"
        case .random: return "Random color"
        }
    }

    var playLabel: LocalizedStringResource { opponent.playLabel }

    var showsThinkingTime: Bool { opponent == .maximum }

    // MARK: Players

    /// The game to start. `coin` resolves Random: true when the first player takes White.
    func players(firstPlaysWhite coin: Bool) -> (white: GamePlayer, black: GamePlayer, rotated: Bool) {
        let firstWhite: Bool
        switch side {
        case .white: firstWhite = true
        case .black: firstWhite = false
        case .random: firstWhite = coin
        }
        let first = GamePlayer(name: firstName.trimmingCharacters(in: .whitespaces), computer: false, level: 0)
        let second: GamePlayer
        if let strength = opponent.strength {
            second = .computer(strength, thinkingTime: thinkingTime)
        } else {
            second = GamePlayer(name: secondName.trimmingCharacters(in: .whitespaces), computer: false, level: 0)
        }
        return firstWhite ? (first, second, false) : (second, first, true)
    }

    // MARK: The remembered choice

    /// The last choice, else the defaults. A missing or unknown value takes the default of its field.
    init(remembered defaults: UserDefaults) {
        if let raw = defaults.object(forKey: AppSettings.newGameOpponentKey) as? Int, let value = Opponent(rawValue: raw) {
            opponent = value
        }
        if let raw = defaults.object(forKey: AppSettings.newGameSideKey) as? Int, let value = Side(rawValue: raw) {
            side = value
        }
        if let value = defaults.object(forKey: AppSettings.newGameNameKey) as? String {
            firstName = value
        }
        if let value = defaults.object(forKey: AppSettings.newGameSecondNameKey) as? String {
            secondName = value
        }
        if let value = defaults.object(forKey: AppSettings.newGameThinkingTimeKey) as? Double, Self.thinkingTimes.contains(value) {
            thinkingTime = value
        }
    }

    func remember(in defaults: UserDefaults) {
        defaults.set(opponent.rawValue, forKey: AppSettings.newGameOpponentKey)
        defaults.set(side.rawValue, forKey: AppSettings.newGameSideKey)
        defaults.set(firstName, forKey: AppSettings.newGameNameKey)
        defaults.set(secondName, forKey: AppSettings.newGameSecondNameKey)
        defaults.set(thinkingTime, forKey: AppSettings.newGameThinkingTimeKey)
    }
}
