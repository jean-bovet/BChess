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
    /// The wide layout: the verdict, the best line and the statistics each on their own line.
    var stacked = false

    private var scoreChip: some View {
        Text(verdict?.score ?? "")
            .font(.footnote.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(Walnut.scoreChipText)
            .background(Walnut.scoreChip, in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func content(for verdict: Verdict) -> some View {
        if stacked {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    scoreChip
                    Text(verdict.sentence)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Walnut.textPrimary)
                }
                if !line.isEmpty {
                    (Text("Best ").foregroundStyle(Walnut.textSecondary)
                     + Text(line).fontWeight(.semibold).foregroundStyle(Walnut.textPrimary))
                        .font(.footnote)
                        .lineLimit(2)
                }
                if let statistics {
                    Text(statistics)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Walnut.textSecondary)
                }
            }
        } else {
            HStack(spacing: 8) {
                scoreChip
                // The sentence gives way to the line when the width is short
                Text(verdict.sentence + (line.isEmpty ? "" : " \u{00B7}"))
                    .foregroundStyle(Walnut.textSecondary)
                    .lineLimit(1)
                    .layoutPriority(-1)
                if !line.isEmpty {
                    Text(line)
                        .fontWeight(.semibold)
                        .foregroundStyle(Walnut.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .font(.footnote)
        }
    }

    var body: some View {
        Group {
            if let verdict {
                content(for: verdict)
            } else {
                Text("Analyzing\u{2026}")
                    .font(.footnote)
                    .foregroundStyle(Walnut.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, stacked ? 14 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .walnutCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("engine-readout")
    }

    /// The verdict on the session's position, or nil while it awaits the search or the game is over.
    static func verdict(of session: GameSession) -> Verdict? {
        guard session.gameEnd == .none, let info = session.info else {
            return nil
        }
        return Verdict(centipawns: info.value, isMate: info.mat)
    }

    /// The engine's readout of the session, or nil when there is nothing to show (the game is over).
    static func make(session: GameSession, showStatistics: Bool, stacked: Bool = false) -> EngineView? {
        guard session.gameEnd == .none else {
            return nil
        }
        guard let info = session.info else {
            return EngineView(verdict: nil, line: "", stacked: stacked)
        }
        return EngineView(verdict: Verdict(centipawns: info.value, isMate: info.mat),
                          line: info.bestLine(false),
                          statistics: showStatistics ? statistics(of: info) : nil,
                          stacked: stacked)
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

/// White's share of the evaluation, as a thin vertical bar the height of the board. White's part
/// grows from White's side: the bottom, or the top when the board is rotated.
struct EvaluationBar: View {
    let verdict: Verdict
    let rotated: Bool

    @Environment(\.colorScheme) private var colorScheme

    static var width: CGFloat {
        #if os(macOS)
        10
        #else
        8
        #endif
    }

    var body: some View {
        let dark = colorScheme == .dark
        GeometryReader { proxy in
            ZStack(alignment: rotated ? .top : .bottom) {
                Rectangle().fill(dark ? Color.black : Walnut.textPrimary)
                Rectangle().fill(Color(red: 0.984, green: 0.973, blue: 0.953))
                    .frame(height: proxy.size.height * verdict.whiteShare)
            }
        }
        .frame(width: Self.width)
        .clipShape(RoundedRectangle(cornerRadius: Self.width / 2))
        .overlay {
            if dark {
                RoundedRectangle(cornerRadius: Self.width / 2)
                    .strokeBorder(Color(red: 0.290, green: 0.239, blue: 0.200), lineWidth: 1)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Evaluation \(verdict.score)")
    }
}

#if DEBUG
#Preview("Equal") {
    PreviewScenarios.engineEqual.view()
}

#Preview("Slightly better") {
    PreviewScenarios.engineSlightlyBetter.view()
}

#Preview("Mate") {
    PreviewScenarios.engineMate.view()
}

#Preview("Analyzing") {
    PreviewScenarios.engineAnalyzing.view()
}

#Preview("Statistics") {
    PreviewScenarios.engineStatistics.view()
}

#Preview("Stacked") {
    PreviewScenarios.engineStacked.view()
}

#Preview("Evaluation bars") {
    PreviewScenarios.engineEvaluationBars.view()
}
#endif
