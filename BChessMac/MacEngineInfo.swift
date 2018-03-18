//
//  ChessView.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/11/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class MacEngineInfo {
    
    let numberFormatter = NumberFormatter()
    
    init() {
        numberFormatter.numberStyle = .decimal
        numberFormatter.thousandSeparator = ","
        numberFormatter.hasThousandSeparators = true
    }
        
    func boldText(text: String) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [ NSAttributedStringKey.font : NSFont.boldSystemFont(ofSize: 12)])
    }
    
    func regularText(text: String) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [ NSAttributedStringKey.font : NSFont.systemFont(ofSize: 12)])
    }

    func attributedString(forInfo info: FEngineInfo?, engine: FEngine) -> NSAttributedString {
        let infoColorToPlay = engine.isWhite() ? "White" : "Black"

        if let info = info {
            let infoString = NSMutableAttributedString()
            infoString.append(boldText(text: "Side to play: "))
            infoString.append(regularText(text: infoColorToPlay))
            infoString.append(regularText(text: "\n"))

            if let opening = info.opening {
                infoString.append(boldText(text: "Opening: "))
                infoString.append(regularText(text: opening))
                infoString.append(regularText(text: "\n"))
                return infoString
            } else {
                infoString.append(boldText(text: "Value: "))
                let infoValue: String
                if info.mat {
                    infoValue = "#"
                } else {
                    infoValue = String(info.value)
                }
                infoString.append(regularText(text: infoValue))
                infoString.append(regularText(text: "\n"))
                
                infoString.append(boldText(text: "Line: "))
                let lineInfo = info.bestLine(false)
                infoString.append(regularText(text: lineInfo))
                infoString.append(regularText(text: "\n"))
                
                infoString.append(boldText(text: "Depth: "))
                infoString.append(regularText(text: "\(info.depth)/\(info.quiescenceDepth)"))
                infoString.append(regularText(text: "\n"))
                
                infoString.append(boldText(text: "Nodes: "))
                let infoNodes = self.numberFormatter.string(from: NSNumber(value: info.nodeEvaluated))!
                infoString.append(regularText(text: infoNodes))
                infoString.append(regularText(text: "\n"))
                
                infoString.append(boldText(text: "Speed: "))
                let infoSpeed = self.numberFormatter.string(from: NSNumber(value: info.movesPerSecond))!
                infoString.append(regularText(text: "\(infoSpeed) n/s"))
            }
            return infoString
        } else {
            let infoString = NSMutableAttributedString()
            infoString.append(boldText(text: "Side to play: "))
            infoString.append(regularText(text: infoColorToPlay))
            return infoString
        }
    }
    
}
