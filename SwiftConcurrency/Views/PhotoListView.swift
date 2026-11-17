//
//  PhotoListView.swift
//  SwiftConcurrency
//

import SwiftUI

struct PhotoListView: View {
    @State private var viewModel = PhotoListViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Photos")
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading photos…")
        case .loaded(let photos):
            List(photos) { photo in
                PhotoRowView(photo: photo)
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.load()
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load photos", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    PhotoListView()
}
