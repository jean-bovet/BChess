//
//  PromotionView.swift
//  BChess
//
//  Created by Jean Bovet on 1/15/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct PromotionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var promotion: Promotion
    let callback: ((String) -> Void)?
    
    func pieceNames() -> [String] {
        if promotion.isWhite {
            return [ "R", "N", "B", "Q" ]
        } else {
            return [ "r", "n", "b", "q" ]
        }
    }
    
    func limitPieceSize() -> Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        VStack {
            HStack {
                ForEach(pieceNames(), id: \.self) { name in
                    Image(Piece.pieceImageNames[name]!)
                        .resizable()
                        .aspectRatio(1.0, contentMode: .fit)
                        .if(limitPieceSize()) { view in
                            view.frame(width: 100, height: 100, alignment: .center)
                        }
                        .padding()
                        .onTapGesture() {
                            callback?(name)
                            dismiss()
                        }
                }
            }
            Button("Cancel") {
                dismiss()
            }.padding()
        }
    }
}

#Preview {
    PromotionView(promotion: .constant(Promotion(move: FEngineMove(), isWhite: true)), callback: nil)
}
