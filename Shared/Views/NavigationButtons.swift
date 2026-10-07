//
//  NavigationButtons.swift
//  BChess
//
//  Back and Forward through the game. A tap steps; touch and hold (click and hold on the Mac) opens a
//  menu with the jump to the start or the end.
//

import SwiftUI

struct NavigationButtons: View {

    let session: GameSession

    private func go(_ direction: Direction) {
        withAnimation { session.move(to: direction) }
    }

    var body: some View {
        Menu {
            Button("Start of Game", systemImage: "backward.end") { go(.start) }
                .disabled(!session.canMove(to: .start))
        } label: {
            Label("Back", systemImage: "chevron.backward")
        } primaryAction: {
            go(.backward)
        }
        .menuIndicator(.hidden)
        .disabled(!session.canMove(to: .backward))

        Menu {
            Button("End of Game", systemImage: "forward.end") { go(.end) }
                .disabled(!session.canMove(to: .end))
        } label: {
            Label("Forward", systemImage: "chevron.forward")
        } primaryAction: {
            go(.forward)
        }
        .menuIndicator(.hidden)
        .disabled(!session.canMove(to: .forward))
    }
}

#if DEBUG
#Preview("Navigation") {
    PreviewScenarios.navigationButtons.view()
}
#endif
