//
//  VerdictTests.swift
//  BChessTests
//

import Testing

struct VerdictTests {

    @Test func sentenceThresholds() {
        let cases: [(Int, String)] = [
            (0, "The position is equal"),
            (29, "The position is equal"),
            (-29, "The position is equal"),
            (30, "White is slightly better"),
            (99, "White is slightly better"),
            (100, "White is better"),
            (249, "White is better"),
            (250, "White is winning"),
            (900, "White is winning"),
            (-30, "Black is slightly better"),
            (-99, "Black is slightly better"),
            (-100, "Black is better"),
            (-249, "Black is better"),
            (-250, "Black is winning"),
        ]
        for (cp, sentence) in cases {
            #expect(Verdict(centipawns: cp, isMate: false).sentence == sentence, "cp \(cp)")
        }
    }

    @Test func mateNamesTheWinner() {
        #expect(Verdict(centipawns: 30000, isMate: true).sentence == "White has a forced mate")
        #expect(Verdict(centipawns: -30000, isMate: true).sentence == "Black has a forced mate")
        #expect(Verdict(centipawns: 30000, isMate: true).score == "Mate")
        #expect(Verdict(centipawns: -30000, isMate: true).score == "Mate")
    }

    @Test func scoreFormatting() {
        #expect(Verdict(centipawns: 40, isMate: false).score == "+0.4")
        #expect(Verdict(centipawns: -120, isMate: false).score == "\u{2212}1.2")
        #expect(Verdict(centipawns: 0, isMate: false).score == "0.0")
        #expect(Verdict(centipawns: 4, isMate: false).score == "0.0")
        #expect(Verdict(centipawns: -4, isMate: false).score == "0.0")
        #expect(Verdict(centipawns: 1250, isMate: false).score == "+12.5")
    }

    @Test func whiteShare() {
        #expect(Verdict(centipawns: 0, isMate: false).whiteShare == 0.5)
        #expect(Verdict(centipawns: 600, isMate: false).whiteShare == 1)
        #expect(Verdict(centipawns: -600, isMate: false).whiteShare == 0)
        #expect(Verdict(centipawns: 1000, isMate: false).whiteShare == 1)
        #expect(Verdict(centipawns: -1000, isMate: false).whiteShare == 0)
        #expect(Verdict(centipawns: 300, isMate: false).whiteShare == 0.75)
        #expect(Verdict(centipawns: 30000, isMate: true).whiteShare == 1)
        #expect(Verdict(centipawns: -30000, isMate: true).whiteShare == 0)
    }
}
