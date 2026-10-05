//
//  Game.swift
//  BChess
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Foundation

/// The moves of the current game in the shape that the move list and the strip display: the main line
/// as rows, and every move of the tree (variations at any depth) reachable by its uuid.
struct Game {

    /// The main line, paired into full moves. A row that starts with Black has no white move.
    private(set) var rows = [FullMove]()

    /// Every node of the tree by uuid.
    private(set) var nodes = [UInt: FEngineMoveNode]()

    /// The index of the row that displays each move: its own for the main line, the row of the move it
    /// replaces for a move of a variation.
    private(set) var rowIndex = [UInt: Int]()

    /// The number of alternatives in the whole game.
    private(set) var variationCount = 0

    /// The uuid of the move before each move along its own branch.
    private var parents = [UInt: UInt]()

    mutating func rebuild(engine: FEngine) {
        self = Game(mainLine: engine.moveNodesTree())
    }

    init() {}

    init(mainLine: [FEngineMoveNode]) {
        var previous: UInt?
        for node in mainLine {
            var row: FullMove
            if node.whiteMove || rows.isEmpty || rows[rows.count - 1].black != nil || rows[rows.count - 1].number != Int(node.moveNumber) {
                row = FullMove(id: rows.count, number: Int(node.moveNumber))
                row.white = node.whiteMove ? node : nil
                row.black = node.whiteMove ? nil : node
                rows.append(row)
            } else {
                rows[rows.count - 1].black = node
            }
            let index = rows.count - 1
            nodes[node.uuid] = node
            rowIndex[node.uuid] = index
            parents[node.uuid] = previous
            for alternative in node.variations {
                let tokens = add(alternative: alternative, parent: previous, row: index)
                rows[index].variations.append(tokens)
            }
            previous = node.uuid
        }
    }

    /// Registers one alternative, its continuation and the alternatives nested in it, and returns its
    /// tokens: its moves, and the alternatives to each of them in parentheses.
    private mutating func add(alternative: FEngineMoveNode, parent: UInt?, row: Int) -> [MoveToken] {
        variationCount += 1
        var result: [MoveToken] = [.open]
        var previous = parent
        var isFirst = true
        for node in [alternative] + alternative.variations {
            result.append(.move(Self.label(of: node, numbered: node.whiteMove || isFirst), uuid: node.uuid))
            isFirst = false
            let comment = FullMove.clean(node.comment)
            if !comment.isEmpty {
                result.append(.comment(comment))
            }
            nodes[node.uuid] = node
            rowIndex[node.uuid] = row
            parents[node.uuid] = previous
            // The alternatives to a continuation move; those of the first node are the caller's
            if node !== alternative {
                for nested in node.variations {
                    result += add(alternative: nested, parent: previous, row: row)
                }
            }
            previous = node.uuid
        }
        result.append(.close)
        return result
    }

    private static func label(of node: FEngineMoveNode, numbered: Bool) -> String {
        numbered ? GameText.moveLabel(number: Int(node.moveNumber), isWhite: node.whiteMove, san: node.name) : node.name
    }

    /// The moves from the start to this move along its own branch: the main line up to the move that a
    /// variation replaces, then the variation up to the move itself.
    func path(to uuid: UInt) -> [FEngineMoveNode] {
        var result = [FEngineMoveNode]()
        var cursor: UInt? = uuid
        while let current = cursor, let node = nodes[current] {
            result.append(node)
            cursor = parents[current]
        }
        return result.reversed()
    }

    /// The last `count` plies of the path to the current move, labelled for the strip; the last one is
    /// always the current move. Empty at the start of the game.
    func recentMoves(current uuid: UInt, count: Int = 6) -> [MoveToken] {
        let recent = path(to: uuid).suffix(count)
        return recent.enumerated().map { offset, node in
            .move(Self.label(of: node, numbered: node.whiteMove || offset == 0), uuid: node.uuid)
        }
    }
}
