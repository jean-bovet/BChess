//
//  GameText.swift
//  BChess
//
//  The words of the game screen: titles, player labels, move labels and the status line.
//

import Foundation

enum GameText {

    /// The player's name when it has one, else the computer's level, else "You" against a computer, else the colour.
    static func name(of player: GamePlayer, isWhite: Bool, opponent: GamePlayer) -> String {
        if let name = givenName(of: player) {
            return name
        }
        if player.computer {
            return player.strength.computerName
        }
        if opponent.computer {
            return "You"
        }
        return isWhite ? "White" : "Black"
    }

    /// The player's own name, trimmed; nil when it has none (empty or whitespace only).
    private static func givenName(of player: GamePlayer) -> String? {
        let name = player.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    static func title(white: GamePlayer, black: GamePlayer) -> String {
        "\(name(of: white, isWhite: true, opponent: black)) vs \(name(of: black, isWhite: false, opponent: white))"
    }

    /// The colour with what the player is doing, for the line under a player's name: "White \u{00B7} your move" for a
    /// human against a computer, the bare colour for a human waiting and for a computer whose name already says its
    /// level ("Casual Player"). It adds the level only where the name does not: "Black \u{00B7} 10 s" at Maximum (the thinking
    /// time is not in "Full Engine") and "Black \u{00B7} Club" for a computer with a name of its own.
    static func sideDetail(of player: GamePlayer, isWhite: Bool, opponent: GamePlayer, toMove: Bool) -> String {
        let color = isWhite ? "White" : "Black"
        if player.computer {
            if player.strength == .maximum {
                return "\(color) \u{00B7} \(Int(player.thinkingTime)) s"
            }
            return givenName(of: player) == nil ? color : "\(color) \u{00B7} \(player.strength.displayName)"
        }
        guard toMove else {
            return color
        }
        return "\(color) \u{00B7} \(opponent.computer ? "your move" : "to move")"
    }

    /// "8. c3" for White, "8…O-O" for Black.
    static func moveLabel(number: Int, isWhite: Bool, san: String) -> String {
        isWhite ? "\(number). \(san)" : "\(number)\u{2026}\(san)"
    }

    static func status(mode: GameMode.Value, isThinking: Bool, gameEnd: GameEnd,
                       white: GamePlayer, black: GamePlayer, isWhiteToMove: Bool, lastMove: String?) -> String {
        switch mode {
        case .analyze:
            return "Analyzing. Moves are not saved."
        case .train:
            return "Practicing openings."
        case .play:
            break
        }

        let text: String
        switch gameEnd {
        case .checkmate:
            // The side to move is the one that is mated
            text = "Checkmate. \(isWhiteToMove ? "Black" : "White") wins."
        case .stalemate:
            text = "Stalemate."
        case .repetition:
            text = "Draw by repetition."
        case .finished:
            text = "Game over."
        case .none:
            let player = isWhiteToMove ? white : black
            let opponent = isWhiteToMove ? black : white
            let name = Self.name(of: player, isWhite: isWhiteToMove, opponent: opponent)
            if isThinking {
                text = "\(name) is thinking\u{2026}"
            } else if name == "You" {
                text = "Your move."
            } else {
                text = "\(name) to move."
            }
        }
        guard let lastMove else {
            return text
        }
        return "\(text) Last: \(lastMove)"
    }
}
