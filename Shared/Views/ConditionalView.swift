//
//  ConditionalView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, content: (Self) -> Content) -> some View {
        if condition {
            content(self)
        }
        else {
            self
        }
    }
    
    @ViewBuilder
    func hide(_ condition: Bool, remove: Bool = false) -> some View {
        if condition {
            if !remove {
                self.hidden()
            }
        }
        else {
            self
        }
    }
}
