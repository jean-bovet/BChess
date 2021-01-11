//
//  ContentView.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
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
}

struct Position {
    let rank: Int
    let file: Int
    
    static func empty() -> Position {
        return Position(rank: -1, file: -1)
    }
}
    
struct LastMoveModifier: ViewModifier {
    let rank: Int
    let file: Int
    let lastMove: FEngineMove?
    
    func isLastMoveStart(_ rank: Int, _ file: Int) -> Bool {
        if let move = lastMove {
            return move.fromRank == rank && move.fromFile == file
        } else {
            return false
        }
    }

    func isLastMoveEnd(_ rank: Int, _ file: Int) -> Bool {
        if let move = lastMove {
            return move.toRank == rank && move.toFile == file
        } else {
            return false
        }
    }


    func body(content: Content) -> some View {
        return content
            .if(isLastMoveStart(rank, file)) { view in
                view.border(Color.orange.opacity(0.8), width: 3)
            }
            .if(isLastMoveEnd(rank, file)) { view in
                view.border(Color.orange.opacity(0.8), width: 5)
            }
    }
}

//struct PieceModifier: ViewModifier {
//
//    let rank: Int
//    let file: Int
//    let pieces: [Piece]
//
//    func pieceImage(atRank rank: Int, file: Int) -> Image? {
//        return pieces.filter { $0.rank == rank && $0.file == file }.first?.image
//    }
//
//    func body(content: Content) -> some View {
//        let image = pieceImage(atRank: rank, file: file)
//        return content.if(image != nil) { view in
//            view.overlay(image!.resizable())
//        }
//    }
//}

struct SelectionModifier: ViewModifier {
    
    let rank: Int
    let file: Int
    let selection: SelectionState

    func body(content: Content) -> some View {
        return content.if(selection.selected(rank: rank, file: file) || selection.isPossibleMove(rank, file)) { view in
                view.overlay(Color.yellow.opacity(0.8))
            }
    }
}

struct SelectionState {
    let selection: Position
    let possibleMoves: [FEngineMove]
    
    func selected(rank: Int, file: Int) -> Bool {
        return selection.rank == rank && selection.file == file
    }
    
    func isPossibleMove(_ rank: Int, _ file: Int) -> Bool {
        return possibleMove(rank, file) != nil
    }
    
    func possibleMove(_ rank: Int, _ file: Int) -> FEngineMove? {
        return possibleMoves.filter { $0.fromFile == file && $0.fromRank == rank || $0.toFile == file && $0.toRank == rank }.first
    }
    
}

struct TopInformationView: View {
    
    let info: FEngineInfo?
    let engine: FEngine
    
    func whoIsPlaying() -> String {
        var text = engine.isWhite() ? "White" : "Black"
        if engine.isAnalyzing() {
            text.append(" is thinking")
        } else {
            text.append("'s turn")
        }
        return text
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(whoIsPlaying()).bold()
            Text(engine.pgnFormattedForDisplay())
        }
    }
}

struct BottomInformationView: View {
    
    let state: BoardState

    let numberFormatter = NumberFormatter()
    let valueFormatter = NumberFormatter()

    init(state: BoardState) {
        self.state = state
        
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = ","
        numberFormatter.usesGroupingSeparator = true
        
        valueFormatter.numberStyle = .decimal
        valueFormatter.minimumFractionDigits = 2
        valueFormatter.maximumFractionDigits = 2
        valueFormatter.groupingSeparator = ","
        valueFormatter.usesGroupingSeparator = true
    }

    func value() -> String {
        guard let info = state.info else {
            return " "
        }
        
        let value: String
        if info.mat {
            value = "#"
        } else {
            value = valueFormatter.string(from: NSNumber(value: Double(info.value) / 100.0))!
        }
        let line = info.bestLine(false)
        return "\(value) \(line)"
    }
    
    func speed() -> String {
        guard let info = state.info else {
            return " "
        }

        let nodes = numberFormatter.string(from: NSNumber(value: info.nodeEvaluated))!
        let speed = numberFormatter.string(from: NSNumber(value: info.movesPerSecond))!
        
        var text = "Depth \(info.depth)"
        if info.quiescenceDepth > 0 && info.quiescenceDepth != info.depth {
            text += "/\(info.quiescenceDepth)"
        }
        text += " with \(nodes) nodes at \(speed) n/s"
        return text
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if let opening = state.info?.opening {
                Text(opening)
            } else {
                Text(value())
                Text(speed())
            }
        }
    }
}

