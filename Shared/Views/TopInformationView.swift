//
//  TopInformationView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct ColorInformationView: View {

    @Binding var document: ChessDocument
    let isWhite: Bool
    
    func capturedPieces() -> [String] {
        return document.engine.allMoves()
            .filter { $0.isCapture }
            .filter { $0.isWhite == isWhite }
            .compactMap { $0.capturedPiece as String? }
            .sorted()
    }

    func materialPoints() -> String? {
        let captures = document.engine.allMoves()
            .filter { $0.isCapture }
        var points = 0
        for move in captures {
            switch move.capturedPiece {
            case "P":
                points += 1
            case "p":
                points -= 1
            case "N", "B":
                points += 3
            case "n", "b":
                points -= 3
            case "R":
                points += 5
            case "r":
                points -= 5
            case "Q":
                points += 9
            case "q":
                points -= 9
            default:
                break
            }
        }
        
        if isWhite && points < 0 {
            return "+\(abs(points))"
        }
        if !isWhite && points > 0 {
            return "+\(abs(points))"
        }

        return nil
    }
    
    var body: some View {
        HStack {
            if isWhite {
                Image(systemName: "arrowtriangle.right").hide(!document.engine.isWhite())
                Text(Image(systemName: document.whitePlayer.computer ? "cpu" : "person.fill"))
                Text("White")
            } else {
                Image(systemName: "arrowtriangle.right.fill").hide(document.engine.isWhite())
                Text(Image(systemName: document.blackPlayer.computer ? "cpu" : "person.fill"))
                Text("Black")
            }
            
            HStack(spacing: 0) {
                ForEach(capturedPieces(), id: \.self) { piece in
                    SquareView(piece: Piece(name: piece, file: 0, rank: 0))
                        .frame(width: 24, height: 24)
                }
            }
            
            if let points = materialPoints() {
                Text(points)
            }
        }
    }
}

struct TopInformationView: View {
    
    @Binding var document: ChessDocument
                
    var body: some View {
        VStack(alignment: .leading) {
            ColorInformationView(document: $document, isWhite: true)
            ColorInformationView(document: $document, isWhite: false)
        }
    }
}

struct TopInformationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let doc = try! ChessDocument(pgn: "1. e4 e5")
            TopInformationView(document: .constant(doc))
        }
        Group {
            let doc = try! ChessDocument(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 ")
            TopInformationView(document: .constant(doc))
        }
        Group {
            let doc = try! ChessDocument(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 5. d4 exd4 6. Qxd4 Qxd4 7. Nd5 Nxd5 8. Bb5+ c6 9. Bxc6+ Nxc6 *")
            TopInformationView(document: .constant(doc))
        }
    }
}
