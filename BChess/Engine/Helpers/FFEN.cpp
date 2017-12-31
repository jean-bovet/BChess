//
//  FFEN.cpp
//  BChess
//
//  Created by Jean Bovet on 11/30/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FFEN.hpp"
#include "FUtility.hpp"

#include <vector>
#include <cassert>

inline static bool charToSquare(char p, BoardSquare &square) {
    square.empty = false;
    square.color = Color::WHITE;
    switch (p) {
        case 'p':
            square.piece = Piece::PAWN;
            square.color = Color::BLACK;
            break;
        case 'P':
            square.piece = Piece::PAWN;
            break;
            
        case 'r':
            square.piece = Piece::ROOK;
            square.color = Color::BLACK;
            break;
        case 'R':
            square.piece = Piece::ROOK;
            break;
            
        case 'b':
            square.piece = Piece::BISHOP;
            square.color = Color::BLACK;
            break;
        case 'B':
            square.piece = Piece::BISHOP;
            break;
            
        case 'n':
            square.piece = Piece::KNIGHT;
            square.color = Color::BLACK;
            break;
        case 'N':
            square.piece = Piece::KNIGHT;
            break;
            
        case 'q':
            square.piece = Piece::QUEEN;
            square.color = Color::BLACK;
            break;
        case 'Q':
            square.piece = Piece::QUEEN;
            break;
            
        case 'k':
            square.piece = Piece::KING;
            square.color = Color::BLACK;
            break;
        case 'K':
            square.piece = Piece::KING;
            break;
            
        default:
            return false; // Invalid FEN entry
            break;
    }
    return true;
}

inline static char squareToChar(BoardSquare square) {
    if (square.empty) {
        return ' ';
    }
    
    bool white = square.color == Color::WHITE;
    return pieceToChar(square.piece, white);
}

struct Coordinate {
    Rank rank = 0;
    File file = 0;
};

std::string FFEN::getFEN(ChessBoard board) {
    // "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    std::string fen = "";
    for (Rank rank=8; rank>0; rank--) {
        int emptyCount = 0;
        for (File file=0; file<8; file++) {
            auto square = board.get(file, rank - 1);
            if (square.empty) {
                emptyCount += 1;
            } else {
                if (emptyCount > 0) {
                    fen += std::to_string(emptyCount);
                    emptyCount = 0;
                }
                fen += squareToChar(square);
            }
        }
        
        if (emptyCount > 0) {
            fen += std::to_string(emptyCount);
        }

        if (rank - 1 > 0) {
            fen += "/";
        }
    }
    
    // Color to move
    if (board.color == Color::WHITE) {
        fen += " w";
    } else {
        fen += " b";
    }
    
    // Castling availability
    fen += " "+board.getCastling();
    
    // En passant
    if (board.enPassant > 0) {
        int square = lsb(board.enPassant);
        fen += " "+SquareNames[square];
    } else {
        fen += " -";
    }
    
    // Halfmove
    fen += " "+std::to_string(board.halfMoveClock);
    
    // Full move number (starting at 1)
    fen += " "+std::to_string(board.fullMoveCount);
    
    return fen;
}

bool FFEN::setFEN(std::string fen, ChessBoard &board) {
    // Non-fully formed FEN should also be supported (for example using
    // the EPD format - https://chessprogramming.wikispaces.com/Kaufman+Test).
    // 1rbq1rk1/p1b1nppp/1p2p3/8/1B1pN3/P2B4/1P3PPP/2RQ1R1K w - - bm Nf6+; id "position 01";
    
    std::vector<std::string> fields;
    split4(fen, fields);
    
    // We need at least two fields, the board position and the color
    // who is playing.
    if (fields.size() < 2) {
        std::cerr << "Invalid FEN string: " << fen << std::endl;
        return false;
    }
    
    // 4k3/2r5/8/8/8/8/2R5/4K3
    auto pieces = fields[0];
    std::vector<std::string> ranks;
    split4(pieces, ranks, "/");

    board.clear();
    
    Coordinate coord = { 7, 0 };
    for (std::string rank : ranks) {
        for (char p : rank) {
            auto emptySquares = p - '0';
            if (emptySquares >= 1 && emptySquares <= 8) {
                for (int i=0; i<emptySquares; i++) {
                    coord.file += 1;
                }
            } else {
                BoardSquare square;
                if (!charToSquare(p, square)) {
                    return false;
                }
                board.set(square, coord.file, coord.rank);
                coord.file += 1;
            }
        }
        coord.rank -= 1;
        coord.file = 0;
    }
    
    auto sideToMove = fields[1];
    board.color = (sideToMove == "w") ? WHITE : BLACK;
    
    // KQkq
    if (fields.size() > 2) {
        board.setCastling(fields[2]);
    }
    
    // En passant
    if (fields.size() > 3) {
        auto enPassant = fields[3];
        if (enPassant == "-") {
            board.enPassant = 0;
        } else {
            bb_set(board.enPassant, squareForName(enPassant));
        }
    }
    
    // Half move
    if (fields.size() > 4) {
        board.halfMoveClock = integer(fields[4]);
    }

    // Full move
    if (fields.size() > 5) {
        board.fullMoveCount = integer(fields[5]);
    }
    
    return true;
}
