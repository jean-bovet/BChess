//
//  FBoard.hpp
//  BChess
//
//  Created by Jean Bovet on 11/26/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#ifndef FBoard_hpp
#define FBoard_hpp

#include <stdio.h>
#include <cstdint>
#include <string>

typedef uint64_t Bitboard;

namespace Color {
    enum Color: int {
        WHITE, BLACK, COUNT        
    };
}

#define INVERSE(color) ((color) == Color::WHITE ? Color::BLACK : Color::WHITE)

namespace Piece {
    enum Piece: int {
        PAWN, ROOK, KNIGHT, BISHOP, QUEEN, KING, COUNT
    };
}

enum enumSquare {
    a1, b1, c1, d1, e1, f1, g1, h1,
    a2, b2, c2, d2, e2, f2, g2, h2,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a8, b8, c8, d8, e8, f8, g8, h8
};

static std::string SquareNames[64] = {
    "a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1",
    "a2", "b2", "c2", "d2", "e2", "f2", "g2", "h2",
    "a3", "b3", "c3", "d3", "e3", "f3", "g3", "h3",
    "a4", "b4", "c4", "d4", "e4", "f4", "g4", "h4",
    "a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5",
    "a6", "b6", "c6", "d6", "e6", "f6", "g6", "h6",
    "a7", "b7", "c7", "d7", "e7", "f7", "g7", "h7",
    "a8", "b8", "c8", "d8", "e8", "f8", "g8", "h8",
};

struct Move {
    int from;
    int to;
    Color::Color color;
    Piece::Piece piece;
};

const int MAX_MOVES = 256;

struct MoveList {
    Move moves[MAX_MOVES];
    int moveCount = 0;
    
    void addMove(int from, int to, Color::Color color, Piece::Piece piece) {
        moves[moveCount] = { from, to, color, piece };
        moveCount++;
    }
    
    void addMoves(int from, Bitboard moves, Color::Color color, Piece::Piece piece);
};

struct Board {
    Board();
    void move(Move move);
    Bitboard pieces[Color::COUNT][Piece::COUNT] = { };
    Bitboard allPieces(Color::Color color);
    Bitboard occupancy();
    Bitboard emptySquares();
};

// Without this, the C file won't be linked
extern "C" void initmagicmoves(void);

static Bitboard WhitePawnAttacks[64];
static Bitboard WhitePawnMoves[64];
static Bitboard BlackPawnAttacks[64];
static Bitboard BlackPawnMoves[64];

static Bitboard KingMoves[64];
static Bitboard KnightMoves[64];

class FastMoveGenerator {
public:
    FastMoveGenerator();
    
    void initPawnMoves();
    void initKingMoves();
    void initKnightMoves();
    
    MoveList generateMoves(Board board, Color::Color color);
    void generatePawnsMoves(Board &board, Color::Color color, MoveList &moveList);
    void generateKingsMoves(Board &board, Color::Color color, MoveList &moveList);
    void generateKnightsMoves(Board &board, Color::Color color, MoveList &moveList);
    void generateSlidingMoves(Board &board, Color::Color color, Piece::Piece piece, MoveList &moveList);
};

#endif /* FBoard_hpp */
