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
            #expect(String(localized: Verdict(centipawns: cp, isMate: false).sentence) == sentence, "cp \(cp)")
        }
    }

    @Test func mateNamesTheWinner() {
        #expect(String(localized: Verdict(centipawns: 30000, isMate: true).sentence) == "White has a forced mate")
        #expect(String(localized: Verdict(centipawns: -30000, isMate: true).sentence) == "Black has a forced mate")
        #expect(Verdict(centipawns: 30000, isMate: true).score == "Mate")
        #expect(Verdict(centipawns: -30000, isMate: true).score == "Mate")
    }

    @Test func scoreFormatting() {
        // A left-to-right isolate around the number keeps its sign on the right side in a right-to-left line
        #expect(Verdict(centipawns: 40, isMate: false).score == "\u{2066}+0.4\u{2069}")
        #expect(Verdict(centipawns: -120, isMate: false).score == "\u{2066}\u{2212}1.2\u{2069}")
        #expect(Verdict(centipawns: 0, isMate: false).score == "\u{2066}0.0\u{2069}")
        #expect(Verdict(centipawns: 4, isMate: false).score == "\u{2066}0.0\u{2069}")
        #expect(Verdict(centipawns: -4, isMate: false).score == "\u{2066}0.0\u{2069}")
        #expect(Verdict(centipawns: 1250, isMate: false).score == "\u{2066}+12.5\u{2069}")
    }

    @Test func accessibilityLabelNamesTheScore() {
        #expect(String(localized: Verdict(centipawns: 40, isMate: false).accessibilityLabel) == "Evaluation \u{2066}+0.4\u{2069}")
        #expect(String(localized: Verdict(centipawns: 30000, isMate: true).accessibilityLabel) == "Evaluation Mate")
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
