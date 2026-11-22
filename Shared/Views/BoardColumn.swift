//
//  BoardColumn.swift
//  Shared
//

import SwiftUI

/// The wide layout's board column: the rows and the board, as wide as the board. The board is the largest
/// square that fits the proposal once the rows have their height, and every row spans that width, so the
/// captured pieces end at the board's edge and the column never stretches past it (a VStack gives the rows
/// all the proposed width, and the slack lands between the board and the move list).
///
/// The column is never narrower than its widest row's minimum width, whatever it is proposed. When that decides the width (a window
/// too short for its rows), the board keeps its height-limited side at the leading edge and the column is
/// wider than the board by the difference: the one bounded, visible overflow, nothing drawn past the column.
struct BoardColumn: Layout {
    /// The evaluation bar's gutter on the board's leading side (`ContentView.boardLeading`): the board subview
    /// is that much wider than its square, and so is the column.
    var leading: CGFloat
    var spacing: CGFloat = 10
    /// The column takes the whole width it is proposed and the board stands in the middle of it (the rows around their own
    /// width), so the board's place does not depend on the rows' text, whatever the script (a face-to-face half).
    var centersBoard = false
    /// Marks the board among the subviews; the others are rows.
    struct IsBoard: LayoutValueKey { static let defaultValue = false }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let fit = Self.fit(proposal, subviews, leading: leading, spacing: spacing, ignoresRowWidths: centersBoard)
        let width = centersBoard ? (proposal.width.flatMap { $0.isFinite ? max($0, fit.width) : nil } ?? fit.width) : fit.width
        return CGSize(width: width, height: fit.side + fit.rows)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let fit = Self.fit(proposal, subviews, leading: leading, spacing: spacing, ignoresRowWidths: centersBoard)
        var y = bounds.minY
        for (index, subview) in subviews.enumerated() {
            let size = subview[IsBoard.self]
                ? CGSize(width: fit.side + leading, height: fit.side)
                : CGSize(width: fit.width, height: fit.heights[index])
            if size == .zero {
                continue
            }
            let x = centersBoard ? bounds.minX + (bounds.width - size.width) / 2 : bounds.minX
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            y += size.height + spacing
        }
    }

    /// What the column measured: its width, the board's side, the rows' heights (by subview index, zero for
    /// the board) and their total with the spacings.
    private struct Fit {
        var width: CGFloat
        var side: CGFloat
        var heights: [CGFloat]
        var rows: CGFloat
    }

    /// One function for both methods, so what is placed is what was measured. A missing or infinite dimension
    /// is not a limit: the other one decides, and with neither the board is its own ideal size.
    /// A nil or infinite dimension is no limit; the finite one decides, and with no finite dimension the board is
    /// its ideal size (a `Layout` never reports an infinite size, so `(∞, ∞)` gets the ideal, as `fixedSize` would).
    private nonisolated static func fit(_ proposal: ProposedViewSize, _ subviews: Subviews, leading: CGFloat, spacing: CGFloat,
                                           ignoresRowWidths: Bool) -> Fit {
        let board = subviews.first { $0[IsBoard.self] }
        let finiteWidth = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        let finiteHeight = proposal.height.flatMap { $0.isFinite ? $0 : nil }

        /// The rows at a width: their heights and the total height they take with the spacings around the board.
        func rows(at width: CGFloat) -> (heights: [CGFloat], total: CGFloat) {
            var heights = [CGFloat](repeating: 0, count: subviews.count)
            var shown = board == nil ? 0 : 1
            var total: CGFloat = 0
            for (index, subview) in subviews.enumerated() where !subview[IsBoard.self] {
                let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
                heights[index] = size.height
                if size != .zero {
                    shown += 1
                    total += size.height
                }
            }
            return (heights, total + spacing * CGFloat(max(0, shown - 1)))
        }

        // The widest row at its narrowest
        let rowsMin = subviews.filter { !$0[IsBoard.self] }
            .map { $0.sizeThatFits(ProposedViewSize(width: 0, height: nil)).width }
            .max() ?? 0

        if finiteWidth == nil && finiteHeight == nil {
            let side = board?.sizeThatFits(.unspecified).height ?? 0
            let width = max(side + leading, rowsMin)
            let measured = rows(at: width)
            return Fit(width: width, side: side, heights: measured.heights, rows: measured.total)
        }

        let limit = finiteWidth ?? .infinity
        let room = finiteHeight ?? .infinity
        var width = limit
        while true {
            let measured = rows(at: width)
            let exact = max(0, min(limit - leading, room - measured.total))
            // A centred board has a whole-point side, so its squares fall on the same pixels whatever the script
            let side = ignoresRowWidths ? (exact + 0.01).rounded(.down) : exact
            let narrower = max(side + leading, rowsMin)
            // Rows measured at a narrower width can only take more lines, so the width only shrinks and, the
            // heights taking finitely many values, the loop ends
            if narrower > width - 0.01 {
                // Never narrower than the rows: a column proposed less than that reports the rows' width, so the
                // parent makes room (the move list gives way) instead of the rows drawing under it
                let final = max(width, rowsMin)
                let remeasured = final > width ? rows(at: final) : measured
                return Fit(width: final, side: min(side, max(0, final - leading)), heights: remeasured.heights, rows: remeasured.total)
            }
            width = narrower
        }
    }
}