enum PlayAgainst: Int {
    case white
    case black
    case human
}

struct PositionTransformer {
    
    let playAgainst: PlayAgainst

    func actualRank(_ rank: Int) -> Int {
        if playAgainst == .white {
            return 7 - rank
        } else {
            return rank
        }
    }
    
    func actualFile(_ file: Int) -> Int {
        if playAgainst == .white {
            return 7 - file
        } else {
            return file
        }
    }
}

struct SquareView: View {
        
    let image: Image?
    
    var body: some View {
        if let image = image {
            image.resizable()
        } else {
            // The contentShape() is needed to define the hit
            // testing area because otherwise with opacity(0),
            // the first Rectangle is not tappable at all.
            Rectangle().opacity(0).contentShape(Rectangle())
        }
    }
    
}

struct BoardView: View {
    
    @ObservedObject var state: BoardState

    let engine: FEngine
    let pieces: [Piece]

    func piece(atRank rank: Int, file: Int) -> Piece? {
        return pieces.filter { $0.rank == rank && $0.file == file }.first
    }

    func applyLevelSettings() {
        switch state.level {
        case 0:
            engine.thinkingTime = 2
        case 1:
            engine.thinkingTime = 5
        case 2:
            engine.thinkingTime = 10
        case 3:
            engine.thinkingTime = 15
        default:
            engine.thinkingTime = 2
        }
    }
    
    func enginePlay() {
        engine.evaluate { (info, completed) in
            DispatchQueue.main.async {
                withAnimation {
                if completed {
                    self.moveEngine(move: info.bestMove)

                    // TODO: refactor?
                    let move = FEngineMove()
                    move.fromFile = info.fromFile
                    move.fromRank = info.fromRank
                    move.toFile = info.toFile
                    move.toRank = info.toRank
                    move.rawMoveValue = info.bestMove
                    state.lastMove = move
                }
                state.info = info
                }
            }
        }
    }
    
    func moveEngine(move: UInt) {
        engine.move(move)
        // TODO
//        document.pgn = engine.pgn()
    }
    
    func processTap(_ rank: Int, _ file: Int) {
        if let move = state.selection.possibleMove(rank, file) {
            withAnimation {
                state.selection = SelectionState(selection: Position.empty(), possibleMoves: [])
                applyLevelSettings()
                moveEngine(move: move.rawMoveValue)
                enginePlay()
            }
        } else {
            state.selection = SelectionState(selection: Position(rank: rank, file: file),
                                       possibleMoves: engine.moves(at: UInt(rank), file: UInt(file)))
        }
    }

    func board(withPieces pieces: [Piece]) -> [Square] {
        var squares = [Square]()
        for rank in 0...7 {
            for file in 0...7 {
                let piece = pieces.piece(atRank: rank, file: file)
                let square = Square(rank: rank, file: file, piece: piece)
                squares.append(square)
            }
        }
        return squares
    }
    
    var body: some View {
        GeometryReader { geometry in
            let minSize: CGFloat = min(geometry.size.width, geometry.size.height)
            let xOffset: CGFloat = (geometry.size.width - minSize) / 2
            let yOffset: CGFloat = (geometry.size.height - minSize) / 2
            let squareSize: CGFloat = minSize / 8
            let b: [Square] = board(withPieces: pieces)
            ForEach(b) { square in
                let r: Int = square.rank
                let f: Int = square.file
                let x: CGFloat = CGFloat(f) * squareSize + xOffset
                let y: CGFloat = CGFloat(7 - r) * squareSize + yOffset
                SquareView(image: square.piece?.image)
                    .frame(width: squareSize, height: squareSize)
                    .offset(x: x,
                            y: y)
                    .onTapGesture {
                        processTap(r, f)
                    }
            }
        }
    }
}

class BoardState: ObservableObject {
    @Published var selection = SelectionState(selection: Position.empty(), possibleMoves: [])
    @Published var lastMove: FEngineMove? = nil
    @Published var info: FEngineInfo? = nil
    @Published var level: Int = 0
    @Published var playAgainst: PlayAgainst = .black
}

struct Square: Identifiable {
    var id: String {
        return piece?.name ?? "\(UUID())"
    }
    let rank: Int
    let file: Int
    let piece: Piece?
}

extension Array where Element == Piece {
    func piece(atRank rank: Int, file: Int) -> Piece? {
        return filter { $0.rank == rank && $0.file == file }.first
    }
}

