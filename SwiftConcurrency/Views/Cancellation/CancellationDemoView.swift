//
//  CancellationDemoView.swift
//  SwiftConcurrency
//

import SwiftUI

struct CancellationDemoView: View {
    @State private var viewModel = CancellationViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    introCard
                    cooperativeCard
                    handlerCard
                    searchCard
                    logCard
                }
                .padding()
            }
            .navigationTitle("Cancellation")
        }
        // Restarts (and cancels the previous run) every time the query changes.
        .task(id: viewModel.query) {
            await viewModel.search(viewModel.query)
        }
    }

    private var introCard: some View {
        DemoCard(
            title: "Cancellation is cooperative",
            systemImage: "xmark.octagon",
            subtitle: "task.cancel() never stops a task by force. It only sets a flag. Your code has to check it with Task.isCancelled or try Task.checkCancellation(), or call APIs like Task.sleep and URLSession that check it for you."
        ) {
            EmptyView()
        }
    }

    // MARK: 1

    private var cooperativeCard: some View {
        DemoCard(title: "1. Checking for cancellation", systemImage: "hand.raised") {
            @Bindable var viewModel = viewModel

            Toggle("Job checks for cancellation", isOn: $viewModel.respectsCancellation)
                .disabled(viewModel.jobState == .running)

            ProgressView(value: Double(viewModel.jobStep), total: Double(viewModel.totalSteps)) {
                HStack {
                    Text("Step \(viewModel.jobStep) of \(viewModel.totalSteps)")
                    Spacer()
                    stateLabel(viewModel.jobState)
                }
                .font(.caption)
            }
            .tint(viewModel.jobState == .cancelled ? .orange : .accentColor)

            startCancelButtons(
                isRunning: viewModel.jobState == .running,
                start: viewModel.startJob,
                cancel: viewModel.cancelJob
            )

            CodeSnippetView(code: """
            for step in 1...10 {
                try Task.checkCancellation()   // throws if cancelled
                try await Task.sleep(for: .milliseconds(400))
                progress = step
            }
            """)

            Text("Turn the toggle off, start, then cancel. The job ignores the flag and runs to the end. Also watch out for `try? await Task.sleep(...)`: it swallows the CancellationError.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 2

    private var handlerCard: some View {
        DemoCard(
            title: "2. withTaskCancellationHandler",
            systemImage: "bolt.horizontal",
            subtitle: "Wraps an old callback API that has its own cancel(). The handler runs the moment the task is cancelled, even while the task is suspended waiting for the callback."
        ) {
            ProgressView(value: viewModel.legacyProgress) {
                HStack {
                    Text(viewModel.legacyResult ?? "Legacy download")
                    Spacer()
                    stateLabel(viewModel.legacyState)
                }
                .font(.caption)
            }
            .tint(viewModel.legacyState == .cancelled ? .orange : .accentColor)

            startCancelButtons(
                isRunning: viewModel.legacyState == .running,
                start: viewModel.startLegacyDownload,
                cancel: viewModel.cancelLegacyDownload
            )

            CodeSnippetView(code: """
            let op = LegacyDownloadOperation()
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { cont in
                    op.start { result in cont.resume(with: result) }
                }
            } onCancel: {
                op.cancel()   // runs immediately, on any thread
            }
            """)
        }
    }

    // MARK: 3

    private var searchCard: some View {
        DemoCard(
            title: "3. Automatic cancellation with .task(id:)",
            systemImage: "magnifyingglass",
            subtitle: "Type quickly. Each keystroke changes the id, so SwiftUI cancels the previous search task and starts a new one. Combined with Task.sleep this gives you a debounce. Leaving the screen cancels it too."
        ) {
            @Bindable var viewModel = viewModel

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search countries", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if viewModel.isSearching {
                    ProgressView()
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            if !viewModel.searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.searchResults.prefix(6), id: \.self) { country in
                        Text(country).font(.subheadline)
                    }
                    if viewModel.searchResults.count > 6 {
                        Text("+ \(viewModel.searchResults.count - 6) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            CodeSnippetView(code: """
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(400)) // debounce
                guard !Task.isCancelled else { return }
                results = await api.search(query)
            }
            """)
        }
    }

    // MARK: Log

    private var logCard: some View {
        DemoCard(title: "Event log", systemImage: "list.bullet.rectangle") {
            EventLogView(log: viewModel.log)
            if !viewModel.log.entries.isEmpty {
                Button("Clear log", role: .destructive) {
                    viewModel.log.clear()
                }
                .font(.caption)
            }
        }
    }

    // MARK: Helpers

    private func startCancelButtons(
        isRunning: Bool,
        start: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) -> some View {
        HStack {
            Button(action: start) {
                Label("Start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)

            Button(role: .destructive, action: cancel) {
                Label("Cancel", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!isRunning)
        }
    }

    @ViewBuilder
    private func stateLabel(_ state: CancellationViewModel.JobState) -> some View {
        switch state {
        case .idle: Text("Idle").foregroundStyle(.secondary)
        case .running: Text("Running…").foregroundStyle(.blue)
        case .finished: Text("Finished").foregroundStyle(.green)
        case .cancelled: Text("Cancelled").foregroundStyle(.orange)
        }
    }
}

#Preview {
    CancellationDemoView()
}
