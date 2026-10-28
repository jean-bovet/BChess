//
//  Verdict.swift
//  BChess
//
//  The engine's evaluation in words. The value is from White's point of view, as the search
//  reports it, so the sentence names a colour and reads the same for every pairing.
//

import Foundation

struct Verdict: Equatable, Sendable {
    let centipawns: Int
    let isMate: Bool

    init(centipawns: Int, isMate: Bool) {
        self.centipawns = centipawns
        self.isMate = isMate
    }

    private var isWhiteAhead: Bool {
        centipawns >= 0
    }

    var sentence: LocalizedStringResource {
        if isMate {
            return isWhiteAhead ? "White has a forced mate" : "Black has a forced mate"
        }
        switch abs(centipawns) {
        case ..<30: return "The position is equal"
        case 30..<100: return isWhiteAhead ? "White is slightly better" : "Black is slightly better"
        case 100..<250: return isWhiteAhead ? "White is better" : "Black is better"
        default: return isWhiteAhead ? "White is winning" : "Black is winning"
        }
    }

    /// One decimal with a sign: "+0.4", "−1.2" (U+2212), "0.0"; "Mate" for a mate, which the engine
    /// reports without a distance.
    var score: String {
        if isMate {
            return String(localized: "Mate")
        }
        let tenths = Int((Double(abs(centipawns)) / 10).rounded())
        if tenths == 0 {
            return GameText.notation("0.0")
        }
        let sign = centipawns > 0 ? "+" : "\u{2212}"
        return GameText.notation("\(sign)\(tenths / 10).\(tenths % 10)")
    }

    /// The evaluation bar's spoken label.
    var accessibilityLabel: LocalizedStringResource {
        "Evaluation \(score)"
    }

    /// White's part of the evaluation bar, 0 to 1.
    var whiteShare: Double {
        if isMate {
            return centipawns >= 0 ? 1 : 0
        }
        return 0.5 + Double(min(max(centipawns, -600), 600)) / 1200
    }
}
