//
//  PhotoListViewModel.swift
//  SwiftConcurrency
//

import Foundation
import Observation

@Observable
final class PhotoListViewModel {
    enum State {
        case idle
        case loading
        case loaded([Photo])
        case failed(String)
    }

    private(set) var state: State = .idle

    private let service: PhotoServiceProtocol

    init(service: PhotoServiceProtocol = PhotoService()) {
        self.service = service
    }

    /// Loads the list once; subsequent calls are ignored unless the previous load failed.
    func loadIfNeeded() async {
        switch state {
        case .idle, .failed: await load()
        case .loading, .loaded: break
        }
    }

    /// Fetches the photo list. Runs on the main actor; the network work itself
    /// happens off-main inside `PhotoService`.
    func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            let photos = try await service.fetchPhotos(page: 1, limit: 30)
            state = .loaded(photos)
        } catch is CancellationError {
            // View went away – leave state as is.
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
