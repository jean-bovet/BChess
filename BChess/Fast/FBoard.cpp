//
//  FBoard.cpp
//  BChess
//
//  Created by Jean Bovet on 11/26/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FBoard.hpp"
#include <bitstring.h>
#include <iostream>
#include <cassert>
#include "magicmoves.h"

/**
rank
    8
    7
    6
    5
    4
    3
    2
    1 a1 b1 c1 d1 e1 f1 g1 h1
      a  b  c  d  e  f  g  h  <- file
    a1 = 0
    h1 = 2^7 = 128
    h8 = 2^63
 */

inline static int square_index(int file, int rank) {
    return 8 * rank + file;
}

inline static int file_index(int square) {
    return square & 7;
}

inline static int rank_index(int square) {
    return square >> 3;
}

inline static bool bb_test(Bitboard bitboard, int square) {
    uint64_t test = bitboard & (1UL << square);
    return test > 0;
}

inline static bool bb_test(Bitboard bitboard, int file, int rank) {
    return bb_test(bitboard, square_index(file, rank));
}

inline static void bb_clear(Bitboard &bitboard, int square) {
    bitboard &= ~(1UL << square);
}

inline static void bb_clear(Bitboard &bitboard, int file, int rank) {
    bb_clear(bitboard, square_index(file, rank));
}

inline static void bb_set(Bitboard &bitboard, int square) {
    bitboard |= 1UL << square;
}

inline static void bb_set(Bitboard &bitboard, int file, int rank) {
    if (file >= 0 && file <= 7 && rank >= 0 && rank <= 7) {
        bb_set(bitboard, square_index(file, rank));
    }
}

inline static void bb_print(Bitboard bitboard) {
    for (int rank = 7; rank >= 0; rank--) {
        for (int file = 0; file < 8; file++) {
            std::cout << (bb_test(bitboard, file, rank) > 0  ? "X" : ".");
        }
        std::cout << std::endl;
    }
    std::cout << std::endl;
}

inline static Bitboard BB(Bitboard userDefined) {
    Bitboard reversed = 0;
    for (int rank = 0; rank < 8; rank++) {
        for (int file = 0; file < 8; file++) {
            if (bb_test(userDefined, 7 - file, rank)) {
                bb_set(reversed, file, rank);
            }
        }
    }
    return reversed;
}

static Bitboard IWhiteKnights = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
01000010\
);

static Bitboard IBlackKnights = BB(0b\
01000010\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhiteRooks = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
10000001\
);

static Bitboard IBlackRooks = BB(0b\
10000001\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhiteBishops = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00100100\
);

static Bitboard IBlackBishops = BB(0b\
00100100\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhiteKing = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00001000\
);

static Bitboard IBlackKing = BB(0b\
00001000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhiteQueen = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00010000\
);

static Bitboard IBlackQueen = BB(0b\
00010000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhitePawns = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
11111111\
00000000\
);

