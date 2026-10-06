//
//  ContentView.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// The game screen: the board between the two players, the status of the game and, when it is on, the
/// engine's opinion. Tall (iPhone) it ends with the last moves; wide (Mac, iPad landscape) it puts the
/// moves, the status and the engine in a sidebar. The shells around it add the title, the menus and the sheets.
struct ContentView: View {
    let session: GameSession

    @AppStorage("showEngine") private var showEngine = false
    @AppStorage("showEngineStatistics") private var showStatistics = false

    @State private var showAllMoves = false

    /// The sidebar sits beside the board when there is more width than height, and the status below it
    /// otherwise (iPhone in portrait). The Mac is always wide.
    @State private var isWide = true

    private var topIsWhite: Bool {
        session.gameState.rotated
    }

    private var ring: Color? {
        switch session.mode.value {
        case .analyze: return .yellow
        case .train: return .green
        case .play: return nil
        }
    }

    private var board: some View {
        BoardFrame(session: session, ring: ring) {
            ZStack {
                BoardView(session: session)
                PiecesView(session: session)
                VariationSelectionView(session: session)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board")
        .accessibilityValue(session.fen)
        // The evaluation bar stands left of the board, as tall as its frame
        .padding(.leading, evaluation == nil ? 0 : EvaluationBar.width + 6)
        .overlay(alignment: .leading) {
            if let evaluation {
                EvaluationBar(verdict: evaluation, rotated: session.gameState.rotated)
            }
        }
    }

    /// The verdict the bar shows: only while the engine is on and has one.
    private var evaluation: Verdict? {
        showEngine ? EngineView.verdict(of: session) : nil
    }

    private var boardColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            PlayerRow(session: session, isWhite: topIsWhite)
            board
            PlayerRow(session: session, isWhite: !topIsWhite)
        }
    }

    private var engine: EngineView? {
        guard showEngine else {
            return nil
        }
        #if os(macOS)
        return EngineView.make(session: session, showStatistics: showStatistics, stacked: isWide)
        #else
        return EngineView.make(session: session, showStatistics: false, stacked: isWide)
        #endif
    }

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top) {
                    // The board gets its full size first; the sidebar takes what is left
                    boardColumn
                        .layoutPriority(1)
                    VStack(alignment: .leading, spacing: 12) {
                        MoveListView(session: session, card: true)
                        StatusLine(session: session)
                            .padding(.horizontal, 4)
                        engine
                    }
                    .frame(width: 320)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    boardColumn
                    StatusLine(session: session)
                        .padding(.horizontal, 2)
                    engine
                    MoveStrip(session: session) { showAllMoves = true }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding()
        .background(Walnut.background.ignoresSafeArea())
        #if os(iOS)
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height
        } action: { wide in
            isWide = wide
        }
        #endif
        .onChange(of: showEngine, initial: true) { _, shown in
            session.showsEngine = shown
        }
        .onAppear {
            // The engine waits for the move animation before it replies
            session.animate = { change, completion in
                withAnimation(.default, completionCriteria: .logicallyComplete, change, completion: completion)
            }
        }
        .sheet(isPresented: $showAllMoves) {
            NavigationStack {
                MoveListView(session: session)
                    .background(Walnut.background)
                    .navigationTitle("Moves")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showAllMoves = false }
                        }
                    }
            }
        }
    }
}

#Preview("Tall") {
    ContentView(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nc6 3. Bb5 *")))
        .frame(width: 390, height: 800)
}

#Preview("Wide") {
    ContentView(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nc6 3. Bb5 *")))
        .frame(width: 900, height: 600)
}

#Preview("Tall, dark") {
    ContentView(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nc6 3. Bb5 *")))
        .frame(width: 390, height: 800)
        .preferredColorScheme(.dark)
}

#Preview("Wide, dark") {
    ContentView(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nc6 3. Bb5 *")))
        .frame(width: 900, height: 600)
        .preferredColorScheme(.dark)
}

#Preview("Analyze") {
    ContentView(session: GameSession(mode: GameMode(value: .analyze)))
}

#Preview("Train") {
    ContentView(session: GameSession(mode: GameMode(value: .train)))
}

#Preview("Rotated") {
    ContentView(session: GameSession(state: GameState(pgn: "*", rotated: true)))
}
