//
//  PhotoService.swift
//  SwiftConcurrency
//

import Foundation

/// Abstraction over the photo list API so view models can be tested with a mock.
nonisolated protocol PhotoServiceProtocol: Sendable {
    func fetchPhotos(page: Int, limit: Int) async throws -> [Photo]
}

nonisolated struct PhotoService: PhotoServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// `@concurrent` runs the request + JSON decoding on the global executor, not the main actor.
    @concurrent
    func fetchPhotos(page: Int = 1, limit: Int = 30) async throws -> [Photo] {
        var components = URLComponents(string: "https://picsum.photos/v2/list")!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([Photo].self, from: data)
    }
}
