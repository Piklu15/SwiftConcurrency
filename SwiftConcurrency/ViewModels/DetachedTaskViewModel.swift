//
//  DetachedTaskViewModel.swift
//  SwiftConcurrency
//

import Foundation
import Observation

@Observable
final class DetachedTaskViewModel {
    enum Strategy: String, CaseIterable, Identifiable {
        case inherited
        case detached
        case concurrent

        var id: Self { self }

        var title: String {
            switch self {
            case .inherited: "Task { }"
            case .detached: "Task.detached { }"
            case .concurrent: "@concurrent func"
            }
        }

        var explanation: String {
            switch self {
            case .inherited: "Inherits the main actor, so the heavy loop runs on the main thread. The UI freezes."
            case .detached: "Runs on a background thread with no actor, priority or cancellation inherited. The UI stays smooth."
            case .concurrent: "The modern way. Runs off the main actor but stays a child task, so cancellation and priority still flow."
            }
        }

        var symbol: String {
            switch self {
            case .inherited: "exclamationmark.triangle.fill"
            case .detached: "arrow.up.right.square"
            case .concurrent: "sparkles"
            }
        }
    }

    static let workloads = [1_000_000, 3_000_000, 6_000_000]

    var limit = 3_000_000

    private(set) var running: Strategy?
    private(set) var result: PrimeResult?
    private(set) var resultStrategy: Strategy?
    private(set) var tapCount = 0

    private var currentTask: Task<Void, Never>?

    var isRunning: Bool { running != nil }

    func tap() {
        tapCount += 1
    }

    func run(_ strategy: Strategy) {
        guard !isRunning else { return }
        running = strategy
        result = nil
        let limit = self.limit

        // This outer `Task { }` is created on the main actor and inherits it.
        currentTask = Task {
            // Give SwiftUI a moment to draw the "running" state before we (maybe) block it.
            try? await Task.sleep(for: .milliseconds(100))

            let result: PrimeResult
            switch strategy {
            case .inherited:
                // ❌ We're on the main actor, and `countPrimes` is synchronous,
                // so it runs right here on the main thread.
                result = PrimeCalculator.countPrimes(upTo: limit)

            case .detached:
                // ✅ A detached task has no actor, so it runs on the global executor.
                // It's *unstructured*: cancelling the outer task does NOT cancel it,
                // so we forward cancellation by hand.
                let worker = Task.detached(priority: .userInitiated) {
                    PrimeCalculator.countPrimes(upTo: limit)
                }
                result = await withTaskCancellationHandler {
                    await worker.value
                } onCancel: {
                    worker.cancel()
                }

            case .concurrent:
                // ✅ Structured: cancellation of the outer task flows in automatically.
                result = await PrimeCalculator.countPrimesInBackground(upTo: limit)
            }

            // Back on the main actor – safe to update UI state.
            self.result = result
            self.resultStrategy = strategy
            self.running = nil
        }
    }

    func cancel() {
        currentTask?.cancel()
    }
}
