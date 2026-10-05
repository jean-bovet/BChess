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

    private var leader: String {
        centipawns >= 0 ? "White" : "Black"
    }

    var sentence: String {
        if isMate {
            return "\(leader) has a forced mate"
        }
        switch abs(centipawns) {
        case ..<30: return "The position is equal"
        case 30..<100: return "\(leader) is slightly better"
        case 100..<250: return "\(leader) is better"
        default: return "\(leader) is winning"
        }
    }

    /// One decimal with a sign: "+0.4", "−1.2" (U+2212), "0.0"; "Mate" for a mate, which the engine
    /// reports without a distance.
    var score: String {
        if isMate {
            return "Mate"
        }
        let tenths = Int((Double(abs(centipawns)) / 10).rounded())
        if tenths == 0 {
            return "0.0"
        }
        let sign = centipawns > 0 ? "+" : "\u{2212}"
        return "\(sign)\(tenths / 10).\(tenths % 10)"
    }

    /// White's part of the evaluation bar, 0 to 1.
    var whiteShare: Double {
        if isMate {
            return centipawns >= 0 ? 1 : 0
        }
        return 0.5 + Double(min(max(centipawns, -600), 600)) / 1200
    }
}