static Bitboard IBlackPawns = BB(0b\
00000000\
11111111\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

inline static int lsb(Bitboard bb) {
    assert(bb > 0);
    return __builtin_ctzll(bb);
}

#pragma mark -

void MoveList::addMoves(int from, Bitboard moves, Color::Color color, Piece::Piece piece) {
    while (moves > 0) {
        int to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(from, to, color, piece);
    }
}

#pragma mark -

Board::Board() {
    pieces[Color::WHITE][Piece::PAWN] = IWhitePawns;
    pieces[Color::WHITE][Piece::KING] = IWhiteKing;
    pieces[Color::WHITE][Piece::QUEEN] = IWhiteQueen;
    pieces[Color::WHITE][Piece::ROOK] = IWhiteRooks;
    pieces[Color::WHITE][Piece::BISHOP] = IWhiteBishops;
    pieces[Color::WHITE][Piece::KNIGHT] = IWhiteKnights;
    
    pieces[Color::BLACK][Piece::PAWN] = IBlackPawns;
    pieces[Color::BLACK][Piece::KING] = IBlackKing;
    pieces[Color::BLACK][Piece::QUEEN] = IBlackQueen;
    pieces[Color::BLACK][Piece::ROOK] = IBlackRooks;
    pieces[Color::BLACK][Piece::BISHOP] = IBlackBishops;
    pieces[Color::BLACK][Piece::KNIGHT] = IBlackKnights;
}

void Board::move(Move move) {
    bb_clear(pieces[move.color][move.piece], move.from);
    bb_set(pieces[move.color][move.piece], move.to);
}

inline static char charForPiece(Color::Color color, Piece::Piece piece) {
    auto white = color == Color::WHITE;
    switch (piece) {
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
        case Piece::COUNT:
            return '?';
    }
}

void Board::print() {
    for (int rank = 7; rank >= 0; rank--) {
        for (int file = 0; file < 8; file++) {
            char c = '.';
            
            for (auto color=0; color<Color::COUNT; color++) {
                for (auto piece=0; piece<Piece::COUNT; piece++) {
                    if (bb_test(pieces[color][piece], file, rank)) {
                        c = charForPiece((Color::Color)color, (Piece::Piece)piece);
                    }
                }
            }
            
            std::cout << c;
        }
        std::cout << std::endl;
    }
    std::cout << std::endl;
}

Square Board::get(int file, int rank) {
    Square square;
    if (bb_test(occupancy(), file, rank)) {
        for (auto color=0; color<Color::COUNT; color++) {
            for (auto piece=0; piece<Piece::COUNT; piece++) {
                if (bb_test(pieces[color][piece], file, rank)) {
                    square.empty = false;
                    square.color = Color::Color(color);
                    square.piece = Piece::Piece(piece);
                    return square;
                }
            }
        }
    } else {
        square.empty = true;
    }
    return square;
}

void Board::set(Square square, int file, int rank) {
    if (square.empty) {
        for (auto color=0; color<Color::COUNT; color++) {
            for (auto piece=0; piece<Piece::COUNT; piece++) {
                bb_clear(pieces[color][piece], file, rank);
            }
        }
    } else {
        bb_set(pieces[square.color][square.piece], file, rank);
    }
}

Bitboard Board::allPieces(Color::Color color) {
    Bitboard all = 0;
    for (auto pieces : pieces[color]) {
        all |= pieces;
    }
    return all;
}

Bitboard Board::occupancy() {
    auto whitePieces = allPieces(Color::WHITE);
    auto blackPieces = allPieces(Color::BLACK);
    return whitePieces|blackPieces;
}

Bitboard Board::emptySquares() {
    return ~occupancy();
}

bool Board::isCheck(Color::Color color) {
    // Locate the king
    int kingSquare = lsb(pieces[color][Piece::KING]);
    assert(kingSquare > 0);
    
    auto otherColor = INVERSE(color);
//    auto blackPieces = allPieces(INVERSE(color));
    
    // Generate all the moves for a knight from the king position
    // and keep only the ones that are actually hitting
    // a black knight, meaning the king is attacked.
    auto moves = KnightMoves[kingSquare] & pieces[otherColor][Piece::KNIGHT];
    if (moves > 0) return true;
    
    // Same for bishop (and queen)
    auto rawBishopMoves = Bmagic(kingSquare, occupancy());
    auto bishopMoves = rawBishopMoves && (pieces[otherColor][Piece::BISHOP]|pieces[otherColor][Piece::QUEEN]);
    if (bishopMoves > 0) return true;

    // Same for rook (and queen)
    auto rawRookMoves = Rmagic(kingSquare, occupancy());
    auto rookMoves = rawRookMoves && (pieces[otherColor][Piece::ROOK]|pieces[otherColor][Piece::QUEEN]);
    if (rookMoves > 0) return true;

    // TODO: king, pawns
    
    return false;
}

#pragma mark -

FastMoveGenerator::FastMoveGenerator() {
    initmagicmoves();
    initPawnMoves();
    initKingMoves();
    initKnightMoves();
}

void FastMoveGenerator::initPawnMoves() {
    for (int square = 8; square < 64-8; square++) {
        int fileIndex = file_index(square);
        int rankIndex = rank_index(square);

        assert(square_index(fileIndex, rankIndex) == square);
        
        // White pawn attacks
        bb_set(PawnAttacks[Color::WHITE][square], fileIndex-1, rankIndex+1);
        bb_set(PawnAttacks[Color::WHITE][square], fileIndex+1, rankIndex+1);
        
        // White pawn moves
        bb_set(PawnMoves[Color::WHITE][square], fileIndex, rankIndex+1);
        if (rankIndex == 1) {
            bb_set(PawnMoves[Color::WHITE][square], fileIndex, rankIndex+2);
        }
        
        // Black pawn attacks
        bb_set(PawnAttacks[Color::BLACK][square], fileIndex-1, rankIndex-1);
        bb_set(PawnAttacks[Color::BLACK][square], fileIndex+1, rankIndex-1);
        
        // Black pawn moves
        bb_set(PawnMoves[Color::BLACK][square], fileIndex, rankIndex-1);
        if (rankIndex == 6) {
            bb_set(PawnMoves[Color::BLACK][square], fileIndex, rankIndex-2);
        }
    }
}

void FastMoveGenerator::initKingMoves() {
    for (int square = 0; square < 64; square++) {
        int fileIndex = file_index(square);
        int rankIndex = rank_index(square);
        
        bb_set(KingMoves[square], fileIndex, rankIndex+1);
        bb_set(KingMoves[square], fileIndex+1, rankIndex+1);
        bb_set(KingMoves[square], fileIndex+1, rankIndex);
        bb_set(KingMoves[square], fileIndex+1, rankIndex-1);
        bb_set(KingMoves[square], fileIndex, rankIndex-1);
        bb_set(KingMoves[square], fileIndex-1, rankIndex-1);
        bb_set(KingMoves[square], fileIndex-1, rankIndex);
        bb_set(KingMoves[square], fileIndex-1, rankIndex+1);
    }
}

void FastMoveGenerator::initKnightMoves() {
    for (int square = 0; square < 64; square++) {
        int fileIndex = file_index(square);
        int rankIndex = rank_index(square);
        
        // Top
        bb_set(KnightMoves[square], fileIndex-1, rankIndex+2);
        bb_set(KnightMoves[square], fileIndex+1, rankIndex+2);

        // Bottom
        bb_set(KnightMoves[square], fileIndex-1, rankIndex-2);
        bb_set(KnightMoves[square], fileIndex+1, rankIndex-2);
        
        // Left
        bb_set(KnightMoves[square], fileIndex-2, rankIndex+1);
        bb_set(KnightMoves[square], fileIndex-2, rankIndex-1);

        // Right
        bb_set(KnightMoves[square], fileIndex+2, rankIndex+1);
        bb_set(KnightMoves[square], fileIndex+2, rankIndex-1);
    }
}

MoveList FastMoveGenerator::generateMoves(Board board, Color::Color color, int squareIndex) {
    MoveList moveList;
        
    generatePawnsMoves(board, color, moveList, squareIndex);
    generateKingsMoves(board, color, moveList, squareIndex);
    generateKnightsMoves(board, color, moveList, squareIndex);
    generateSlidingMoves(board, color, Piece::ROOK, moveList, squareIndex);
    generateSlidingMoves(board, color, Piece::BISHOP, moveList, squareIndex);
    generateSlidingMoves(board, color, Piece::QUEEN, moveList, squareIndex);

//    for (int i=0; i<moveList.moveCount; i++) {
//        auto move = moveList.moves[i];
////        std::cout << SquareNames[move.from] << SquareNames[move.to] << std::endl;
//        auto newBoard = board;
//        newBoard.move(move);
//        bb_print(newBoard.occupancy());
//    }
    
    return moveList;
}

void FastMoveGenerator::generatePawnsMoves(Board &board, Color::Color color, MoveList &moveList, int squareIndex) {
    auto pawns = board.pieces[color][Piece::PAWN];
    auto emptySquares = board.emptySquares();
    auto blackPieces = board.allPieces(INVERSE(color));
    
    // Generate moves for each white pawn
    while (pawns > 0) {
        // Find the first white pawn starting from the least significant bit (that is, square a1)
        int square = lsb(pawns);
        
        // If the square index is specified, only generate move for that square
        if (squareIndex > -1 && square != squareIndex) {
            break;
        }
        
        // Clear that bit so next time we can find the next white pawn
        bb_clear(pawns, square);
        
        // Generate a bitboard for all the attacks that this white pawn
        // can do. The attacks bitboard is masked with the occupancy bitboard
        // because a pawn attack can only happen when there is a black piece
        // in the target square.
        // TODO: occupancy should actually be black occupancy
        // Using white occupancy, we can detect which piece is protected!
        auto attacks = PawnAttacks[color][square] & blackPieces;
        moveList.addMoves(square, attacks, color, Piece::PAWN);
        
        // Generate a bitboard for all the moves that this white pawn can do.
        // The move bitboard is masked with the empty bitboard which
        // in other words ensures that the pawn can only move to unoccupied square.
        auto moves = PawnMoves[color][square] & emptySquares;
        moveList.addMoves(square, moves, color, Piece::PAWN);
    }
}

void FastMoveGenerator::generateKingsMoves(Board &board, Color::Color color, MoveList &moveList, int squareIndex) {
    auto kings = board.pieces[color][Piece::KING];
    auto emptyOrBlackSquares = ~board.allPieces(color);

    // Generate moves for each white knight
    while (kings > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        int square = lsb(kings);
        
        // If the square index is specified, only generate move for that square
        if (squareIndex > -1 && square != squareIndex) {
            break;
        }

        // Clear that bit so next time we can find the next white knight
        bb_clear(kings, square);
        
        // Generate a bitboard for all the moves that this white knight
        // can do. The attacks bitboard is masked to ensure it can only
        // happy on an empty square or a square with a piece of the opposite color.
        auto moves = KingMoves[square] & emptyOrBlackSquares;
        moveList.addMoves(square, moves, color, Piece::KING);
    }
}

void FastMoveGenerator::generateKnightsMoves(Board &board, Color::Color color, MoveList &moveList, int squareIndex) {
    auto whiteKnights = board.pieces[color][Piece::KNIGHT];
    auto emptyOrBlackSquares = ~board.allPieces(color);
    
    // Generate moves for each white knight
    while (whiteKnights > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        int square = lsb(whiteKnights);
        
        // If the square index is specified, only generate move for that square
        if (squareIndex > -1 && square != squareIndex) {
            break;
        }

        // Clear that bit so next time we can find the next white knight
        bb_clear(whiteKnights, square);
        
        // Generate a bitboard for all the moves that this white knight
        // can do. The attacks bitboard is masked to ensure it can only
        // happy on an empty square or a square with a piece of the opposite color.
        auto moves = KnightMoves[square] & emptyOrBlackSquares;
        moveList.addMoves(square, moves, color, Piece::KNIGHT);
    }
}

void FastMoveGenerator::generateSlidingMoves(Board &board, Color::Color color, Piece::Piece piece, MoveList &moveList, int squareIndex) {
    auto slidingPieces = board.pieces[color][piece];
    auto occupancy = board.occupancy();
    auto emptyOrBlackSquares = ~board.allPieces(color);

    // Generate moves for each sliding piece
    while (slidingPieces > 0) {
        // Find the first sliding piece starting from the least significant bit (that is, square a1)
        int square = lsb(slidingPieces);
        
        // If the square index is specified, only generate move for that square
        if (squareIndex > -1 && square != squareIndex) {
            break;
        }

        // Clear that bit so next time we can find the next sliding piece
        bb_clear(slidingPieces, square);
        
        // Generate a bitboard for all the moves that this sliding piece can do.
        Bitboard potentialMoves;
        switch (piece) {
            case Piece::ROOK:
                potentialMoves = Rmagic(square, occupancy);
                break;
                
            case Piece::BISHOP:
                potentialMoves = Bmagic(square, occupancy);
                break;
                
            case Piece::QUEEN:
                potentialMoves = Rmagic(square, occupancy) | Bmagic(square, occupancy);
                break;
                
            default:
                assert(false); // not a sliding piece
                break;
        }
        
        // Note: the occupancy bitboard has all the white and black pieces,
        // we need to filter out the moves that land into a piece of the same
        // color because Rmagic will move to these squares anyway.
        auto moves = potentialMoves & emptyOrBlackSquares;
        
        moveList.addMoves(square, moves, color, piece);
    }
}

