//
//  Tournament.swift
//  BChess
//
//  Created by Jean Bovet on 1/5/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

typealias Callback = () -> Void

protocol Player : class {

    var state: String { get set }
    
    var name: String { get set }
    
    func play(completion: @escaping Callback)
    
    func canPlay() -> Bool
    
}

class PlayerChessEngine: Player {
    
    var name: String
    
    let engine = FEngine()

    init(name: String) {
        self.name = name
        engine.async = false
    }
    
    var state: String {
        set {
            engine.setPGN(newValue)
        }
        get {
            return engine.pgn()
        }
    }

    func play(completion: @escaping Callback) {
        // TODO: do engine thinking time
//        engine.thinkingTime = 10;
        engine.evaluate(5) { (info, completed) in
            if completed {
                self.engine.move(info.bestMove)
//                if !info.mat {
//                    self.engine.move(info.bestMove)
//                }
                completion()
            }
        }
    }
    
    func canPlay() -> Bool {
        return engine.canPlay()
    }
    
}

protocol TournamentDelegate {
    
    func playerDidPlay(player: Player)
    
}

class Tournament {
    
    let playerA: Player
    let playerB: Player
    
    var player: Player
    
    var delegate: TournamentDelegate? = nil
    
    init(playerA: Player, playerB: Player) {
        self.playerA = playerA
        self.playerB = playerB
        self.player = playerA
    }
    
    func go() {
        player = playerA
        play()
    }
    
    func play() {
        guard player.canPlay() else {
            print("Game ended")
            return
        }
        
        player.play {
            self.delegate?.playerDidPlay(player: self.player)
        }
    }
    
    func switchPlayer() {
        let state = player.state
        if player === playerA {
            player = playerB
        } else {
            player = playerA
        }
        player.state = state
    }
}
