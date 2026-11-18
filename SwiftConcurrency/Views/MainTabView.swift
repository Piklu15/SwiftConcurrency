//
//  MainTabView.swift
//  SwiftConcurrency
//

import SwiftUI

/// One tab per Swift concurrency topic.
struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Photos", systemImage: "photo.on.rectangle") {
                PhotoListView()
            }
            Tab("async let", systemImage: "arrow.triangle.branch") {
                AsyncLetDemoView()
            }
            Tab("TaskGroup", systemImage: "square.grid.3x3") {
                TaskGroupDemoView()
            }
            Tab("Detached", systemImage: "cpu") {
                DetachedTaskDemoView()
            }
            Tab("Cancel", systemImage: "xmark.octagon") {
                CancellationDemoView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
