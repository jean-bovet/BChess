//
//  BottomInformationView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct InformationView: View {
    
    let session: GameSession

    let numberFormatter = NumberFormatter()
    let valueFormatter = NumberFormatter()

    init(session: GameSession) {
        self.session = session
        
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
        guard let info = session.info else {
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
        guard let info = session.info else {
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
                Text(session.games[session.currentGameIndex].name)
            }
            
            if let opening = session.openingName {
                HStack {
                    Image(systemName: "book")
                    Text(opening)
                }
            }
            
            List(session.game.moves, children: \FullMove.children) { item in
                FullMoveView(item: item, currentMoveUUID: session.currentMoveUUID)
                    .onTapGesture {
                        session.selectMove(uuid: UInt(item.id)!)
                    }
            }
            .listStyle(.plain)

            if session.mode.value == .play && session.info != nil {
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

#Preview("Short game") {
    InformationView(session: GameSession(state: GameState(pgn: "1. e4 e5 *")))
}

#Preview("Longer game") {
    InformationView(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *")))
}
