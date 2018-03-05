//
//  ChessViewLayouter.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

class ChessViewLayouter {
    
    var viewSize: CGSize = CGSize(width: 0, height: 0) {
        didSet {
            update()
        }
    }
    
    var squareSize: CGFloat = 0
    var squareHorizontalOffset: CGFloat = 0
    var squareVerticalOffset: CGFloat = 0
    
    func update() {
        let width = round(viewSize.width/8)
        let height = round(viewSize.height/8)
        
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
        let rect = CGRect(x: squareHorizontalOffset + CGFloat(file) * squareSize, y: squareVerticalOffset + CGFloat(7 - rank) * squareSize, width: squareSize, height: squareSize)
        callback(rect)
    }
    
}
