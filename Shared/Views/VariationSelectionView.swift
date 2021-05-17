//
//  VariationSelectionView.swift
//  BChess
//
//  Created by Jean Bovet on 5/15/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct VariationSelectionView: View {
    
    @Binding var document: ChessDocument

    func variations(from: [FEngineMoveNode]) -> [Variation] {
        var variations = [Variation]()
        for (i, v) in from.enumerated() {
            variations.append(Variation(index: i,
                             from: Position(rank: Int(v.fromRank), file: Int(v.fromFile)),
                             to: Position(rank: Int(v.toRank), file: Int(v.toFile)),
                             label: "Nxe2"))
        }
        return variations
    }
        
    var body: some View {
        if document.variations.show {
            GeometryReader { geometry in
                let minSize: CGFloat = min(geometry.size.width, geometry.size.height)
                let squareSize: CGFloat = minSize / CGFloat(numberOfSquares)
                let xOffset: CGFloat = (geometry.size.width - minSize) / 2 + squareSize / 2
                let yOffset: CGFloat = (geometry.size.height - minSize) / 2 + squareSize / 2
                
                ForEach(variations(from: document.variations.variations)) { v in
                    let x1 = CGFloat(v.from.file.actual(rotated: document.rotated)) * squareSize + xOffset
                    let y1 = CGFloat(7 - v.from.rank.actual(rotated: document.rotated)) * squareSize + yOffset
                    let x2 = CGFloat(v.to.file.actual(rotated: document.rotated)) * squareSize + xOffset
                    let y2 = CGFloat(7 - v.to.rank.actual(rotated: document.rotated)) * squareSize + yOffset

                    Rectangle()
                        .background(Color.blue)
                        .opacity(0.2)
                        .frame(width: squareSize, height: squareSize, alignment: .center)
                        .offset(x: x2 - squareSize/2, y: y2 - squareSize/2)
                        .onTapGesture {
                            document.variations.selectedVariationIndex = v.index
                            Actions(document: $document).move(to: .forward)
                        }

                    Path { path in
                        path.move(to: CGPoint(x: x1, y: y1))
                        path.addLine(to: CGPoint(x: x2, y: y2))
                    }
                    .stroke(Color.blue, lineWidth: 10)
                }
            }
        }
    }
}

struct VariationSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let doc = ChessDocument()
            ZStack {
                BoardView(document: .constant(doc))
                PiecesView(document: .constant(doc))
                VariationSelectionView(document: .constant(doc))
            }
        }
    }
}
