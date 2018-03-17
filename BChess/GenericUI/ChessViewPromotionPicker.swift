//
//  ChessViewPromotionPicker.swift
//  BChess
//
//  Created by Jean Bovet on 3/11/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

typealias PromotionCallback = (String?) -> Void

class ChessViewPromotionPicker {
    
    class PromotionView: View {
        
        override init(frame frameRect: Rect) {
            super.init(frame: frameRect)
            backgroundColor = Color.lightGray
        }
        
        required init?(coder decoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    let layouter: ChessViewLayouter
    let factory: ChessViewFactory
    let parent: View
    let promotionView: PromotionView
    
    var callback: PromotionCallback?
    
    init(layouter: ChessViewLayouter, factory: ChessViewFactory, parent: View) {
        self.layouter = layouter
        self.factory = factory
        self.parent = parent
        
        promotionView = PromotionView(frame: parent.bounds)
        promotionView.backgroundColor = Color.lightGray
        
        let gesture = TapGestureRecognizer(target: self, action: #selector(backgroundTapped(gesture:)))
        promotionView.addGestureRecognizer(gesture)
    }
    
    func choose(isWhite: Bool, callback: @escaping PromotionCallback) {
        let pieces = isWhite ? [ "Q", "R", "B", "N" ] : [ "q", "r", "b", "n" ]

        self.callback = callback
        promotionView.frame = parent.bounds
        parent.addSubview(promotionView)

        layouter.layoutPromotion(pieces: pieces.count) { index, frame in
            let pieceName = pieces[index]
            let pieceView = factory.pieceView(forName: pieceName)
            pieceView.frame = frame
            pieceView.backgroundColor = Color.white
            promotionView.addSubview(pieceView)

            let gesture = TapGestureRecognizer(target: self, action: #selector(pieceTapped(gesture:)))
            pieceView.addGestureRecognizer(gesture)
        }
    }
    
    @objc func pieceTapped(gesture: TapGestureRecognizer) {
        promotionView.removeFromSuperview()
        
        guard let pieceView = gesture.view as? PieceImageView else {
            return
        }
        
        callback?(pieceView.name)
    }
    
    @objc func backgroundTapped(gesture: TapGestureRecognizer) {
        promotionView.removeFromSuperview()
        callback?(nil)
    }
    
}
