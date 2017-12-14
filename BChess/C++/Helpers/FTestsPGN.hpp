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

class FTestsPGN {
public:
    
    static void runAll() {
        MoveGenerator::initialize();
        
        testPGNMove();
        testPGNGame();
    }
    
    static void testPGNMove() {
        assertMovetextSingle("e4", "e2e4");
        assertMovetextSingle("e5", "");
        
        assertMovetextSingle("Nf3", "g1f3");
        assertMovetextSingle("Ngf3", "g1f3");
        assertMovetextSingle("Nbf3", "");
        
        assertMovetextSingle("f3", "f2f3");
    }
    
    static void testPGNGame() {
        const char *move1to3 =
        "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
        ;
        
        assertPGNGame(move1to3, "r1bqkbnr/1ppp1ppp/p1n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4");
        
        const char *move1to10 =
        "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
        "4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7"
        ;
        
        assertPGNGame(move1to10, "r1bq1rk1/2pnbppp/p2p1n2/1p2p3/3PP3/1BP2N1P/PP3PP1/RNBQR1K1 w - - 1 11");
        
        const char *move1to34 =
        "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
        "4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7\n"
        "11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5\n"
        "Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6\n"
        "23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5\n"
        "hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5"
        ;
        
        assertPGNGame(move1to34, "8/6p1/3k4/R2n1bp1/1p6/1P3P1P/5KP1/8 w - - 3 35");
        
        const char *allMoves =
        "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
        "4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7\n"
        "11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5\n"
        "Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6\n"
        "23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5\n"
        "hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5\n"
        "35. Ra7 g6 36. Ra6+ Kc5 37. Ke1 Nf4 38. g3 Nxh3 39. Kd2 Kb5 40. Rd6 Kc5 41. Ra6\n"
        "Nf2 42. g4 Bd3 43. Re6 1/2-1/2"
        ;
        
        assertPGNGame(allMoves, "8/8/4R1p1/2k3p1/1p4P1/1P1b1P2/3K1n2/8 b - - 2 43");
    }
    
    static void assertPGNGame(const char *pgnGame, std::string expectedFEN) {
        FGame game;
        std::string gameS(pgnGame);
        assert(FPGN::setGame(gameS, game));
        
        // Assert the FEN for the end position
        std::string actualFEN = FFEN::getFEN(game.board);
        assert(actualFEN == expectedFEN);
    }
    
    static void testSinglePGNMove() {
        Board board;
        unsigned cursor = 0;
        bool end = false;
        bool result = FPGN::parseMoveText("1. e4 e5", cursor, board, end);
        assert(result);
        assert(!end);
    }
    
    static void assertMovetextSingle(std::string pgn, std::string expectedMove) {
        unsigned cursor = 0;
        Board board;
        bool end;
        Move move = FPGN::parseMove(pgn, cursor, board, end);
        if (expectedMove.size() == 0) {
            assert(!MOVE_ISVALID(move));
        } else {
            auto moveDescription = MOVE_DESCRIPTION(move);
            assert(moveDescription == expectedMove);
        }
    }
    
};

