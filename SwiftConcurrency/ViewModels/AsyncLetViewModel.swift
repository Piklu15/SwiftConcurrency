//
//  AsyncLetViewModel.swift
//  SwiftConcurrency
//

import Foundation
import Observation

@Observable
final class AsyncLetViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case sequential = "Sequential await"
        case asyncLet = "async let"

        var id: Self { self }
    }

    var shouldFailStats = false

    private(set) var runningMode: Mode?
    private(set) var profile: UserProfile?
    private(set) var stats: UserStats?
    private(set) var notifications: NotificationSummary?
    private(set) var errorMessage: String?
    /// Last total time for each mode, so the two can be compared side by side.
    private(set) var durations: [Mode: Double] = [:]

    let timeline = TimelineRecorder()
    private let service = DashboardService()

    var isRunning: Bool { runningMode != nil }

    func run(_ mode: Mode) async {
        guard !isRunning else { return }
        runningMode = mode
        profile = nil
        stats = nil
        notifications = nil
        errorMessage = nil
        timeline.start()

        do {
            switch mode {
            case .sequential: try await loadSequentially()
            case .asyncLet: try await loadWithAsyncLet()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        timeline.stop()
        durations[mode] = timeline.currentTime
        runningMode = nil
    }

    /// Each `await` suspends until that request finishes before the next one starts.
    /// Total time ≈ 1 + 1.5 + 2 = 4.5 s.
    private func loadSequentially() async throws {
        let service = self.service
        let shouldFail = shouldFailStats

        profile = try await timed("Profile", on: timeline) { try await service.fetchProfile() }
        stats = try await timed("Stats", on: timeline) { try await service.fetchStats(shouldFail: shouldFail) }
        notifications = try await timed("Notifications", on: timeline) { try await service.fetchNotifications() }
    }

    /// `async let` starts each request immediately as a child task, so all three run
    /// at the same time. Total time ≈ the slowest one = 2 s.
    ///
    /// If one child throws, the error propagates out of the `try await`, and Swift
    /// automatically cancels (and waits for) the other children still running.
    private func loadWithAsyncLet() async throws {
        // Copy what the child tasks need into local constants, so they don't
        // have to reach back into this main-actor object.
        let service = self.service
        let timeline = self.timeline
        let shouldFail = shouldFailStats

        async let profile = timed("Profile", on: timeline) { try await service.fetchProfile() }
        async let stats = timed("Stats", on: timeline) { try await service.fetchStats(shouldFail: shouldFail) }
        async let notifications = timed("Notifications", on: timeline) { try await service.fetchNotifications() }

        // Nothing is awaited until here – all three are already running.
        let (loadedProfile, loadedStats, loadedNotifications) = try await (profile, stats, notifications)

        self.profile = loadedProfile
        self.stats = loadedStats
        self.notifications = loadedNotifications
    }
}
