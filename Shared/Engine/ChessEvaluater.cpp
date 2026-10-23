//
//  FEvaluate.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "ChessEvaluater.hpp"
#include "ChessMoveGenerator.hpp"
#include "ChessBoard.hpp"
#include "GameHistory.hpp"

#include "magicmoves.h"

#include <algorithm>
#include <cstring>
#include <iostream>

bool ChessEvaluater::positionalAnalysis = false;

// All these numbers are taken from https://chessprogramming.wikispaces.com/Simplified+evaluation+function
static int PawnPositionBonus[64] = {
    0,  0,  0,  0,  0,  0,  0,  0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5,  5, 10, 25, 25, 10,  5,  5,
    0,  0,  0, 20, 20,  0,  0,  0,
    5, -5,-10,  0,  0,-10, -5,  5,
    5, 10, 10,-20,-20, 10, 10,  5,
    0,  0,  0,  0,  0,  0,  0,  0
};

static int KnightPositionBonus[64] = {
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50,
};

static int BishopPositionBonus[64] = {
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0, 10, 10, 10, 10,  0,-10,
    -10, 10, 10, 10, 10, 10, 10,-10,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -20,-10,-10,-10,-10,-10,-10,-20,
};

static int RookPositionBonus[64] = {
    0,  0,  0,  0,  0,  0,  0,  0,
    5, 10, 10, 10, 10, 10, 10,  5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    0,  0,  0,  5,  5,  0,  0,  0
};

static int QueenPositionBonus[64] = {
    -20,-10,-10, -5, -5,-10,-10,-20,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -10,  0,  5,  5,  5,  5,  0,-10,
    -5,  0,  5,  5,  5,  5,  0, -5,
    0,  0,  5,  5,  5,  5,  0, -5,
    -10,  5,  5,  5,  5,  5,  0,-10,
    -10,  0,  5,  0,  0,  0,  0,-10,
    -20,-10,-10, -5, -5,-10,-10,-20
};

// TODO: see wiki to implement the end game position bonus for king
static int KingPositionBonus[64] = {
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -20,-30,-30,-40,-40,-30,-30,-20,
    -10,-20,-20,-20,-20,-20,-20,-10,
    20, 20,  0,  0,  0,  0, 20, 20,
    20, 30, 10,  0,  0, 10, 30, 20
};

static int PieceValue[PCOUNT] = { 100, 320, 330, 500, 900, 20000 };

static Square whiteIndex(Square original) {
    auto rank = RankFrom(original);
    auto file = FileFrom(original);
    return (7-rank)*8+file;
}

static Square blackIndex(Square original) {
    auto rank = RankFrom(original);
    auto file = FileFrom(original);
    return rank*8+file;
}

int ChessEvaluater::pieceValue(Piece piece) {
    return PieceValue[piece];
}

// Every piece of both colors that attacks `square`, with the pieces `bb` on the board `occupancy`
static Bitboard attackersOf(Square square, Bitboard occupancy, const Bitboard bb[COUNT][PCOUNT]) {
    Bitboard attackers = 0;
    for (unsigned color=0; color<COUNT; color++) {
        // A pawn of the other color on the square sees the squares that our pawns attack it from
        attackers |= PawnAttacks[INVERSE(color)][square] & bb[color][PAWN];
        attackers |= KnightMoves[square] & bb[color][KNIGHT];
        attackers |= KingMoves[square] & bb[color][KING];
    }
    Bitboard diagonal = Bmagic(square, occupancy);
    Bitboard straight = Rmagic(square, occupancy);
    for (unsigned color=0; color<COUNT; color++) {
        attackers |= diagonal & (bb[color][BISHOP] | bb[color][QUEEN]);
        attackers |= straight & (bb[color][ROOK] | bb[color][QUEEN]);
    }
    return attackers & occupancy;
}

