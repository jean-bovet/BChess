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
struct ContentView<MenuItems: View>: View {
    let session: GameSession

    /// The items of the "More" menu in the face-to-face bar (iOS): the shell's, since the navigation bar is hidden there.
    private let menuItems: MenuItems

    /// A test-only source of the fold's regions (the gallery's fixed windows carry none). Nil in the app, which
    /// asks the display; only the source is replaced, never the layout that reads it.
    let foldRegionsOverride: [FoldRegion]?

    init(session: GameSession, foldRegions: [FoldRegion]? = nil, @ViewBuilder menuItems: () -> MenuItems) {
        self.session = session
        self.foldRegionsOverride = foldRegions
        self.menuItems = menuItems()
    }

    @AppStorage("showEngine") private var showEngineSetting = false
    @AppStorage("showEngineStatistics") private var showStatistics = false

    @State private var showAllMoves = false

    /// The screen's layout direction: the side-by-side layout pins itself left to right and gives it back to each half.
    @Environment(\.layoutDirection) private var layoutDirection

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

    /// The engine readout as shown: the setting, except in a friend game on a platform with two boards.
    private var showEngine: Bool {
        FaceToFace.showsEngine(setting: showEngineSetting, state: session.gameState, hasTwoBoards: FaceToFace.platformHasTwoBoards)
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

    private func board(rotated: Bool, acceptsMoves: Bool = true, engineBar: Bool = true) -> some View {
        BoardFrame(rotated: rotated, ring: ring) {
            ZStack {
                BoardView(session: session, rotated: rotated)
                PiecesView(session: session, rotated: rotated, acceptsMoves: acceptsMoves)
                VariationSelectionView(session: session, rotated: rotated)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(acceptsMoves ? "board" : "board-inactive")
        .accessibilityValue(session.fen)
        // The evaluation bar stands left of the board, as tall as its frame. Its place depends only on
        // the setting, so stepping through the moves, which clears the verdict, never moves the board.
        .padding(.leading, engineBar ? boardLeading : 0)
        .overlay(alignment: .leading) {
            if showEngine && engineBar {
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
        board(rotated: session.gameState.rotated)
            .layoutValue(key: BoardColumn.IsBoard.self, value: true)
        PlayerRow(session: session, isWhite: !topIsWhite)
        VariationCards(session: session)
    }

    private var boardColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            boardRows
        }
        .probeFrame("tall-column")
    }

    private var wideBoardColumn: some View {
        BoardColumn(leading: boardLeading) {
            boardRows
        }
        .probeFrame("column")
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

    /// The status line's slot: the result banner once the line has ended, and the status line unless it would only
    /// repeat the banner (at the line's end in play mode; analyze and train keep their mode notice, and browsing an
    /// earlier position says whose move it is there).
    @ViewBuilder
    private var statusArea: some View {
        if let result = session.result {
            VStack(alignment: .leading, spacing: 6) {
                ResultBanner(result: result)
                if !session.isAtLineEnd || session.mode.value != .play {
                    StatusLine(session: session)
                }
            }
        } else {
            StatusLine(session: session)
        }
    }

    /// The sidebar's content; the wide layout only.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            MoveListView(session: session, card: true)
            statusArea
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
                statusArea
                    .padding(.horizontal, 2)
                    .padding(.top, gap - spacing)
            } else {
                // Centres the block in the free height; the tabletop above stays at the top
                Spacer(minLength: 0)
                boardColumn
                statusArea
                    .padding(.horizontal, 2)
            }
            engine(wide: false)
            MoveStrip(session: session) { showAllMoves = true }
            Spacer(minLength: 0)
        }
    }

    #if os(iOS)
    /// The tap target of the bar's buttons.
    private static var tapSize: CGFloat { 44 }

    /// The visible height of the bar between the two boards: thinner than its buttons' tap targets, which overlap the
    /// halves' edges (the bar is above them).
    private static var barHeight: CGFloat { 28 }

    /// The space between a half's board and the bar.
    private static var barClearance: CGFloat { 4 }

    /// One player's half: the board with this player at the bottom and their own row (the opponent's row is on the other
    /// half, facing the opponent; the result replaces the row's detail).
    /// Only the half whose player is on move takes taps and is seen by accessibility, so the `square-…` and `board`
    /// identifiers stay unique and move to the other board after each move.
    private func half(near: Bool) -> some View {
        let bottomIsWhite = FaceToFace.bottomIsWhite(near: near, rotated: session.gameState.rotated)
        let accepts = FaceToFace.acceptsMoves(bottomIsWhite: bottomIsWhite, isWhiteToMove: session.isWhiteToMove)
        return BoardColumn(leading: 0, spacing: 2, centersBoard: true) {
            board(rotated: !bottomIsWhite, acceptsMoves: accepts, engineBar: false)
                .layoutValue(key: BoardColumn.IsBoard.self, value: true)
            HalfPlayerRow(session: session, isWhite: bottomIsWhite)
                .modifier(ScaledHeight(base: 32, relativeTo: .headline))
        }
        // VoiceOver skips the half that cannot move; XCUITest still lists a hidden element (not hittable), so the
        // half's own identifiers differ too (`board-inactive`, `inactive-square-…`) and the live ones stay unique
        .accessibilityHidden(!accepts)
        .dynamicTypeSize(...Self.faceToFaceTextLimit)
    }

    /// The largest text size a half follows: two boards share the screen, and larger sizes leave a small iPhone's boards
    /// too little room (`GalleryScenarioTests.faceToFaceColumnsStayInTheirHalves` holds boards of 100 pt at this size).
    static var faceToFaceTextLimit: DynamicTypeSize { .xxxLarge }

    /// The half in its slot, turned for the player who sits there: 0 near, 180 far (tall).
    private func slot(near: Bool) -> some View {
        half(near: near)
            .rotationEffect(.degrees(FaceToFace.turn(near: near, wide: false)))
            // The column hugs the bar; what the board cannot use is left at the screen's edge
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: near ? .top : .bottom)
            .padding(near ? .top : .bottom, Self.barClearance)
    }

