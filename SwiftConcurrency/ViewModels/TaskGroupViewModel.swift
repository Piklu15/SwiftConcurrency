//
//  TaskGroupViewModel.swift
//  SwiftConcurrency
//

import UIKit
import Observation

@Observable
final class TaskGroupViewModel {
    enum SlotState {
        case pending
        case downloading
        case loaded(UIImage, order: Int)
        case failed(order: Int)
        case cancelled
    }

    struct Slot: Identifiable {
        let id: Int
        var author: String?
        var state: SlotState = .pending
    }

    /// The child task's result: which slot it was for, and what happened.
    private typealias DownloadResult = (index: Int, result: Result<UIImage, any Error>)

    var imageCount = 9
    var maxConcurrent = 3

    private(set) var slots: [Slot] = []
    private(set) var isRunning = false
    private(set) var statusMessage = "Tap Download to start."

    let timeline = TimelineRecorder()

    private let photoService: PhotoServiceProtocol
    private let downloader = ImageDownloader()
    private var runTask: Task<Void, Never>?

    init(photoService: PhotoServiceProtocol = PhotoService()) {
        self.photoService = photoService
    }

    func start() {
        guard !isRunning else { return }
        runTask = Task { await run() }
    }

    /// Cancelling the parent task cancels the task group and therefore every child in it.
    func cancel() {
        runTask?.cancel()
    }

    private func run() async {
        isRunning = true
        defer { isRunning = false }

        timeline.start()
        slots = (0..<imageCount).map { Slot(id: $0) }
        statusMessage = "Fetching photo list…"

        let photos: [Photo]
        do {
            photos = try await photoService.fetchPhotos(page: Int.random(in: 1...30), limit: imageCount)
        } catch {
            timeline.stop()
            statusMessage = isCancellation(error) ? "Cancelled." : "Couldn't load the list: \(error.localizedDescription)"
            return
        }

        for (index, photo) in photos.enumerated() where slots.indices.contains(index) {
            slots[index].author = photo.author
        }
        statusMessage = "Downloading…"

        // Restart the clock so the timeline shows just the image downloads.
        timeline.start()
        let succeeded = await downloadAll(photos)
        timeline.stop()

        let seconds = String(format: "%.2f", timeline.currentTime)
        if Task.isCancelled {
            statusMessage = "Cancelled after \(seconds)s. \(succeeded) of \(photos.count) finished."
        } else {
            statusMessage = "Downloaded \(succeeded) of \(photos.count) in \(seconds)s (max \(maxConcurrent) at a time)."
        }
    }

    /// Downloads every photo in a task group, keeping at most `maxConcurrent` downloads in flight.
    /// Returns how many succeeded.
    private func downloadAll(_ photos: [Photo]) async -> Int {
        let downloader = self.downloader
        let timeline = self.timeline
        let limit = max(1, min(maxConcurrent, photos.count))

        // Adds one child task to the group. Child tasks aren't tied to the main actor;
        // they run on the global concurrent executor. Returns false if the group was
        // already cancelled (`addTaskUnlessCancelled` won't start new work then).
        func addDownload(_ index: Int, to group: inout TaskGroup<DownloadResult>) -> Bool {
            let url = photos[index].thumbnailURL
            return group.addTaskUnlessCancelled {
                do {
                    let image = try await timed("Image \(index + 1)", on: timeline) {
                        try await downloader.download(from: url)
                    }
                    return (index, .success(image))
                } catch {
                    return (index, .failure(error))
                }
            }
        }

        var succeeded = 0
        var completionOrder = 0

        // Each child returns a Result instead of throwing, so one failed image
        // doesn't tear down the whole group.
        await withTaskGroup(of: DownloadResult.self) { group in
            var nextIndex = 0

            // 1. Start the first `limit` downloads.
            while nextIndex < limit {
                if addDownload(nextIndex, to: &group) {
                    slots[nextIndex].state = .downloading
                }
                nextIndex += 1
            }

            // 2. Results arrive in *completion* order, not the order tasks were added.
            for await (index, result) in group {
                completionOrder += 1
                switch result {
                case .success(let image):
                    succeeded += 1
                    slots[index].state = .loaded(image, order: completionOrder)
                case .failure(let error) where isCancellation(error):
                    slots[index].state = .cancelled
                case .failure:
                    slots[index].state = .failed(order: completionOrder)
                }

                // 3. One finished, so start the next one (a sliding window).
                if nextIndex < photos.count {
                    if addDownload(nextIndex, to: &group) {
                        slots[nextIndex].state = .downloading
                    }
                    nextIndex += 1
                }
            }
        }

        return succeeded
    }
}
