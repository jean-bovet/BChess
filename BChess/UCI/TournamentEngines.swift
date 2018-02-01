//
//  TournamentEngines.swift
//  BChess
//
//  Created by Jean Bovet on 1/5/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

class TournamentEngine: TournamentDelegate {
    
    let tournament: Tournament
    
    init() {
        let playerA = PlayerChessEngine(name: "Bob")
//        playerA.engine.positionalAnalysis = false
        playerA.engine.ttEnabled = false

        let playerB = PlayerChessEngine(name: "Alice")
//        playerB.engine.positionalAnalysis = true
        playerB.engine.ttEnabled = false

        tournament = Tournament(playerA: playerA, playerB: playerB)
        tournament.delegate = self
    }

    func go() {
        tournament.go()
        RunLoop.main.run()
    }
    
    func playerDidPlay(player: Player) {
        print("\(player.name): \(player.state)")

        DispatchQueue.main.async {
            self.tournament.switchPlayer()
            self.tournament.play()
        }
    }

}
