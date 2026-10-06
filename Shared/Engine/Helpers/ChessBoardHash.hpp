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
    
    /// The castling part of the state key, one right at a time: 0 white king side, 1 white queen side,
    /// 2 black king side, 3 black queen side
    static uint64_t castlingKey(int right);
    
    /// The en-passant part of the state key: the file key when an en-passant capture is legal, else 0
    static uint64_t enPassantKey(const ChessBoard &board);
};
