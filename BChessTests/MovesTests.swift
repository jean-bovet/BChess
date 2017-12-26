//
//  MovesTests.swift
//  BChessTests
//
//  Created by Jean Bovet on 12/7/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import XCTest

class MovesTests: XCTestCase {
        
    func testWhitePawnFromStartRank() {
        assertMoves("8/8/8/8/8/8/2P5/8 w - - 0 1",
                    [
                        "8/8/8/8/8/2P5/8/8 b - - 0 1",
                        "8/8/8/8/2P5/8/8/8 b - c3 0 1"
            ]);
    }
    
    func testWhitePawnFromMiddleRank() {
        assertMoves("8/8/8/8/2P5/8/8/8 w - - 0 1",
                    [ "8/8/8/2P5/8/8/8/8 b - - 0 1" ]);
    }
    
    func testKnight() {
        assertMoves("8/8/8/3N4/8/8/8/8 w - - 0 1",
                    [ "8/2N5/8/8/8/8/8/8 b - - 1 1",
                        "8/4N3/8/8/8/8/8/8 b - - 1 1",
                        "8/8/5N2/8/8/8/8/8 b - - 1 1",
                        "8/8/8/8/5N2/8/8/8 b - - 1 1",
                        "8/8/8/8/8/4N3/8/8 b - - 1 1",
                        "8/8/8/8/8/2N5/8/8 b - - 1 1",
                        "8/8/8/8/1N6/8/8/8 b - - 1 1",
                        "8/8/1N6/8/8/8/8/8 b - - 1 1"
        ],
                    "d5");
    }
    
    func testKnightInCorner() {
        assertMoves("8/8/8/8/8/8/8/N7 w - - 0 1",
                    ["8/8/8/8/8/1N6/8/8 b - - 1 1",
                        "8/8/8/8/8/8/2N5/8 b - - 1 1"
                        ],
                    "a1");
    }
    
    func testKnightWithPawns() {
        assertMoves("8/8/1P3p2/3N4/8/8/8/8 w - - 0 1",
                    [
                        "8/2N5/1P3p2/8/8/8/8/8 b - - 1 1",
                        "8/4N3/1P3p2/8/8/8/8/8 b - - 1 1",
                        "8/8/1P3N2/8/8/8/8/8 b - - 0 1",
                        "8/8/1P3p2/8/5N2/8/8/8 b - - 1 1",
                        "8/8/1P3p2/8/8/4N3/8/8 b - - 1 1",
                        "8/8/1P3p2/8/8/2N5/8/8 b - - 1 1",
                        "8/8/1P3p2/8/1N6/8/8/8 b - - 1 1"
        ],
                    "d5");
    }
    

    func testBlackKingCheckByKnight() {
        assertMoves("3r3k/5Npp/8/8/2Q5/1B6/8/7K b - - 0 1", [ "3r2k1/5Npp/8/8/2Q5/1B6/8/7K w - - 1 2" ], "h8");
    }
    
    func testBlackKingCheckByQueen() {
        assertMoves("3r2Qk/6pp/8/6N1/8/1B6/8/7K b - - 0 1", [ "6rk/6pp/8/6N1/8/1B6/8/7K w - - 0 2" ]);
    }
    
    func testBlackIsMate() {
        assertMoves("6rk/5Npp/8/8/8/1B6/8/7K b - - 0 1", []);
    }
    
    func testPawnMoveNotOverPiece() {
        assertMoves("7k/8/8/8/8/4n3/4P3/7K w - - 0 1", [
            "7k/8/8/8/8/4n3/4P2K/8 b - - 1 1",
            "7k/8/8/8/8/4n3/4P3/6K1 b - - 1 1"
            ])
    }
    
    func testOnlyOneMoveBecauseOfCheckFromH7() {
        assertMoves("6k1/7P/p7/4p3/4b2K/5q2/6r1/8 b - - 0 45", [
            "8/7k/p7/4p3/4b2K/5q2/6r1/8 w - - 0 46",
            "6k1/7b/p7/4p3/7K/5q2/6r1/8 w - - 0 46",
            "7k/7P/p7/4p3/4b2K/5q2/6r1/8 w - - 1 46",
            "8/6kP/p7/4p3/4b2K/5q2/6r1/8 w - - 1 46",
            "5k2/7P/p7/4p3/4b2K/5q2/6r1/8 w - - 1 46",
            "8/5k1P/p7/4p3/4b2K/5q2/6r1/8 w - - 1 46",
            ])
    }
    
    func testEnPassantMove() {
        assertMoves("4k3/8/8/2pP4/8/8/8/4K3 w - c6 0 2", [
            "4k3/8/2P5/8/8/8/8/4K3 b - - 0 2", // pawn en passant
            "4k3/8/3P4/2p5/8/8/8/4K3 b - - 0 2", // pawn
            "4k3/8/8/2pP4/8/8/8/3K4 b - - 1 2", // king
            "4k3/8/8/2pP4/8/8/3K4/8 b - - 1 2",
            "4k3/8/8/2pP4/8/8/4K3/8 b - - 1 2",
            "4k3/8/8/2pP4/8/8/5K2/8 b - - 1 2",
            "4k3/8/8/2pP4/8/8/8/5K2 b - - 1 2"
            ])
    }
    
