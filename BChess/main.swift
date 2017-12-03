//
//  main.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

let engine = FBoardEngine()
engine.runTests()
//engine.generatePositions()

let formatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter
}()

func run(perf: Performance) {
    perf.generate(depth: 4)
    print("\(formatter.string(for: perf.moves)!) moves in \(perf.timeElapsed) seconds => \(formatter.string(for: perf.movesPerSecond)!) moves/s")
}

//run(perf: PerformanceClassic())
run(perf: PerformanceCpp())

//let uci = UCI()
//uci.run()

