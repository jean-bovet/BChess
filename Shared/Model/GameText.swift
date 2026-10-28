//
//  GameText.swift
//  BChess
//
//  The words of the game screen: titles, player labels, move labels and the status line.
//

import Foundation

enum GameText {

    /// Notation inside a sentence or alone: wrapped in a left-to-right isolate (U+2066 ... U+2069), so that a right-to-left
    /// paragraph keeps "8…O-O", "−1.2" or "9/12" in order and its sign or slash on the right side. A layout direction on a
    /// `Text` does not set a paragraph's base direction; the isolate does. Display only: never written to a file.
    static func notation(_ text: String) -> String {
        "\u{2066}\(text)\u{2069}"
    }

    /// The side's name: "White", "Black".
    static func color(isWhite: Bool) -> LocalizedStringResource {
        isWhite ? "White" : "Black"
    }

    /// The thinking time of the Full Engine: "10 s". The digits stay Western (D1), so the number is formatted here and
    /// the catalog key is `%@ s`.
    static func seconds(_ count: Int) -> LocalizedStringResource {
        "\(String(count)) s"
    }

    /// Whether the player is the person at the device: no name of its own, against a computer. The one condition
    /// behind "You" in a name and "Your move." in the status line.
    private static func isYou(_ player: GamePlayer, opponent: GamePlayer) -> Bool {
        !player.computer && givenName(of: player) == nil && opponent.computer
    }

    /// The player's name when it has one, else the computer's level, else "You" against a computer, else the colour.
    static func name(of player: GamePlayer, isWhite: Bool, opponent: GamePlayer) -> String {
        if let name = givenName(of: player) {
            return name
        }
        if player.computer {
            return String(localized: player.strength.computerName)
        }
        if isYou(player, opponent: opponent) {
            return String(localized: "You")
        }
        return String(localized: color(isWhite: isWhite))
    }

    /// The player's own name, trimmed; nil when it has none (empty or whitespace only).
    private static func givenName(of player: GamePlayer) -> String? {
        let name = player.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    static func title(white: GamePlayer, black: GamePlayer) -> String {
        let whiteName = name(of: white, isWhite: true, opponent: black)
        let blackName = name(of: black, isWhite: false, opponent: white)
        return String(localized: "\(whiteName) vs \(blackName)")
    }

    /// The colour with what the player is doing, for the line under a player's name: "White \u{00B7} your move" for a
    /// human against a computer, the bare colour for a human waiting and for a computer whose name already says its
    /// level ("Casual Player"). It adds the level only where the name does not: "Black \u{00B7} 10 s" at Maximum (the thinking
    /// time is not in "Full Engine") and "Black \u{00B7} Club" for a computer with a name of its own.
    static func sideDetail(of player: GamePlayer, isWhite: Bool, opponent: GamePlayer, toMove: Bool) -> String {
        let colorName = String(localized: color(isWhite: isWhite))
        if player.computer {
            if player.strength == .maximum {
                let time = String(localized: seconds(Int(player.thinkingTime)))
                return String(localized: "\(colorName) \u{00B7} \(time)")
            }
            guard givenName(of: player) != nil else {
                return colorName
            }
            let level = String(localized: player.strength.displayName)
            return String(localized: "\(colorName) \u{00B7} \(level)")
        }
        guard toMove else {
            return colorName
        }
        let doing = opponent.computer ? String(localized: "your move") : String(localized: "to move")
        return String(localized: "\(colorName) \u{00B7} \(doing)")
    }

    /// "8. c3" for White, "8…O-O" for Black.
    static func moveLabel(number: Int, isWhite: Bool, san: String) -> String {
        isWhite ? "\(number). \(san)" : "\(number)\u{2026}\(san)"
    }

    static func status(mode: GameMode.Value, isThinking: Bool, gameEnd: GameEnd,
                       white: GamePlayer, black: GamePlayer, isWhiteToMove: Bool, lastMove: String?) -> String {
        switch mode {
        case .analyze:
            return String(localized: "Analyzing. Moves are not saved.")
        case .train:
            return String(localized: "Practicing openings.")
        case .play:
            break
        }

        let text: String
        switch gameEnd {
        case .checkmate:
            // The side to move is the one that is mated
            text = isWhiteToMove ? String(localized: "Checkmate. Black wins.") : String(localized: "Checkmate. White wins.")
        case .stalemate:
            text = String(localized: "Stalemate.")
        case .repetition:
            text = String(localized: "Draw by repetition.")
        case .finished:
            text = String(localized: "Game over.")
        case .none:
            let player = isWhiteToMove ? white : black
            let opponent = isWhiteToMove ? black : white
            let name = Self.name(of: player, isWhite: isWhiteToMove, opponent: opponent)
            if isThinking {
                text = String(localized: "\(name) is thinking\u{2026}")
            } else if isYou(player, opponent: opponent) {
                text = String(localized: "Your move.")
            } else {
                text = String(localized: "\(name) to move.")
            }
        }
        guard let lastMove else {
            return text
        }
        return String(localized: "\(text) Last: \(notation(lastMove))")
    }

    // MARK: Alerts of the games list

    /// "3 games exported to “Folder”": a plural key, written into the catalog by hand (the count is a count, not
    /// notation).
    static func exported(count: Int, folder: String) -> LocalizedStringResource {
        "\(count) games exported to “\(folder)”"
    }

    static func exportFailed(_ error: Error) -> LocalizedStringResource {
        "Couldn't export the games. \(error.localizedDescription)"
    }

    static func deleteFailed(_ error: Error) -> LocalizedStringResource {
        "Couldn't delete this game. \(error.localizedDescription)"
    }
}