int ChessEvaluater::see(ChessBoard &board, Move move) {
    const Square from = MOVE_FROM(move), to = MOVE_TO(move);
    const Color mover = MOVE_COLOR(move);
    
    Bitboard bb[COUNT][PCOUNT];
    memcpy(bb, board.pieces, sizeof(bb));
    Bitboard occupancy = board.getOccupancy();
    
    // The mover leaves its square. The pawn that an en-passant capture takes leaves its own square, which
    // can open a line onto the target.
    bb_clear(bb[mover][MOVE_PIECE(move)], from);
    bb_clear(occupancy, from);
    if (MOVE_IS_ENPASSANT(move)) {
        Square victim = mover == WHITE ? to - 8 : to + 8;
        bb_clear(bb[INVERSE(mover)][PAWN], victim);
        bb_clear(occupancy, victim);
    }
    
    // gain[d] is what the side that makes capture d nets if the exchange stops after it
    int gain[32];
    int depth = 0;
    Piece promoted = MOVE_PROMOTION_PIECE(move);
    gain[0] = PieceValue[MOVE_CAPTURED_PIECE(move)];
    Piece onSquare = MOVE_PIECE(move);
    if (promoted > PAWN) {
        gain[0] += PieceValue[promoted] - PieceValue[PAWN];
        onSquare = promoted;
    }
    
    Color side = INVERSE(mover);
    while (depth < 31) {
        Bitboard attackers = attackersOf(to, occupancy, bb);
        
        // The least valuable attacker of the side to capture
        Piece capturer = PCOUNT;
        Bitboard capturers = 0;
        for (unsigned piece=PAWN; piece<PCOUNT; piece++) {
            capturers = attackers & bb[side][piece];
            if (capturers) {
                capturer = Piece(piece);
                break;
            }
        }
        if (capturer == PCOUNT) {
            break;
        }
        // The king may only capture when nothing of the other side still attacks the square
        if (capturer == KING) {
            Bitboard others = 0;
            for (unsigned piece=PAWN; piece<PCOUNT; piece++) {
                others |= attackers & bb[INVERSE(side)][piece];
            }
            if (others) {
                break;
            }
        }
        
        Square origin = lsb(capturers);
        depth++;
        gain[depth] = PieceValue[onSquare] - gain[depth-1];
        
        // A pawn that gets to the last rank is a queen from then on
        Rank lastRank = side == WHITE ? 7 : 0;
        if (capturer == PAWN && RankFrom(to) == lastRank) {
            gain[depth] += PieceValue[QUEEN] - PieceValue[PAWN];
            onSquare = QUEEN;
        } else {
            onSquare = capturer;
        }
        
        bb_clear(bb[side][capturer], origin);
        bb_clear(occupancy, origin);
        side = INVERSE(side);
    }
    
    // Each side stops the exchange when continuing would cost it
    while (depth > 0) {
        gain[depth-1] = -std::max(-gain[depth-1], gain[depth]);
        depth--;
    }
    return gain[0];
}

bool ChessEvaluater::isQuiet(Move move) {
    // A quiet move is a move that is not:
    // - a capture
    // - a promotion
    // - a check
    return !MOVE_IS_CAPTURE(move) && MOVE_PROMOTION_PIECE(move) == 0 && !MOVE_IS_CHECK(move);
}

int ChessEvaluater::getBonus(Piece piece, Color color, Square square) {
    auto index = color == WHITE ? whiteIndex(square) : blackIndex(square);
    switch (piece) {
        case PAWN:
            return PawnPositionBonus[index];
            
        case BISHOP:
            return BishopPositionBonus[index];
            
        case KNIGHT:
            return KnightPositionBonus[index];
            
        case ROOK:
            return RookPositionBonus[index];
            
        case KING:
            return KingPositionBonus[index];
            
        case QUEEN:
            return QueenPositionBonus[index];
            
        default:
            return 0;
    }
}

bool ChessEvaluater::isDraw(ChessBoard &board, const HistoryPtr &history) {
    return ChessHistory::isThreefoldRepetition(board.getHash(), board.reversiblePlies, history);
}

bool ChessEvaluater::isFiftyMoveDraw(ChessBoard &board) {
    if (board.halfMoveClock < 100) {
        return false;
    }
    // Only a side in check can be mated, and the mate is told by one legal move at most
    if (board.isCheck(board.color)) {
        auto moves = ChessMoveGenerator::generateMoves(board, board.color, ChessMoveGenerator::Mode::firstMoveOnly);
        return moves.count > 0;
    }
    return true;
}

bool ChessEvaluater::isDeadPosition(const ChessBoard &board) {
    int knights = 0;
    Bitboard bishops = 0;
    for (unsigned color=0; color<COUNT; color++) {
        // A pawn, a rook or a queen can always mate in some line
        if (board.pieces[color][PAWN] || board.pieces[color][ROOK] || board.pieces[color][QUEEN]) {
            return false;
        }
        knights += bb_count(board.pieces[color][KNIGHT]);
        bishops |= board.pieces[color][BISHOP];
    }
    
    // Only kings and minor pieces are left: one minor piece or none cannot mate
    if (knights + bb_count(bishops) <= 1) {
        return true;
    }
    
    // Bishops alone, all on squares of one colour, cannot mate whoever owns them
    const Bitboard darkSquares = 0x55AA55AA55AA55AAULL;
    return knights == 0 && ((bishops & darkSquares) == 0 || (bishops & ~darkSquares) == 0);
}

int ChessEvaluater::evaluate(ChessBoard &board) {
    auto moves = ChessMoveGenerator::generateMoves(board, board.color, ChessMoveGenerator::Mode::firstMoveOnly);
    return evaluate(board, moves);
}

