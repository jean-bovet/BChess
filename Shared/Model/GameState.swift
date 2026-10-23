//
//  GameState.swift
//  BChess
//
//  The persisted value of a game and its codec, shared by the macOS document and the iOS game library.
//

import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// A BChess game: `GameState` as JSON, with the `.bchess` extension.
    static let bchessGame = UTType(exportedAs: "ch.arizona-software.bchess.game")
    /// Portable Game Notation. The type belongs to Apple's Chess.app, hence imported.
    static let pgn = UTType(importedAs: "com.apple.chess.pgn")
}

extension EngineStrength {
    /// The level's name on the ladder and in a row's detail: "Club".
    var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .casual: "Casual"
        case .club: "Club"
        case .strong: "Strong"
        case .maximum: "Maximum"
        }
    }

    /// The computer's name on the game screen and in the New Game button: "Club Player", "Full Engine".
    var computerName: String {
        self == .maximum ? "Full Engine" : "\(displayName) Player"
    }
}

/// The model of a player.
///
/// `level` is the file format of a computer's strength, and only its meaning changed (APP-3): 0 Beginner,
/// 1 Casual, 2 Club, 3 Strong, 4, 5 and 6 Maximum thinking 5, 10 and 30 seconds, anything else Club. The old
/// meaning (2, 5, 10 and 15 seconds) is gone.
struct GamePlayer: Codable, Equatable, Sendable {
    var name: String
    var computer: Bool
    var level: Int

    static let human = GamePlayer(name: "", computer: false, level: 0)
    static let defaultWhite = human
    static let defaultBlack = GamePlayer.computer(.club)

    /// How strongly this player plays when it is a computer.
    var strength: EngineStrength {
        switch level {
        case 0: return .beginner
        case 1: return .casual
        case 2: return .club
        case 3: return .strong
        case 4, 5, 6: return .maximum
        default: return .club
        }
    }

    /// The seconds the engine thinks: 5, 10 or 30 at Maximum, and 0 below it, where the strength is a depth.
    var thinkingTime: TimeInterval {
        switch level {
        case 4: return 5
        case 5: return 10
        case 6: return 30
        default: return 0
        }
    }

    /// The only writer of the new levels. The thinking time counts at Maximum only and is rounded to 5, 10 or 30.
    static func computer(_ strength: EngineStrength, thinkingTime: TimeInterval = 10) -> GamePlayer {
        let level: Int
        switch strength {
        case .beginner: level = 0
        case .casual: level = 1
        case .club: level = 2
        case .strong: level = 3
        case .maximum: level = thinkingTime <= 5 ? 4 : (thinkingTime <= 10 ? 5 : 6)
        }
        return GamePlayer(name: "", computer: true, level: level)
    }
}

/// The state of the game that is saved to the file. The coding keys are the file format: older BChess
/// versions wrote files in this shape, and every one of them must keep opening.
struct GameState: Codable, Equatable, Sendable {
    var pgn: String
    var rotated: Bool
    var white: GamePlayer
    var black: GamePlayer

    static let newGame = GameState(pgn: "*")

    init(pgn: String, rotated: Bool = false, white: GamePlayer = .defaultWhite, black: GamePlayer = .defaultBlack) {
        self.pgn = pgn
        self.rotated = rotated
        self.white = white
        self.black = black
    }

    private enum CodingKeys: String, CodingKey {
        case pgn, rotated, white, black
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pgn = try container.decode(String.self, forKey: .pgn)
        rotated = try container.decode(Bool.self, forKey: .rotated)
        // Optional for backwards compatibility
        white = try container.decodeIfPresent(GamePlayer.self, forKey: .white) ?? .defaultWhite
        black = try container.decodeIfPresent(GamePlayer.self, forKey: .black) ?? .defaultBlack
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pgn, forKey: .pgn)
        try container.encode(rotated, forKey: .rotated)
        try container.encode(white, forKey: .white)
        try container.encode(black, forKey: .black)
    }

    // MARK: Codec

    /// Reads a game from the bytes of a `.bchess` or `.json` file (`GameState` JSON) or of a `.pgn`
    /// file (standard PGN, both players human).
    init(data: Data, contentType: UTType) throws {
        switch contentType {
        case .bchessGame, .json:
            self = try JSONDecoder().decode(GameState.self, from: data)
        case .pgn:
            self = GameState(pgn: String(decoding: data, as: UTF8.self), white: .human, black: .human)
        default:
            throw CocoaError(.fileReadUnknown)
        }
        // Validate with a throwaway engine, so that a corrupt file is refused when it is read
        guard FEngine().loadAllGames(pgn) else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    /// The bytes to write for a file of this type: JSON for `.bchess` and `.json`, raw PGN for `.pgn`.
    func data(for contentType: UTType) throws -> Data {
        switch contentType {
        case .bchessGame, .json:
            // Sorted keys make the bytes stable, so an unchanged game writes an identical file
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(self)
        case .pgn:
            guard let data = pgn.data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            return data
        default:
            throw CocoaError(.fileWriteUnsupportedScheme)
        }
    }
}
