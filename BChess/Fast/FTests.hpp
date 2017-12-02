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
    }
        
    static void testWhitePawnFromStartRank() {
        assertMoves("8/8/8/8/8/8/2P5/8 w - - 0 1",
                    {
                        "8/8/8/8/8/2P5/8/8 w - - 0 1",
                        "8/8/8/8/2P5/8/8/8 w - - 0 1"
                    });
    }
    
    static void testWhitePawnFromMiddleRank() {
        assertMoves("8/8/8/8/2P5/8/8/8 w - - 0 1",
                    { "8/8/8/2P5/8/8/8/8 w - - 0 1" });
    }
    
    static void testKnight() {
        assertMoves("8/8/8/3N4/8/8/8/8 w - - 0 1",
                    { "8/2N5/8/8/8/8/8/8 w - - 0 1",
                     "8/4N3/8/8/8/8/8/8 w - - 0 1",
                     "8/8/5N2/8/8/8/8/8 w - - 0 1",
                     "8/8/8/8/5N2/8/8/8 w - - 0 1",
                     "8/8/8/8/8/4N3/8/8 w - - 0 1",
                     "8/8/8/8/8/2N5/8/8 w - - 0 1",
                     "8/8/8/8/1N6/8/8/8 w - - 0 1",
                     "8/8/1N6/8/8/8/8/8 w - - 0 1"
                    },
                    "d5");
    }

    static void testKnightInCorner() {
        assertMoves("8/8/8/8/8/8/8/N7 w - - 0 1",
                    {"8/8/8/8/8/1N6/8/8 w - - 0 1",
                        "8/8/8/8/8/8/2N5/8 w - - 0 1"},
                    "a1");
    }

    static void testKnightWithPawns() {
        assertMoves("8/8/1P3p2/3N4/8/8/8/8 w - - 0 1",
                    {"8/2N5/1P3p2/8/8/8/8/8 w - - 0 1",
                     "8/4N3/1P3p2/8/8/8/8/8 w - - 0 1",
                     "8/8/1P3N2/8/8/8/8/8 w - - 0 1",
                     "8/8/1P3p2/8/5N2/8/8/8 w - - 0 1",
                     "8/8/1P3p2/8/8/4N3/8/8 w - - 0 1",
                     "8/8/1P3p2/8/8/2N5/8/8 w - - 0 1",
                        "8/8/1P3p2/8/1N6/8/8/8 w - - 0 1"},
                    "d5");
    }

//    func testBlackKingCheckByKnight() {
//        assertMoves("3r3k/5Npp/8/8/2Q5/1B6/8/7K b - - 1 1", [ "3r2k1/5Npp/8/8/2Q5/1B6/8/7K w - - 2 2" ], "h8")
//    }
//
//    func testBlackKingCheckByQueen() {
//        assertMoves("3r2Qk/6pp/8/6N1/8/1B6/8/7K b - - 1 1", [ "6rk/6pp/8/6N1/8/1B6/8/7K w - - 0 2"])
//    }
//
//    func testBlackIsMate() {
//        assertMoves("6rk/5Npp/8/8/8/1B6/8/7K b - - 1 2", [])
//    }

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