int ChessEvaluater::evaluate(ChessBoard &board, const MoveList &moves) {
    if (moves.count == 0) {
        if (board.isCheck(board.color)) {
            // No moves but a check, that's a mat
            // Note: always evaluate from white's point of view
            return board.color == WHITE ? -MAT_VALUE : MAT_VALUE;
        } else {
            // No moves and not check, that's a draw
            return 0;
        }
    }
    
    // A dead position is a draw, and every leaf of the search comes through here to be told so. It depends on the
    // pieces alone, so the transposition table can keep it.
    if (isDeadPosition(board)) {
        return 0;
    }
    
    // Compute the piece balance value
    int value = 0;
    for (unsigned color=0; color<COUNT; color++) {
        // Note: always evaluate from white's point of view
        int colorSign = (color == WHITE) ? 1 : -1;
        
        // The bonus of the pieces' locations, for that particular color
        int totalBonus = 0;
        for (unsigned piece=0; piece<PCOUNT; piece++) {
            Bitboard pieces = board.pieces[color][piece];
            int count = bb_count(pieces);
            int pvalue = PieceValue[piece];

            value += colorSign * (pvalue * count);
            
            // Advantage when a pair of bishop is detected, which is worth 1/2 pawn
            // https://www.chess.com/article/view/the-evaluation-of-material-imbalances-by-im-larry-kaufman
            if (piece == BISHOP && count >= 2) {
                value += colorSign * (PieceValue[PAWN]/2);
            }
            
            // Now let's add some bonus depending on the piece location
            while (pieces > 0) {
                Square square = lsb(pieces);
                bb_clear(pieces, square);
                
                totalBonus += getBonus((Piece)piece, (Color)color, square);
            }
        }
        
        value += colorSign * totalBonus;
    }
    
    // Compute the piece action value (either attacked, defended or hanging) and mobility
    // See http://www.chessbin.com/post/Chess-Board-Evaluation
    if (positionalAnalysis) {
        auto moveList = ChessMoveGenerator::generateMoves(board, board.color, ChessMoveGenerator::Mode::moveCaptureAndDefenseMoves);
        auto opponentMoveList = ChessMoveGenerator::generateMoves(board, INVERSE(board.color), ChessMoveGenerator::Mode::moveCaptureAndDefenseMoves);
        
        value += evaluateAction(moveList) + evaluateAction(opponentMoveList);
        value += evaluateMobility(moveList) + evaluateMobility(opponentMoveList);
    }
    
    return value;
}

int ChessEvaluater::evaluateAction(ChessBoard board) {
    auto moveList = ChessMoveGenerator::generateMoves(board, board.color, ChessMoveGenerator::Mode::moveCaptureAndDefenseMoves);
    auto opponentMoveList = ChessMoveGenerator::generateMoves(board, INVERSE(board.color), ChessMoveGenerator::Mode::moveCaptureAndDefenseMoves);
    return evaluateAction(moveList) + evaluateAction(opponentMoveList);
}

// TODO: at some point, give more value to pawn when attacking or defending than queen?
//static int PieceActionValue[PCOUNT] = { 6, 3, 3, 2, 1, 1 };

int ChessEvaluater::evaluateAction(const MoveList &moves) {
    int attackedValues[2][64] = { };
    int defendedValues[2][64] = { };
    
    for (int index=0; index<moves.count; index++) {
        auto move = moves[index];
        auto moveColor = MOVE_COLOR(move);
        
        if (MOVE_IS_CAPTURE(move)) {
            auto to = MOVE_TO(move);
            if (MOVE_CAPTURED_PIECE_COLOR(move) == MOVE_COLOR(move)) {
                // Same color, means defense. Doesn't count towards
                // mobility because in reality that piece cannot move.
                defendedValues[moveColor][to]++;
            } else {
                // Different color means capture.
                // This count also towards mobility.
                attackedValues[INVERSE(moveColor)][to]++;
            }
        }
    }
    
    int value = 0;
    
    for (int index=0; index<64; index++) {
        for (unsigned color=0; color<COUNT; color++) {
            auto colorSign = (color == WHITE) ? 1 : -1;
            
            auto attacked = attackedValues[color][index];
            auto defended = defendedValues[color][index];
            
            value -= colorSign * attacked;
            value += colorSign * defended;
            
            if (defended < attacked) {
                value -= colorSign * ((attacked - defended) * 10);
            }
        }
    }
        
    return value;
}

int ChessEvaluater::evaluateMobility(ChessBoard board) {
    auto moveList = ChessMoveGenerator::generateMoves(board, board.color, ChessMoveGenerator::Mode::moveCaptureAndDefenseMoves);
    auto opponentMoveList = ChessMoveGenerator::generateMoves(board, INVERSE(board.color), ChessMoveGenerator::Mode::moveCaptureAndDefenseMoves);
    return evaluateMobility(moveList) + evaluateMobility(opponentMoveList);
}

int ChessEvaluater::evaluateMobility(const MoveList &moves) {
    int mobility = 0;
    
    for (int index=0; index<moves.count; index++) {
        auto move = moves[index];
        auto moveColor = MOVE_COLOR(move);
        auto whiteMove = moveColor == WHITE;
        auto colorSign = whiteMove ? 1 : -1;
        
        if (MOVE_IS_CAPTURE(move)) {
            if (MOVE_CAPTURED_PIECE_COLOR(move) != MOVE_COLOR(move)) {
                // Different color means capture.
                // This count also towards mobility.
                mobility += colorSign * 1;
            }
        } else {
            // Regular move, just count towards mobility
            mobility += colorSign * 1;
            
            // One more bonus when castling because two pieces are moving
            if (MOVE_IS_CASTLING(move)) {
                mobility += colorSign * 1;
            }
        }
    }
    
    return mobility;
}
