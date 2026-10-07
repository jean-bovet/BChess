//
//  BoardView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// The 64 squares, with the last move and the selection on them.
struct BoardView: View {
    
    let session: GameSession

    func backgroundColor(rank: Int, file: Int) -> Color {
        if rank % 2 == 0 {
            return file % 2 == 0 ? Walnut.darkSquare : Walnut.lightSquare
        } else {
            return file % 2 == 0 ? Walnut.lightSquare : Walnut.darkSquare
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach((0...7).reversed(), id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach(0...7, id: \.self) { file in
                        let r = rank.actual(rotated: session.gameState.rotated)
                        let f = file.actual(rotated: session.gameState.rotated)
                        Rectangle()
                            .fill(backgroundColor(rank: r, file: f))
                            .modifier(LastMoveModifier(rank: r, file:f, session: session))
                            .modifier(SelectionModifier(rank: r, file: f, selection: session.selection))
                    }
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }
}

/// The walnut frame around the board: rounded, with a soft shadow, and the coordinates drawn in it.
/// The content is laid out in the square inside the frame. A ring around the frame shows the mode.
struct BoardFrame<Content: View>: View {
    let session: GameSession
    /// Yellow for analyze, green for train: the ring around the frame.
    var ring: Color?
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let thickness = side * Walnut.frameFraction
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Walnut.frame)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                    .overlay {
                        if let ring {
                            RoundedRectangle(cornerRadius: 10).strokeBorder(ring, lineWidth: 3).padding(-3)
                        }
                    }
                LabelsView(session: session)
                content
                    .padding(thickness)
            }
            .frame(width: side, height: side)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#if DEBUG
#Preview("Board") {
    PreviewScenarios.board.view()
}
#endif
