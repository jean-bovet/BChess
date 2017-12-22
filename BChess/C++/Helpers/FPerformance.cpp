//
//  FPerformance.cpp
//  BChess
//
//  Created by Jean Bovet on 11/30/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FPerformance.hpp"
#include "FBoard.hpp"

void FPerformance::generateMoves(Board board, int depth) {
    if (depth == 0) {
        return;
    }
    
    MoveList moves = generator.generateMoves(board);
    moveCount += moves.count;
    for (int index=0; index<moves.count; index++) {
        auto m = moves._moves[index];
        Board newBoard = board;
        newBoard.move(m);
        generateMoves(newBoard, depth - 1);
    }
}
