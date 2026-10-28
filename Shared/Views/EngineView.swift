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
    /// The wide layout (iPad, a wide Mac window): more room around the lines, and the best line may wrap.
    var wide = false

    private func scoreChip(_ score: String) -> some View {
        Text(score)
            .font(.footnote.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(Walnut.scoreChipText)
            .background(Walnut.scoreChip, in: RoundedRectangle(cornerRadius: 6))
    }

    /// The best line, or a hidden stand-in while there is none, so the card keeps its height.
    private var bestLine: some View {
        // One key, "Best %@": a language may put the line first
        Text("Best \(Text(GameText.notation(line)).fontWeight(.semibold).foregroundStyle(Walnut.textPrimary))")
            .foregroundStyle(Walnut.textSecondary)
            .font(.footnote)
            .lineLimit(wide ? 2 : 1)
            .truncationMode(.tail)
            .opacity(line.isEmpty ? 0 : 1)
    }

    var body: some View {
        // The verdict, the best line and the statistics each on their own line, so the verdict is never cut
        VStack(alignment: .leading, spacing: wide ? 8 : 4) {
            if let verdict {
                HStack(spacing: 8) {
                    scoreChip(verdict.score)
                    Text(verdict.sentence)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Walnut.textPrimary)
                        .lineLimit(1)
                }
            } else {
                // As tall as a verdict, so the cards below stay in place while it is awaited
                ZStack(alignment: .leading) {
                    scoreChip("0.0").hidden()
                    Text("Analyzing\u{2026}")
                        .font(.subheadline)
                        .foregroundStyle(Walnut.textSecondary)
                }
            }
            bestLine
            if let statistics {
                Text(statistics)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Walnut.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, wide ? 14 : 10)
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
    static func make(session: GameSession, showStatistics: Bool, wide: Bool = false) -> EngineView? {
        guard session.gameEnd == .none else {
            return nil
        }
        guard let info = session.info else {
            return EngineView(verdict: nil, line: "", wide: wide)
        }
        return EngineView(verdict: Verdict(centipawns: info.value, isMate: info.mat),
                          line: info.bestLine(false),
                          statistics: showStatistics ? statistics(of: info) : nil,
                          wide: wide)
    }

    static func statistics(of info: FEngineInfo) -> String {
        statistics(depth: Int(info.depth), quiescenceDepth: Int(info.quiescenceDepth),
                   nodes: Int(info.nodeEvaluated), speed: Int(info.movesPerSecond))
    }

    /// "Depth 9/12 with 1,234,567 nodes at 410,000 n/s". The depth is notation and stays in Western digits (D1); the
    /// node count and the speed are counts and follow the locale.
    static func statistics(depth: Int, quiescenceDepth: Int, nodes: Int, speed: Int) -> String {
        var depthText = String(depth)
        if quiescenceDepth > 0 && quiescenceDepth != depth {
            depthText += "/\(quiescenceDepth)"
        }
        depthText = GameText.notation(depthText)
        let nodeText = nodes.formatted(.number)
        let speedText = speed.formatted(.number)
        return String(localized: "Depth \(depthText) with \(nodeText) nodes at \(speedText) n/s")
    }
}

/// White's share of the evaluation, as a thin vertical bar the height of the board. White's part
/// grows from White's side: the bottom, or the top when the board is rotated.
struct EvaluationBar: View {
    /// Nil while the next verdict is awaited or the game is over: the bar keeps the last one.
    let verdict: Verdict?
    let rotated: Bool

    @State private var shown: Verdict?
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
                    .frame(height: proxy.size.height * (shown?.whiteShare ?? 0.5))
            }
        }
        .frame(width: Self.width)
        .onChange(of: verdict, initial: true) { _, verdict in
            if let verdict {
                shown = verdict
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.width / 2))
        .overlay {
            if dark {
                RoundedRectangle(cornerRadius: Self.width / 2)
                    .strokeBorder(Color(red: 0.290, green: 0.239, blue: 0.200), lineWidth: 1)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(shown.map { String(localized: $0.accessibilityLabel) } ?? String(localized: "Evaluation"))
    }
}
