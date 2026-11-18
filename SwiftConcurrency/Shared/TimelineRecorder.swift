//
//  TimelineRecorder.swift
//  SwiftConcurrency
//

import Foundation
import Observation

nonisolated enum TimelineOutcome: Sendable {
    case running
    case success
    case failed
    case cancelled
}

/// One bar on the timeline: when a unit of work started, when it ended and how.
nonisolated struct TimelineEntry: Identifiable, Sendable {
    let id: Int
    let label: String
    let start: Double
    var end: Double?
    var outcome: TimelineOutcome = .running
}

/// Records when concurrent pieces of work start and finish so the UI can draw them
/// as bars. Overlapping bars = work that really ran at the same time.
///
/// It lives on the main actor (the project's default isolation), so child tasks
/// running elsewhere report to it with `await`.
@Observable
final class TimelineRecorder {
    private(set) var entries: [TimelineEntry] = []
    private(set) var isRecording = false
    private var origin = ContinuousClock.now
    private var stoppedAt: Double?

    /// Seconds since `start()`, frozen once `stop()` is called.
    var currentTime: Double {
        stoppedAt ?? (ContinuousClock.now - origin).seconds
    }

    func start() {
        entries = []
        origin = .now
        stoppedAt = nil
        isRecording = true
    }

    func stop() {
        stoppedAt = currentTime
        isRecording = false
    }

    func begin(_ label: String) -> Int {
        let id = entries.count
        entries.append(TimelineEntry(id: id, label: label, start: currentTime))
        return id
    }

    func end(_ id: Int, outcome: TimelineOutcome) {
        guard entries.indices.contains(id), entries[id].end == nil else { return }
        entries[id].end = currentTime
        entries[id].outcome = outcome
    }
}

/// Runs `operation` and records its start, end and outcome on `recorder`.
///
/// `nonisolated` (and, with Approachable Concurrency, implicitly `nonisolated(nonsending)`),
/// so it runs on whatever executor the caller is on – a child task's executor when called
/// from `async let` or a task group.
nonisolated func timed<T: Sendable>(
    _ label: String,
    on recorder: TimelineRecorder,
    operation: () async throws -> T
) async throws -> T {
    let id = await recorder.begin(label)
    do {
        let value = try await operation()
        await recorder.end(id, outcome: .success)
        return value
    } catch {
        await recorder.end(id, outcome: isCancellation(error) ? .cancelled : .failed)
        throw error
    }
}
