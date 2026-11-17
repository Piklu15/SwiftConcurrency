//
//  PhotoRowView.swift
//  SwiftConcurrency
//

import SwiftUI

struct PhotoRowView: View {
    @State private var viewModel: PhotoRowViewModel

    init(photo: Photo) {
        _viewModel = State(initialValue: PhotoRowViewModel(photo: photo))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            imageView
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(viewModel.authorName)
                .font(.headline)
            Text(viewModel.sizeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        // `.task` starts when the row appears and is cancelled automatically when it disappears.
        .task {
            await viewModel.loadImage()
        }
    }

    @ViewBuilder
    private var imageView: some View {
        switch viewModel.imageState {
        case .loading:
            ZStack {
                Color.secondary.opacity(0.15)
                ProgressView()
            }
        case .loaded(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .transition(.opacity)
        case .failed:
            ZStack {
                Color.secondary.opacity(0.15)
                Button {
                    Task { await viewModel.loadImage() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

//#Preview("Single row") {
//    PhotoRowView(photo: .sample)
//        .padding()
//}

//#Preview("In a list") {
//    List(Photo.samples) { photo in
//        PhotoRowView(photo: photo)
//    }
//    .listStyle(.plain)
//}

#Preview("Failed image") {
    // An id Picsum doesn't have, so the download fails and the Retry state shows.
    PhotoRowView(photo: Photo(id: "999999", author: "Missing Image", width: 0, height: 0))
        .padding()
}

extension Photo {
    static let sample = Photo(id: "0", author: "Alejandro Escamilla", width: 5000, height: 3333)

    static let samples: [Photo] = [
        sample,
        Photo(id: "10", author: "Paul Jarvis", width: 2500, height: 1667),
        Photo(id: "20", author: "Aleks Dorohovich", width: 3670, height: 2462)
    ]
}

