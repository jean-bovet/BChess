//
//  MoveListView.swift
//  BChess
//
//  The moves of the game as a score sheet: one row per move number, with comments and variations.
//

import SwiftUI

struct MoveListView: View {

    let session: GameSession
    /// The wide layout's card: a surface with a "MOVES" caption above the rows.
    var card = false

    private static let scheme = "bchess-move"

    var body: some View {
        if card {
            VStack(alignment: .leading, spacing: 0) {
                Text("MOVES")
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(Walnut.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                list
            }
            .walnutCard(radius: 12)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(session.game.rows) { row in
                MoveRowView(row: row, current: session.currentMoveUUID, select: { session.selectMove(uuid: $0) })
                    .id(row.id)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == Self.scheme, let host = url.host(), let uuid = UInt(host) else {
                    return .discarded
                }
                session.selectMove(uuid: uuid)
                return .handled
            })
            // A move deep in a variation brings its row into view
            .onChange(of: session.currentMoveUUID, initial: true) { _, uuid in
                if let index = session.game.rowIndex[uuid] {
                    proxy.scrollTo(index)
                }
            }
        }
        .accessibilityIdentifier("moves")
    }

    static func link(for uuid: UInt) -> URL? {
        URL(string: "\(scheme)://\(uuid)")
    }
}

private struct MoveRowView: View {
    let row: FullMove
    let current: UInt
    let select: (UInt) -> Void

    private func moveButton(_ node: FEngineMoveNode?) -> some View {
        Group {
            if let node {
                Button { select(node.uuid) } label: {
                    let isCurrent = node.uuid == current
                    Text(node.name)
                        .fontWeight(isCurrent ? .bold : .regular)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .foregroundStyle(isCurrent ? Walnut.pillText : Walnut.textPrimary)
                        .background(isCurrent ? Walnut.pillBackground : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text("\u{2026}")
                    .foregroundStyle(Walnut.textSecondary)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func comment(_ text: String) -> some View {
        Text(text)
            .italic()
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func variation(_ tokens: [MoveToken]) -> AttributedString {
        var result = AttributedString()
        var afterOpen = true
        for token in tokens {
            var piece: AttributedString
            switch token {
            case .move(let label, let uuid):
                piece = AttributedString(label)
                piece.link = MoveListView.link(for: uuid)
                if uuid == current {
                    piece.font = .footnote.bold()
                    piece.foregroundColor = Walnut.pillText
                    piece.backgroundColor = Walnut.pillBackground
                }
            case .comment(let text):
                piece = AttributedString(text)
                piece.font = .footnote.italic()
            case .open:
                piece = AttributedString("(")
            case .close:
                piece = AttributedString(")")
            }
            if !afterOpen, token != .close {
                result += AttributedString(" ")
            }
            result += piece
            afterOpen = token == .open
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text("\(row.number).")
                    .foregroundStyle(Walnut.textSecondary)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
                moveButton(row.white)
                moveButton(row.black)
            }
            if !row.whiteComment.isEmpty {
                comment(row.whiteComment)
            }
            if !row.blackComment.isEmpty {
                comment(row.blackComment)
            }
            ForEach(row.variations.indices, id: \.self) { index in
                Text(variation(row.variations[index]))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview("Short game") {
    PreviewScenarios.moveListShortGame.view()
}

#Preview("Variations and comments") {
    PreviewScenarios.moveListVariationsAndComments.view()
}

#Preview("Card") {
    PreviewScenarios.moveListCard.view()
}
#endif
