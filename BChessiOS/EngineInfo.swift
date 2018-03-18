//
//  EngineInfo.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/3/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

class EngineInfo {
    
    let numberFormatter = NumberFormatter()
    let valueFormatter = NumberFormatter()

    init() {
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = ","
        numberFormatter.usesGroupingSeparator = true
        
        valueFormatter.numberStyle = .decimal
        valueFormatter.maximumFractionDigits = 2
        valueFormatter.groupingSeparator = ","
        valueFormatter.usesGroupingSeparator = true
    }
    
    func boldText(text: String) -> NSAttributedString {
        return NSAttributedString(string: text,
                                  attributes: [
                                    NSAttributedStringKey.font : UIFont.boldSystemFont(ofSize: 12),
                                    NSAttributedStringKey.foregroundColor : UIColor.black
            ])
    }
    
    func regularText(text: String) -> NSAttributedString {
        return NSAttributedString(string: text,
                                  attributes: [
                                    NSAttributedStringKey.font : UIFont.systemFont(ofSize: 12),
                                    NSAttributedStringKey.foregroundColor : UIColor.black
            ])
    }
    
    func information(forInfo info: FEngineInfo?, engine: FEngine) -> NSAttributedString {
        let infoString = NSMutableAttributedString()
        
        let infoColorToPlay = engine.isWhite() ? "White to play" : "Black to play"
        infoString.append(boldText(text: infoColorToPlay))
        infoString.append(regularText(text: "\n"))

        if let opening = info?.opening {
            infoString.append(regularText(text: opening))
            infoString.append(regularText(text: "\n"))
        } else if let info = info {
            let value: String
            if info.mat {
                value = "#"
            } else {
                value = valueFormatter.string(from: NSNumber(value: Double(info.value) / 100.0))!
            }
            let line = info.bestLine(false)
            infoString.append(regularText(text: "[\(value)] \(line)"))
            infoString.append(regularText(text: "\n"))
            
            let nodes = numberFormatter.string(from: NSNumber(value: info.nodeEvaluated))!
            let speed = numberFormatter.string(from: NSNumber(value: info.movesPerSecond))!
            
            infoString.append(regularText(text: "Depth \(info.depth)/\(info.quiescenceDepth) with \(nodes) nodes at \(speed) n/s"))
            
        }
        return infoString
    }

}
