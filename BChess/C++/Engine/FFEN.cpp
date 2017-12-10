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

inline static Square charToSquare(char p) {
    Square square;
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
            assert(false); // Invalid FEN entry
            break;
    }
    return square;
}

inline static char squareToChar(Square square) {
    if (square.empty) {
        return ' ';
    }
    
    bool white = square.color == Color::WHITE;
    
    switch (square.piece) {
        case Piece::PAWN:
            return white ? 'P' : 'p';
        case Piece::ROOK:
            return white ? 'R' : 'r';
        case Piece::KNIGHT:
            return white ? 'N' : 'n';
        case Piece::BISHOP:
            return white ? 'B' : 'b';
        case Piece::QUEEN:
            return white ? 'Q' : 'q';
        case Piece::KING:
            return white ? 'K' : 'k';
        case Piece::PCOUNT:
            assert(false); // invalid
    }
}

struct Coordinate {
    int rank = 0;
    int file = 0;
};

std::string FFEN::getFEN(Board board) {
    // "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    std::string fen = "";
    for (int rank=7; rank>=0; rank--) {
        int emptyCount = 0;
        for (int file=0; file<8; file++) {
            auto square = board.get(file, rank);
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
            emptyCount = 0;
        }

        if (rank > 0) {
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

Board FFEN::createBoard(std::string fen) {
    std::vector<std::string> fields;
    split4(fen, fields);
    assert(fields.size() == 6);
    
    // 4k3/2r5/8/8/8/8/2R5/4K3
    auto pieces = fields[0];
    std::vector<std::string> ranks;
    split4(pieces, ranks, "/");

    Board board;
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
                auto square = charToSquare(p);
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
    board.setCastling(fields[2]);
    
    // En passant
    auto enPassant = fields[3];
    if (enPassant == "-") {
        board.enPassant = 0;
    } else {
        bb_set(board.enPassant, squareIndexForName(enPassant));
    }
    
    // Half move
    board.halfMoveClock = stoi(fields[4]);

    // Full move
    board.fullMoveCount = stoi(fields[5]);
    
    return board;
}
