//
//  BottomInformationView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct BottomInformationView: View {
    
    let document: ChessDocument

    let numberFormatter = NumberFormatter()
    let valueFormatter = NumberFormatter()

    init(document: ChessDocument) {
        self.document = document
        
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = ","
        numberFormatter.usesGroupingSeparator = true
        
        valueFormatter.numberStyle = .decimal
        valueFormatter.minimumFractionDigits = 2
        valueFormatter.maximumFractionDigits = 2
        valueFormatter.groupingSeparator = ","
        valueFormatter.usesGroupingSeparator = true
    }

    func value() -> String {
        guard let info = document.info else {
            return " "
        }
        
        let value: String
        if info.mat {
            value = "#"
        } else {
            value = valueFormatter.string(from: NSNumber(value: Double(info.value) / 100.0))!
        }
        let line = info.bestLine(false)
        return "\(value) \(line)"
    }
    
    func speed() -> String {
        guard let info = document.info else {
            return " "
        }

        let nodes = numberFormatter.string(from: NSNumber(value: info.nodeEvaluated))!
        let speed = numberFormatter.string(from: NSNumber(value: info.movesPerSecond))!
        
        var text = "Depth \(info.depth)"
        if info.quiescenceDepth > 0 && info.quiescenceDepth != info.depth {
            text += "/\(info.quiescenceDepth)"
        }
        text += " with \(nodes) nodes at \(speed) n/s"
        return text
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if let opening = document.info?.opening {
                Text(opening)
            } else {
                Text(value())
                Text(speed())
            }
            Text(document.engine.pgnFormattedForDisplay())
        }
    }
}

struct BottomInformationView_Previews: PreviewProvider {
    static var previews: some View {
        let doc = ChessDocument(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *")
        BottomInformationView(document: doc)
    }
}
