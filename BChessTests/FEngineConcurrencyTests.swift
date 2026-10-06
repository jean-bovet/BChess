//
//  FEngineConcurrencyTests.swift
//  BChessTests
//
//  The bridge's guarantee: once cancel, evaluate or a position change has returned, no callback of an
//  earlier search runs, a stop is never lost, and a search never touches the game that the caller edits.
//

import Foundation
import Testing

private let middlegame = "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"

private func makeEngine(fen: String = middlegame) -> FEngine {
    let engine = FEngine()
    engine.useOpeningBook = false
    engine.setFEN(fen)
    return engine
}

struct FEngineConcurrencyTests {

    @Test func stopBeforeArmDeliversBestMove() {
        let engine = makeEngine()
        defer { engine.cancel() }

        // Hold the search queue so that the search is requested but not armed when stop arrives
        let gate = DispatchSemaphore(value: 0)
        engine.perform(onSearchQueue: { gate.wait() })

        let result = Locked<FEngineInfo?>(nil)
        let delivered = DispatchSemaphore(value: 0)
        engine.analyze { info, completed in
            if completed {
                result.value = info
                delivered.signal()
            }
        }
        engine.stop()
        gate.signal()

        #expect(delivered.wait(seconds: 2))
        // A real move, legal in the position that was searched: an empty search would give a garbage string
        let info = result.value
        #expect(info?.hasBestMove == true)
        let move = info?.bestMove(true) ?? ""
        let checker = FEngine()
        checker.setFEN(middlegame)
        #expect(checker.move(uci: String(move)))
        #expect(!engine.isAnalyzing())
    }

    @Test func cancelBeforeArmNeverDelivers() {
        let engine = makeEngine()

        let gate = DispatchSemaphore(value: 0)
        engine.perform(onSearchQueue: { gate.wait() })

        let calls = Locked(0)
        engine.analyze { _, _ in calls.update { $0 += 1 } }
        engine.cancel()
        gate.signal()
        engine.drainSearchQueue()

        #expect(calls.value == 0)
        #expect(!engine.isAnalyzing())
    }

    @Test func replacedSearchNeverDelivers() {
        let engine = makeEngine()
        defer {
            // The search must have unwound before the checkpoint it may still call is cleared
            engine.cancel()
            engine.drainSearchQueue()
            engine.setSearchCheckpoint(nil)
        }

        // Park the first search inside alpha-beta, so that it is certainly running when it is replaced
        let parked = DispatchSemaphore(value: 0)
        let go = DispatchSemaphore(value: 0)
        let fired = Locked(false)
        engine.setSearchCheckpoint {
            if fired.update({ let was = $0; $0 = true; return was }) == false {
                parked.signal()
                go.wait()
            }
        }

        let replaced = Locked(false)
        let lateCalls = Locked(0)
        let completedFirst = Locked(false)
        engine.analyze { _, completed in
            if replaced.value {
                lateCalls.update { $0 += 1 }
            }
            if completed {
                completedFirst.value = true
            }
        }
        #expect(parked.wait(seconds: 5))

        let secondDone = DispatchSemaphore(value: 0)
        engine.evaluate(3) { _, completed in
            if completed {
                secondDone.signal()
            }
        }
        replaced.value = true

        // Give a search that is not serialized behind the first one time to start and re-arm
        Thread.sleep(forTimeInterval: 0.1)
        go.signal()

        #expect(secondDone.wait(seconds: 10))
        engine.drainSearchQueue()
        // The first search must have unwound by now; if it was not serialized it needs a moment
        Thread.sleep(forTimeInterval: 0.2)
        #expect(lateCalls.value == 0)
        #expect(!completedFirst.value)
    }

    /// Runs one position change while a search is delivering, and checks the search is dead when it returns.
    private func expectInvalidates(_ name: String, sourceLocation: SourceLocation = #_sourceLocation, _ change: (FEngine) -> Void) {
        let engine = makeEngine()
        engine.setPGN("1. e4 e5 2. Nf3 Nc6 *")
        defer { engine.cancel() }

        let changed = Locked(false)
        let firstCallback = DispatchSemaphore(value: 0)
        let lateCalls = Locked(0)
        engine.analyze { _, _ in
            if changed.value {
                lateCalls.update { $0 += 1 }
            }
            firstCallback.signal()
        }
        #expect(firstCallback.wait(seconds: 5), "\(name): the search did not start", sourceLocation: sourceLocation)

        change(engine)
        changed.value = true

        #expect(!engine.isAnalyzing(), "\(name) left the search running", sourceLocation: sourceLocation)
        engine.cancel() // so that a search that is still running cannot stall the drain below
        engine.drainSearchQueue()
        #expect(lateCalls.value == 0, "\(name): a callback arrived after it returned", sourceLocation: sourceLocation)
    }

