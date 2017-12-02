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

class FTests {
public:
    static void runAll() {
        testWhitePawnFromStartRank();
        testWhitePawnFromMiddleRank();
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
    
    static void assertMoves(std::string fen, std::initializer_list<std::string> movesFen) {
        Board board = FFEN::createBoard(fen);
        std::string boardFEN = FFEN::getFEN(board);
        assert(boardFEN == fen);
        
        FastMoveGenerator generator;
        MoveList moves = generator.generateMoves(board, board.color);
        assert(moves.moveCount == movesFen.size());

        int index = 0;
        for (std::string expectedMoveFEN : movesFen) {
            Move move = moves.moves[index];
            Board newBoard = board;
            newBoard.move(move);
//            newBoard.print();
            std::string moveFEN = FFEN::getFEN(newBoard);
            assert(moveFEN == expectedMoveFEN);
            index++;
        }
    }
};

