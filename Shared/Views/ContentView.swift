//
//  ContentView.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: BChessUIDocument
            
    @State private var showInfo: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            TopInformationView(document: document)
            
            ZStack {
                BoardView(document: $document)
                PiecesView(document: $document)
            }
            
            if (showInfo) {
                BottomInformationView(document: document)
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Section {
                        Button(action: { Actions(document: $document).newGame(playAgainstWhite: false ) }) {
                            Label("New Game as White", systemImage: "plus.circle.fill")
                        }

                        Button(action: { Actions(document: $document).newGame(playAgainstWhite: true ) }) {
                            Label("New Game as Black", systemImage: "plus.circle")
                        }
                    }

                    Section {
                        Button(action: { Actions(document: $document).takeBackMove() }) {
                            Label("Take Back Move", systemImage: "arrow.uturn.backward.square.fill")
                        }
                    }

                    Section {
                        Picker(selection: $document.level, label: Text("Level")) {
                            Text("2 seconds").tag(0)
                            Text("5 seconds").tag(1)
                            Text("10 seconds").tag(2)
                            Text("15 seconds").tag(3)
                        }
                        Button(action: { showInfo.toggle() }) {
                            if (showInfo) {
                                Label("Hide Information", systemImage: "info.circle")
                            } else {
                                Label("Show Information", systemImage: "info.circle")
                            }
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

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            let doc = BChessUIDocument()
            ContentView(document: .constant(doc))
        }
    }
}
