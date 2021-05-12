//
//  FullMoveItemView.swift
//  BChess
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct FullMoveItemView: View {
    
    var item: FullMoveItem
    var currentMoveUUID: UInt
    
    func moveNameText(node: FEngineMoveNode) -> Text {
        if node.uuid == currentMoveUUID {
            return Text("\(node.name)")
                .bold()
                .underline()
        } else {
            return Text("\(node.name)")
        }
    }
    
    var body: some View {
        if let wm = item.whiteMove, let bm = item.blackMove {
            Text("\(wm.moveNumber). ") +
            moveNameText(node: wm) +
            Text(item.whiteComment)
                .italic() +
            moveNameText(node: bm) +
            Text(item.blackComment)
                .italic()
        } else if let wm = item.whiteMove {
            Text("\(wm.moveNumber). ") +
            moveNameText(node: wm) +
            Text(item.whiteComment)
                .italic()
        } else if let bm = item.blackMove {
            Text("\(bm.moveNumber)... ") +
            moveNameText(node: bm) +
            Text(item.whiteComment)
                .italic()
        } else {
            Text("")
        }
    }
}

struct FullMoveItemView_Previews: PreviewProvider {
    static var previews: some View {
        FullMoveItemView(item: FullMoveItem(), currentMoveUUID: 0)
    }
}
