//
//  PrimeCalculator.swift
//  SwiftConcurrency
//
//  Deliberately slow, CPU-bound work used by the Task.detached demo.
//

import Foundation

nonisolated struct PrimeResult: Sendable {
    let limit: Int
    let checkedUpTo: Int
    let primeCount: Int
    let largestPrime: Int
    let duration: Double
    let ranOnMainThread: Bool
    let priority: TaskPriority
    let wasCancelled: Bool
}

/// `nonisolated` so it isn't tied to the main actor (this project's default isolation).
/// Where it runs depends entirely on *who calls it*.
nonisolated enum PrimeCalculator {
    /// Synchronous and CPU-heavy. Called from the main actor it blocks the UI;
    /// called from a detached task it runs on a background thread.
    static func countPrimes(upTo limit: Int) -> PrimeResult {
        let start = ContinuousClock.now
        let onMainThread = Thread.isMainThread
        let priority = Task.currentPriority

        var count = 0
        var largest = 0
        var checked = 1
        var cancelled = false

        for number in 2...max(2, limit) {
            // Cooperative cancellation: CPU loops never stop on their own,
            // so check every so often.
            if number % 20_000 == 0, Task.isCancelled {
                cancelled = true
                break
            }
            if isPrime(number) {
                count += 1
                largest = number
            }
            checked = number
        }

        return PrimeResult(
            limit: limit,
            checkedUpTo: checked,
            primeCount: count,
            largestPrime: largest,
            duration: (ContinuousClock.now - start).seconds,
            ranOnMainThread: onMainThread,
            priority: priority,
            wasCancelled: cancelled
        )
    }

    /// The modern alternative to `Task.detached` for "run this off the main actor":
    /// an `@concurrent` async function always runs on the global concurrent executor,
    /// but stays a normal child of the calling task (inherits priority and cancellation).
    @concurrent
    static func countPrimesInBackground(upTo limit: Int) async -> PrimeResult {
        countPrimes(upTo: limit)
    }

    private static func isPrime(_ n: Int) -> Bool {
        if n < 4 { return n > 1 }
        if n % 2 == 0 || n % 3 == 0 { return false }
        var i = 5
        while i * i <= n {
            if n % i == 0 || n % (i + 2) == 0 { return false }
            i += 6
        }
        return true
    }
}

extension TaskPriority {
    nonisolated var name: String {
        switch self {
        case .high: "high / userInitiated"
        case .medium: "medium"
        case .low: "low / utility"
        case .background: "background"
        default: "raw \(rawValue)"
        }
    }
}
