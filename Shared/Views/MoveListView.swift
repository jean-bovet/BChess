//
//  MoveListView.swift
//  BChess
//
//  The moves of the game as a score sheet: one row per move number, with comments and variations.
//

import SwiftUI

struct MoveListView: View {

    let session: GameSession

    private static let scheme = "bchess-move"

    var body: some View {
        ScrollViewReader { proxy in
            List(session.game.rows) { row in
                MoveRowView(row: row, current: session.currentMoveUUID, select: { session.selectMove(uuid: $0) })
                    .id(row.id)
            }
            .listStyle(.plain)
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
                    Text(node.name)
                        .fontWeight(node.uuid == current ? .bold : .regular)
                        .underline(node.uuid == current)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text("\u{2026}")
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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

#Preview("Short game") {
    MoveListView(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nc6 *")))
}

#Preview("Variations and comments") {
    MoveListView(session: GameSession(state: GameState(
        pgn: "1. e4 {King's pawn} e5 (1... c5 {Sicilian} 2. Nf3 (2. c3 {Alapin}) d6) 2. Nf3 Nc6 3. Bb5 *")))
}
