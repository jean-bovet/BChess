//
//  FPerformance.cpp
//  BChess
//
//  Created by Jean Bovet on 11/30/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FPerformance.hpp"
#include "FBoard.hpp"

void FPerformance::generateMoves(Board board, Color color, int depth) {
    if (depth == 0) {
        return;
    }
    
    MoveList moves = generator.generateMoves(board, color);
    moveCount += moves.moveCount;
    for (int i=0; i<moves.moveCount; i++) {
        Move m = moves.moves[i];
        Board newBoard = board;
        newBoard.move(m);
        generateMoves(newBoard, INVERSE(color), depth - 1);
    }
}
