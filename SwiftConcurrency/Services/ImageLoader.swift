//
//  ImageLoader.swift
//  SwiftConcurrency
//

import UIKit

/// Downloads images with async/await.
///
/// Being an `actor` makes the cache and the in-flight table safe to touch from many
/// rows at once. Concurrent requests for the same URL share a single download.
actor ImageLoader {
    static let shared = ImageLoader()

    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 200
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        // Someone is already downloading this URL – just await their result.
        if let existing = inFlight[url] {
            return try await existing.value
        }

        let session = self.session
        let task = Task<UIImage, Error> {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            guard let image = UIImage(data: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            // Decode the bitmap now (off the main thread) so scrolling stays smooth.
            return await image.byPreparingForDisplay() ?? image
        }
        inFlight[url] = task

        do {
            let image = try await task.value
            cache.setObject(image, forKey: url as NSURL)
            inFlight[url] = nil
            return image
        } catch {
            inFlight[url] = nil
            throw error
        }
    }
}
