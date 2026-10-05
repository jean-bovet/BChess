//
//  TestSupport.swift
//  BChessTests
//
//  Small thread-safe helpers for tests that observe engine callbacks from other threads.
//

import Foundation

/// A value guarded by a lock, for state shared with `@Sendable` callbacks.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    @discardableResult
    func update<R>(_ body: (inout Value) -> R) -> R {
        lock.withLock { body(&stored) }
    }
}

extension DispatchSemaphore {
    /// True when the semaphore was signaled within `seconds`.
    func wait(seconds: TimeInterval) -> Bool {
        wait(timeout: .now() + seconds) == .success
    }
}

extension FEngine {
    /// Blocks until everything queued on the search queue so far has run.
    func drainSearchQueue() {
        let done = DispatchSemaphore(value: 0)
        perform(onSearchQueue: { done.signal() })
        done.wait()
    }
}
