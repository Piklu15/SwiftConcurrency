//
//  ImageDownloader.swift
//  SwiftConcurrency
//

import UIKit

/// Downloads an image every time, with no caching, so the TaskGroup demo shows real
/// network timings on every run. (The app's `ImageLoader` caches, which is what you
/// want in production but would make repeated demo runs instant.)
nonisolated struct ImageDownloader: Sendable {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    @concurrent
    func download(from url: URL) async throws -> UIImage {
        // URLSession is cancellation-aware: cancelling the task cancels the request
        // and throws `URLError(.cancelled)`.
        let (data, response) = try await Self.session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        return await image.byPreparingForDisplay() ?? image
    }
}
