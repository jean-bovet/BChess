//
//  GamesTests.swift
//  BChessTests
//
//  Created by Jean Bovet on 11/24/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import XCTest

class GamesTests: XCTestCase {

    /** Test the following move sequence by making sure the castle e1g1 is
     correctly processed. Also check that the best move for this position
     is b7a8 for black:
     
     ♖..♚.♝♞♜
     .♝..♟♟..
     .♟.♟...♟
     .♛.♙...♕
     ....♙.♟.
     .♙......
     .....♙♙♙
     ......♔.
 */
    func testCastleAndBestMoveB7A8() {
        // 37 half-move from starting position
        // 19 full-move from starting position - the last move a1a8 is white.
        let s = "position startpos moves e2e4 b7b6 d2d4 c7c6 g1f3 d7d6 b1c3 c8b7 d4d5 c6c5 f1b5 b8d7 b5d7 d8d7 c1h6 g7h6 f3g5 h6g5 d1h5 h7h6 e1g1 c5c4 a2a4 g5g4 c3b5 e8d8 b2b3 c4b3 c2b3 a7a6 f1c1 a6b5 a4b5 a8a1 c1a1 d7b5 a1a8"
        let fen = "R2k1bnr/1b2pp2/1p1p3p/1q1P3Q/4P1p1/1P6/5PPP/6K1 b - - 1 19"
        assert(command: s, resultingFEN: fen, bestMove: "bestmove b7a8", depth: 5)
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
    func testPawnForkQueenAndKing() {
        let s = "position fen 8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1"
        let fen = "8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1"
        assert(command: s, resultingFEN: fen, bestMove: "bestmove c3c4", depth: 5)
    }
    
    /** Evaluate the following position with black to move.
     Best move should be C8B7 (bishop capturing the pawn).
     ♜.♝♛♚..♜
     ♟♙.♟.♟♟♟
     ...♟♟♙..
     ........
     ........
     ♙.♘..♘.♙
     .♙♙..♙♙.
     ♖.♗.♔♗.♖
 */
    func testBlackToMoveC8B7() {
        let s = "position fen r1bqk2r/pP1p1ppp/3ppP2/8/8/P1N2N1P/1PP2PP1/R1B1KB1R b KQkq - 0 12"
        let fen = "r1bqk2r/pP1p1ppp/3ppP2/8/8/P1N2N1P/1PP2PP1/R1B1KB1R b KQkq - 0 12"
        assert(command: s, resultingFEN: fen, bestMove: "bestmove c8b7")
    }
    
    /** Evaluate the following position with black to move.
 ....♚...
 ..♜.....
 ........
 ........
 ........
 ........
 ..♖.....
 ....♔...
*/
    func testBlackToMoveC7C2() {
        let s = "position fen 4k3/2r5/8/8/8/8/2R5/4K3 b - - 0 1"
        let fen = "4k3/2r5/8/8/8/8/2R5/4K3 b - - 0 1"
        assert(command: s, resultingFEN: fen, bestMove: "bestmove c7c2")
    }
    
    func testManyMovesIncludingCastleAndHalfMoveClock() {
        let s = "position startpos moves e2e4 a7a5 g1f3 a5a4 d2d4 b7b6 f1e2 c8b7 e1g1 b7e4 b1c3 e4c6 c1f4 a4a3 b2b3 b6b5 d4d5 c6b7 c3b5 b7a6 b5c3 a6b7 e2c4 e7e6 d5e6 f7e6 f1e1 g7g5 f4g5 b7f3 g5d8 f3d1 e1d1 e8d8 c4e6 g8f6 c3b5 f8c5 d1d3 h8e8 e6f5 e8g8 a1d1 c7c6 c2c4 c6b5 c4b5 d7d5 d3d5 f6d5 d1d5 d8e7 d5c5 e7d6 c5c1"
        let fen = "rn4r1/7p/3k4/1P3B2/8/pP6/P4PPP/2R3K1 b - - 2 28"
        // TODO: I think g8d8 is a better move, but let's check
        assert(command: s, resultingFEN: fen, bestMove: "bestmove g8h8")
    }
    
    func testBlackMoveToMate() {
        let s = "position fen 8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39"
        let fen = "8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39"
        assert(command: s, resultingFEN: fen, bestMove: "bestmove f2g2")
    }

    func testPawnPromotionToKnightToMate() {
        let s = "position fen 6br/5Ppk/7p/8/8/8/8/4K3 w - - 0 1"
        let fen = "6br/5Ppk/7p/8/8/8/8/4K3 w - - 0 1"
        assert(command: s, resultingFEN: fen, bestMove: "bestmove f7f8")
    }
    
    func assert(command: String, resultingFEN: String, bestMove: String, depth: Int = UCI.defaultDepth) {
        let uci = UCI()
        uci.engine.useOpeningBook = false
        
        var tokens = command.split(separator: " ").map { String($0) }
        uci.process(&tokens)
                
        let fen = uci.engine.fen()
        XCTAssertEqual(fen, resultingFEN)
        
        let expectation = XCTestExpectation(description: "evaluation")
        var engineInfo: FEngineInfo? = nil
        uci.engine.evaluate(depth) { (info, completed) in
            if completed {
                engineInfo = info
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 30)
        XCTAssertEqual(engineInfo?.uciBestMove, bestMove)
    }
}
