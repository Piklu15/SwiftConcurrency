//
//  CancellationViewModel.swift
//  SwiftConcurrency
//

import Foundation
import Observation

@Observable
final class CancellationViewModel {
    enum JobState: Equatable {
        case idle
        case running
        case finished
        case cancelled
    }

    let log = EventLog()

    // MARK: 1. Cooperative cancellation

    var respectsCancellation = true
    let totalSteps = 10
    private(set) var jobStep = 0
    private(set) var jobState: JobState = .idle
    private var jobTask: Task<Void, Never>?

    func startJob() {
        guard jobState != .running else { return }
        let cooperative = respectsCancellation
        jobTask = Task { await runJob(cooperative: cooperative) }
    }

    func cancelJob() {
        // cancel() does NOT stop the task. It only sets a flag that the task must check.
        jobTask?.cancel()
        log.add("jobTask.cancel() called → Task.isCancelled is now true", .warning)
    }

    private func runJob(cooperative: Bool) async {
        jobState = .running
        jobStep = 0
        log.add("Job started (\(cooperative ? "checks" : "ignores") cancellation)")

        do {
            for step in 1...totalSteps {
                if cooperative {
                    // Throws CancellationError if the task was cancelled.
                    try Task.checkCancellation()
                    // Task.sleep is also cancellation-aware and throws right away.
                    try await Task.sleep(for: .milliseconds(400))
                } else {
                    // Ignores cancellation completely.
                    await uncancellableDelay(seconds: 0.4)
                    if Task.isCancelled {
                        log.add("Step \(step): cancelled, but this job keeps working", .error)
                    }
                }
                jobStep = step
            }
            jobState = .finished
            log.add("Job finished all \(totalSteps) steps", .success)
        } catch {
            jobState = .cancelled
            log.add("Job stopped at step \(jobStep)/\(totalSteps): CancellationError thrown", .success)
        }
    }

    // MARK: 2. withTaskCancellationHandler

    private(set) var legacyProgress = 0.0
    private(set) var legacyState: JobState = .idle
    private(set) var legacyResult: String?
    private var legacyTask: Task<Void, Never>?

    func startLegacyDownload() {
        guard legacyState != .running else { return }
        legacyTask = Task {
            legacyState = .running
            legacyProgress = 0
            legacyResult = nil
            log.add("Legacy download started")

            do {
                // The progress callback arrives on a background queue; hop to the main actor.
                // (A @MainActor class is Sendable, so capturing `self` here is allowed.)
                let file = try await legacyDownload { progress in
                    Task { @MainActor in
                        if self.legacyState == .running { self.legacyProgress = progress }
                    }
                }
                legacyResult = file
                legacyState = .finished
                log.add("Legacy download finished: \(file)", .success)
            } catch {
                legacyState = .cancelled
                log.add("onCancel stopped the legacy operation → continuation resumed with CancellationError", .success)
            }
        }
    }

    func cancelLegacyDownload() {
        log.add("legacyTask.cancel() called → onCancel handler runs immediately", .warning)
        legacyTask?.cancel()
    }

    // MARK: 3. Automatic cancellation with .task(id:)

    var query = ""
    private(set) var searchResults: [String] = []
    private(set) var isSearching = false

    /// Called from `.task(id: query)`. Every time `query` changes SwiftUI cancels the
    /// previous call and starts a new one, so we get debouncing for free.
    func search(_ text: String) async {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        do {
            // Debounce: if the user types again within 400 ms, this sleep throws.
            try await Task.sleep(for: .milliseconds(400))

            isSearching = true
            log.add("Searching \"\(text)\"…")
            try await Task.sleep(for: .milliseconds(700)) // pretend network call

            searchResults = Self.countries.filter { $0.localizedCaseInsensitiveContains(text) }
            isSearching = false
            log.add("\"\(text)\" → \(searchResults.count) results", .success)
        } catch {
            // Don't touch isSearching here: the newer search that replaced us owns it now.
            log.add("Search for \"\(text)\" cancelled (query changed)", .warning)
        }
    }

    private static let countries = [
        "Argentina", "Australia", "Austria", "Bangladesh", "Belgium", "Bhutan", "Brazil",
        "Canada", "Chile", "China", "Colombia", "Denmark", "Egypt", "Finland", "France",
        "Germany", "Greece", "India", "Indonesia", "Ireland", "Italy", "Japan", "Kenya",
        "Malaysia", "Maldives", "Mexico", "Nepal", "Netherlands", "New Zealand", "Nigeria",
        "Norway", "Pakistan", "Peru", "Philippines", "Portugal", "Singapore", "South Africa",
        "South Korea", "Spain", "Sri Lanka", "Sweden", "Switzerland", "Thailand", "Turkey",
        "United Kingdom", "United States", "Vietnam"
    ]
}
