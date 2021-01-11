//
//  SelectionModifier.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct SelectionModifier: ViewModifier {
    
    let rank: Int
    let file: Int
    let selection: Selection

    func body(content: Content) -> some View {
        return content.if(selection.selected(rank: rank, file: file) || selection.isPossibleMove(rank, file)) { view in
                view.overlay(Color.yellow.opacity(0.8))
            }
    }
}
