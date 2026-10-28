//
//  MoveListView.swift
//  BChess
//
//  The moves of the game as a score sheet: one row per move number, with comments and variations.
//

import SwiftUI

struct MoveListView: View {

    let session: GameSession
    /// The wide layout's card: a surface with a "Moves" caption above the rows.
    var card = false

    private static let scheme = "bchess-move"

    var body: some View {
        if card {
            VStack(alignment: .leading, spacing: 0) {
                Text("Moves")
                    .textCase(.uppercase)
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

struct MoveRowView: View {
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
                Text(verbatim: "\u{2026}")
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

    /// One variation as a paragraph: "(8…O-O 9. d4 {a comment})". The whole line is a left-to-right isolate, so its base
    /// direction never follows the window's (a right-to-left window would set the parentheses and the numbers on the wrong
    /// side of the moves), and each comment is a first-strong isolate, so a Hebrew or Arabic comment reads right to left
    /// and an English one left to right inside it. Display only: the tokens, and so the game file, are untouched. A layout
    /// pin on the `Text` would not do either job (it does not set the bidi base direction).
    static func variationText(_ tokens: [MoveToken], current: UInt) -> AttributedString {
        var result = AttributedString("\u{2066}")
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
                piece = AttributedString("\u{2068}\(text)\u{2069}")
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
        result += AttributedString("\u{2069}")
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(verbatim: "\(row.number).")
                    .foregroundStyle(Walnut.textSecondary)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
                moveButton(row.white)
                moveButton(row.black)
            }
            // "8. c3 c6", the number column on the left, in every language: the notation reads left to right
            .environment(\.layoutDirection, .leftToRight)
            if !row.whiteComment.isEmpty {
                comment(row.whiteComment)
            }
            if !row.blackComment.isEmpty {
                comment(row.blackComment)
            }
            ForEach(row.variations.indices, id: \.self) { index in
                Text(Self.variationText(row.variations[index], current: current))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
