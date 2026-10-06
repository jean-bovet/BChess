//
//  ChessBoardHash.hpp
//  BChess
//
//  Created by Jean Bovet on 1/6/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#pragma once

#include "ChessBoard.hpp"
#include "Types.hpp"
#include <cstdint>

class ChessBoardHash {    
public:
    static void initialize();
    
    static BoardHash hash(ChessBoard board);
    
    static uint64_t getPseudoNumber(Square square, Color color, Piece piece);
    
    static uint64_t getWhiteTurn();
    
    /// The part of the hash that is not piece placement or side to move: the castling rights held,
    /// and the en-passant file when an en-passant capture is legal (FIDE 9.2.3: positions are the
    /// same when the same moves are possible, so an en-passant square nothing can use does not count).
    static uint64_t stateKey(const ChessBoard &board);
};
