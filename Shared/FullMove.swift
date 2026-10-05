//
//  FullMove.swift
//  BChess
//
//  Created by Jean Bovet on 5/16/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Foundation

/// A piece of a flattened variation: a move that can be selected, a comment, or a parenthesis.
enum MoveToken: Equatable {
    case move(String, uuid: UInt)
    case comment(String)
    case open
    case close
}

/// One row of the move list: a move number with White's and Black's move of the main line, and the
/// alternatives to either of them.
struct FullMove: Identifiable {
    /// The index of the row in `Game.rows`.
    let id: Int
    let number: Int

    var white: FEngineMoveNode?
    var black: FEngineMoveNode?

    /// Every alternative to the white move, then to the black move, as tokens including their own parentheses.
    var variations = [[MoveToken]]()

    var whiteComment: String {
        FullMove.clean(white?.comment ?? "")
    }

    var blackComment: String {
        FullMove.clean(black?.comment ?? "")
    }

    /// A comment on one line, without the whitespace around it.
    static func clean(_ comment: String) -> String {
        comment.components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
