//
//  SearchLimitsTests.swift
//  BChessTests
//
//  The `go` command's limits and the time they allow, without a process.
//

import Foundation
import Testing

struct SearchLimitsTests {

    private func limits(_ command: String) -> SearchLimits {
        SearchLimits(goTokens: command.split(separator: " ").map { String($0) })
    }

    private func milliseconds(_ command: String, whiteToMove: Bool = true) -> Int {
        Int((limits(command).search(whiteToMove: whiteToMove).time * 1000).rounded())
    }

    // MARK: Parsing

    @Test func parsesTheClock() {
        let parsed = limits("wtime 10000 btime 9000 winc 100 binc 200 movestogo 20")
        #expect(parsed.wtime == 10000)
        #expect(parsed.btime == 9000)
        #expect(parsed.winc == 100)
        #expect(parsed.binc == 200)
        #expect(parsed.movestogo == 20)
        #expect(!parsed.infinite)
    }

    @Test func parsesTheOtherLimits() {
        #expect(limits("movetime 500").movetime == 500)
        #expect(limits("depth 4").depth == 4)
        #expect(limits("infinite").infinite)
        #expect(limits("") == SearchLimits(goTokens: []))
        #expect(limits("").wtime == nil)
    }

    @Test func skipsWhatItDoesNotKnow() {
        let parsed = limits("nodes 5 searchmoves e2e4 d2d4 depth 3 ponder mate 2")
        #expect(parsed.depth == 3)
        #expect(parsed.wtime == nil)
        #expect(!parsed.infinite)
    }

    @Test func invalidValuesAreAbsentOrClamped() {
        #expect(limits("movestogo 0").movestogo == nil)
        #expect(limits("movestogo -3").movestogo == nil)
        #expect(limits("movestogo 5000").movestogo == 1000)
        #expect(limits("depth 0").depth == 1)
        #expect(limits("depth -2").depth == 1)
        #expect(limits("depth 100").depth == 64)
        #expect(limits("depth 4294967296").depth == 64)
        #expect(limits("wtime -5").wtime == 0)
        #expect(limits("wtime abc").wtime == nil)
        #expect(limits("wtime").wtime == nil)
        #expect(limits("wtime btime 5").wtime == nil)
        #expect(limits("wtime btime 5").btime == 5)
        // Does not fit an Int
        #expect(limits("wtime 99999999999999999999").wtime == nil)
        // Fits, and is clamped to a day
        #expect(limits("wtime 9223372036854775807").wtime == SearchLimits.maximum)
        #expect(limits("movetime 9223372036854775807").movetime == SearchLimits.maximum)
    }

    // MARK: Allocation

    @Test func clockAllocation() {
        // 10+0.1 on the first move: a thirtieth of the clock and the increment
        #expect(milliseconds("wtime 10000 btime 10000 winc 100 binc 100") == 433)
        // Black reads its own clock and increment
        #expect(milliseconds("wtime 10000 btime 3000 winc 100 binc 0", whiteToMove: false) == 100)
        // The last move of the period: all but the safety margin
        #expect(milliseconds("wtime 1000 movestogo 1") == 950)
        // Nearly out of time: the minimum
        #expect(milliseconds("wtime 30") == 10)
        #expect(milliseconds("wtime 0") == 10)
        #expect(milliseconds("wtime -5") == 10)
    }

    @Test func movetimeAllocation() {
        #expect(milliseconds("movetime 500") == 450)
        #expect(milliseconds("movetime 20") == 10)
        // Movetime wins over a clock
        #expect(milliseconds("movetime 500 wtime 100000") == 450)
    }

    @Test func noTimerWithoutALimit() {
        #expect(limits("infinite").search(whiteToMove: true) == (depth: -1, time: 0))
        #expect(limits("").search(whiteToMove: true) == (depth: -1, time: 0))
        // A clock for the other side only
        #expect(limits("btime 5000").search(whiteToMove: true) == (depth: -1, time: 0))
        #expect(limits("infinite wtime 5000").search(whiteToMove: true) == (depth: -1, time: 0))
    }

    @Test func depthLimit() {
        #expect(limits("depth 4").search(whiteToMove: true) == (depth: 4, time: 0))
        // The depth also caps a search that has a clock
        let both = limits("depth 6 wtime 10000").search(whiteToMove: true)
        #expect(both.depth == 6)
        #expect(both.time > 0)
    }

    @Test func hugeValuesNeverOverflow() {
        let day = Double(SearchLimits.maximum) / 1000
        let huge = "wtime 9223372036854775807 winc 9223372036854775807 movestogo 1"
        let allowed = limits(huge).search(whiteToMove: true).time
        #expect(abs(allowed - (day - 0.05)) < 1e-6)
        #expect(milliseconds("wtime 9223372036854775807 winc 9223372036854775807") == SearchLimits.maximum - 50)
        #expect(milliseconds("movetime 9223372036854775807") == SearchLimits.maximum - 50)
        #expect(milliseconds("wtime 99999999999999999999 movetime 1000") == 950)
    }
}
