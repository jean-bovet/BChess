//
//  FGame.hpp
//  BChess
//
//  Created by Jean Bovet on 12/14/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "ChessBoard.hpp"
#include "FMoveList.hpp"

#include <vector>

class FGame {
private:
    void replayMoves();
    
public:
    enum class Outcome {
        white_wins, black_wins, draw, in_progress
    };
    
    ChessBoard board;
    ChessBoard startBoard;
    
    MoveList moves;
    int moveCursor = 0;
    
    Outcome outcome = Outcome::in_progress;
    
    void reset();
    
    bool setFEN(std::string fen);
    std::string getFEN();
    
    BoardSquare getPieceAt(File file, Rank rank);
    
    std::vector<Move> movesAt(File file, Rank rank);
    
    void move(Move move);
    void move(std::string from, std::string to);
    
    bool canUndoMove();
    bool canRedoMove();
    
    void undoMove();
    void redoMove();
    
    void debugEvaluate();
};

