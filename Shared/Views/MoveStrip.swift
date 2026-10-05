//
//  MoveStrip.swift
//  BChess
//
//  The last few moves on one line, with a button for the whole list.
//

import SwiftUI

struct MoveStrip: View {

    let session: GameSession
    let showAll: () -> Void

    var body: some View {
        let moves = session.game.recentMoves(current: session.currentMoveUUID)
        HStack {
            ScrollViewReader { proxy in
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(moves.enumerated()), id: \.offset) { _, token in
                        if case .move(let label, let uuid) = token {
                            Button(label) { session.selectMove(uuid: uuid) }
                                .buttonStyle(.plain)
                                .fontWeight(uuid == session.currentMoveUUID ? .bold : .regular)
                                .id(uuid)
                        }
                    }
                    if moves.isEmpty {
                        Text("No moves yet")
                            .foregroundStyle(.secondary)
                    }
                }
              }
              // The current move is the last one: keep it in view on a narrow screen
              .onChange(of: session.currentMoveUUID, initial: true) { _, uuid in
                  proxy.scrollTo(uuid, anchor: .trailing)
              }
            }
            Button(action: showAll) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                    if session.game.variationCount > 0 {
                        Text("\u{2442}\(session.game.variationCount)")
                    }
                }
            }
            .accessibilityLabel("All moves")
        }
        .font(.callout)
    }
}

#Preview("Start") {
    MoveStrip(session: GameSession(), showAll: {})
        .padding()
}

#Preview("Middle") {
    MoveStrip(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 *")), showAll: {})
        .padding()
}

#Preview("With variations") {
    MoveStrip(session: GameSession(state: GameState(pgn: "1. e4 e5 (1... c5) 2. Nf3 (2. c3) Nc6 *")), showAll: {})
        .padding()
}
