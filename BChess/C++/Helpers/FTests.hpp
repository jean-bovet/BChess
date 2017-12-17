//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FBoard.hpp"
#include "FFEN.hpp"
#include "FMinimax.hpp"
#include "FMoveGenerator.hpp"
#include "FPGN.hpp"

#include <set>
#include <vector>

class FTests {
public:
    
    static void runAll() {
        MoveGenerator::initialize();
        
        testInvalidMove();
        testSimpleMove();
        testMoveCapture();
        testMoveEnPassant();
        testMovePromotion();
        
        testEmptyBoard();

        testWhiteKingCheckWithKnight();
        testWhiteKingCheckWithBishop();
        testWhiteKingCheckWithRook();
        testWhiteKingCheckWithQueenLikeBishop();
        testWhiteKingCheckWithQueenLikeRook();

        testWhiteKingNotCheck();

        testBlackKingCheck();
        
        testPawnForkQueenAndKing();
    }
    
    static void testInvalidMove() {
        Move m = 0;
        assert(!MOVE_ISVALID(m));
    }

    static void testSimpleMove() {
        Move m = createMove(12, 62, BLACK, BISHOP);
        assert(MOVE_FROM(m) == 12);
        assert(MOVE_TO(m) == 62);
        assert(MOVE_COLOR(m) == BLACK);
        assert(MOVE_PIECE(m) == BISHOP);
        assert(!MOVE_IS_CAPTURE(m));
        assert(!MOVE_IS_ENPASSANT(m));
        assert(MOVE_ISVALID(m));
    }
    
    static void testMoveCapture() {
        Move m = createCapture(12, 62, BLACK, BISHOP);
        assert(MOVE_FROM(m) == 12);
        assert(MOVE_TO(m) == 62);
        assert(MOVE_COLOR(m) == BLACK);
        assert(MOVE_PIECE(m) == BISHOP);
        assert(MOVE_IS_CAPTURE(m));
        assert(!MOVE_IS_ENPASSANT(m));
        assert(MOVE_ISVALID(m));
    }

    static void testMoveEnPassant() {
        Move m = createEnPassant(12, 62, BLACK, BISHOP);
        assert(MOVE_FROM(m) == 12);
        assert(MOVE_TO(m) == 62);
        assert(MOVE_COLOR(m) == BLACK);
        assert(MOVE_PIECE(m) == BISHOP);
        assert(MOVE_IS_CAPTURE(m));
        assert(MOVE_IS_ENPASSANT(m));
        assert(MOVE_ISVALID(m));
    }

    static void testMovePromotion() {
        Move m = createPromotion(12, 62, BLACK, PAWN, ROOK);
        assert(MOVE_FROM(m) == 12);
        assert(MOVE_TO(m) == 62);
        assert(MOVE_COLOR(m) == BLACK);
        assert(MOVE_PIECE(m) == PAWN);
        assert(MOVE_PROMOTION_PIECE(m) == ROOK);
        assert(!MOVE_IS_CAPTURE(m));
        assert(!MOVE_IS_ENPASSANT(m));
        assert(MOVE_ISVALID(m));
    }

    static void testEmptyBoard() {
        Board board;
        assert(board.getOccupancy() > 0);
        assert(!board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
        
        board.clear();
        assert(board.getOccupancy() == 0);
        assert(!board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }
    
    static void testWhiteKingCheckWithKnight() {
        Board board;
        assert(FFEN::setFEN("8/2k5/8/8/8/2K5/4n3/8 w - - 0 1", board));
        assert(board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }
    
    static void testWhiteKingCheckWithBishop() {
        Board board;
        assert(FFEN::setFEN("8/2k5/5b2/8/8/2K5/8/8 w - - 0 1", board));
        assert(board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }
    
    static void testWhiteKingCheckWithRook() {
        Board board;
        assert(FFEN::setFEN("8/2k5/8/8/8/2K3r1/8/8 w - - 0 1", board));
        assert(board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }
    
    static void testWhiteKingCheckWithQueenLikeBishop() {
        Board board;
        assert(FFEN::setFEN("8/2k3q1/8/8/8/2K5/8/8 w - - 0 1", board));
        assert(board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }
    
    static void testWhiteKingCheckWithQueenLikeRook() {
        Board board;
        assert(FFEN::setFEN("8/2k5/8/8/8/2K3q1/8/8 w - - 0 1", board));
        assert(board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }
    
    static void testWhiteKingNotCheck() {
        Board board;
        assert(FFEN::setFEN("8/2k5/8/8/8/2K5/5n2/8 w - - 0 1", board));
        assert(!board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }
    
    static void testBlackKingCheck() {
        Board board;
        assert(FFEN::setFEN("8/2k5/4N3/8/8/2K5/5n2/8 w - - 0 1", board));
        assert(!board.isCheck(Color::WHITE));
        assert(board.isCheck(Color::BLACK));
    }
    
    /** Assert the following position and evaluate the best move for white
     which is c3c4:
     ........
     ........
     ........
     .♛.♚....
     ........
     ..♙.....
     .♘......
     ....♔...
     */
    static void testPawnForkQueenAndKing() {
        std::string start = "8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1";
        std::string end = "8/8/8/3k4/2N5/8/8/4K3 b - - 0 2";
        assertBestMove(start, end, "c3c4",  { "c3c4", "Qb5xc4", "Nb2xc4" } );
    }

    static void assertBestMove(std::string fen, std::string finalFEN, std::string bestMove, std::vector<std::string> bestLine) {
        Board board;
        assert(FFEN::setFEN(fen, board));
        std::string boardFEN = FFEN::getFEN(board);
        assert(boardFEN == fen);

        Minimax minimax;
        Minimax::Info info = minimax.searchBestMove(board, 4, nil);
        
        // Assert the best move
        auto expectedMove = FPGN::to_string(info.evaluation.move);
        assert(expectedMove == bestMove);

        // Assert the best line
        std::vector<std::string> evaluatedLine;
        for (auto move : info.evaluation.line) {
            evaluatedLine.push_back(FPGN::to_string(move));
        }
        assert(evaluatedLine.size() == bestLine.size());
        assert(evaluatedLine == bestLine);

        // Now play the moves to reach the final position
        Board finalBoard = board;
        for (auto move : info.evaluation.line) {
            finalBoard.move(move);
        }
        auto finalBoardFEN = FFEN::getFEN(finalBoard);
        assert(finalBoardFEN == finalFEN);
    }
        
};

