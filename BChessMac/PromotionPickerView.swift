//
//  PromotionPickerView.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/28/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class PromotionPickerView: NSView {

    var borderView: NSView? = nil
    
    var pieces = [ "" ]
    
    override var tag: Int {
        return 1
    }
    
    override func layout() {
        super.layout()

        let width = floor((bounds.size.width - 2) / CGFloat(pieces.count))
        let height = bounds.size.height - 2

        let size = min(width, height)
        let verticalOffset = round((height - size) / 2)
        
        if borderView == nil {
            borderView = NSView()
            if let borderView = borderView {
                borderView.wantsLayer = true
                borderView.layer?.borderColor = NSColor.black.cgColor
                borderView.layer?.borderWidth = 1
                addSubview(borderView)
            }
        }
        borderView!.frame = NSMakeRect(0, verticalOffset, bounds.size.width, size + 2)
        
//        var blackSquare = true
        
//        for index in 0..<pieces.count {
//            let frame = NSMakeRect(CGFloat(index) * size + 1, verticalOffset + 1, size, size)
//
//            let square = boardSquareView(rank: 0, file: index, blackSquare: blackSquare)
//            square.frame = frame
//
//            let piece = pieceSquareView(rank: 0, file: index, action: #selector(pieceSelected(sender:)))
//            piece.image = image(forPiece: pieces[index])
//            piece.frame = frame
//
//            blackSquare = !blackSquare
//        }
    }
    
    @objc func pieceSelected(sender: NSGestureRecognizer) {
//        if let pickerView = sender.view as? PieceView {
//            NSApp.mainWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse(rawValue: pickerView.file))
//        }
    }
}
