//
//  ChessViewLayouter.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import CoreGraphics

extension UInt {
    func actualRank(_ flipped: Bool) -> UInt {
        var _value = self
        if flipped {
            _value = 7 - _value
        }
        if #available(iOS 10.0, *) {
            _value = 7 - _value
        }
        return _value
    }
    
    func actualFile(_ flipped: Bool) -> UInt {
        var _value = self
        if flipped {
            _value = 7 - _value
        }
        return _value
    }
    
}

class ChessViewLayouter {
    
    var viewSize: CGSize = CGSize(width: 0, height: 0) {
        didSet {
            update()
        }
    }
    
    var boardFrame: CGRect {
        return CGRect(x: squareHorizontalOffset, y: squareVerticalOffset, width: squareSize*8, height: squareSize*8)
    }
    
    // True if the board needs to be flipped to show black
    // at the bottom and white on top (used when the player
    // plays black).
    var flipped = false
    
    let fontSize: CGFloat = 10
    let margin: CGFloat = 16
    
    var squareSize: CGFloat = 0
    var squareHorizontalOffset: CGFloat = 0
    var squareVerticalOffset: CGFloat = 0
    
    func update() {
        let width = round((viewSize.width-2*margin)/8)
        let height = round((viewSize.height-2*margin)/8)
        
        squareSize = min(width, height)
        
        squareHorizontalOffset = round((viewSize.width - CGFloat(8*squareSize))/2)
        squareVerticalOffset = round((viewSize.height - CGFloat(8*squareSize))/2)
    }
    
    func coordinate(location: CGPoint) -> (UInt, UInt)? {
        var value: (UInt, UInt)? = nil
        for rank: UInt in 0...7 {
            for file: UInt in 0...7 {
                layout(file: file, rank: rank, callback: { (rect) in
                    if rect.contains(location) {
                        value = (file, rank)
                    }
                })
            }
        }
        return value
    }
    
    func layout(file: UInt, rank: UInt, callback: (CGRect) -> Void) {
        let rect = CGRect(x: squareHorizontalOffset + CGFloat(file.actualFile(flipped)) * squareSize,
                          y: squareVerticalOffset + CGFloat(rank.actualRank(flipped)) * squareSize,
                          width: squareSize,
                          height: squareSize)
        callback(rect)
    }
    
    func layoutPromotion(pieces: Int, callback: (Int, CGRect) -> Void) {
        let pieceSize = squareSize * 2
        
        let width = pieceSize * CGFloat(pieces)
        let height = pieceSize
        
        var frameCursor = CGRect(x: (viewSize.width-width)/2, y: (viewSize.height-height)/2, width: pieceSize, height: pieceSize)
        for pieceIndex in 0..<pieces {
            callback(pieceIndex, frameCursor)
            frameCursor = frameCursor.offsetBy(dx: pieceSize, dy: 0)
        }
    }
    
}
