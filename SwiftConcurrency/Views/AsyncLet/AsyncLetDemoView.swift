//
//  AsyncLetDemoView.swift
//  SwiftConcurrency
//

import SwiftUI

struct AsyncLetDemoView: View {
    @State private var viewModel = AsyncLetViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    introCard
                    controlsCard
                    dashboardCard
                    timelineCard
                    codeCard
                }
                .padding()
            }
            .navigationTitle("async let")
        }
    }

    private var introCard: some View {
        DemoCard(
            title: "What is async let?",
            systemImage: "arrow.triangle.branch",
            subtitle: "async let starts a child task right away and lets you await its result later. Use it when you know up front how many independent things to load, like the three requests on this dashboard."
        ) {
            EmptyView()
        }
    }

    private var controlsCard: some View {
        DemoCard(title: "Load the dashboard", systemImage: "play.circle") {
            Toggle("Make the Stats request fail", isOn: $viewModel.shouldFailStats)
                .disabled(viewModel.isRunning)

            Text("When this is on, watch the timeline: with async let, Notifications is cancelled the moment Stats throws.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(AsyncLetViewModel.Mode.allCases) { mode in
                Button {
                    Task { await viewModel.run(mode) }
                } label: {
                    HStack {
                        Text(mode == .sequential ? "Load one by one" : "Load with async let")
                        Spacer()
                        if viewModel.runningMode == mode {
                            ProgressView()
                        } else if let duration = viewModel.durations[mode] {
                            Text(String(format: "%.2fs", duration))
                                .monospacedDigit()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(mode == .sequential ? .gray : .accentColor)
                .disabled(viewModel.isRunning)
            }
        }
    }

    private var dashboardCard: some View {
        DemoCard(title: "Dashboard", systemImage: "person.crop.square") {
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            HStack(alignment: .top, spacing: 12) {
                tile(title: "Profile", symbol: "person.fill", isLoaded: viewModel.profile != nil) {
                    Text(viewModel.profile?.name ?? "Placeholder Name")
                        .font(.subheadline.bold())
                    Text(viewModel.profile?.handle ?? "@handle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                tile(title: "Stats", symbol: "chart.bar.fill", isLoaded: viewModel.stats != nil) {
                    Text("\(viewModel.stats?.followers ?? 0) followers")
                        .font(.subheadline.bold())
                    Text("\(viewModel.stats?.posts ?? 0) posts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                tile(title: "Inbox", symbol: "bell.fill", isLoaded: viewModel.notifications != nil) {
                    Text("\(viewModel.notifications?.unread ?? 0) unread")
                        .font(.subheadline.bold())
                    Text(viewModel.notifications?.latest ?? "Latest notification")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func tile<Content: View>(
        title: String,
        symbol: String,
        isLoaded: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.tint)
            content()
                .redacted(reason: isLoaded ? [] : .placeholder)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .animation(.default, value: isLoaded)
    }

    private var timelineCard: some View {
        DemoCard(
            title: "Timeline",
            systemImage: "chart.bar.xaxis",
            subtitle: "Sequential: bars follow each other (~4.5 s). async let: bars overlap (~2 s, the slowest request)."
        ) {
            TimelineChartView(recorder: viewModel.timeline, minimumDuration: 4.5)
        }
    }

    private var codeCard: some View {
        DemoCard(title: "The code", systemImage: "chevron.left.forwardslash.chevron.right") {
            Text("Sequential")
                .font(.subheadline.bold())
            CodeSnippetView(code: """
            let profile = try await api.fetchProfile()
            let stats = try await api.fetchStats()
            let inbox = try await api.fetchNotifications()
            """)

            Text("Concurrent with async let")
                .font(.subheadline.bold())
            CodeSnippetView(code: """
            async let profile = api.fetchProfile()
            async let stats = api.fetchStats()
            async let inbox = api.fetchNotifications()

            // All three are already running.
            let (p, s, n) = try await (profile, stats, inbox)
            """)

            Text("Rules to remember: each async let is a child task with structured lifetime. Leaving the scope without awaiting it cancels it. If you await one and it throws, the other children are cancelled automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AsyncLetDemoView()
}
