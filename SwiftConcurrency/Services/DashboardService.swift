//
//  DashboardService.swift
//  SwiftConcurrency
//
//  A fake API with fixed delays so the timing difference between sequential
//  and `async let` loading is easy to see.
//

import Foundation

nonisolated struct UserProfile: Sendable {
    let name: String
    let handle: String
}

nonisolated struct UserStats: Sendable {
    let followers: Int
    let following: Int
    let posts: Int
}

nonisolated struct NotificationSummary: Sendable {
    let unread: Int
    let latest: String
}

nonisolated enum DashboardError: LocalizedError {
    case statsUnavailable

    var errorDescription: String? {
        "The stats server returned an error."
    }
}

nonisolated struct DashboardService: Sendable {
    static let profileDelay: Duration = .seconds(1)
    static let statsDelay: Duration = .seconds(1.5)
    static let notificationsDelay: Duration = .seconds(2)

    /// `@concurrent` = always runs on the global concurrent executor, never on the caller's actor.
    @concurrent
    func fetchProfile() async throws -> UserProfile {
        try await Task.sleep(for: Self.profileDelay)
        return UserProfile(name: "Taylor Appleseed", handle: "@taylor")
    }

    @concurrent
    func fetchStats(shouldFail: Bool) async throws -> UserStats {
        try await Task.sleep(for: Self.statsDelay)
        if shouldFail { throw DashboardError.statsUnavailable }
        return UserStats(followers: 1_284, following: 312, posts: 87)
    }

    @concurrent
    func fetchNotifications() async throws -> NotificationSummary {
        // `Task.sleep` throws `CancellationError` as soon as the task is cancelled,
        // which is what lets `async let` stop this early when a sibling fails.
        try await Task.sleep(for: Self.notificationsDelay)
        return NotificationSummary(unread: 5, latest: "Sam liked your photo")
    }
}
