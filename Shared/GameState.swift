//
//  BoardState.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

final class GameState: ObservableObject {
    @Published var selection = SelectionState(position: Position.empty(), possibleMoves: [])
    @Published var lastMove: FEngineMove? = nil
    @Published var info: FEngineInfo? = nil
    @Published var level: Int = 0
    @Published var playAgainst: PlayAgainst = .black
}
