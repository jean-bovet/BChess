//
//  SelectionModifier.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// Tints the selected square, and marks where its piece can go: a dot on an empty square, a ring where
/// it captures.
struct SelectionModifier: ViewModifier {
    
    let rank: Int
    let file: Int
    let selection: Selection
    @AppStorage(AppSettings.showLegalMovesKey) private var showLegalMoves = AppSettings.showLegalMovesDefault

    func body(content: Content) -> some View {
        content
            .overlay {
                if selection.selected(rank: rank, file: file) {
                    Walnut.lastMove
                } else if showLegalMoves, let move = selection.possibleMove(rank, file) {
                    GeometryReader { geometry in
                        let side = min(geometry.size.width, geometry.size.height)
                        Group {
                            if move.isCapture {
                                Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: side * 0.09)
                                    .frame(width: side * 0.9, height: side * 0.9)
                            } else {
                                Circle().fill(Color.black.opacity(0.25))
                                    .frame(width: side * 0.3, height: side * 0.3)
                            }
                        }
                        .frame(width: side, height: side)
                    }
                }
            }
    }
}