    /// The half in a side-by-side slot, turned a quarter toward its player: laid out in the slot's transposed size
    /// (so its width is the slot's height), turned, and framed back to the slot. Each half gets the screen's layout
    /// direction back, so its rows mirror as chrome does though the arrangement itself is pinned left to right.
    private func turnedSlot(near: Bool) -> some View {
        GeometryReader { proxy in
            half(near: near)
                .environment(\.layoutDirection, layoutDirection)
                .frame(width: proxy.size.height, height: proxy.size.width)
                .rotationEffect(.degrees(FaceToFace.turn(near: near, wide: true)))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(near ? .trailing : .leading, Self.barClearance)
    }

    /// Undo steps back one move, as Back does (a different move afterwards replaces the undone one); More is the shell's menu.
    private var undoButton: some View {
        Button {
            withAnimation { session.move(to: .backward) }
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
                .labelStyle(.iconOnly)
                .font(.system(size: 22))
                .frame(width: Self.tapSize, height: Self.tapSize)
        }
        .disabled(!session.canMove(to: .backward))
    }

    private var moreButton: some View {
        Menu {
            menuItems
        } label: {
            Label("More", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .font(.system(size: 22))
                .frame(width: Self.tapSize, height: Self.tapSize)
        }
    }

    /// The bar is thin (its buttons' tap targets overflow it), and at least as tall as the fold's gap, so neither half reaches the hinge.
    private func bar(gap: CGFloat) -> some View {
        HStack {
            undoButton
            Spacer(minLength: 0)
            moreButton
        }
        .frame(height: max(Self.barHeight, gap))
        .zIndex(1)
    }

    /// The bar between side-by-side halves: Undo at the top, More at the bottom.
    /// As wide as its buttons, and at least as wide as the fold's gap.
    private func verticalBar(gap: CGFloat) -> some View {
        VStack {
            undoButton
            Spacer(minLength: 0)
            moreButton
        }
        .frame(width: max(Self.tapSize, gap))
    }

    /// Two boards against a friend: tall, the far half turned to face the far player and the bar between the halves;
    /// wide, the first player's half on the left and the other's on the right, each turned toward its own short end.
    /// With a fold inside, the first half ends before it and the bar stands over the fold; otherwise the halves
    /// are equal.
    @ViewBuilder private func faceToFaceLayout(_ placement: Placement?) -> some View {
        if placement?.isWide ?? false {
            HStack(spacing: 0) {
                if let primary = placement?.split.primary, let gap = placement?.split.gap {
                    turnedSlot(near: true)
                        .frame(width: primary)
                    verticalBar(gap: gap)
                    turnedSlot(near: false)
                } else {
                    turnedSlot(near: true)
                    verticalBar(gap: 0)
                    turnedSlot(near: false)
                }
            }
            // The first player's half is on the left in every language
            .environment(\.layoutDirection, .leftToRight)
        } else {
            VStack(spacing: 0) {
                if let primary = placement?.split.primary, let gap = placement?.split.gap {
                    slot(near: false)
                        .frame(height: primary)
                    bar(gap: gap)
                    slot(near: true)
                } else {
                    slot(near: false)
                    bar(gap: 0)
                    slot(near: true)
                }
            }
        }
    }
    #endif

    private var content: some View {
        let placement = placement
        return Group {
            #if os(iOS)
            if FaceToFace.isOn(session.gameState) {
                faceToFaceLayout(placement)
            } else if placement?.isWide ?? true {
                wideLayout(placement)
            } else {
                tallLayout(placement)
            }
            #else
            // The Mac has no placement and is always wide
            if placement?.isWide ?? true {
                wideLayout(placement)
            } else {
                tallLayout(placement)
            }
            #endif
        }
        .padding(placement?.insets ?? EdgeInsets())
    }


    /// The content, on iOS drawn over a clear base that takes exactly the space the container offers: the layout is
    /// chosen from that space, never from the size the content asks for. (Measured on the content itself, the first
    /// pass, before any measure, drew the wide layout, whose minimum width is wider than a phone; the frame then
    /// reported that width, the layout stayed wide, and a phone in dark mode showed the move list beside the board.)
    @ViewBuilder private var measuredContent: some View {
        #if os(iOS)
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: FoldGeometry.self) { [override = foldRegionsOverride] proxy in
                FoldGeometry(size: proxy.size, regions: foldRegions(proxy, override: override))
            } action: { geometry in
                self.geometry = geometry
            }
            // Nothing is drawn before the first measure: no layout is guessed
            .overlay {
                if geometry != nil {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        #else
        content
        #endif
    }

    var body: some View {
        measuredContent
        .padding()
        .background(Walnut.background.ignoresSafeArea())
        // The effective value: Players switching a computer game to "A friend" stops the analysis in the same screen
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
/// The fold's regions in the content's coordinates: the test hook when set, else the display's division region.
/// A free function: a generic view's `Self` is not `Sendable`, and the geometry closure is.
private nonisolated func foldRegions(_ proxy: GeometryProxy, override: [FoldRegion]?) -> [FoldRegion] {
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

#if os(iOS)
/// A height that follows the text size but not the script: the rows and the status of a half take the same room in
/// every language, so the board gets the same square (right to left included) and measured equals placed.
private struct ScaledHeight: ViewModifier {
    @ScaledMetric private var height: CGFloat
    private let alignment: Alignment

    init(base: CGFloat, relativeTo style: Font.TextStyle, alignment: Alignment = .center) {
        _height = ScaledMetric(wrappedValue: base, relativeTo: style)
        self.alignment = alignment
    }

    func body(content: Content) -> some View {
        content.frame(height: height, alignment: alignment)
    }
}

/// The measure the layout is chosen from, as one value so it publishes once per change.
private struct FoldGeometry: Equatable {
    var size: CGSize
    var regions: [FoldRegion]
}
#endif

extension ContentView where MenuItems == EmptyView {
    /// The Mac, and every screen that has no bar menu.
    init(session: GameSession, foldRegions: [FoldRegion]? = nil) {
        self.init(session: session, foldRegions: foldRegions) { EmptyView() }
    }
}
