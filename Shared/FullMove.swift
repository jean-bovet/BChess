//
//  FullMove.swift
//  BChess
//
//  Created by Jean Bovet on 5/16/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

final class FullMove: Identifiable {
    let id: String
    
    var whiteMove: FEngineMoveNode?
    var blackMove: FEngineMoveNode?
    
    var children: [FullMove]?
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

    init(id: String) {
        self.id = id
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
    
    func canMergeWithNext(item: FullMove) -> Bool {
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

extension Array where Element == FullMove {
    
    mutating func add(element: FullMove) {
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
