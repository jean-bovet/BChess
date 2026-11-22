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
    /// behind "You" in a name ("your move" in a player row's detail follows `opponent.computer` instead).
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

    /// The colour with what the player is doing, beside a player's name (nothing but "to move", or nothing, where the name is the colour): "White \u{00B7} your move" for a
    /// human against a computer, the bare colour for a human waiting and for a computer whose name already says its
    /// level ("Casual Player"). It adds the level only where the name does not: "Black \u{00B7} 10 s" at Maximum (the thinking
    /// time is not in "Full Engine") and "Black \u{00B7} Club" for a computer with a name of its own. A computer to move
    /// that is searching reads "Black \u{00B7} thinking\u{2026}" whatever its level: the status line no longer says it.
    static func sideDetail(of player: GamePlayer, isWhite: Bool, opponent: GamePlayer, toMove: Bool,
                           isThinking: Bool) -> String {
        let colorName = String(localized: color(isWhite: isWhite))
        if player.computer {
            if toMove && isThinking {
                let thinking = String(localized: "thinking\u{2026}")
                return String(localized: "\(colorName) \u{00B7} \(thinking)")
            }
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
        // A human with no name of its own, against a human, is named by its colour: the detail says it only once
        let nameIsColour = givenName(of: player) == nil && !opponent.computer
        guard toMove else {
            return nameIsColour ? "" : colorName
        }
        let doing = opponent.computer ? String(localized: "your move") : String(localized: "to move")
        if nameIsColour {
            return doing
        }
        return String(localized: "\(colorName) \u{00B7} \(doing)")
    }

    /// "8. c3" for White, "8…O-O" for Black.
    static func moveLabel(number: Int, isWhite: Bool, san: String) -> String {
        isWhite ? "\(number). \(san)" : "\(number)\u{2026}\(san)"
    }

    /// "White wins", "Black wins", "Draw": the colour, not the player's name.
    static func resultTitle(_ result: GameResult) -> LocalizedStringResource {
        switch result.winner {
        case .white: "White wins"
        case .black: "Black wins"
        case .draw: "Draw"
        }
    }

    /// Why the game ended; nil for a declared result (`.finished`, which has no reason of its own) and for `.none`.
    static func resultReason(_ end: GameEnd) -> LocalizedStringResource? {
        switch end {
        case .checkmate: "Checkmate"
        case .stalemate: "Stalemate"
        case .repetition: "Threefold repetition"
        case .fiftyMoves: "Fifty-move rule"
        case .deadPosition: "Insufficient material"
        case .finished, .none: nil
        @unknown default: nil
        }
    }

    /// The result on one line, for a face-to-face half whose row has room for no banner: "White wins · Checkmate", or
    /// just "Draw" for a declared draw (a declared result has no reason of its own).
    static func resultDetail(_ result: GameResult) -> String {
        let title = String(localized: resultTitle(result))
        guard let reason = resultReason(result.reason) else {
            return title
        }
        let why = String(localized: reason)
        return String(localized: "\(title) \u{00B7} \(why)")
    }

    /// The one sentence the game screen's status line adds to the player rows (whose turn it is, and the computer
    /// thinking), the move strip and the board (the last move): what the mode is, or why this position cannot be played
    /// (a position in the middle of an imported line; the result banner says how the line ends). `nil` while a game is
    /// being played.
    static func status(mode: GameMode.Value, gameEnd: GameEnd) -> String? {
        switch mode {
        case .analyze:
            return String(localized: "Analyzing. Moves are not saved.")
        case .train:
            return String(localized: "Practicing openings.")
        case .play:
            break
        }

        guard let reason = resultReason(gameEnd) else {
            return nil
        }
        return String(localized: reason)
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
