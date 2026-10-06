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
        HStack(spacing: 6) {
            ScrollViewReader { proxy in
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(moves.enumerated()), id: \.offset) { _, token in
                        if case .move(let label, let uuid) = token {
                            let isCurrent = uuid == session.currentMoveUUID
                            Button { session.selectMove(uuid: uuid) } label: {
                                Text(label)
                                    .fontWeight(isCurrent ? .bold : .regular)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, isCurrent ? 10 : 8)
                                    .currentMovePill(isCurrent)
                            }
                            .buttonStyle(.plain)
                            .id(uuid)
                        }
                    }
                    if moves.isEmpty {
                        Text("No moves yet")
                            .foregroundStyle(Walnut.textSecondary)
                    }
                }
                .frame(minWidth: 0, alignment: .trailing)
              }
              // The current move is the last one: keep it in view on a narrow screen
              .onChange(of: session.currentMoveUUID, initial: true) { _, uuid in
                  proxy.scrollTo(uuid, anchor: .trailing)
              }
            }
            Button(action: showAll) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                    Text("Moves")
                    if session.game.variationCount > 0 {
                        Text("\u{2442}\(session.game.variationCount)")
                    }
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 32)
                .foregroundStyle(Color.accentColor)
                .walnutCard(radius: 16)
            }
            .buttonStyle(.plain)
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

#Preview("Dark") {
    MoveStrip(session: GameSession(state: GameState(pgn: "1. e4 e5 (1... c5) 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 *")), showAll: {})
        .padding()
        .background(Walnut.background)
        .preferredColorScheme(.dark)
}
