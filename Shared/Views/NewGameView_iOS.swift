//
//  NewGameView_iOS.swift
//  BChess
//
//  Created by Jean Bovet on 4/25/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct NewPlayerConfigurationView_iOS: View {
    
    @Binding var player: GamePlayer

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: $player.name)
            Toggle(isOn: $player.computer) {
                Text("Computer")
                    .fixedSize()
            }
            Picker(selection: $player.level, label: Text("Level")) {
                Text("2 seconds").tag(0)
                Text("5 seconds").tag(1)
                Text("10 seconds").tag(2)
                Text("15 seconds").tag(3)
            }
            .hide(!player.computer, remove: true)
        }.padding()
    }
}

struct NewGameView_iOS: View {
    
    @Environment(\.presentationMode) var presentationMode

    @Binding var document: ChessDocument

    @State private var temporaryWhitePlayer = GamePlayer(name: "", computer: true, level: 0)
    @State private var temporaryBlackPlayer = GamePlayer(name: "", computer: true, level: 0)

    var editMode: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("White Player").bold()) {
                    NewPlayerConfigurationView_iOS(player: $temporaryWhitePlayer)
                }
                Section(header: Text("Black Player").bold()) {
                    NewPlayerConfigurationView_iOS(player: $temporaryBlackPlayer)
                }
            }
            .onAppear() {
                temporaryWhitePlayer = document.whitePlayer
                temporaryBlackPlayer = document.blackPlayer
            }
            .navigationBarTitle(editMode ? "Settings" : "New Game")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if editMode {
                        Button("OK") {
                            document.whitePlayer = temporaryWhitePlayer
                            document.blackPlayer = temporaryBlackPlayer
                            document.engineShouldMove.toggle()
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else {
                        Button("New Game") {
                            document.whitePlayer = temporaryWhitePlayer
                            document.blackPlayer = temporaryBlackPlayer
                            Actions(document: $document).newGame()
                            document.engineShouldMove.toggle()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct NewGameView_iOS_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let doc = ChessDocument()
            NewGameView_iOS(document: .constant(doc), editMode: false)
        }
        Group {
            let doc = ChessDocument()
            NewGameView_iOS(document: .constant(doc), editMode: true)
        }
    }
}
