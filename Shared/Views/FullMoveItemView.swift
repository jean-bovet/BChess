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
    
    var body: some View {
        if let wm = item.whiteMove, let bm = item.blackMove {
            Text("\(wm.moveNumber). \(wm.name)") +
            Text(item.whiteComment)
                .italic() +
            Text("\(bm.name)") +
            Text(item.blackComment)
                .italic()
        } else if let wm = item.whiteMove {
            Text("\(wm.moveNumber). \(wm.name)") +
            Text(item.whiteComment)
                .italic()
        } else if let bm = item.blackMove {
            Text("\(bm.moveNumber)... \(bm.name)") +
            Text(item.whiteComment)
                .italic()
        } else {
            Text("")
        }
    }
}

struct FullMoveItemView_Previews: PreviewProvider {
    static var previews: some View {
        FullMoveItemView(item: FullMoveItem())
    }
}
