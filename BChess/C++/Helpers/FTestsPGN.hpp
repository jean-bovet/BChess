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
        
        testPGNGameInput();
        testPGNGameOutput();
    }
    
    static void testPGNMove() {
        assertMovetextSingle("e4", "e2e4");
        assertMovetextSingle("e5", "");
        
        assertMovetextSingle("Nf3", "g1f3");
        assertMovetextSingle("Ngf3", "g1f3");
        assertMovetextSingle("Nbf3", "");
        
        assertMovetextSingle("f3", "f2f3");
    }
    
    
    constexpr const static char * move1to3 =
    "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
    ;

    constexpr const static char *move1to10 =
    "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
    "4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7"
    ;

    constexpr const static char *move1to34 =
    "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
    "4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7\n"
    "11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5\n"
    "Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6\n"
    "23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5\n"
    "hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5"
    ;
    
    constexpr const static char *allMoves =
    "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
    "4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7\n"
    "11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5\n"
    "Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6\n"
    "23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5\n"
    "hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5\n"
    "35. Ra7 g6 36. Ra6+ Kc5 37. Ke1 Nf4 38. g3 Nxh3 39. Kd2 Kb5 40. Rd6 Kc5 41. Ra6\n"
    "Nf2 42. g4 Bd3 43. Re6 1/2-1/2"
    ;
    

    static void testPGNGameInput() {
        assertPGNGame(move1to3, "r1bqkbnr/1ppp1ppp/p1n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4");
        
        assertPGNGame(move1to10, "r1bq1rk1/2pnbppp/p2p1n2/1p2p3/3PP3/1BP2N1P/PP3PP1/RNBQR1K1 w - - 1 11");
        
        assertPGNGame(move1to34, "8/6p1/3k4/R2n1bp1/1p6/1P3P1P/5KP1/8 w - - 3 35");
        
        assertPGNGame(allMoves, "8/8/4R1p1/2k3p1/1p4P1/1P1b1P2/3K1n2/8 b - - 2 43");
    }

    static void testPGNGameOutput() {
        assertOutputPGN(move1to3, "r1bqkbnr/1ppp1ppp/p1n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4", "1. e2e4 e7e5 2. Ng1f3 Nb8c6 3. Bf1b5 a7a6 *");
        
        assertOutputPGN(move1to10, "r1bq1rk1/2pnbppp/p2p1n2/1p2p3/3PP3/1BP2N1P/PP3PP1/RNBQR1K1 w - - 1 11", "1. e2e4 e7e5 2. Ng1f3 Nb8c6 3. Bf1b5 a7a6 4. Bb5a4 Ng8f6 5. Ke1g1 Bf8e7 6. Rf1e1 b7b5 7. Ba4b3 d7d6 8. c2c3 Ke8g8 9. h2h3 Nc6b8 10. d2d4 Nb8d7 *");
        
        assertOutputPGN(move1to34, "8/6p1/3k4/R2n1bp1/1p6/1P3P1P/5KP1/8 w - - 3 35", "1. e2e4 e7e5 2. Ng1f3 Nb8c6 3. Bf1b5 a7a6 4. Bb5a4 Ng8f6 5. Ke1g1 Bf8e7 6. Rf1e1 b7b5 7. Ba4b3 d7d6 8. c2c3 Ke8g8 9. h2h3 Nc6b8 10. d2d4 Nb8d7 11. c3c4 c7c6 12. c4b5 a6b5 13. Nb1c3 Bc8b7 14. Bc1g5 b5b4 15. Nc3b1 h7h6 16. Bg5h4 c6c5 17. d4e5 Nf6e4 18. Bh4e7 Qd8e7 19. e5d6 Qe7f6 20. Nb1d2 Ne4d6 21. Nd2c4 Nd6c4 22. Bb3c4 Nd7b6 23. Nf3e5 Ra8e8 24. Bc4f7 Rf8f7 25. Ne5f7 Re8e1 26. Qd1e1 Kg8f7 27. Qe1e3 Qf6g5 28. Qe3g5 h6g5 29. b2b3 Kf7e6 30. a2a3 Ke6d6 31. a3b4 c5b4 32. Ra1a5 Nb6d5 33. f2f3 Bb7c8 34. Kg1f2 Bc8f5 *");

        assertOutputPGN(allMoves, "8/8/4R1p1/2k3p1/1p4P1/1P1b1P2/3K1n2/8 b - - 2 43", "1. e2e4 e7e5 2. Ng1f3 Nb8c6 3. Bf1b5 a7a6 4. Bb5a4 Ng8f6 5. Ke1g1 Bf8e7 6. Rf1e1 b7b5 7. Ba4b3 d7d6 8. c2c3 Ke8g8 9. h2h3 Nc6b8 10. d2d4 Nb8d7 11. c3c4 c7c6 12. c4b5 a6b5 13. Nb1c3 Bc8b7 14. Bc1g5 b5b4 15. Nc3b1 h7h6 16. Bg5h4 c6c5 17. d4e5 Nf6e4 18. Bh4e7 Qd8e7 19. e5d6 Qe7f6 20. Nb1d2 Ne4d6 21. Nd2c4 Nd6c4 22. Bb3c4 Nd7b6 23. Nf3e5 Ra8e8 24. Bc4f7 Rf8f7 25. Ne5f7 Re8e1 26. Qd1e1 Kg8f7 27. Qe1e3 Qf6g5 28. Qe3g5 h6g5 29. b2b3 Kf7e6 30. a2a3 Ke6d6 31. a3b4 c5b4 32. Ra1a5 Nb6d5 33. f2f3 Bb7c8 34. Kg1f2 Bc8f5 35. Ra5a7 g7g6 36. Ra7a6 Kd6c5 37. Kf2e1 Nd5f4 38. g2g3 Nf4h3 39. Ke1d2 Kc5b5 40. Ra6d6 Kb5c5 41. Rd6a6 Nh3f2 42. g3g4 Bf5d3 43. Ra6e6 1/2-1/2");
    }
    
    static void assertOutputPGN(const char *pgnGame, std::string expectedFEN, std::string outputPGN) {
        FGame game;
        std::string gameS(pgnGame);
        assert(FPGN::setGame(gameS, game));

        // Assert the FEN for the end position
        std::string actualFEN = FFEN::getFEN(game.board);
        assert(actualFEN == expectedFEN);

        auto generatedPGN = FPGN::getGame(game);
        assert(generatedPGN == outputPGN);
        
        // Now let's try again the assert the game using the generated PGN and the expected FEN of the game
        // in the final position.
        assertPGNGame(generatedPGN.c_str(), expectedFEN);
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
        FGame game;
        unsigned cursor = 0;
        bool end = false;
        bool result = FPGN::parseMoveText("1. e4 e5", cursor, game, end);
        assert(result);
        assert(!end);
    }
    
    static void assertMovetextSingle(std::string pgn, std::string expectedMove) {
        unsigned cursor = 0;
        FGame game;
        bool end;
        Move move = FPGN::parseMove(pgn, cursor, game, end);
        if (expectedMove.size() == 0) {
            assert(!MOVE_ISVALID(move));
        } else {
            auto moveDescription = MOVE_DESCRIPTION(move);
            assert(moveDescription == expectedMove);
        }
    }
    
};

