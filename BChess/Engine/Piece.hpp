//
//  FPiece.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <cassert>

enum Piece: unsigned {
    PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING, PCOUNT
};

inline static char pieceToChar(Piece piece, bool white) {
    switch (piece) {
        case PAWN:
            return white ? 'P' : 'p';
        case ROOK:
            return white ? 'R' : 'r';
        case KNIGHT:
            return white ? 'N' : 'n';
        case BISHOP:
            return white ? 'B' : 'b';
        case QUEEN:
            return white ? 'Q' : 'q';
        case KING:
            return white ? 'K' : 'k';
        case PCOUNT:
            assert(false); // invalid
    }
}
