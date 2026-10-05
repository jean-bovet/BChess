//
//  EngineView.swift
//  BChess
//
//  The engine's opinion of the position in words, with a bar and its best line.
//

import SwiftUI

struct EngineView: View {

    /// Nil while the first result of the search is awaited.
    let verdict: Verdict?
    let line: String
    /// Depth, nodes and speed, shown only when the user asked for them.
    var statistics: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let verdict {
                HStack {
                    Text(verdict.sentence)
                    Spacer()
                    Text(verdict.score)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.medium))
                EvaluationBar(whiteShare: verdict.whiteShare)
                    .frame(height: 6)
                if !line.isEmpty {
                    Text("Best: \(line)")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let statistics {
                    Text(statistics)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Analyzing\u{2026}")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("engine-readout")
    }

    /// The engine's readout of the session, or nil when there is nothing to show (the game is over).
    static func make(session: GameSession, showStatistics: Bool) -> EngineView? {
        guard session.gameEnd == .none else {
            return nil
        }
        guard let info = session.info else {
            return EngineView(verdict: nil, line: "")
        }
        return EngineView(verdict: Verdict(centipawns: info.value, isMate: info.mat),
                          line: info.bestLine(false),
                          statistics: showStatistics ? statistics(of: info) : nil)
    }

    static func statistics(of info: FEngineInfo) -> String {
        let nodes = info.nodeEvaluated.formatted(.number)
        let speed = info.movesPerSecond.formatted(.number)
        var text = "Depth \(info.depth)"
        if info.quiescenceDepth > 0 && info.quiescenceDepth != info.depth {
            text += "/\(info.quiescenceDepth)"
        }
        return text + " with \(nodes) nodes at \(speed) n/s"
    }
}

/// White's share of the evaluation, from the left.
private struct EvaluationBar: View {
    let whiteShare: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.black.opacity(0.75))
                Rectangle().fill(Color.white)
                    .frame(width: proxy.size.width * whiteShare)
            }
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.secondary.opacity(0.5), lineWidth: 0.5))
        }
    }
}

#Preview("Equal") {
    EngineView(verdict: Verdict(centipawns: 10, isMate: false), line: "9. h3 d5 10. exd5")
        .padding()
}

#Preview("Slightly better") {
    EngineView(verdict: Verdict(centipawns: -60, isMate: false), line: "9. h3 d5 10. exd5")
        .padding()
}

#Preview("Mate") {
    EngineView(verdict: Verdict(centipawns: 100_000, isMate: true), line: "Qh7#")
        .padding()
}

#Preview("Analyzing") {
    EngineView(verdict: nil, line: "")
        .padding()
}

#Preview("Statistics") {
    EngineView(verdict: Verdict(centipawns: 120, isMate: false), line: "9. h3 d5 10. exd5",
               statistics: "Depth 9/12 with 1,234,567 nodes at 410,000 n/s")
        .padding()
}