    @Test func positionChangeInvalidatesSearch() {
        expectInvalidates("setFEN") { $0.setFEN(middlegame) }
        expectInvalidates("setPGN") { $0.setPGN("1. d4 d5 *") }
        expectInvalidates("loadAllGames") { $0.loadAllGames("1. d4 d5 *") }
        expectInvalidates("move(uci:)") { $0.move(uci: "a2a3") }
        expectInvalidates("move:") { engine in
            let moves = engine.moves(at: 1, file: 0) // the pawn on a2
            engine.move(moves[0].rawMoveValue)
        }
        expectInvalidates("moveTo") { $0.move(to: .backward, variation: 0) }
        expectInvalidates("setCurrentGameIndex") { $0.currentGameIndex = 0 }
        expectInvalidates("setCurrentMoveNodeUUID") { engine in
            engine.currentMoveNodeUUID = engine.moveNodesTree()[0].uuid
        }
    }

    /// Parks the search thread inside alpha-beta (history modified), releases it and mutates the game
    /// at once. What the thread does after the release and the mutation are unordered, which is what
    /// the Thread Sanitizer reports when the search shares the game's history. Without it, a smoke test.
    private func mutateWhileSearching(_ mutate: (FEngine) -> Void) {
        let engine = makeEngine()
        engine.setPGN("1. e4 e5 2. Nf3 Nc6 *")
        defer {
            // The search must have unwound before the checkpoint it may still call is cleared
            engine.cancel()
            engine.drainSearchQueue()
            engine.setSearchCheckpoint(nil)
        }

        let parked = DispatchSemaphore(value: 0)
        let go = DispatchSemaphore(value: 0)
        let fired = Locked(false)
        engine.setSearchCheckpoint {
            if fired.update({ let was = $0; $0 = true; return was }) == false {
                parked.signal()
                go.wait()
            }
        }
        engine.analyze { _, _ in }
        #expect(parked.wait(seconds: 5))

        go.signal()
        mutate(engine)
    }

    @Test func mutatingDuringSearchIsRaceFree() {
        mutateWhileSearching { engine in
            let moves = engine.moves(at: 1, file: 0)
            engine.move(moves[0].rawMoveValue)
        }
        mutateWhileSearching { $0.setFEN(middlegame) }
        mutateWhileSearching { $0.move(to: .backward, variation: 0) }
    }

    @Test func inlineSearchWaitsForUnwinding() {
        let engine = makeEngine()
        engine.setPGN("1. e4 e5 2. Nf3 Nc6 *")
        defer {
            // The search must have unwound before the checkpoint it may still call is cleared
            engine.cancel()
            engine.drainSearchQueue()
            engine.setSearchCheckpoint(nil)
        }

        let parked = DispatchSemaphore(value: 0)
        let go = DispatchSemaphore(value: 0)
        let fired = Locked(false)
        engine.setSearchCheckpoint {
            if fired.update({ let was = $0; $0 = true; return was }) == false {
                parked.signal()
                go.wait()
            }
        }
        engine.analyze { _, _ in }
        #expect(parked.wait(seconds: 5))

        go.signal()
        engine.async = false
        let result = Locked<FEngineInfo?>(nil)
        engine.evaluate(3) { info, completed in
            if completed {
                result.value = info
            }
        }
        #expect(result.value?.bestMove(true) != nil)
    }

    @Test func staleTimerDoesNotStopNextSearch() async throws {
        let engine = makeEngine()
        defer { engine.cancel() }

        // Wait until the first search is running, so that its timer is armed
        let started = DispatchSemaphore(value: 0)
        engine.evaluate(-1, time: 0.2) { _, _ in started.signal() }
        #expect(started.wait(seconds: 5))
        engine.cancel()
        engine.analyze { _, _ in }

        try await Task.sleep(for: .milliseconds(600))
        #expect(engine.isAnalyzing())
    }

    @Test func cancelStopsPromptly() throws {
        let engine = makeEngine()
        defer {
            engine.cancel()
            engine.drainSearchQueue()
            engine.setSearchCheckpoint(nil)
        }

        // A checkpoint proves that the search is deep inside alpha-beta, then slows every node down:
        // only a cancel that reaches the move loops lets it end within the deadline
        let started = DispatchSemaphore(value: 0)
        let calls = Locked(0)
        engine.setSearchCheckpoint {
            let n = calls.update { $0 += 1; return $0 }
            if n == 300 {
                started.signal()
            }
            if n >= 300 {
                Thread.sleep(forTimeInterval: 0.02)
            }
        }
        engine.analyze { _, _ in }
        #expect(started.wait(seconds: 10))

        // Once cancelled, the search unwinds: whatever is queued behind it runs soon
        engine.cancel()
        let unwound = DispatchSemaphore(value: 0)
        engine.perform(onSearchQueue: { unwound.signal() })
        #expect(unwound.wait(seconds: 0.5))
        #expect(!engine.isAnalyzing())
    }
}
