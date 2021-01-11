//
//  SquareView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct SquareView: View {
        
    let piece: Piece?
    
    var body: some View {
        if let imageName = piece?.imageName {
            Image(imageName).resizable()
        } else {
            // The contentShape() is needed to define the hit
            // testing area because otherwise with opacity(0),
            // the first Rectangle is not tappable at all.
            Rectangle().opacity(0).contentShape(Rectangle())
        }
    }
    
}
