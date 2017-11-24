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
        let s = "position startpos moves e2e4 b7b6 d2d4 c7c6 g1f3 d7d6 b1c3 c8b7 d4d5 c6c5 f1b5 b8d7 b5d7 d8d7 c1h6 g7h6 f3g5 h6g5 d1h5 h7h6 e1g1 c5c4 a2a4 g5g4 c3b5 e8d8 b2b3 c4b3 c2b3 a7a6 f1c1 a6b5 a4b5 a8a1 c1a1 d7b5 a1a8"
        let fen = "R2k1bnr/1b2pp2/1p1p3p/1q1P3Q/4P1p1/1P6/5PPP/6K1 b KQkq - 0 1"
        assert(command: s, resultingFEN: fen, bestMove: "bestmove b7a8")
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
        assert(command: s, resultingFEN: fen, bestMove: "bestmove c3c4")
    }
    
    func assert(command: String, resultingFEN: String, bestMove: String) {
        let uci = UCI()
        var tokens = command.split(separator: " ").map { String($0) }
        uci.process(&tokens)
        
//        print(uci.engine.board)
        
        let fen = uci.engine.board.toFEN()
        XCTAssertEqual(fen, resultingFEN)
        
        let expectation = XCTestExpectation(description: "evaluation")
        var engineInfo: Analysis.Info? = nil
        uci.engine.evaluate(depth: UCIEngine.defaultDepth) { (info, completed) in
            if completed {
                engineInfo = info
                expectation.fulfill()
            } else {
//                print(info.uciInfoMessage)
            }
        }
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(engineInfo?.uciBestMove, bestMove)
    }
}
