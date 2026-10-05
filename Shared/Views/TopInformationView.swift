//
//  TopInformationView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct ColorInformationView: View {

    let session: GameSession
    let isWhite: Bool
    
    var body: some View {
        HStack {
            if isWhite {
                Image(systemName: "arrowtriangle.right").hide(!session.isWhiteToMove)
                Text(Image(systemName: session.gameState.white.computer ? "cpu" : "person.fill"))
                Text("White")
            } else {
                Image(systemName: "arrowtriangle.right.fill").hide(session.isWhiteToMove)
                Text(Image(systemName: session.gameState.black.computer ? "cpu" : "person.fill"))
                Text("Black")
            }
            
            HStack(spacing: 0) {
                ForEach(session.capturedPieces(white: isWhite), id: \.self) { piece in
                    SquareView(piece: Piece(name: piece, file: 0, rank: 0))
                        .frame(width: 24, height: 24)
                }
            }
            
            if let points = session.materialPoints(white: isWhite) {
                Text(points)
            }
        }
    }
}

struct TopInformationView: View {
    
    let session: GameSession
                
    var body: some View {
        VStack(alignment: .leading) {
            ColorInformationView(session: session, isWhite: true)
            ColorInformationView(session: session, isWhite: false)
        }
    }
}

#Preview("Opening") {
    TopInformationView(session: GameSession(state: GameState(pgn: "1. e4 e5")))
}

#Preview("Captures") {
    TopInformationView(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 ")))
}

#Preview("Material") {
    TopInformationView(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 5. d4 exd4 6. Qxd4 Qxd4 7. Nd5 Nxd5 8. Bb5+ c6 9. Bxc6+ Nxc6 *")))
}
