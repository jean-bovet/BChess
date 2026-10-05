//
//  AnalyzeActionsView.swift
//  BChess
//
//  Created by Jean Bovet on 4/26/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct NavigationActionView: View {
    
    let session: GameSession
    
    var body: some View {
        HStack() {
            if session.mode.value != .play {
                Button(action: {
                    session.analyzeReset()
                }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                }
            }
            
            Button(action: {
                session.move(to: .start)
            }) {
                Image(systemName: "backward.end.fill")
            }.disabled(!session.canMove(to: .start))

            Button(action: {
                session.move(to: .backward)
            }) {
                Image(systemName: "arrowtriangle.backward.fill")
            }.disabled(!session.canMove(to: .backward))

            Button(action: {
                session.move(to: .forward)
            }) {
                Image(systemName: "arrowtriangle.forward.fill")
            }.disabled(!session.canMove(to: .forward))

            Button(action: {
                session.move(to: .end)
            }) {
                Image(systemName: "forward.end.fill")
            }.disabled(!session.canMove(to: .end))
        }
    }
}

#Preview {
    NavigationActionView(session: GameSession())
}
