//
//  LegacyDownloadOperation.swift
//  SwiftConcurrency
//
//  Simulates an old callback-based API that knows nothing about Swift concurrency,
//  and shows how to bridge it to async/await *with* cancellation support.
//

import Foundation

/// A pretend "legacy" download: ticks on a GCD timer, reports progress through a
/// callback and finishes through a completion handler. It has its own `cancel()`.
nonisolated final class LegacyDownloadOperation: @unchecked Sendable {
    // All mutable state is protected by `lock`, which is why `@unchecked Sendable` is OK.
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var completion: (@Sendable (Result<String, any Error>) -> Void)?
    private var progressHandler: (@Sendable (Double) -> Void)?
    private var ticks = 0
    private var isCancelled = false

    private let steps = 10
    private let interval = 0.3

    func start(
        progress: @escaping @Sendable (Double) -> Void,
        completion: @escaping @Sendable (Result<String, any Error>) -> Void
    ) {
        lock.lock()
        if isCancelled {
            // cancel() ran before we even started.
            lock.unlock()
            completion(.failure(CancellationError()))
            return
        }
        self.completion = completion
        self.progressHandler = progress

        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        lock.unlock()

        timer.resume()
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        lock.unlock()
        finish(.failure(CancellationError()))
    }

    private func tick() {
        lock.lock()
        guard completion != nil else {
            lock.unlock()
            return
        }
        ticks += 1
        let current = ticks
        let progress = progressHandler
        lock.unlock()

        progress?(Double(current) / Double(steps))
        if current >= steps {
            finish(.success("report.pdf (\(steps * 512) KB)"))
        }
    }

    /// Calls the completion handler exactly once.
    private func finish(_ result: Result<String, any Error>) {
        lock.lock()
        let completion = self.completion
        let timer = self.timer
        self.completion = nil
        self.progressHandler = nil
        self.timer = nil
        lock.unlock()

        timer?.cancel()
        completion?(result)
    }
}

/// The async/await wrapper.
///
/// - `withCheckedThrowingContinuation` turns the completion handler into an `await`.
/// - `withTaskCancellationHandler` makes it cancellable: when the Swift task is cancelled,
///   `onCancel` runs *immediately* (on whatever thread called `cancel()`), and we use it
///   to stop the legacy operation, which then resumes the continuation with an error.
nonisolated func legacyDownload(progress: @escaping @Sendable (Double) -> Void) async throws -> String {
    let operation = LegacyDownloadOperation()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            operation.start(progress: progress) { result in
                continuation.resume(with: result)
            }
        }
    } onCancel: {
        operation.cancel()
    }
}

/// A delay that ignores cancellation (like many older APIs), used to show
/// what happens when code doesn't cooperate.
nonisolated func uncancellableDelay(seconds: Double) async {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
            continuation.resume()
        }
    }
}
