//
//  TaskGroupDemoView.swift
//  SwiftConcurrency
//

import SwiftUI

struct TaskGroupDemoView: View {
    @State private var viewModel = TaskGroupViewModel()

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    introCard
                    controlsCard
                    gridCard
                    timelineCard
                    codeCard
                }
                .padding()
            }
            .navigationTitle("TaskGroup")
        }
    }

    private var introCard: some View {
        DemoCard(
            title: "What is a TaskGroup?",
            systemImage: "square.grid.3x3",
            subtitle: "Use a task group when the number of child tasks is only known at runtime, for example one download per photo. Results come back in the order they finish, and you can limit how many run at once."
        ) {
            EmptyView()
        }
    }

    private var controlsCard: some View {
        DemoCard(title: "Download photos", systemImage: "arrow.down.circle") {
            @Bindable var viewModel = viewModel

            Stepper("Images: \(viewModel.imageCount)", value: $viewModel.imageCount, in: 3...15)
                .onChange(of: viewModel.imageCount) { _, newValue in
                    viewModel.maxConcurrent = min(viewModel.maxConcurrent, newValue)
                }
                .disabled(viewModel.isRunning)
            Stepper("Max at once: \(viewModel.maxConcurrent)", value: $viewModel.maxConcurrent, in: 1...viewModel.imageCount)
                .disabled(viewModel.isRunning)

            Text("Try 1 (sequential) vs. all images at once and compare the timeline.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    viewModel.start()
                } label: {
                    Label("Download", systemImage: "arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)

                Button(role: .destructive) {
                    viewModel.cancel()
                } label: {
                    Label("Cancel group", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isRunning)
            }

            HStack(spacing: 8) {
                if viewModel.isRunning { ProgressView() }
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var gridCard: some View {
        DemoCard(
            title: "Results",
            systemImage: "photo.on.rectangle",
            subtitle: "The badge shows the order each download finished in."
        ) {
            if viewModel.slots.isEmpty {
                Text("No downloads yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.slots) { slot in
                        SlotView(slot: slot)
                    }
                }
            }
        }
    }

    private var timelineCard: some View {
        DemoCard(title: "Timeline", systemImage: "chart.bar.xaxis") {
            TimelineChartView(recorder: viewModel.timeline, minimumDuration: 1, rowHeight: 12, labelWidth: 64)
        }
    }

    private var codeCard: some View {
        DemoCard(title: "The code", systemImage: "chevron.left.forwardslash.chevron.right") {
            CodeSnippetView(code: """
            await withTaskGroup(of: (Int, UIImage?).self) { group in
                for (i, photo) in photos.enumerated() {
                    group.addTask {
                        (i, try? await download(photo.url))
                    }
                }
                // Results arrive as each child finishes.
                for await (i, image) in group {
                    images[i] = image
                }
            }
            """)

            Text("Limiting concurrency (sliding window)")
                .font(.subheadline.bold())
            CodeSnippetView(code: """
            var next = 0
            while next < maxConcurrent {        // start the first N
                group.addTask(operation: job(next)); next += 1
            }
            for await result in group {         // one finished,
                handle(result)
                if next < photos.count {        // start one more
                    group.addTaskUnlessCancelled(operation: job(next))
                    next += 1
                }
            }
            """)

            Text("The group can't return until every child has finished. Cancelling the task that owns the group cancels all of its children.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SlotView: View {
    let slot: TaskGroupViewModel.Slot

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if let badge {
                Text(badge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(6)
            }
        }
        .animation(.default, value: badge)
    }

    @ViewBuilder
    private var content: some View {
        switch slot.state {
        case .pending:
            placeholder(symbol: "clock", text: "Waiting")
        case .downloading:
            ZStack {
                Color.secondary.opacity(0.15)
                ProgressView()
            }
        case .loaded(let image, _):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        case .failed:
            placeholder(symbol: "exclamationmark.triangle", text: "Failed")
        case .cancelled:
            placeholder(symbol: "stop.circle", text: "Cancelled")
        }
    }

    private var badge: String? {
        switch slot.state {
        case .loaded(_, let order), .failed(let order): "#\(order)"
        default: nil
        }
    }

    private func placeholder(symbol: String, text: String) -> some View {
        ZStack {
            Color.secondary.opacity(0.15)
            VStack(spacing: 4) {
                Image(systemName: symbol)
                Text(text).font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    TaskGroupDemoView()
}