    func testWhiteKingCastling() {
        // No castling at starting position
        assertMoves(StartPosFEN, [], "e1")
        
        // Castling on both sides for white is possible
        assertMoves("4k3/8/8/8/8/8/3PPP2/R3K2R w KQ - 0 1",
                    [
                        "4k3/8/8/8/8/8/3PPP2/R4RK1 b - - 1 1", // King side
                        "4k3/8/8/8/8/8/3PPP2/2KR3R b - - 1 1", // Queen side
                        "4k3/8/8/8/8/8/3PPP2/R2K3R b - - 1 1",
                        "4k3/8/8/8/8/8/3PPP2/R4K1R b - - 1 1"
            ], "e1"
        )
        
        // Black rook attacking g1 (so no king side castling possible)
        assertMoves("4k1r1/8/8/8/8/8/3PPP2/R3K2R w KQ - 0 1",
                    [
                        "4k1r1/8/8/8/8/8/3PPP2/2KR3R b - - 1 1", // Queen side
                        "4k1r1/8/8/8/8/8/3PPP2/R2K3R b - - 1 1",
                        "4k1r1/8/8/8/8/8/3PPP2/R4K1R b - - 1 1"
            ], "e1"
        )
        
        // Black rook attacking b1 (so no queen side castling possible)
        assertMoves("1r2k3/8/8/8/8/8/3PPP2/R3K2R w KQ - 0 1",
                    [
                        "1r2k3/8/8/8/8/8/3PPP2/R4RK1 b - - 1 1", // King side
                        "1r2k3/8/8/8/8/8/3PPP2/R2K3R b - - 1 1",
                        "1r2k3/8/8/8/8/8/3PPP2/R4K1R b - - 1 1"
            ], "e1"
        )
    }
    
    func testBlackKingCastling() {
        // No castling at starting position after e2e4 for white
        assertMoves("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1", [], "e8")
        
        // Castling on both sides for black is possible
        assertMoves("r3k2r/3ppp2/8/8/8/8/8/4K3 b kq - 0 1",
                    [
                        "r4rk1/3ppp2/8/8/8/8/8/4K3 w - - 1 2", // King side
                        "2kr3r/3ppp2/8/8/8/8/8/4K3 w - - 1 2", // Queen side
                        "r4k1r/3ppp2/8/8/8/8/8/4K3 w - - 1 2",
                        "r2k3r/3ppp2/8/8/8/8/8/4K3 w - - 1 2"
            ], "e8"
        )

        // White rook attacking g8 (so no king side castling possible)
        assertMoves("r3k2r/3ppp2/8/8/8/8/8/4K1R1 b kq - 0 1",
                    [
                        "2kr3r/3ppp2/8/8/8/8/8/4K1R1 w - - 1 2", // Queen side
                        "r4k1r/3ppp2/8/8/8/8/8/4K1R1 w - - 1 2",
                        "r2k3r/3ppp2/8/8/8/8/8/4K1R1 w - - 1 2"
            ], "e8"
        )

        // White rook attacking b8 (so no queen side castling possible)
        assertMoves("r3k2r/3ppp2/8/8/8/8/8/1R2K3 b kq - 0 1",
                    [
                        "r4rk1/3ppp2/8/8/8/8/8/1R2K3 w - - 1 2", // King side
                        "r4k1r/3ppp2/8/8/8/8/8/1R2K3 w - - 1 2",
                        "r2k3r/3ppp2/8/8/8/8/8/1R2K3 w - - 1 2"
            ], "e8"
        )
    }
    
    func testBlackKingCannotCastleBecauseInCheck() {
        assertMoves("r3kb1r/pp2pQpp/n7/qNn1N3/8/P7/1PP2PPP/R1B1R1K1 b kq - 0 15",
                    [
                        "r2k1b1r/pp2pQpp/n7/qNn1N3/8/P7/1PP2PPP/R1B1R1K1 w - - 1 16", // King to d8 it's only possible move
            ], "e8"
        )
    }

    func testWhitePawnPromotion() {
        assertMoves("4k3/6P1/8/8/8/8/8/4K3 w - - 0 2", [
            "4k1Q1/8/8/8/8/8/8/4K3 b - - 0 2",
            "4k1R1/8/8/8/8/8/8/4K3 b - - 0 2",
            "4k1B1/8/8/8/8/8/8/4K3 b - - 0 2",
            "4k1N1/8/8/8/8/8/8/4K3 b - - 0 2",
            ], "g7")
    }
    
    func testBlackPawnPromotion() {
        assertMoves("4k3/8/8/8/8/8/6p1/4K3 b - - 0 1", [
            "4k3/8/8/8/8/8/8/4K1q1 w - - 0 2",
            "4k3/8/8/8/8/8/8/4K1r1 w - - 0 2",
            "4k3/8/8/8/8/8/8/4K1b1 w - - 0 2",
            "4k3/8/8/8/8/8/8/4K1n1 w - - 0 2"
            ], "g2")
    }
    
    func assertMoves(_ startFEN: String, _ expectedMoveFENs: [String], _ squareName: String? = nil) {
        let engine = FEngine()
        let moveFENs = engine.moveFENs(from: startFEN, squareName: squareName)
        XCTAssertEqual(moveFENs.count, expectedMoveFENs.count)
        
        let expectedMoveFENsSet = Set<String>(expectedMoveFENs)
        let moveFENsSet = Set<String>(moveFENs)
        XCTAssertEqual(moveFENsSet, expectedMoveFENsSet)
    }
    
}
