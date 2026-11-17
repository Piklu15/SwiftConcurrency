//
//  Photo.swift
//  SwiftConcurrency
//

import Foundation

/// A photo returned by the Picsum list API (https://picsum.photos/v2/list).
/// `nonisolated` so it can be decoded and passed around off the main actor.
nonisolated struct Photo: Identifiable, Hashable, Decodable, Sendable {
    let id: String
    let author: String
    let width: Int
    let height: Int

    /// A small, row-sized version of the image (cheaper than the full-size `download_url`).
    var thumbnailURL: URL {
        URL(string: "https://picsum.photos/id/\(id)/400/300")!
    }
}
