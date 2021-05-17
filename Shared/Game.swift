//
//  FullMove.swift
//  BChess
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

final class Game: ObservableObject {
    
    @Published var moves = [FullMove]()
        
    func rebuild(engine: FEngine) {
        moves.removeAll()
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
    
    func hasVariations(moveUUID: UInt) -> Bool {
        return variations(moveUUID: moveUUID).count > 1
    }
    
    func variations(moveUUID: UInt) -> [FEngineMoveNode] {
        let nodes = moves.compactMap { node -> FEngineMoveNode? in
            if let wm = node.whiteMove, wm.uuid == moveUUID {
                return wm
            }
            if let bm = node.blackMove, bm.uuid == moveUUID {
                return bm
            }
            return nil
        }

        if let node = nodes.first {
            return [node] + node.variations
        } else {
            return []
        }
    }

}
