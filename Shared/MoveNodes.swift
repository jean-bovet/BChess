//
//  FullMoveItem.swift
//  BChess
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

final class FullMoveItem: Identifiable {
    let id = UUID()
    
    var whiteMove: FEngineMoveNode?
    var blackMove: FEngineMoveNode?
    
    var children: [FullMoveItem]?
    var hasChildren: Bool {
        if let c = children {
            return !c.isEmpty
        } else {
            return false
        }
    }
    
    var whiteComment: String {
        if let wm = whiteMove {
            return normalizeComment(comment: wm.comment)
        } else {
            return " "
        }
    }
    
    var blackComment: String {
        if let bm = blackMove {
            return normalizeComment(comment: bm.comment)
        } else {
            return " "
        }
    }

    func normalizeComment(comment: String) -> String {
        let nc = comment.components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        if nc.isEmpty {
            return " "
        } else {
            return " \(nc) "
        }
    }
    
    func canMergeWithNext(item: FullMoveItem) -> Bool {
        guard let wm = whiteMove else {
            return false
        }
        guard blackMove == nil else {
            return false
        }
        guard !hasChildren else {
            return false
        }
        guard wm.comment.isEmpty else {
            return false
        }
        
        guard item.whiteMove == nil else {
            return false
        }
        
        guard let bm = item.blackMove else {
            return false
        }
                    
        return wm.moveNumber == bm.moveNumber
    }
}

extension Array where Element == FullMoveItem {
    
    mutating func add(element: FullMoveItem) {
        if let lastElement = last {
            if lastElement.hasChildren {
                append(element)
            } else if lastElement.canMergeWithNext(item: element) {
                lastElement.blackMove = element.blackMove
                lastElement.children = element.children
            } else {
                append(element)
            }
        } else {
            append(element)
        }
    }
}

class MoveNodes: ObservableObject {
    
    @Published var moveNodes = [FullMoveItem]()
        
    func rebuild(engine: FEngine) {
        moveNodes.removeAll()
        moveNodes = moveItems(engine: engine)
    }
    
    func moveItems(engine: FEngine) -> [FullMoveItem] {
        var items = [FullMoveItem]()
        for node in engine.moveNodesTree() {
            items.add(element: moveItems(from: node, engine: engine))
        }
        return items
    }
    
    func moveItems(from: FEngineMoveNode, engine: FEngine) -> FullMoveItem {
        var children = [FullMoveItem]()
        for childNode in from.variations {
            let child = moveItems(from: childNode, engine: engine)
            children.add(element: child)
        }
        let item = FullMoveItem()
        item.whiteMove = from.whiteMove ? from : nil
        item.blackMove = from.whiteMove ? nil : from
        item.children = children.isEmpty ? nil : children
        return item
    }
    
}