struct ContentView: View {
    @Binding var document: BChessUIDocument
    
    @ObservedObject private var state = BoardState()
        
    @State private var showInfo: Bool = false

    var engine: FEngine {
        return document.engine
    }
    
    func backgroundColor(rank: Int, file: Int) -> Color {
        if rank % 2 == 0 {
            return file % 2 == 0 ? .gray : .white
        } else {
            return file % 2 == 0 ? .white : .gray
        }
    }
    
    func newGame(playAgainstWhite: Bool) {
//        engine.setFEN(StartPosFEN)
//        if playAgainstWhite {
//            playAgainst = .white
//        } else {
//            playAgainst = .black
//        }
//        if engine.isWhite() && playAgainst == .white {
//            enginePlay()
//        }
//        if !engine.isWhite() && playAgainst == .black {
//            enginePlay()
//        }
//        selection = SelectionState(selection: Position.empty(), possibleMoves: [])
    }

    var body: some View {
        VStack(alignment: .leading) {
            TopInformationView(info: state.info, engine: engine)
            
            ZStack {
                VStack(spacing: 0) {
                    let pt = PositionTransformer(playAgainst: state.playAgainst)
                    ForEach((0...7).reversed(), id: \.self) { rank in
                        let r = pt.actualFile(rank)
                        HStack(spacing: 0) {
                            ForEach((0...7), id: \.self) { file in
                                let f = pt.actualFile(file)
                                Rectangle()
                                    .fill(backgroundColor(rank: r, file: f))
                                    .modifier(LastMoveModifier(rank: r, file: f, lastMove: state.lastMove))
                                    .modifier(SelectionModifier(rank: r, file: f, selection: state.selection))
                            }
                        }
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)

                BoardView(state: state, engine: engine, pieces: document.pieces)
            }
            
            if (showInfo) {
                BottomInformationView(state: state)
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Section {
                        Button(action: { newGame(playAgainstWhite: false ) }) {
                            Label("New Game as White", systemImage: "plus.circle.fill")
                        }

                        Button(action: { newGame(playAgainstWhite: true ) }) {
                            Label("New Game as Black", systemImage: "plus.circle")
                        }
                    }

                    Divider()
                    
                    Picker(selection: $state.level, label: Text("Level")) {
                        Text("2 seconds").tag(0)
                        Text("5 seconds").tag(1)
                        Text("10 seconds").tag(2)
                        Text("15 seconds").tag(3)
                    }
                    
                    Divider()
                    
                    Button(action: { showInfo.toggle() }) {
                        if (showInfo) {
                            Label("Hide Information", systemImage: "info.circle")
                        } else {
                            Label("Show Information", systemImage: "info.circle")
                        }
                    }
                }
                label: {
                    Label("Level", systemImage: "arrow.up.arrow.down")
                }
            }
        }

    }
}

struct Piece {
    let name: String
    let file: UInt
    let rank: UInt
    let image: Image
}

struct PiecesFactory {
    
    let pieceImageNames = [
        "p" : "pawn_b",
        "P" : "pawn_w",
        "n" : "knight_b",
        "N" : "knight_w",
        "b" : "bishop_b",
        "B" : "bishop_w",
        "r" : "rook_b",
        "R" : "rook_w",
        "q" : "queen_b",
        "Q" : "queen_w",
        "k" : "king_b",
        "K" : "king_w",
        ]
    
    func pieces(forState state: String) -> [Piece] {
        var pieces = [Piece]()
        var cursor = state.startIndex
        while cursor < state.endIndex {
            let nextCursor = state.index(cursor, offsetBy: 4)
            let token = state[cursor..<nextCursor]
            pieces.append(piece(forToken: String(token)))
            cursor = nextCursor
        }
        return pieces
    }
    
    func piece(forToken token: String) -> Piece {
        let pieceName = String(token.prefix(2))
        let pieceFile = UInt(String(token[token.index(token.startIndex, offsetBy: 2)]))!
        let pieceRank = UInt(String(token[token.index(token.startIndex, offsetBy: 3)]))!
        
        let pieceImageName = String(pieceName.prefix(1))
        let pieceImage = Image(pieceImageNames[pieceImageName]!)
        return Piece(name: pieceName, file: pieceFile, rank: pieceRank, image: pieceImage)
    }
                    
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            ContentView(document: .constant(BChessUIDocument()))
        }
    }
}
