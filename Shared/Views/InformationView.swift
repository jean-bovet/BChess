//
//  BottomInformationView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct InformationView: View {
    
    @Binding var document: ChessDocument

    let numberFormatter = NumberFormatter()
    let valueFormatter = NumberFormatter()

    init(document: Binding<ChessDocument>) {
        self._document = document
        
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkerboard.rectangle")
                Text(document.engine.games[Int(document.currentGameIndex)].name)
            }
            
            if let opening = document.engine.openingName() {
                HStack {
                    Image(systemName: "book")
                    Text(opening)
                }
            }
            
            List(document.game.moves, children: \FullMove.children) { item in
                FullMoveView(item: item, currentMoveUUID: document.engine.currentMoveNodeUUID)
                    .onTapGesture {
                        document.currentMoveIndex = UInt(item.id)!
                    }
            }
            
            Spacer()
            
            if document.mode.value == .play {
                HStack() {
                    Image(systemName: "cpu")
                    Text(value())
                }
                HStack {
                    Text(Image(systemName: "speedometer"))
                    Text(speed())
                }
            }
        }
    }
}

struct BottomInformationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let doc = try! ChessDocument(pgn: "1. e4 e5 *")
            InformationView(document: .constant(doc))
        }
        Group {
            let doc = try! ChessDocument(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *")
            InformationView(document: .constant(doc))
        }
    }
}
