//
//  FullMove.swift
//  BChess
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Foundation

/// The moves of the current game as a tree of full moves, in the shape that the move list displays.
struct Game {
    
    var moves = [FullMove]()
        
    mutating func rebuild(engine: FEngine) {
        moves = moveItems(engine: engine)
    }
    
    func moveItems(engine: FEngine) -> [FullMove] {
        var items = [FullMove]()
        for node in engine.moveNodesTree() {
            items.add(element: moveItems(from: node, engine: engine))
        }
        return items
    }
    
    func moveItems(from: FEngineMoveNode, engine: FEngine) -> FullMove {
        var children = [FullMove]()
        for childNode in from.variations {
            let child = moveItems(from: childNode, engine: engine)
            children.add(element: child)
        }
        let item = FullMove(id: "\(from.uuid)")
        item.whiteMove = from.whiteMove ? from : nil
        item.blackMove = from.whiteMove ? nil : from
        item.children = children.isEmpty ? nil : children
        return item
    }

}
