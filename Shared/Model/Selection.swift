//
//  Selection.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Foundation

struct Selection {
    let position: Position
    let possibleMoves: [FEngineMove]
    
    static func empty() -> Selection {
        return Selection(position: Position.empty(), possibleMoves: [])
    }
    
    func selected(rank: Int, file: Int) -> Bool {
        return position.rank == rank && position.file == file
    }
    
    func isPossibleMove(_ rank: Int, _ file: Int) -> Bool {
        return possibleMove(rank, file) != nil
    }
    
    func possibleMove(_ rank: Int, _ file: Int) -> FEngineMove? {
        return possibleMoves.filter { $0.toFile == file && $0.toRank == rank }.first
    }
    
}
