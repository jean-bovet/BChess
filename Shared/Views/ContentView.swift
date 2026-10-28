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

    /// A test-only source of the fold's regions (the gallery's fixed windows carry none). Nil in the app, which
    /// asks the display; only the source is replaced, never the layout that reads it.
    let foldRegionsOverride: [FoldRegion]?

    init(session: GameSession, foldRegions: [FoldRegion]? = nil) {
        self.session = session
        self.foldRegionsOverride = foldRegions
    }

    @AppStorage("showEngine") private var showEngine = false
    @AppStorage("showEngineStatistics") private var showStatistics = false

    @State private var showAllMoves = false

    #if os(iOS)
    /// What the layout reads from its container: the size of the content (inside the padding) and the fold's
    /// regions in that same space. Nil until the first measure.
    @State private var geometry: FoldGeometry?
    #endif

    /// Where the layout stands: the rectangle the content may use, whether it is wide, and how it steps over a fold.
    private struct Placement {
        var size: CGSize
        var area: CGRect
        /// The sidebar sits beside the board when the usable area has more width than height, and the status below
        /// it otherwise (iPhone in portrait).
        var isWide: Bool
        var split: FoldSplit

        /// The distance from each edge of the content to the usable area.
        var insets: EdgeInsets {
            EdgeInsets(top: area.minY, leading: area.minX, bottom: size.height - area.maxY, trailing: size.width - area.maxX)
        }
    }

    private var placement: Placement? {
        #if os(iOS)
        guard let geometry else {
            return nil
        }
        // Wide or tall is decided on the area the content may use, so a fold that pushes the layout onto one side
        // leaves a narrow strip the tall layout fits
        let area = FoldLayout.usableArea(size: geometry.size, regions: geometry.regions)
        let wide = area.width > area.height
        let split = FoldLayout.split(length: wide ? geometry.size.width : geometry.size.height,
                                     fold: FoldLayout.fold(in: geometry.regions, wide: wide))
        return Placement(size: geometry.size, area: area, isWide: wide, split: split)
        #else
        return nil
        #endif
    }

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
        // The evaluation bar stands left of the board, as tall as its frame. Its place depends only on
        // the setting, so stepping through the moves, which clears the verdict, never moves the board.
        .padding(.leading, boardLeading)
        .overlay(alignment: .leading) {
            if showEngine {
                EvaluationBar(verdict: EngineView.verdict(of: session), rotated: session.gameState.rotated)
            }
        }
        // The board never mirrors, in any language: the a-file on the left and rank 1 at the bottom for White, and the
        // evaluation bar on its left (its side is chrome, not meaning). One pin over the whole subtree, bar included.
        .environment(\.layoutDirection, .leftToRight)
    }

    /// The evaluation bar's gutter on the board's leading side; the wide column reserves it beside the square.
    private var boardLeading: CGFloat {
        showEngine ? EvaluationBar.width + 6 : 0
    }

    /// The two players, the board between them and the variation cards: the tall layout stacks them, the wide
    /// layout's `BoardColumn` sizes the column from the board.
    @ViewBuilder private var boardRows: some View {
        PlayerRow(session: session, isWhite: topIsWhite)
        board
            .layoutValue(key: BoardColumn.IsBoard.self, value: true)
        PlayerRow(session: session, isWhite: !topIsWhite)
        VariationCards(session: session)
    }

    private var boardColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            boardRows
        }
    }

    private var wideBoardColumn: some View {
        BoardColumn(leading: boardLeading) {
            boardRows
        }
    }

    /// The engine readout, in the sidebar's form when the layout is wide.
    private func engine(wide: Bool) -> EngineView? {
        guard showEngine else {
            return nil
        }
        #if os(macOS)
        return EngineView.make(session: session, showStatistics: showStatistics, wide: wide)
        #else
        return EngineView.make(session: session, showStatistics: false, wide: wide)
        #endif
    }

    /// The sidebar's content; the wide layout only.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            MoveListView(session: session, card: true)
            StatusLine(session: session)
                .padding(.horizontal, 4)
            engine(wide: true)
        }
    }

    private func wideLayout(_ placement: Placement?) -> some View {
        Group {
            if let split = placement?.split, let primary = split.primary {
                // The fold is inside the area: the board column ends before it, the sidebar starts after it
                HStack(alignment: .top, spacing: split.gap) {
                    wideBoardColumn
                        .frame(width: primary, alignment: .topLeading)
                    sidebar
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                HStack(alignment: .top) {
                    // The board gets its full size first; the sidebar takes what is left
                    wideBoardColumn
                        .layoutPriority(1)
                    sidebar
                        .frame(minWidth: sidebarWidth(placement), maxWidth: .infinity)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    /// 320 pt, or half of a small usable area (a fold that pushed the layout onto one side) so it never overflows.
    private func sidebarWidth(_ placement: Placement?) -> CGFloat {
        guard let placement else {
            return 320
        }
        return min(320, placement.area.width / 2)
    }

    private func tallLayout(_ placement: Placement?) -> some View {
        let spacing: CGFloat = 10
        let split = placement?.split
        return VStack(alignment: .leading, spacing: spacing) {
            if let primary = split?.primary, let gap = split?.gap {
                // Tabletop: the whole extent above the fold is the board column's, so the rest starts after the fold
                boardColumn
                    .frame(height: primary, alignment: .top)
                StatusLine(session: session)
                    .padding(.horizontal, 2)
                    .padding(.top, gap - spacing)
            } else {
                boardColumn
                StatusLine(session: session)
                    .padding(.horizontal, 2)
            }
            engine(wide: false)
            MoveStrip(session: session) { showAllMoves = true }
            Spacer(minLength: 0)
        }
    }

    private var content: some View {
        let placement = placement
        return Group {
            // The Mac has no placement and is always wide
            if placement?.isWide ?? true {
                wideLayout(placement)
            } else {
                tallLayout(placement)
            }
        }
        .padding(placement?.insets ?? EdgeInsets())
    }

    #if os(iOS)
    /// The fold's regions in the content's coordinates: the test hook when set, else the display's division region.
    private nonisolated static func foldRegions(_ proxy: GeometryProxy, override: [FoldRegion]?) -> [FoldRegion] {
        if let override {
            return override
        }
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division, options: .includeInactive)
                .map { FoldRegion(frame: $0.frame, isActive: $0.isActive) }
        }
        return []
    }
    #endif

    var body: some View {
        content
        #if os(iOS)
        // Fills the space inside the padding, so its size and the regions are in one coordinate space
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: FoldGeometry.self) { [override = foldRegionsOverride] proxy in
            FoldGeometry(size: proxy.size, regions: Self.foldRegions(proxy, override: override))
        } action: { geometry in
            self.geometry = geometry
        }
        #endif
        .padding()
        .background(Walnut.background.ignoresSafeArea())
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

#if os(iOS)
/// The measure the layout is chosen from, as one value so it publishes once per change.
private struct FoldGeometry: Equatable {
    var size: CGSize
    var regions: [FoldRegion]
}
#endif
