//
//  PhotoRowViewModel.swift
//  SwiftConcurrency
//

import UIKit
import Observation

@Observable
final class PhotoRowViewModel {
    enum ImageState {
        case loading
        case loaded(UIImage)
        case failed
    }

    let photo: Photo
    private(set) var imageState: ImageState = .loading

    private let imageLoader: ImageLoader

    init(photo: Photo, imageLoader: ImageLoader = .shared) {
        self.photo = photo
        self.imageLoader = imageLoader
    }

    var authorName: String { photo.author }
    var sizeDescription: String { "\(photo.width) × \(photo.height)" }

    func loadImage() async {
        if case .loaded = imageState { return }
        imageState = .loading
        do {
            let image = try await imageLoader.image(for: photo.thumbnailURL)
            imageState = .loaded(image)
        } catch is CancellationError {
            // Row scrolled off screen before finishing; it'll retry when it reappears.
        } catch {
            imageState = .failed
        }
    }
}
