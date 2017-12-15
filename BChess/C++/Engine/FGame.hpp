//
//  FGame.hpp
//  BChess
//
//  Created by Jean Bovet on 12/14/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FBoard.hpp"
#include <vector>

class FGame {
private:
    size_t moveCursor = 0;
    void replayMoves();
    
public:
    Board board;
    std::vector<Move> moves;
    
    void setFEN(std::string fen);
    std::string getFEN();
    
    BoardSquare getPieceAt(File file, Rank rank);
    
    std::vector<Move> movesAt(File file, Rank rank);
    
    void move(Move move);
    void move(std::string from, std::string to);
    
    bool canUndoMove();
    bool canRedoMove();
    
    void undoMove();
    void redoMove();
};

