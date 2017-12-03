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
#include <set>
#include <vector>

class FTests {
public:
    
    static void runAll() {
        testWhitePawnFromStartRank();
        testWhitePawnFromMiddleRank();
        testKnight();
        testKnightInCorner();
        testKnightWithPawns();
        testEmptyBoard();
        
        testWhiteKingCheckWithKnight();
        testWhiteKingCheckWithBishop();
        testWhiteKingCheckWithRook();
        testWhiteKingCheckWithQueenLikeBishop();
        testWhiteKingCheckWithQueenLikeRook();
        
        testWhiteKingNotCheck();
        
        testBlackKingCheck();
        testBlackKingCheckByKnight();
        testBlackKingCheckByQueen();
        
        testBlackIsMate();
    }
    
    static void testWhitePawnFromStartRank() {
        assertMoves("8/8/8/8/8/8/2P5/8 w - - 0 1",
                    {
                        "8/8/8/8/8/2P5/8/8 b - - 0 1",
                        "8/8/8/8/2P5/8/8/8 b - - 0 1"
                    });
    }
    
    static void testWhitePawnFromMiddleRank() {
        assertMoves("8/8/8/8/2P5/8/8/8 w - - 0 1",
                    { "8/8/8/2P5/8/8/8/8 b - - 0 1" });
    }
    
    static void testKnight() {
        assertMoves("8/8/8/3N4/8/8/8/8 w - - 0 1",
                    { "8/2N5/8/8/8/8/8/8 b - - 0 1",
                     "8/4N3/8/8/8/8/8/8 b - - 0 1",
                     "8/8/5N2/8/8/8/8/8 b - - 0 1",
                     "8/8/8/8/5N2/8/8/8 b - - 0 1",
                     "8/8/8/8/8/4N3/8/8 b - - 0 1",
                     "8/8/8/8/8/2N5/8/8 b - - 0 1",
                     "8/8/8/8/1N6/8/8/8 b - - 0 1",
                     "8/8/1N6/8/8/8/8/8 b - - 0 1"
                    },
                    "d5");
    }

    static void testKnightInCorner() {
        assertMoves("8/8/8/8/8/8/8/N7 w - - 0 1",
                    {"8/8/8/8/8/1N6/8/8 b - - 0 1",
                        "8/8/8/8/8/8/2N5/8 b - - 0 1"},
                    "a1");
    }

    static void testKnightWithPawns() {
        assertMoves("8/8/1P3p2/3N4/8/8/8/8 w - - 0 1",
                    {
                        "8/2N5/1P3p2/8/8/8/8/8 b - - 0 1",
                        "8/4N3/1P3p2/8/8/8/8/8 b - - 0 1",
                        "8/8/1P3N2/8/8/8/8/8 b - - 0 1",
                        "8/8/1P3p2/8/5N2/8/8/8 b - - 0 1",
                        "8/8/1P3p2/8/8/4N3/8/8 b - - 0 1",
                        "8/8/1P3p2/8/8/2N5/8/8 b - - 0 1",
                        "8/8/1P3p2/8/1N6/8/8/8 b - - 0 1"
                    },
                    "d5");
    }

    static void testEmptyBoard() {
        Board board;
        assert(board.occupancy() > 0);
        assert(!board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));

        board.clear();
        assert(board.occupancy() == 0);
        assert(!board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }
    
    static void testWhiteKingCheckWithKnight() {
        auto board = FFEN::createBoard("8/2k5/8/8/8/2K5/4n3/8 w - - 0 1");
        assert(board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }
    
    static void testWhiteKingCheckWithBishop() {
        auto board = FFEN::createBoard("8/2k5/5b2/8/8/2K5/8/8 w - - 0 1");
        assert(board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }
    
    static void testWhiteKingCheckWithRook() {
        auto board = FFEN::createBoard("8/2k5/8/8/8/2K3r1/8/8 w - - 0 1");
        assert(board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }

    static void testWhiteKingCheckWithQueenLikeBishop() {
        auto board = FFEN::createBoard("8/2k3q1/8/8/8/2K5/8/8 w - - 0 1");
        assert(board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }

    static void testWhiteKingCheckWithQueenLikeRook() {
        auto board = FFEN::createBoard("8/2k5/8/8/8/2K3q1/8/8 w - - 0 1");
        assert(board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }

    static void testWhiteKingNotCheck() {
        auto board = FFEN::createBoard("8/2k5/8/8/8/2K5/5n2/8 w - - 0 1");
        assert(!board.isCheck(Color::WHITE));
        assert(!board.isCheck(Color::BLACK));
    }

    static void testBlackKingCheck() {
        auto board = FFEN::createBoard("8/2k5/4N3/8/8/2K5/5n2/8 w - - 0 1");
        assert(!board.isCheck(Color::WHITE));
        assert(board.isCheck(Color::BLACK));
    }

    static void testBlackKingCheckByKnight() {
        assertMoves("3r3k/5Npp/8/8/2Q5/1B6/8/7K b - - 0 1", { "3r2k1/5Npp/8/8/2Q5/1B6/8/7K w - - 0 1" }, "h8");
    }

    static void testBlackKingCheckByQueen() {
        assertMoves("3r2Qk/6pp/8/6N1/8/1B6/8/7K b - - 0 1", { "6rk/6pp/8/6N1/8/1B6/8/7K w - - 0 1" });
    }

    static void testBlackIsMate() {
        assertMoves("6rk/5Npp/8/8/8/1B6/8/7K b - - 0 1", {});
    }

    static void assertMoves(std::string fen, std::initializer_list<std::string> movesFen, std::string squareName = "") {
        Board board = FFEN::createBoard(fen);
        std::string boardFEN = FFEN::getFEN(board);
        assert(boardFEN == fen);

        int squareIndex = squareIndexForName(squareName);
                
        FastMoveGenerator generator;
        MoveList moves = generator.generateMoves(board, board.color, squareIndex);
        assert(moves.moveCount == movesFen.size());

        std::set<std::string> expectedMovesFen(movesFen);
        
        int index = 0;
        for (std::string expectedMoveFEN : movesFen) {
            Move move = moves.moves[index];
            Board newBoard = board;
            newBoard.move(move);
//            newBoard.print();
            std::string moveFEN = FFEN::getFEN(newBoard);
            assert(expectedMovesFen.count(moveFEN) > 0);
            expectedMovesFen.erase(moveFEN);
            index++;
        }
    }
    
    static int squareIndexForName(std::string name) {
        for (int i=0; i<64; i++) {
            if (SquareNames[i] == name) {
                return i;
            }
        }
        return -1;
    }
};

